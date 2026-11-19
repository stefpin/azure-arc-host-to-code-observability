// =============================================================================================
// minibank-api  -  ASP.NET Core minimal API (.NET 10), hosted in IIS on APP-WIN (192.168.110.31:8080)
//   * serves the React page minibank-web from wwwroot (same IIS site)
//   * reads customers/accounts and writes transfers in SQL Server (MiniBankDemo on APP-SQL)
//   * calls minibank-transfer (Java on OpenShift) through its Route
//   * sends traces, metrics and logs to Application Insights appi-minibank
//   * v1.4 (P1): business tags on the request spans (Application Insights customDimensions = AppRequests.Properties):
//     minibank.trafficSource on every /api/ request; minibank.userId, minibank.tier and enduser.id where the customer is
//     known; minibank.channel, minibank.amountIdr, minibank.amountBand and minibank.outcome on Transfer and QRIS
// DEMO ONLY: synthetic data, no real authentication. Never log full account numbers.
// =============================================================================================
using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Data.SqlClient;
using OpenTelemetry;
using OpenTelemetry.Resources;

const string AppVersion = "1.2.0";
const string ScenarioHeader = "X-MiniBank-Scenario";   // the scenario travels as this header AND as JSON field "scenario"
const string SourceHeader = "X-MiniBank-Source";       // v1.4 traffic-source label: people, robot, traffic, probe (else unknown)
const decimal MaxAmount = 500_000_000m;               // largest amount the demo accepts (IDR)

var builder = WebApplication.CreateBuilder(args);

// ---- 1. Telemetry (Azure Monitor OpenTelemetry distro) ---------------------------------------
// The connection string comes ONLY from the environment variable APPLICATIONINSIGHTS_CONNECTION_STRING
// (machine variable on APP-WIN). "minibank-api" becomes the cloud role name in Application Insights.
var telemetryOn = !string.IsNullOrWhiteSpace(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]);
var otel = builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("minibank-api", serviceVersion: AppVersion));
if (telemetryOn)
{
    otel.UseAzureMonitor();   // requests, SQL + HTTP dependencies, exceptions and logs
}

// ---- 2. HTTP client for minibank-transfer (Java on OpenShift, plain HTTP Route in the lab) -----
builder.Services.AddHttpClient("transfer", c =>
{
    c.BaseAddress = new Uri(builder.Configuration["TransferService:BaseUrl"]
        ?? throw new InvalidOperationException("TransferService:BaseUrl is missing in appsettings.json"));
    c.Timeout = TimeSpan.FromSeconds(20);   // the slowest scenario chain takes about 4 seconds
});

var app = builder.Build();
var log = app.Logger;

// ---- 3. Settings from appsettings.json -------------------------------------------------------
var connStr = app.Configuration.GetConnectionString("MiniBank")
    ?? throw new InvalidOperationException("ConnectionStrings:MiniBank is missing in appsettings.json");
var demoPassword = app.Configuration["Demo:Password"] ?? "Demo123!";   // demo value, documented in the runbook
var demoPin = app.Configuration["Demo:Pin"] ?? "123456";               // demo value, documented in the runbook
var scenarios = new[] { "normal", "slow-sql", "slow-oracle", "slow-python", "slow-postgres",
                        "fail-oracle", "fail-java", "fail-python", "fail-api" };
var trafficSources = new[] { "people", "robot", "traffic", "probe", "unknown" };   // v1.4 labels of X-MiniBank-Source
var accountNoPattern = new Regex(@"^\d{10}$");
var userIdPattern = new Regex(@"^[A-Z0-9._-]{1,30}$");                            // v1.4: only such values become a tag
var customerDirectory = new CustomerDirectory(connStr, log);                      // v1.4: User ID + tier per account
app.Lifetime.ApplicationStarted.Register(customerDirectory.StartRefresh);
var jsonWeb = new JsonSerializerOptions(JsonSerializerDefaults.Web);
var merchants = new Merchant[]   // 5 fictional QRIS merchants (static list, no database)
{
    new("QR-0001", "Kopi Senja (Demo)", "Jakarta"),
    new("QR-0002", "Warung Nusantara (Demo)", "Bandung"),
    new("QR-0003", "Toko Buku Pelangi (Demo)", "Surabaya"),
    new("QR-0004", "Apotek Sehat (Demo)", "Yogyakarta"),
    new("QR-0005", "Bakmi Lestari (Demo)", "Semarang"),
};

