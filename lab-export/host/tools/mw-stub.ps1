# mw-stub.ps1 - stand-in for fault.ps1, used ONLY by "mystery-window.ps1 -Test stub". It prints the same messages as
# fault.ps1 (draw, reveal, stop, status) and changes nothing in the lab: no fault, no undo step, no ledger row.
# Behaviour from $env:MW_STUB_MODE: ok (default), busy (draw refused), void (draw VOID). State: %TEMP%\mw-stub-state.json
param([switch]$Mystery, [int]$Pick = 0, [switch]$Reveal, [switch]$Stop, [switch]$Status)
$inv = [Globalization.CultureInfo]::InvariantCulture
$sf = Join-Path $env:TEMP 'mw-stub-state.json'
$mode = $env:MW_STUB_MODE; if (-not $mode) { $mode = 'ok' }
$fp = '4745 27D2 19ED 45BC'
function Wib([DateTime]$t) { return $t.ToString('HH:mm:ss', $inv) }
function Get-St { if (Test-Path -LiteralPath $sf) { return (Get-Content -LiteralPath $sf -Raw | ConvertFrom-Json) }; return $null }
function Set-St($o) { ConvertTo-Json -InputObject $o | Set-Content -LiteralPath $sf -Encoding ASCII }
if ($Status) {
    $st = Get-St
    if (-not $st) { Write-Host 'No fault run recorded.'; return }
    $now = [DateTime]::UtcNow.AddHours(7)
    $end = [DateTime]::ParseExact($st.End, 'yyyy-MM-dd HH:mm:ss', $inv)
    $state = 'ended'; if ($st.Active -and $end -gt $now) { $state = 'ACTIVE' }
    Write-Host ('Run {0} (mystery) {1}: start {2} WIB, end {3} WIB' -f $st.RunId, $state, (Wib $end.AddMinutes(-8)), (Wib $end))
    Write-Host ('Number {0}, sealed fingerprint {1}, fault active check: {2}' -f $st.Number, $fp, $st.Checked)
    return
}
if ($Mystery) {
    if ($mode -eq 'busy') { Write-Host 'Not started: another run is active (stand-in for the test)'; return }
    $n = $Pick; if ($n -eq 0) { $n = 4 }
    $now = [DateTime]::UtcNow.AddHours(7)
    $runId = 'M' + $now.ToString('yyyyMMdd-HHmmss', $inv)
    $end = $now.AddSeconds(5).AddMinutes(8)
    Set-St ([ordered]@{ RunId = $runId; Number = $n; End = $end.ToString('yyyy-MM-dd HH:mm:ss', $inv); Active = $true; Checked = '' })
    Write-Host ''
    Write-Host ('Draw {0}: number {1} is sealed.' -f $runId, $n)
    Write-Host ('Sealed fingerprint: {0}   (write it down; -Reveal recomputes it)' -f $fp)
    Write-Host ('The fault runs 8 minutes, until {0} WIB. Checking that it took effect ...' -f (Wib $end))
    Start-Sleep -Seconds 3
    if ($mode -eq 'void') {
        Set-St ([ordered]@{ RunId = $runId; Number = $n; End = $end.ToString('yyyy-MM-dd HH:mm:ss', $inv); Active = $false; Checked = 'False' })
        Write-Host 'The fault did not take effect: this draw is VOID and everything is reset. Ask the bank for a new number.'
    } else {
        Set-St ([ordered]@{ RunId = $runId; Number = $n; End = $end.ToString('yyyy-MM-dd HH:mm:ss', $inv); Active = $true; Checked = 'True' })
        Write-Host 'Fault is active. Watch the board. When it shows a verdict: .\fault.ps1 -Reveal'
    }
    return
}
if ($Stop) {
    $st = Get-St
    if ($st -and $st.Active) {
        $st.Active = $false; Set-St $st
        Write-Host ('stopped run {0} (mystery)' -f $st.RunId)
        Write-Host 'The fault is reset. To see the answer: .\fault.ps1 -Reveal'
    } else { Write-Host 'stop: no active run (all undo steps ran anyway)' }
    Write-Host '  stand-in: nothing to undo'
    return
}
if ($Reveal) {
    $st = Get-St
    if (-not $st) { Write-Host 'No mystery draw to reveal.'; return }
    $st.Active = $false; Set-St $st
    Write-Host ''
    Write-Host ('Draw {0}, number {1}: Application: minibank-api Statement preview throws NullReferenceException' -f $st.RunId, $st.Number)
    Write-Host 'Expected layer: Application'
    Write-Host ('Fingerprint shown at the draw: {0}  recomputed now: {0}  -> MATCH (answer unchanged)' -f $fp)
    Write-Host ('Board verdict: Application - minibank-api at {0} WIB (3 min 5 s after the fault started) -> RIGHT LAYER' -f (Wib ([DateTime]::UtcNow.AddHours(7))))
    Write-Host 'ledger: 0 row(s) sent (stand-in: nothing sent)'
    return
}
