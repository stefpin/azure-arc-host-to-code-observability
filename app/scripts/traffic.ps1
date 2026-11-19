<#
  MiniBank traffic generator v1.3 - runs on HV-HOST-02 (Windows PowerShell 5.1).
  Every minute it logs in the 3 demo users, refreshes their accounts and sends Transfer (60 %), QRIS (25 %) and
  Statement (15 %) calls, evenly spread over the minute.
  -Scenario mix      : -SlowPercent (default 6) is split over slow-sql, slow-oracle, slow-python and slow-postgres;
                       -FailPercent (default 0.05 = 1 in 2,000) is split 3:2:3:2 over fail-oracle, fail-java,
                       fail-python and fail-api; the rest is normal. Any other -Scenario value sends only that scenario.
  -DeclinesPerHour   : business declines. Each one is a transfer from the demo user's smaller account for IDR 10-25
                       million more than its balance; the API rejects it with "Insufficient balance" (HTTP 409).
                       No money moves and nothing is written to the databases. Default 0.
  -Minutes 0         : run until stopped (scheduled task minibank-traffic). Without -Minutes 0 the script ends.
  -LogFile           : also append every summary line to this file (renamed to <file>.1 at 5 MB).
  v1.4: every call carries the header X-MiniBank-Source: traffic (traffic-source label on the API request spans).
  Examples (PowerShell on HV-HOST-02, folder F:\Build\minibank\scripts):
    .\traffic.ps1 -Minutes 30 -PerMinute 30 -Scenario mix
    .\traffic.ps1 -Minutes 10 -PerMinute 6 -Scenario fail-oracle            # incident window next to the background traffic
    .\traffic.ps1 -Minutes 5 -PerMinute 0 -DeclinesPerHour 240              # burst of about 20 business declines
  One summary line per minute. Stop with Ctrl+C.
#>
param(
    [string]$BaseUrl = 'http://192.168.110.31:8080',
    [int]$Minutes = 30,
    [int]$PerMinute = 30,
    [ValidateSet('mix', 'normal', 'slow-sql', 'slow-oracle', 'slow-python', 'slow-postgres',
                 'fail-oracle', 'fail-java', 'fail-python', 'fail-api')]
    [string]$Scenario = 'mix',
    [ValidateRange(0, 100)][double]$FailPercent = 0.05,
    [ValidateRange(0, 100)][double]$SlowPercent = 6,
    [ValidateRange(0, 3600)][double]$DeclinesPerHour = 0,
    [string]$LogFile = ''
)
$ErrorActionPreference = 'Stop'
if ($FailPercent + $SlowPercent -gt 100) { throw '-FailPercent plus -SlowPercent must not exceed 100.' }
$Users    = @('ANDI.WIJAYA', 'SITI.RAHAYU', 'BUDI.SANTOSO')
$Password = 'Demo123!'   # demo password (documented, synthetic users)
$Pin      = '123456'     # demo PIN (documented)
$MaxAmount = 500000000   # API maximum per payment (IDR)
$slowEach = $SlowPercent / 4
$MixTable = @(           # percent of operations; the rest is normal
    @{ Name = 'slow-sql'; Pct = $slowEach }, @{ Name = 'slow-oracle'; Pct = $slowEach },
    @{ Name = 'slow-python'; Pct = $slowEach }, @{ Name = 'slow-postgres'; Pct = $slowEach },
    @{ Name = 'fail-oracle'; Pct = $FailPercent * 0.3 }, @{ Name = 'fail-java'; Pct = $FailPercent * 0.2 },
    @{ Name = 'fail-python'; Pct = $FailPercent * 0.3 }, @{ Name = 'fail-api'; Pct = $FailPercent * 0.2 }
)
$rng = New-Object System.Random

function Write-Log([string]$Text) {
    Write-Host $Text
    if ($LogFile) {
        try {
            if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 5MB)) { Move-Item $LogFile "$LogFile.1" -Force }
            Add-Content -Path $LogFile -Value $Text -Encoding ASCII
        } catch { }
    }
}

function Get-NextScenario {
    if ($Scenario -ne 'mix') { return $Scenario }
    $r = $rng.NextDouble() * 100
    foreach ($item in $MixTable) { $r -= $item.Pct; if ($r -lt 0) { return $item.Name } }
    return 'normal'
}

