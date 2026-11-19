package id.minibank.transfer;

import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClientException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

/**
 * POST /api/transfers, POST /api/qris/payments, GET /api/ledger/{accountNo}?days=30
 * Called by minibank-api through the OpenShift Route. Every error answer is JSON {error, service, traceId}.
 */
@RestController
@RequestMapping("/api")
public class TransferController {

    /** The scenario travels end to end as this header and as the JSON field "scenario". */
    public static final String SCENARIO_HEADER = "X-MiniBank-Scenario";

    private static final Set<String> SCENARIOS = Set.of("normal", "slow-sql", "slow-oracle", "slow-python",
            "slow-postgres", "fail-oracle", "fail-java", "fail-python", "fail-api");
    private static final Logger log = LoggerFactory.getLogger(TransferController.class);

    public record TransferRequest(String referenceNo, String fromAccount, String toAccount,
                                  BigDecimal amount, String note, String scenario) {}

    public record QrisPaymentRequest(String referenceNo, String fromAccount, String merchantId,
                                     String merchantName, BigDecimal amount, String scenario) {}

    public record BookingResult(String referenceNo, String status, String fraudDecision, int fraudScore, String traceId) {}

    public record Statement(String accountNo, int days, List<LedgerRepository.LedgerLine> entries) {}

    private final LedgerRepository ledger;
    private final FraudClient fraud;
    private final RatesClient rates;

    public TransferController(LedgerRepository ledger, FraudClient fraud, RatesClient rates) {
        this.ledger = ledger;
        this.fraud = fraud;
        this.rates = rates;
    }

    @PostMapping("/transfers")
    public BookingResult transfer(@RequestBody TransferRequest req,
                                  @RequestHeader(value = SCENARIO_HEADER, required = false) String header,
                                  HttpServletRequest http) {
        String scenario = scenarioOf(req.scenario(), header);
        requireAccount(req.fromAccount());
        requireAccount(req.toAccount());
        requireAmount(req.amount());
        String reference = requireReference(req.referenceNo());
        failJavaIfAsked(scenario);

        RatesClient.RateCheck rate = rates.check("TRANSFER", req.amount(), scenario);              // Java on OpenShift (OpenTelemetry, zero code)
        FraudClient.FraudResult check = fraud.check(reference, "TRANSFER", req.amount(), scenario); // Python + PostgreSQL
        String traceId = traceId(http);
        ledger.bookTransfer(reference, req.fromAccount(), req.toAccount(), req.amount(), traceId, scenario); // Oracle
        logBooking("TRANSFER", reference, req.fromAccount(), req.amount(), rate, check.decision());
        return new BookingResult(reference, "SUCCESS", check.decision(), check.score(), traceId);
    }

    @PostMapping("/qris/payments")
    public BookingResult qris(@RequestBody QrisPaymentRequest req,
                              @RequestHeader(value = SCENARIO_HEADER, required = false) String header,
                              HttpServletRequest http) {
        String scenario = scenarioOf(req.scenario(), header);
        requireAccount(req.fromAccount());
        requireAmount(req.amount());
        String reference = requireReference(req.referenceNo());
        String merchant = isBlank(req.merchantName()) ? req.merchantId() : req.merchantName();
        if (isBlank(merchant)) {
            throw new IllegalArgumentException("merchantId is required");
        }
        failJavaIfAsked(scenario);

        RatesClient.RateCheck rate = rates.check("QRIS", req.amount(), scenario);
        FraudClient.FraudResult check = fraud.check(reference, "QRIS", req.amount(), scenario);
        String traceId = traceId(http);
        ledger.bookQris(reference, req.fromAccount(), merchant, req.amount(), traceId, scenario);
        logBooking("QRIS", reference, req.fromAccount(), req.amount(), rate, check.decision());
        return new BookingResult(reference, "SUCCESS", check.decision(), check.score(), traceId);
    }

    @GetMapping("/ledger/{accountNo}")
    public Statement ledger(@PathVariable String accountNo,
                            @RequestParam(defaultValue = "30") int days,
                            @RequestHeader(value = SCENARIO_HEADER, required = false) String header) {
        String scenario = scenarioOf(null, header);
        requireAccount(accountNo);
        int period = Math.max(1, Math.min(days, 90));
        failJavaIfAsked(scenario);
        return new Statement(accountNo, period, ledger.statement(accountNo, period, scenario));
    }