// ---- 4. Middleware ---------------------------------------------------------------------------
// 4a. Send the W3C trace context back to the browser (header "traceparent"),
//     so the page can always show a Trace ID that can be pasted into Application Insights.
app.Use(async (ctx, next) =>
{
    var activity = Activity.Current;
    ctx.Response.OnStarting(() =>
    {
        if (activity is not null)
        {
            ctx.Response.Headers["traceparent"] = $"00-{activity.TraceId}-{activity.SpanId}-01";
        }
        return Task.CompletedTask;
    });
    await next(ctx);
});

// 4b. v1.4 traffic source: every /api/ request span gets the tag minibank.trafficSource from header X-MiniBank-Source
//     (people = web page default, robot = browser robot, traffic = traffic.ps1, probe = probe.ps1). A missing or unknown
//     value is recorded as "unknown" and is never rejected. Static files and the page itself carry no label.
app.Use(async (ctx, next) =>
{
    if (ctx.Request.Path.StartsWithSegments("/api"))
    {
        RequestSpan(ctx)?.SetTag("minibank.trafficSource", TrafficSourceOf(ctx));
    }
    await next(ctx);
});

// 4c. Every unhandled exception (for example scenario fail-api) becomes JSON {error, code, traceId}.
//     ASP.NET Core still logs the exception, so it appears in Application Insights (AppExceptions).
app.UseExceptionHandler(errorApp => errorApp.Run(async ctx =>
{
    var error = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;
    var span = RequestSpan(ctx);
    if (span is not null && span.GetTagItem("minibank.channel") is not null)
    {
        span.SetTag("minibank.outcome", "failed");   // v1.4: a payment that ended with an unhandled exception (HTTP 500)
    }
    ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;
    await ctx.Response.WriteAsJsonAsync(new { error = error?.Message ?? "Unexpected error", code = "UNHANDLED", traceId = TraceId() });
}));

// 4d. The React single-page application (Vite build output copied into wwwroot)
app.UseDefaultFiles();
app.UseStaticFiles();

// ---- 5. API endpoints ------------------------------------------------------------------------
app.MapGet("/api/health", () => Results.Ok(new { status = "ok", service = "minibank-api", version = AppVersion }));

// The browser SDK needs the connection string. It only allows SENDING telemetry, not reading it.
app.MapGet("/api/config", (IConfiguration cfg) => Results.Ok(new
{
    appInsightsConnectionString = cfg["APPLICATIONINSIGHTS_CONNECTION_STRING"] ?? "",
    appVersion = AppVersion,
}));

// Login: look up the customer by User ID in SQL Server; every demo user has the password Demo:Password.
app.MapPost("/api/login", async (LoginRequest req, HttpContext ctx) =>
{
    var userId = (req.UserId ?? "").Trim().ToUpperInvariant();
    var span = RequestSpan(ctx);
    if (userIdPattern.IsMatch(userId))
    {
        span?.SetTag("minibank.userId", userId);   // v1.4: the User ID that tries to log in (enduser.id only after success)
    }
    if (userId.Length == 0 || string.IsNullOrEmpty(req.Password))
    {
        return Error(400, "User ID and password are required.", "VALIDATION");
    }

    await using var conn = new SqlConnection(connStr);
    await conn.OpenAsync();
    await using var cmd = new SqlCommand("SELECT CustomerId, UserId, FullName FROM dbo.Customers WHERE UserId = @userId", conn);
    cmd.Parameters.AddWithValue("@userId", userId);
    await using var reader = await cmd.ExecuteReaderAsync();
    if (!await reader.ReadAsync() || req.Password != demoPassword)
    {
        log.LogWarning("Login failed for User ID {UserId}", userId);
        return Error(401, "Invalid User ID or password.", "LOGIN_FAILED");
    }

    var customer = new { customerId = reader.GetInt32(0), userId = reader.GetString(1), fullName = reader.GetString(2) };
    TagCustomer(span, customerDirectory.ByUserId(customer.userId) ?? new CustomerInfo(customer.customerId, customer.userId, null));
    log.LogInformation("Login successful for User ID {UserId}", userId);
    return Results.Ok(customer);
});

