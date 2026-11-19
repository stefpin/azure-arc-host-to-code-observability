# myst16.ps1 - 16 Nov 2026 (approved by the lab owner: card 6 into the mystery draw with series-host.on kept; mystery tests after the
# Monday series; first draw via PowerShell as the baseline, the rest via the Mystery control window). Runs on HV-HOST-02 as task
# bg-myst16. Switches mystery-host.on ON (pool of 6), then draws: 1 = fault command directly, 2.. = mystery-window.ps1 -Test real-draw.
# 6 draws; if the host card has not come up, up to 3 more. Gate before each draw: no run active, at least 6 min since the last
# reveal and the last 4 readings Healthy. Log C:\BuildLog\myst16.log (card names only after a reveal). Stop: C:\BuildLog\myst16.stop
param([int[]]$Picks = @(2, 5, 0, 3, 6, 1, 4, 0, 5, 2))
$ErrorActionPreference = 'Continue'
$log = 'C:\BuildLog\myst16.log'; $stopF = 'C:\BuildLog\myst16.stop'
$fs = 'F:\Build\minibank\scripts\fault.ps1'; $mw = 'F:\Build\minibank\scripts\mystery-window.ps1'
$vd = 'C:\ProgramData\MiniBank\verdict'; $sd = 'C:\ProgramData\MiniBank\fault'; $tl = 'C:\BuildLog\mystery-window-test.log'
function L([string]$t) { Add-Content -LiteralPath $log -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' ' + $t) }
function Get-Last([int]$n) {
    $f = Join-Path $vd ('verdict-' + [DateTime]::UtcNow.ToString('yyyyMMdd') + '.jsonl')
    if (-not (Test-Path -LiteralPath $f)) { return @() }
    return @(Get-Content -LiteralPath $f -Tail $n | ForEach-Object { try { $_ | ConvertFrom-Json } catch { } })
}
function Get-StatusText { return ((& $fs -Status 6>&1 2>&1) | Out-String) }
function Wait-Gate([DateTime]$NotBefore) {
    $t0 = Get-Date
    while ($true) {
        if (Test-Path -LiteralPath $stopF) { L 'stop file found - no more draws'; return $false }
        $r = Get-Last 4
        $bad = @($r | Where-Object { $_.Status -ne 'Healthy' }).Count
        $active = (Get-StatusText) -cmatch '\) ACTIVE: start'
        if ((Get-Date) -ge $NotBefore -and $r.Count -eq 4 -and $bad -eq 0 -and -not $active) {
            L ('gate open after {0:0} s: last 4 readings Healthy, no run active' -f ((Get-Date) - $t0).TotalSeconds); return $true
        }
        if (((Get-Date) - $t0).TotalMinutes -gt 30) { L ('gate NOT open within 30 min (not Healthy {0} of {1}, active {2}) - stopping' -f $bad, $r.Count, $active); return $false }
        Start-Sleep -Seconds 30
    }
}
function Write-Lines([string]$Text, [string]$Prefix) { foreach ($x in ($Text -split "`r?`n")) { if ($x.Trim()) { L ($Prefix + $x.TrimEnd()) } } }

L ('==== myst17 start (window ' + (Get-FileHash $mw -Algorithm MD5).Hash.Substring(0, 12) + ', fault command ' + (Get-FileHash $fs -Algorithm MD5).Hash.Substring(0, 12) + ')')
if (-not (Test-Path -LiteralPath (Join-Path $sd 'mystery-host.on'))) { New-Item -ItemType File -Path (Join-Path $sd 'mystery-host.on') -Force | Out-Null; L 'switch mystery-host.on created (mystery pool of 6)' }
else { L 'switch mystery-host.on already present' }
L ('switches: series-host.on ' + (Test-Path (Join-Path $sd 'series-host.on')) + ', mystery-host.on ' + (Test-Path (Join-Path $sd 'mystery-host.on')))
$lastReveal = (Get-Date).AddMinutes(-10); $hostSeen = $false; $n = 0
foreach ($pick in $Picks) {
    if ($hostSeen) { break }
    if ($n -ge 10) { break }
    if (-not (Wait-Gate $lastReveal.AddMinutes(6))) { break }
    $n++
    if ($n -eq -1) {
        L ("draw $n of 6+ : fault command directly (PowerShell baseline), -Pick $pick")
        $t0 = Get-Date
        $out = ((& $fs -Mystery -Pick $pick 6>&1 2>&1) | Out-String)
        Write-Lines $out '  draw> '
        $end = $null
        if ($out -match 'until (\d{2}):(\d{2}):(\d{2}) WIB') { $end = (Get-Date).Date.AddHours([int]$Matches[1]).AddMinutes([int]$Matches[2]).AddSeconds([int]$Matches[3]) }
        if (-not $end -or $end -lt $t0) { $end = $t0.AddMinutes(8) }
        if ($out -match 'VOID|Not started') { L 'draw 1 did not run (VOID or not started) - next draw'; $lastReveal = Get-Date; continue }
        $revealAt = $end.AddSeconds(15)
        while ((Get-Date) -lt $revealAt) { Start-Sleep -Seconds 10 }
        $rv = ((& $fs -Reveal 6>&1 2>&1) | Out-String)
        Write-Lines $rv '  reveal> '
        $lastReveal = Get-Date
        if ($rv -match 'Expected layer: Host') { $hostSeen = $true }
    } else {
        $n0 = 0; if (Test-Path -LiteralPath $tl) { $n0 = @(Get-Content -LiteralPath $tl).Count }
        L ("draw $n : Mystery control window -Test real-draw -TestPick $pick")
        $p = Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $mw, '-Test', 'real-draw', '-TestPick', [string]$pick) -PassThru -WindowStyle Hidden
        if (-not $p.WaitForExit(1260000)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L '  window test did not finish within 21 min - stopped it' }
        $lines = @(); if (Test-Path -LiteralPath $tl) { $lines = @(Get-Content -LiteralPath $tl | Select-Object -Skip $n0) }
        foreach ($x in $lines) { if ($x -match 'BEGIN|SUMMARY|FAIL|INFO|RESULT|REVEAL') { L ('  window> ' + $x.Substring([Math]::Min(20, $x.Length))) } }
        $lastReveal = Get-Date
        if (($lines -join "`n") -match 'Expected layer: Host') { $hostSeen = $true }
        if (($lines -join "`n") -notmatch 'RESULT ') { L '  no RESULT line from the window - checking the status and revealing with the fault command'; Write-Lines (Get-StatusText) '  status> '; if ((Get-StatusText) -match 'mystery') { $rv = ((& $fs -Reveal 6>&1 2>&1) | Out-String); Write-Lines $rv '  reveal> ' } }
    }
    L ("draw $n done; host card seen so far: $hostSeen")
}
Write-Lines (Get-StatusText) 'final status> '
L ('switches: series-host.on ' + (Test-Path (Join-Path $sd 'series-host.on')) + ', mystery-host.on ' + (Test-Path (Join-Path $sd 'mystery-host.on')))
L ("==== myst17 end: $n draws, host card seen: $hostSeen")
