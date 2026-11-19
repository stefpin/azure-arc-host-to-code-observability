<#
  MiniBank v1.3 - install the balance top-up on APP-SQL (PowerShell as Administrator, APP-SQL - PowerShell Direct).
  Registers the scheduled task minibank-topup (runs as SYSTEM, a SQL Server sysadmin through BUILTIN\Administrators)
  that runs topup-demo-balances.ps1 at 00:00, 06:00, 12:00 and 18:00 WIB (converted to this VM's time zone; a run
  missed while the VM was off starts when it is back), then runs it once and shows the log.
  v1.4: the task action is unchanged; topup-demo-balances.sql now tops up all 66 accounts by tier (view
  dbo.DemoBalanceTargets from db\sqlserver\02-p1-tiers-customers.sql). Running this installer again is optional: it only
  refreshes the task description and runs one top-up.
    powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\install-topup-task.ps1
  Other times (WIB): -HoursWib 1,7,13,19
#>
param(
    [string]$ScriptsDir = 'C:\Build\minibank\scripts',
    [int[]]$HoursWib = @(0, 6, 12, 18)
)
$ErrorActionPreference = 'Stop'
$wibZone = [TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
$triggers = foreach ($h in $HoursWib) {
    $wib = [DateTime]::SpecifyKind([DateTime]::Today.AddHours($h), [DateTimeKind]::Unspecified)
    $local = [TimeZoneInfo]::ConvertTime($wib, $wibZone, [TimeZoneInfo]::Local)
    New-ScheduledTaskTrigger -Daily -At $local
}
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptsDir\topup-demo-balances.ps1"
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'minibank-topup' -Description 'MiniBank v1.4: set all demo balances to their tier targets (view dbo.DemoBalanceTargets) every 6 hours' `
    -Action $action -Trigger $triggers -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName 'minibank-topup'
Start-Sleep -Seconds 15
$info = Get-ScheduledTaskInfo -TaskName 'minibank-topup'
'minibank-topup: last run {0}, result {1}, next run {2} (VM time zone {3})' -f $info.LastRunTime, $info.LastTaskResult, $info.NextRunTime, (Get-TimeZone).Id
Get-Content 'C:\BuildLog\topup.log' -Tail 1