// Accounts of one customer (with balance), or all demo accounts without balance (transfer destinations).
app.MapGet("/api/accounts", async (int? customerId, HttpContext ctx) =>
{
    if (customerId is not null)
    {
        TagCustomer(RequestSpan(ctx), customerDirectory.ByCustomerId(customerId.Value));   // v1.4
    }
    var sql = customerId is null
        ? "SELECT a.AccountNo, a.CustomerId, c.FullName, a.ProductName, CAST(NULL AS decimal(18,2)) " +
          "FROM dbo.Accounts a JOIN dbo.Customers c ON c.CustomerId = a.CustomerId ORDER BY c.FullName, a.AccountNo"
        : "SELECT a.AccountNo, a.CustomerId, c.FullName, a.ProductName, a.Balance " +
          "FROM dbo.Accounts a JOIN dbo.Customers c ON c.CustomerId = a.CustomerId " +
          "WHERE a.CustomerId = @customerId ORDER BY a.AccountNo";

    await using var conn = new SqlConnection(connStr);
    await conn.OpenAsync();
    await using var cmd = new SqlCommand(sql, conn);
    if (customerId is not null)
    {
        cmd.Parameters.AddWithValue("@customerId", customerId.Value);
    }
    await using var reader = await cmd.ExecuteReaderAsync();
    var accounts = new List<AccountDto>();
    while (await reader.ReadAsync())
    {
        accounts.Add(new AccountDto(reader.GetString(0).Trim(), reader.GetInt32(1), reader.GetString(2),
            reader.GetString(3), reader.IsDBNull(4) ? null : reader.GetDecimal(4)));
    }
    return Results.Ok(accounts);
});

// Statement (last N days): the ledger lives in Oracle, so the API asks minibank-transfer.
app.MapGet("/api/accounts/{accountNo}/statement", async (string accountNo, int? days, HttpContext ctx, IHttpClientFactory http) =>
{
    var scenario = ScenarioOf(ctx, null);
    if (scenario is null) return Error(400, "Unknown scenario.", "VALIDATION");
    if (!accountNoPattern.IsMatch(accountNo)) return Error(400, "Account number must have 10 digits.", "VALIDATION");
    TagCustomer(RequestSpan(ctx), customerDirectory.ByAccount(accountNo));   // v1.4: owner of the account (in memory, no SQL call)
    if (scenario == "fail-api")
    {
        throw new InvalidOperationException("Simulated failure in minibank-api (fail-api) for Statement");
    }

    var period = Math.Clamp(days ?? 30, 1, 90);
    using var request = new HttpRequestMessage(HttpMethod.Get, $"/api/ledger/{accountNo}?days={period}");
    request.Headers.Add(ScenarioHeader, scenario);
    var (ok, body, failure) = await CallTransferServiceAsync(http, request);
    if (!ok)
    {
        log.LogWarning("Statement for account {Account} failed: {Failure}", Mask(accountNo), failure);
        return Error(502, failure ?? "minibank-transfer failed", "DOWNSTREAM_FAILED", new { downstream = Detail(body) });
    }
    return Results.Content(body, "application/json");
});

app.MapGet("/api/qris/merchants", () => Results.Ok(merchants));