    // ---------- error handling: HTTP status + JSON {error, service, traceId} ----------

    @ExceptionHandler({IllegalArgumentException.class, HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String, String>> badRequest(Exception ex, HttpServletRequest http) {
        return error(HttpStatus.BAD_REQUEST, ex.getMessage(), http);
    }

    @ExceptionHandler(ScenarioException.class)
    public ResponseEntity<Map<String, String>> scenarioFailure(ScenarioException ex, HttpServletRequest http) {
        log.error("Scenario failure: {}", ex.getMessage(), ex);   // logged exception -> Application Insights exception
        return error(HttpStatus.INTERNAL_SERVER_ERROR, ex.getMessage(), http);
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> oracleFailure(DataAccessException ex, HttpServletRequest http) {
        String message = "Oracle error: " + ex.getMostSpecificCause().getMessage();
        log.error(message, ex);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, message, http);
    }

    @ExceptionHandler(RestClientException.class)
    public ResponseEntity<Map<String, String>> fraudFailure(RestClientException ex, HttpServletRequest http) {
        String message = "minibank-fraud failed: " + ex.getMessage();
        log.error(message, ex);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, message, http);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> otherFailure(Exception ex, HttpServletRequest http) {
        log.error("Unexpected error: {}", ex.getMessage(), ex);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, ex.getMessage(), http);
    }

    private ResponseEntity<Map<String, String>> error(HttpStatus status, String message, HttpServletRequest http) {
        return ResponseEntity.status(status).body(Map.of(
                "error", message == null ? status.getReasonPhrase() : message,
                "service", "minibank-transfer",
                "traceId", traceId(http)));
    }

    // ---------- helpers ----------

    /** Trace ID = W3C trace ID of the incoming "traceparent" header (sent by minibank-api, kept by the agent). */
    static String traceId(HttpServletRequest http) {
        String traceparent = http.getHeader("traceparent");   // 00-<32 hex trace id>-<16 hex span id>-<flags>
        if (traceparent != null) {
            String[] parts = traceparent.split("-");
            if (parts.length >= 4 && parts[1].length() == 32) {
                return parts[1];
            }
        }
        String fromMdc = MDC.get("trace_id");
        return fromMdc != null ? fromMdc : "n/a";
    }

    /** The account number goes into the log record as custom dimension "minibank.account";
     *  the agent masks it (telemetry processor in applicationinsights.json) before it leaves the pod. */
    private static void logBooking(String channel, String reference, String account, BigDecimal amount,
                                   RatesClient.RateCheck rate, String decision) {
        MDC.put("minibank.account", account);
        try {
            log.info("{} {} booked: amount {} fee {} rules {} fraud {}", channel, reference, amount,
                    rate.fee(), rate.ruleSet(), decision);
        } finally {
            MDC.remove("minibank.account");
        }
    }

    private static String scenarioOf(String fromBody, String fromHeader) {
        String s = isBlank(fromBody) ? fromHeader : fromBody;
        s = isBlank(s) ? "normal" : s.trim().toLowerCase(Locale.ROOT);
        if (!SCENARIOS.contains(s)) {
            throw new IllegalArgumentException("Unknown scenario: " + s);
        }
        return s;
    }

    private static void failJavaIfAsked(String scenario) {
        if ("fail-java".equals(scenario)) {
            throw new ScenarioException("Simulated failure in minibank-transfer (fail-java)");
        }
    }

    private static void requireAccount(String accountNo) {
        if (accountNo == null || !accountNo.matches("\\d{10}")) {
            throw new IllegalArgumentException("Account number must have 10 digits");
        }
    }

    private static void requireAmount(BigDecimal amount) {
        if (amount == null || amount.signum() <= 0) {
            throw new IllegalArgumentException("Amount must be greater than zero");
        }
    }

    private static String requireReference(String referenceNo) {
        if (isBlank(referenceNo) || referenceNo.length() > 20) {
            throw new IllegalArgumentException("referenceNo is required (max 20 characters)");
        }
        return referenceNo;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