# One API call. Returns Ok, Data, Ms, Error, Code and the TraceId of a failed call.
function Invoke-MiniBank([string]$Method, [string]$Path, $Body = $null, [string]$ScenarioName = 'normal') {
    $result = @{ Ok = $true; Data = $null; Ms = 0; Error = ''; Code = ''; TraceId = '' }
    $call = @{ Method = $Method; Uri = "$BaseUrl$Path"; TimeoutSec = 30; UseBasicParsing = $true
               Headers = @{ 'X-MiniBank-Scenario' = $ScenarioName; 'X-MiniBank-Source' = 'traffic' } }
    if ($null -ne $Body) {
        $call.Body = ($Body | ConvertTo-Json -Compress)
        $call.ContentType = 'application/json; charset=utf-8'
    }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $result.Data = Invoke-RestMethod @call
    } catch {
        $result.Ok = $false
        $result.Error = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try { $e = $_.ErrorDetails.Message | ConvertFrom-Json; $result.Error = $e.error; $result.Code = $e.code; $result.TraceId = $e.traceId } catch { }
        }
    }
    $sw.Stop()
    $result.Ms = $sw.ElapsedMilliseconds
    return $result
}

# Business decline: pay more than the smaller account holds -> HTTP 409 INSUFFICIENT_FUNDS (no money moves).
function Invoke-Decline {
    $accounts = $sessions[($Users | Get-Random)]
    if (-not $accounts) { return $null }
    $low = $accounts | Sort-Object { [decimal]$_.balance } | Select-Object -First 1
    $amount = [decimal]([Math]::Ceiling([double]$low.balance / 1000000) * 1000000) + (Get-Random -Minimum 10 -Maximum 26) * 1000000
    if ($amount -gt $MaxAmount) { return $null }
    $to = ($allAccounts | Where-Object { $_.accountNo -ne $low.accountNo } | Get-Random).accountNo
    return Invoke-MiniBank 'Post' '/api/transfer' @{ fromAccount = $low.accountNo; toAccount = $to; amount = $amount
                                                   note = 'traffic'; pin = $Pin; scenario = 'normal' } 'normal'
}

# Wait for the API (a host restart takes a while). Interactive runs give up after about 2 minutes.
$merchants = $null; $allAccounts = $null; $waitStart = Get-Date
while ($true) {
    $merchants = (Invoke-MiniBank 'Get' '/api/qris/merchants').Data
    $allAccounts = (Invoke-MiniBank 'Get' '/api/accounts').Data
    if ($merchants -and $allAccounts) { break }
    if ($Minutes -gt 0 -and ((Get-Date) - $waitStart).TotalMinutes -ge 2) { throw "MiniBank API not reachable at $BaseUrl" }
    Write-Log ('{0:yyyy-MM-dd HH:mm} waiting for the MiniBank API at {1}' -f (Get-Date), $BaseUrl)
    Start-Sleep -Seconds 60
}