// Transfer between two demo accounts.
app.MapPost("/api/transfer", async (TransferRequest req, HttpContext ctx, IHttpClientFactory http) =>
{
    var scenario = ScenarioOf(ctx, req.Scenario);
    if (scenario is null) return Error(400, "Unknown scenario.", "VALIDATION");
    if (!accountNoPattern.IsMatch(req.FromAccount ?? "") || !accountNoPattern.IsMatch(req.ToAccount ?? ""))
    {
        return Error(400, "Account numbers must have 10 digits.", "VALIDATION");
    }
    if (req.FromAccount == req.ToAccount) return Error(400, "Choose a different destination account.", "VALIDATION");

    var payment = new Payment("TRANSFER", req.FromAccount!, req.ToAccount, null, null, req.Amount, req.Note, req.Pin, scenario);
    return await ProcessPaymentAsync(payment, ctx, http);
});

// QRIS payment to one of the fictional merchants.
app.MapPost("/api/qris/pay", async (QrisPayRequest req, HttpContext ctx, IHttpClientFactory http) =>
{
    var scenario = ScenarioOf(ctx, req.Scenario);
    if (scenario is null) return Error(400, "Unknown scenario.", "VALIDATION");
    if (!accountNoPattern.IsMatch(req.FromAccount ?? "")) return Error(400, "Account number must have 10 digits.", "VALIDATION");
    var merchant = merchants.FirstOrDefault(m => m.MerchantId == req.MerchantId);
    if (merchant is null) return Error(400, "Unknown QRIS merchant.", "VALIDATION");

    var payment = new Payment("QRIS", req.FromAccount!, null, merchant.MerchantId, merchant.Name, req.Amount, null, req.Pin, scenario);
    return await ProcessPaymentAsync(payment, ctx, http);
});

// Unknown /api/... paths return JSON 404; every other path returns the SPA (hash routes such as #/home).
app.MapFallback("/api/{**path}", () => Error(404, "Unknown API path.", "NOT_FOUND"));
app.MapFallbackToFile("index.html");

if (!telemetryOn)
{
    log.LogWarning("APPLICATIONINSIGHTS_CONNECTION_STRING is not set: telemetry to Application Insights is OFF.");
}
app.Run();

// ---- 6. Helpers ------------------------------------------------------------------------------

