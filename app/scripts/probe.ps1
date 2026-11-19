<#
  MiniBank internal availability probe - run on HV-HOST-02 (Windows PowerShell 5.1). Stop with Ctrl+C.
  Every 60 s: GET /api/health and a normal transfer of IDR 10,000 between the two demo accounts of BUDI.SANTOSO
  (the direction alternates, so the balances stay the same). Then it sends ONE availability result to Application
  Insights (POST <IngestionEndpoint>/v2.1/track). The probe's trace ID is sent as "traceparent", so the availability
  result and the API transaction share the same Operation ID.
  Connection string: -ConnectionString, else env APPLICATIONINSIGHTS_CONNECTION_STRING, else a prompt.
  v1.4: both calls carry the header X-MiniBank-Source: probe (traffic-source label on the API request spans).
    powershell -ExecutionPolicy Bypass -File .\probe.ps1
#>
param(
    [string]$BaseUrl = 'http://192.168.110.31:8080',
    [string]$ConnectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING,
    [int]$IntervalSeconds = 60
)
$ErrorActionPreference = 'Stop'
if (-not $ConnectionString) { $ConnectionString = Read-Host 'Paste the Application Insights connection string' }

# connection string = key=value;key=value;...  -> InstrumentationKey and IngestionEndpoint
$cs = @{}
foreach ($part in $ConnectionString.Split(';')) {
    $kv = $part.Split('=', 2)
    if ($kv.Count -eq 2 -and $kv[0].Trim()) { $cs[$kv[0].Trim()] = $kv[1].Trim() }
}
$iKey = $cs['InstrumentationKey']
$ingestion = $cs['IngestionEndpoint']
if (-not $iKey -or -not $ingestion) { throw 'The connection string must contain InstrumentationKey and IngestionEndpoint.' }
$trackUrl = $ingestion.TrimEnd('/') + '/v2.1/track'

$budi = @('9901000031', '9901000032')   # the two accounts of BUDI.SANTOSO (seed data)
$pin = '123456'                          # demo PIN (documented)
$run = 0
Write-Host "MiniBank probe -> $BaseUrl every $IntervalSeconds s; results to $trackUrl. Ctrl+C stops."

while ($true) {
    $run++
    $traceId = [guid]::NewGuid().ToString('N')                 # 32 hex characters
    $spanId = [guid]::NewGuid().ToString('N').Substring(0, 16)  # 16 hex characters
    $headers = @{ 'traceparent' = "00-$traceId-$spanId-01"; 'X-MiniBank-Scenario' = 'normal'; 'X-MiniBank-Source' = 'probe' }
    $from = $budi[$run % 2]; $to = $budi[($run + 1) % 2]
    $ok = $true; $steps = @()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $health = Invoke-RestMethod -Uri "$BaseUrl/api/health" -Headers $headers -TimeoutSec 10 -UseBasicParsing
        $steps += "health $($health.status)"
        $body = @{ fromAccount = $from; toAccount = $to; amount = 10000; note = 'probe'; pin = $pin; scenario = 'normal' } |
            ConvertTo-Json -Compress
        $t = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/transfer" -Headers $headers -Body $body `
            -ContentType 'application/json; charset=utf-8' -TimeoutSec 30 -UseBasicParsing
        $steps += "transfer $($t.status) $($t.referenceNo)"
    } catch {
        $ok = $false
        $msg = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        $steps += "FAILED: $msg"
    }
    $sw.Stop()
    $message = $steps -join '; '
    if ($message.Length -gt 1000) { $message = $message.Substring(0, 1000) }

    $item = @{
        name = 'Microsoft.ApplicationInsights.Availability'
        time = (Get-Date).ToUniversalTime().ToString('o')
        iKey = $iKey
        tags = @{ 'ai.cloud.role' = 'minibank-probe'; 'ai.cloud.roleInstance' = $env:COMPUTERNAME; 'ai.operation.id' = $traceId }
        data = @{
            baseType = 'AvailabilityData'
            baseData = @{
                ver = 2; id = $spanId; name = 'MiniBank transfer probe (internal)'
                duration = $sw.Elapsed.ToString(); success = $ok
                runLocation = 'lab HV-HOST-02'; message = $message
                properties = @{ baseUrl = $BaseUrl; traceId = $traceId }
            }
        }
    }
    $json = ConvertTo-Json -InputObject @($item) -Depth 8 -Compress
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $trackUrl -Body $json -ContentType 'application/json; charset=utf-8' -UseBasicParsing
        Write-Host ('{0:HH:mm:ss} success={1} {2} ms={3} trace={4} accepted={5}' -f (Get-Date), $ok, $message, $sw.ElapsedMilliseconds, $traceId, $resp.itemsAccepted)
    } catch {
        Write-Host "Could not send the availability result: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $IntervalSeconds
}
