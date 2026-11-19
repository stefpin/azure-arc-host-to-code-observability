<#
  MiniBank v1.3 - continuous load generator and availability probe on HV-HOST-02 (PowerShell as Administrator).
  minibank-traffic : traffic.ps1 -Minutes 0 (runs until stopped) with about 30 operations per minute, 0.05 % technical
                    failures, 6 % slow calls and about 4 business declines per hour. Starts 10 minutes after the host
                    starts; a watchdog trigger every 15 minutes starts it again if it stopped (a running copy is never
                    started twice); no run-time limit; log C:\BuildLog\traffic.log.
  minibank-probe   : the probe task of Chapter 17.2 keeps its action and gets the same watchdog and no run-time limit
                    (Windows stops a task after 3 days by default).
    powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\install-traffic-tasks.ps1
  Pause the traffic : Disable-ScheduledTask minibank-traffic; Stop-ScheduledTask minibank-traffic
  Resume            : Enable-ScheduledTask minibank-traffic; Start-ScheduledTask minibank-traffic
#>
param(
    [string]$ScriptsDir = 'F:\Build\minibank\scripts',
    [int]$PerMinute = 30,
    [double]$FailPercent = 0.05,
    [double]$SlowPercent = 6,
    [double]$DeclinesPerHour = 4,
    [string]$LogFile = 'C:\BuildLog\traffic.log'
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
function New-TaskTriggers([string]$BootDelay) {
    $boot = New-ScheduledTaskTrigger -AtStartup
    if ($BootDelay) { $boot.Delay = $BootDelay }
    $watchdog = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)
    return @($boot, $watchdog)
}

# 1. continuous load generator (replaces the 2-hour task of version 1.2)
if (Get-ScheduledTask -TaskName 'minibank-traffic' -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName 'minibank-traffic' -ErrorAction SilentlyContinue
}
if ((Test-Path $LogFile) -and -not (Select-String -Path $LogFile -Pattern 'traffic v1.3' -Quiet)) {
    Move-Item $LogFile ($LogFile -replace '\.log$', '-before-v1.3.log') -Force
}
$argLine = "-NoProfile -ExecutionPolicy Bypass -File $ScriptsDir\traffic.ps1 -Minutes 0 -PerMinute $PerMinute -Scenario mix " +
           "-FailPercent $FailPercent -SlowPercent $SlowPercent -DeclinesPerHour $DeclinesPerHour -LogFile $LogFile"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine
Register-ScheduledTask -TaskName 'minibank-traffic' -Description 'MiniBank v1.3 continuous load generator (traffic.ps1 -Minutes 0)' `
    -Action $action -Trigger (New-TaskTriggers 'PT10M') -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null

# 2. availability probe: same action, watchdog, no run-time limit; restart so the new limit applies
$probe = Get-ScheduledTask -TaskName 'minibank-probe' -ErrorAction SilentlyContinue
if ($probe) {
    Register-ScheduledTask -TaskName 'minibank-probe' -Description 'MiniBank availability probe (probe.ps1), no run-time limit' `
        -Action $probe.Actions -Trigger (New-TaskTriggers '') -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Stop-ScheduledTask -TaskName 'minibank-probe' -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-ScheduledTask -TaskName 'minibank-probe'
} else {
    Write-Warning 'Task minibank-probe not found: create it first (Chapter 17.2), then run this script again.'
}
Start-ScheduledTask -TaskName 'minibank-traffic'
Start-Sleep -Seconds 5
foreach ($n in 'minibank-traffic', 'minibank-probe') {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($t) {
        $kinds = ($t.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace 'MSFT_Task', '' -replace 'Trigger', '' }) -join ' + '
        '{0}: {1}, run-time limit {2} (PT0S = none), triggers {3}' -f $n, $t.State, $t.Settings.ExecutionTimeLimit, $kinds
    }
}