// Shared flow for Transfer and QRIS:
// PIN -> fail-api -> balance check -> Transfers row PENDING -> slow-sql -> minibank-transfer -> SUCCESS / FAILED
async Task<IResult> ProcessPaymentAsync(Payment p, HttpContext ctx, IHttpClientFactory http)
{
    // v1.4 business tags, set BEFORE any check or downstream call so that every failure carries them too.
    // User ID and tier come from the in-memory customer directory (SQL Server data, no extra SQL call here).
    var span = RequestSpan(ctx);
    if (span is not null)
    {
        span.SetTag("minibank.channel", p.Channel);
        span.SetTag("minibank.amountIdr", (double)p.Amount);
        span.SetTag("minibank.amountBand", AmountBand(p.Amount));
        TagCustomer(span, customerDirectory.ByAccount(p.From));
    }

    if (p.Amount <= 0 || p.Amount > MaxAmount)
    {
        return Error(400, "Amount must be between IDR 1 and IDR 500.000.000.", "VALIDATION");
    }
    if (p.Pin != demoPin) return Error(401, "Wrong PIN.", "WRONG_PIN");

    // Scenario fail-api: throw BEFORE any downstream call (no SQL, no Java). The exception handler sets minibank.outcome.
    if (p.Scenario == "fail-api")
    {
        throw new InvalidOperationException($"Simulated failure in minibank-api (fail-api) for {p.Channel}");
    }

    await using var conn = new SqlConnection(connStr);
    await conn.OpenAsync();

    // The accounts must exist and the source balance must be high enough.
    var balance = await ScalarAsync(conn, "SELECT Balance FROM dbo.Accounts WHERE AccountNo = @a", ("@a", p.From));
    if (balance is null) return Error(404, "Source account not found.", "NOT_FOUND");
    if (p.To is not null && await ScalarAsync(conn, "SELECT Balance FROM dbo.Accounts WHERE AccountNo = @a", ("@a", p.To)) is null)
    {
        return Error(404, "Destination account not found.", "NOT_FOUND");
    }
    if ((decimal)balance < p.Amount) return Outcome(span, "declined", Error(409, "Insufficient balance.", "INSUFFICIENT_FUNDS"));

    // Write the Transfers row with status PENDING. ReferenceNo = MB + yyMMddHHmmss (WIB) + 4 random digits.
    var referenceNo = NewReferenceNo();
    var traceId = TraceId();
    await ExecAsync(conn, null,
        "INSERT INTO dbo.Transfers (ReferenceNo, FromAccount, ToAccount, MerchantId, Amount, Channel, Scenario, Status, TraceId) " +
        "VALUES (@ref, @from, @to, @merchant, @amount, @channel, @scenario, 'PENDING', @trace)",
        ("@ref", referenceNo), ("@from", p.From), ("@to", p.To), ("@merchant", p.MerchantId),
        ("@amount", p.Amount), ("@channel", p.Channel), ("@scenario", p.Scenario), ("@trace", traceId));

    // Scenario slow-sql: SQL Server waits 1.5 seconds (a slow SQL dependency of minibank-api).
    if (p.Scenario == "slow-sql")
    {
        await ExecAsync(conn, null, "WAITFOR DELAY '00:00:01.500'");
    }

    // Call minibank-transfer (Java). The scenario is forwarded as header and as JSON field.
    var payload = p.Channel == "QRIS"
        ? (object)new { referenceNo, fromAccount = p.From, merchantId = p.MerchantId, merchantName = p.MerchantName, amount = p.Amount, scenario = p.Scenario }
        : (object)new { referenceNo, fromAccount = p.From, toAccount = p.To, amount = p.Amount, note = p.Note, scenario = p.Scenario };
    using var request = new HttpRequestMessage(HttpMethod.Post, p.Channel == "QRIS" ? "/api/qris/payments" : "/api/transfers")
    {
        Content = JsonContent.Create(payload),
    };
    request.Headers.Add(ScenarioHeader, p.Scenario);
    var (ok, responseBody, failure) = await CallTransferServiceAsync(http, request);

    if (!ok)
    {
        await ExecAsync(conn, null, "UPDATE dbo.Transfers SET Status = 'FAILED' WHERE ReferenceNo = @ref", ("@ref", referenceNo));
        log.LogWarning("{Channel} {ReferenceNo} FAILED: {Failure} (from {From}, scenario {Scenario})",
            p.Channel, referenceNo, failure, Mask(p.From), p.Scenario);
        return Outcome(span, "failed",
            Error(502, failure ?? "minibank-transfer failed", "DOWNSTREAM_FAILED", new { referenceNo, downstream = Detail(responseBody) }));
    }

    // Success: move the money and set Status SUCCESS in one SQL transaction.
    var result = JsonSerializer.Deserialize<TransferServiceResult>(responseBody, jsonWeb);
    await using (var tx = (SqlTransaction)await conn.BeginTransactionAsync())
    {
        var debited = await ExecAsync(conn, tx,
            "UPDATE dbo.Accounts SET Balance = Balance - @amount WHERE AccountNo = @from AND Balance >= @amount",
            ("@amount", p.Amount), ("@from", p.From));
        if (debited == 0)
        {
            await tx.RollbackAsync();
            await ExecAsync(conn, null, "UPDATE dbo.Transfers SET Status = 'FAILED' WHERE ReferenceNo = @ref", ("@ref", referenceNo));
            return Outcome(span, "declined", Error(409, "Insufficient balance.", "INSUFFICIENT_FUNDS"));
        }
        if (p.To is not null)
        {
            await ExecAsync(conn, tx, "UPDATE dbo.Accounts SET Balance = Balance + @amount WHERE AccountNo = @to",
                ("@amount", p.Amount), ("@to", p.To));
        }
        await ExecAsync(conn, tx, "UPDATE dbo.Transfers SET Status = 'SUCCESS' WHERE ReferenceNo = @ref", ("@ref", referenceNo));
        await tx.CommitAsync();
    }

    log.LogInformation("{Channel} {ReferenceNo} SUCCESS: IDR {Amount} from {From} to {To}, scenario {Scenario}, fraud {Decision}",
        p.Channel, referenceNo, p.Amount, Mask(p.From), p.To is null ? p.MerchantName : Mask(p.To), p.Scenario, result?.FraudDecision);

    return Outcome(span, "success", Results.Ok(new
    {
        referenceNo,
        status = "SUCCESS",
        channel = p.Channel,
        fromAccount = p.From,
        toAccount = p.To,
        merchantId = p.MerchantId,
        merchantName = p.MerchantName,
        amount = p.Amount,
        note = p.Note,
        createdAt = DateTimeOffset.UtcNow,
        fraudDecision = result?.FraudDecision,
        traceId,
    }));
}

