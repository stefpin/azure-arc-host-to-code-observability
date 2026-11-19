<#
  MiniBank cross-layer lab v1.5 - verdict observer (HV-HOST-02, scheduled task minibank-verdict-observer, every minute, SYSTEM).
  Reads the board verdict MiniBankRootCause() from law-appmon with the host managed identity (Log Analytics Reader),
  appends it to C:\ProgramData\MiniBank\verdict\verdict-<UTC date>.jsonl and sends it to the table MiniBankVerdict_CL
  (Logs Ingestion API, DCR dcr-minibank-rca, role Monitoring Metrics Publisher). The verdict history feeds the timeline
  and the mystery scorecard. It never reads the mystery answers. Errors: C:\ProgramData\MiniBank\verdict\observer-errors.log
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WorkspaceId = '<WORKSPACE_ID>'
$DceUri = 'https://dcr-minibank-rca-jnvj-indonesiacentral.logs.z1.ingest.monitor.azure.com'
$DcrImmutableId = 'dcr-<IMMUTABLE_ID>'
$dir = 'C:\ProgramData\MiniBank\verdict'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
function Get-MiToken([string]$Resource) {
    $u = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + [uri]::EscapeDataString($Resource)
    return (Invoke-RestMethod -Headers @{ Metadata = 'true' } -Uri $u -TimeoutSec 15).access_token
}
function Invoke-Verdict {
    try {
        $tok = Get-MiToken 'https://api.loganalytics.io'
        $r = Invoke-RestMethod -Method Post -Uri "https://api.loganalytics.io/v1/workspaces/$WorkspaceId/query" -Headers @{ Authorization = "Bearer $tok" } `
            -ContentType 'application/json' -Body (ConvertTo-Json -Compress -InputObject @{ query = ('MiniBankRootCause(datetime({0}))' -f [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')) }) -TimeoutSec 50
        $tab = $r.tables[0]
        $row = $tab.rows[0]
        $v = @{}
        for ($i = 0; $i -lt $tab.columns.Count; $i++) { $v[$tab.columns[$i].name] = $row[$i] }
        $rec = [ordered]@{ TimeGenerated = $v['TimeGenerated']; Status = $v['Status']; Layer = $v['Layer']; Component = $v['Component']
                           Evidence = $v['Evidence']; Onset = $v['Onset']; Impact = $v['Impact']; Confidence = $v['Confidence']
                           Rule = $v['Rule']; Observer = $env:COMPUTERNAME }
        $line = ConvertTo-Json -InputObject $rec -Compress
        Add-Content -Path (Join-Path $dir ('verdict-' + [DateTime]::UtcNow.ToString('yyyyMMdd') + '.jsonl')) -Value $line -Encoding UTF8
        $mt = Get-MiToken 'https://monitor.azure.com'
        $uri = "$DceUri/dataCollectionRules/$DcrImmutableId/streams/Custom-MiniBankVerdict?api-version=2023-01-01"
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $mt" } -ContentType 'application/json' -Body ('[' + $line + ']') -TimeoutSec 30 | Out-Null
    } catch {
        $msg = '{0} {1}' -f [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'), $_.Exception.Message
        Add-Content -Path (Join-Path $dir 'observer-errors.log') -Value $msg -Encoding UTF8
    }
}
$started = Get-Date
Invoke-Verdict
# second evaluation about 30 s later: the board is read twice a minute, so two matching rows confirm a verdict in ~30 s
$wait = 30 - ((Get-Date) - $started).TotalSeconds
if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
Invoke-Verdict
Get-ChildItem $dir -Filter 'verdict-*.jsonl' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-21) } | Remove-Item -Force -ErrorAction SilentlyContinue