$sessions = @{}
if ($Minutes -gt 0) { $end = (Get-Date).AddMinutes($Minutes); $runText = "$Minutes min" } else { $end = [DateTime]::MaxValue; $runText = 'until stopped' }
Write-Log ('{0:yyyy-MM-dd HH:mm} MiniBank traffic v1.3 -> {1} {2}, {3} operations/min, scenario {4}, failures {5} %, slow {6} %, declines {7}/hour' -f `
    (Get-Date), $BaseUrl, $runText, $PerMinute, $Scenario, $FailPercent, $SlowPercent, $DeclinesPerHour)

while ((Get-Date) -lt $end) {
    $minuteStart = Get-Date
    try {
        # log in the demo users and refresh their accounts (Login telemetry once per minute and user)
        foreach ($u in $Users) {
            $login = Invoke-MiniBank 'Post' '/api/login' @{ userId = $u; password = $Password }
            if (-not $login.Ok) { Write-Log "Login $u failed: $($login.Error)"; continue }
            $acc = Invoke-MiniBank 'Get' "/api/accounts?customerId=$($login.Data.customerId)"
            if ($acc.Ok) { $sessions[$u] = @($acc.Data) }
        }
        # this minute's work: PerMinute operations plus 0..n business declines, in random order
        $declines = 0
        if ($DeclinesPerHour -gt 0) {
            $expected = $DeclinesPerHour / 60.0
            $declines = [int][Math]::Floor($expected)
            if ($rng.NextDouble() -lt ($expected - $declines)) { $declines++ }
        }
        $work = @()
        if ($PerMinute -gt 0) { $work += @('op') * $PerMinute }
        if ($declines -gt 0) { $work += @('decline') * $declines }
        if ($work.Count -gt 1) { $work = @($work | Sort-Object { $rng.Next() }) }
        $ok = 0; $failed = 0; $declined = 0; $slow = 0; $lastTrace = ''
        $times = New-Object System.Collections.ArrayList
        $intervalMs = [int](60000 / [Math]::Max(1, $work.Count))
        foreach ($item in $work) {
            if ((Get-Date) -ge $end) { break }
            $opStart = Get-Date
            $r = $null
            if ($item -eq 'decline') {
                $r = Invoke-Decline
            } else {
                $accounts = $sessions[($Users | Get-Random)]
                if ($accounts) {
                    # pay from the account with the highest balance, so balances stay healthy
                    $from = ($accounts | Sort-Object { [decimal]$_.balance } -Descending | Select-Object -First 1).accountNo
                    $s = Get-NextScenario
                    $roll = Get-Random -Minimum 1 -Maximum 101
                    if ($roll -le 60) {
                        $to = ($allAccounts | Where-Object { $_.accountNo -ne $from } | Get-Random).accountNo
                        $amount = (Get-Random -Minimum 10 -Maximum 501) * 1000
                        $r = Invoke-MiniBank 'Post' '/api/transfer' @{ fromAccount = $from; toAccount = $to; amount = $amount
                                                                      note = 'traffic'; pin = $Pin; scenario = $s } $s
                    } elseif ($roll -le 85) {
                        $merchantId = ($merchants | Get-Random).merchantId
                        $amount = (Get-Random -Minimum 5 -Maximum 251) * 1000
                        $r = Invoke-MiniBank 'Post' '/api/qris/pay' @{ fromAccount = $from; merchantId = $merchantId; amount = $amount
                                                                      pin = $Pin; scenario = $s } $s
                    } else {
                        $acct = ($accounts | Get-Random).accountNo
                        $r = Invoke-MiniBank 'Get' "/api/accounts/$acct/statement?days=30" $null $s
                    }
                }
            }
            if ($null -ne $r) {
                if ($r.Ok) { $ok++ }
                elseif ($r.Code -eq 'INSUFFICIENT_FUNDS') { $declined++ }
                else { $failed++; if ($r.TraceId) { $lastTrace = $r.TraceId } }
                if ($r.Ms -ge 1000) { $slow++ }
                [void]$times.Add([double]$r.Ms)
            }
            $wait = $intervalMs - [int]((Get-Date) - $opStart).TotalMilliseconds
            if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
        }
        if ($work.Count -eq 0) {
            $rest = 60000 - [int]((Get-Date) - $minuteStart).TotalMilliseconds
            if ($rest -gt 0) { Start-Sleep -Milliseconds $rest }
        }
        $sorted = @($times | Sort-Object)
        $avg = 0; $p95 = 0
        if ($sorted.Count -gt 0) {
            $avg = [int](($sorted | Measure-Object -Average).Average)
            $p95 = $sorted[[Math]::Max(0, [int][Math]::Ceiling($sorted.Count * 0.95) - 1)]
        }
        $traceText = ''
        if ($lastTrace) { $traceText = "lastFailedTrace=$lastTrace" }
        Write-Log ('{0:yyyy-MM-dd HH:mm} ok={1} failed={2} declined={3} slow>1s={4} avg={5}ms p95={6}ms scenario={7} {8}' -f `
            (Get-Date), $ok, $failed, $declined, $slow, $avg, $p95, $Scenario, $traceText)
    } catch {
        Write-Log ('{0:yyyy-MM-dd HH:mm} error: {1}' -f (Get-Date), $_.Exception.Message)
        Start-Sleep -Seconds 30
    }
}