// Sends one request to minibank-transfer. Returns ok=false with a readable reason on HTTP errors and network errors.
async Task<(bool Ok, string Body, string? Failure)> CallTransferServiceAsync(IHttpClientFactory http, HttpRequestMessage request)
{
    try
    {
        using var response = await http.CreateClient("transfer").SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        return response.IsSuccessStatusCode
            ? (true, body, null)
            : (false, body, $"minibank-transfer returned HTTP {(int)response.StatusCode}");
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
    {
        log.LogWarning(ex, "minibank-transfer could not be reached");
        return (false, "", "minibank-transfer could not be reached: " + ex.Message);
    }
}

// Scenario = JSON field "scenario" if present, otherwise header X-MiniBank-Scenario, otherwise "normal".
// Returns null for an unknown name.
string? ScenarioOf(HttpContext ctx, string? fromBody)
{
    var value = string.IsNullOrWhiteSpace(fromBody) ? ctx.Request.Headers[ScenarioHeader].ToString() : fromBody;
    value = string.IsNullOrWhiteSpace(value) ? "normal" : value.Trim().ToLowerInvariant();
    return scenarios.Contains(value) ? value : null;
}

// v1.4: traffic-source label from header X-MiniBank-Source. Only the 5 known labels are kept, anything else
// (or no header) is "unknown"; this never rejects a request.
string TrafficSourceOf(HttpContext ctx)
{
    var value = ctx.Request.Headers[SourceHeader].ToString().Trim().ToLowerInvariant();
    return trafficSources.Contains(value) ? value : "unknown";
}

// v1.4: the ASP.NET Core request span (the request in Application Insights); null when telemetry is off.
static Activity? RequestSpan(HttpContext ctx) => ctx.Features.Get<IHttpActivityFeature>()?.Activity ?? Activity.Current;

// v1.4: amount band of a payment, used by the workbook "Business impact (IDR)".
static string AmountBand(decimal amount) =>
    amount >= 100_000_000m ? ">=100M" : amount >= 10_000_000m ? "10-100M" : amount >= 1_000_000m ? "1-10M" : "<1M";

// v1.4: customer tags. enduser.id = User ID (real demo User IDs, decided for the demo); account numbers stay masked.
static void TagCustomer(Activity? span, CustomerInfo? customer)
{
    if (span is null || customer is null) return;
    span.SetTag("enduser.id", customer.UserId);
    span.SetTag("minibank.userId", customer.UserId);
    if (!string.IsNullOrEmpty(customer.Tier)) span.SetTag("minibank.tier", customer.Tier);
}

// v1.4: minibank.outcome = success, declined (business decline, HTTP 409) or failed (technical failure, HTTP 5xx).
static IResult Outcome(Activity? span, string outcome, IResult result)
{
    span?.SetTag("minibank.outcome", outcome);
    return result;
}

// Every error response carries the trace ID of the request.
static IResult Error(int status, string message, string code, object? detail = null) =>
    Results.Json(new { error = message, code, detail, traceId = TraceId() }, statusCode: status);

// W3C trace ID of the current request = Operation ID in Application Insights.
static string TraceId() => Activity.Current?.TraceId.ToString() ?? "";

// Only the last 4 digits of an account number may appear in logs.
static string Mask(string? accountNo) =>
    string.IsNullOrEmpty(accountNo) || accountNo.Length < 4 ? "****" : "******" + accountNo[^4..];

static string NewReferenceNo()
{
    var wib = DateTime.UtcNow.AddHours(7);   // WIB = UTC+7, no daylight saving time
    return "MB" + wib.ToString("yyMMddHHmmss", CultureInfo.InvariantCulture)
                + Random.Shared.Next(0, 10000).ToString("D4", CultureInfo.InvariantCulture);
}

// Picks the "error" text out of a downstream JSON error body (or the first 200 characters).
static string? Detail(string body)
{
    if (string.IsNullOrWhiteSpace(body)) return null;
    try
    {
        using var doc = JsonDocument.Parse(body);
        if (doc.RootElement.ValueKind == JsonValueKind.Object && doc.RootElement.TryGetProperty("error", out var e))
        {
            return e.ToString();
        }
    }
    catch (JsonException)
    {
        // not JSON: fall through
    }
    return body.Length > 200 ? body[..200] : body;
}

static async Task<object?> ScalarAsync(SqlConnection conn, string sql, params (string Name, object? Value)[] args)
{
    await using var cmd = new SqlCommand(sql, conn);
    foreach (var (name, value) in args) cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
    var result = await cmd.ExecuteScalarAsync();
    return result is DBNull ? null : result;
}

static async Task<int> ExecAsync(SqlConnection conn, SqlTransaction? tx, string sql, params (string Name, object? Value)[] args)
{
    await using var cmd = new SqlCommand(sql, conn, tx);
    foreach (var (name, value) in args) cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
    return await cmd.ExecuteNonQueryAsync();
}

// ---- 7. Request and response shapes (JSON uses camelCase) -----------------------------------
record LoginRequest(string? UserId, string? Password);
record TransferRequest(string? FromAccount, string? ToAccount, decimal Amount, string? Note, string? Pin, string? Scenario);
record QrisPayRequest(string? FromAccount, string? MerchantId, decimal Amount, string? Pin, string? Scenario);
record AccountDto(string AccountNo, int CustomerId, string OwnerName, string ProductName, decimal? Balance);
record Merchant(string MerchantId, string Name, string City);
record Payment(string Channel, string From, string? To, string? MerchantId, string? MerchantName,
               decimal Amount, string? Note, string? Pin, string Scenario);
record TransferServiceResult(string? ReferenceNo, string? Status, string? FraudDecision, int? FraudScore, string? TraceId);
record CustomerInfo(int CustomerId, string UserId, string? Tier);

// ---- 8. v1.4 customer directory for the telemetry tags --------------------------------------
// User ID and tier of every demo account (dbo.Accounts + dbo.Customers), read in the BACKGROUND: at start-up, when the copy
// is older than 5 minutes and after a lookup miss, at most once a minute. A request never waits for it and never gets an
// extra SQL call, so Statement still calls only minibank-transfer and fail-api still throws before any downstream call.
// Before db\sqlserver\02-p1-tiers-customers.sql has run (no column Tier) it still delivers the User IDs, without a tier.
sealed class CustomerDirectory
{
    private static readonly TimeSpan MaxAge = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan RetryAfter = TimeSpan.FromMinutes(1);
    private readonly string connStr;
    private readonly ILogger log;
    private Snapshot current = Snapshot.Empty;   // replaced as a whole, never changed in place
    private long lastAttemptTicks;                // UTC ticks of the last refresh attempt
    private int refreshing;                       // 1 while a refresh runs

    public CustomerDirectory(string connStr, ILogger log)
    {
        this.connStr = connStr;
        this.log = log;
    }

    public CustomerInfo? ByAccount(string accountNo) => Find(s => s.ByAccount, accountNo);
    public CustomerInfo? ByUserId(string userId) => Find(s => s.ByUserId, userId);
    public CustomerInfo? ByCustomerId(int customerId) => Find(s => s.ByCustomerId, customerId);

    private CustomerInfo? Find<TKey>(Func<Snapshot, Dictionary<TKey, CustomerInfo>> index, TKey key) where TKey : notnull
    {
        var snapshot = Volatile.Read(ref current);
        index(snapshot).TryGetValue(key, out var customer);
        var age = DateTime.UtcNow - snapshot.LoadedUtc;
        if (age > MaxAge || (customer is null && age > RetryAfter))
        {
            StartRefresh();
        }
        return customer;
    }

    // Starts one background refresh. The execution context does not flow, so the SQL query has no parent request.
    public void StartRefresh()
    {
        var now = DateTime.UtcNow.Ticks;
        if (now - Interlocked.Read(ref lastAttemptTicks) < RetryAfter.Ticks) return;
        if (Interlocked.CompareExchange(ref refreshing, 1, 0) != 0) return;
        Interlocked.Exchange(ref lastAttemptTicks, now);
        if (ExecutionContext.IsFlowSuppressed())
        {
            _ = Task.Run(RefreshAsync);
            return;
        }
        using (ExecutionContext.SuppressFlow())
        {
            _ = Task.Run(RefreshAsync);
        }
    }

    private async Task RefreshAsync()
    {
        try
        {
            List<DirectoryRow> rows;
            try
            {
                rows = await ReadRowsAsync(withTier: true);
            }
            catch (SqlException ex) when (ex.Number == 207)   // invalid column name: 02-p1-tiers-customers.sql has not run yet
            {
                rows = await ReadRowsAsync(withTier: false);
            }
            var byAccount = new Dictionary<string, CustomerInfo>(StringComparer.Ordinal);
            var byUserId = new Dictionary<string, CustomerInfo>(StringComparer.OrdinalIgnoreCase);
            var byCustomerId = new Dictionary<int, CustomerInfo>();
            foreach (var row in rows)
            {
                if (!byCustomerId.TryGetValue(row.CustomerId, out var customer))
                {
                    customer = new CustomerInfo(row.CustomerId, row.UserId, row.Tier);
                    byCustomerId[row.CustomerId] = customer;
                    byUserId[row.UserId] = customer;
                }
                if (row.AccountNo is not null)
                {
                    byAccount[row.AccountNo] = customer;
                }
            }
            Volatile.Write(ref current, new Snapshot(DateTime.UtcNow, byAccount, byUserId, byCustomerId));
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Customer directory for the telemetry tags could not be loaded; it is tried again later");
        }
        finally
        {
            Volatile.Write(ref refreshing, 0);
        }
    }

    private async Task<List<DirectoryRow>> ReadRowsAsync(bool withTier)
    {
        var sql = "SELECT a.AccountNo, c.CustomerId, c.UserId, " + (withTier ? "c.Tier" : "CAST(NULL AS varchar(10))") +
                  " FROM dbo.Customers c LEFT JOIN dbo.Accounts a ON a.CustomerId = c.CustomerId";
        var rows = new List<DirectoryRow>();
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();
        await using var cmd = new SqlCommand(sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            rows.Add(new DirectoryRow(reader.IsDBNull(0) ? null : reader.GetString(0).Trim(), reader.GetInt32(1),
                reader.GetString(2), reader.IsDBNull(3) ? null : reader.GetString(3)));
        }
        return rows;
    }

    private sealed record DirectoryRow(string? AccountNo, int CustomerId, string UserId, string? Tier);

    private sealed record Snapshot(DateTime LoadedUtc, Dictionary<string, CustomerInfo> ByAccount,
                                   Dictionary<string, CustomerInfo> ByUserId, Dictionary<int, CustomerInfo> ByCustomerId)
    {
        public static readonly Snapshot Empty = new(DateTime.MinValue, new Dictionary<string, CustomerInfo>(),
            new Dictionary<string, CustomerInfo>(), new Dictionary<int, CustomerInfo>());
    }
}
