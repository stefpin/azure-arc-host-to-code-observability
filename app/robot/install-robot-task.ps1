<#
  MiniBank v1.4 - install the browser robot on APP-WIN (PowerShell as Administrator, APP-WIN - PowerShell Direct).
  Registers the scheduled task minibank-robot that runs robot.js with Node.js 24 and the installed Microsoft Edge
  (headless, nothing is downloaded at run time). The task runs as the local Administrator with the logon type S4U
  ('Run whether user is logged on or not', no password is stored). It does NOT run as SYSTEM: Microsoft Edge exits at once
  with exit code 1002 under the SYSTEM account (found in the build on 12 Nov 2026). Like the traffic task on HV-HOST-02 it starts 3 minutes
  after boot, a watchdog trigger every 15 minutes starts it again if it stopped (a running copy is never started twice),
  it restarts after a failure (exit code not 0) and has no run-time limit. Log: C:\BuildLog\robot.log.
  Browser profiles (one per robot customer): C:\ProgramData\MiniBank\robot\profiles\<User ID>.
  Incident note (written by scripts\incident.ps1 on HV-HOST-02): C:\ProgramData\MiniBank\robot\incident.json.

  BEFORE this script, install the npm package once (needs registry.npmjs.org; P1-DC-DEPLOY.md shows the Node.js path):
    Set-Location C:\Build\minibank\robot
    npm.cmd ci          # exact version from package-lock.json; if npm reports a lock file problem: npm.cmd install
    node robot.js --once --type statement --customer SITI.RAHAYU     # one journey in the foreground, ends with result=success
  Then:
    powershell -ExecutionPolicy Bypass -File C:\Build\minibank\robot\install-robot-task.ps1
  Pause the robot : Disable-ScheduledTask minibank-robot; Stop-ScheduledTask minibank-robot
  Resume          : Enable-ScheduledTask minibank-robot; Start-ScheduledTask minibank-robot
  Remove          : powershell -ExecutionPolicy Bypass -File C:\Build\minibank\robot\install-robot-task.ps1 -Remove
#>
param(
    [string]$RobotDir = 'C:\Build\minibank\robot',
    [string]$DataDir = 'C:\ProgramData\MiniBank\robot',
    [string]$LogFile = 'C:\BuildLog\robot.log',
    [string]$BaseUrl = 'http://192.168.110.31:8080',
    [string]$NodeExe = '',
    [string]$RunAsUser = "$env:COMPUTERNAME\Administrator",
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'
$taskName = 'minibank-robot'

# Stops the robot's node.exe and the Edge processes that use the robot profiles.
function Stop-RobotProcesses {
    $profiles = Join-Path $DataDir 'profiles'
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
        Where-Object { $_.CommandLine -like '*robot.js*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
        Where-Object { $_.CommandLine -like "*$profiles*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if ($Remove) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    Stop-RobotProcesses
    "Task $taskName removed and robot processes stopped. Profiles ($DataDir) and log ($LogFile) are kept; delete them by hand if wanted."
    return
}

# 1. Node.js 24: -NodeExe, else node.exe on the PATH, else the portable Node.js of runbook Chapter 15.4 (C:\tools\node-v24.*-win-x64)
if (-not $NodeExe) {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($cmd) { $NodeExe = $cmd.Source }
}
if (-not $NodeExe) {
    $portable = Get-ChildItem 'C:\tools' -Directory -Filter 'node-v24*-win-x64' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($portable) { $NodeExe = Join-Path $portable.FullName 'node.exe' }
}
if (-not $NodeExe -or -not (Test-Path $NodeExe)) {
    throw 'node.exe (Node.js 24) not found: pass -NodeExe <full path of node.exe>.'
}
$nodeVersion = (& $NodeExe --version).Trim()
if ($nodeVersion -notlike 'v24.*') { Write-Warning "Node.js $nodeVersion found; the robot is built for Node.js 24." }

# 2. Microsoft Edge and the npm package
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge (msedge.exe) not found in Program Files.' }
if (-not (Test-Path (Join-Path $RobotDir 'node_modules\playwright-core\package.json'))) {
    throw "playwright-core is not installed: run 'npm.cmd ci' in $RobotDir first (see the top of this script)."
}

# 3. Folders
New-Item -ItemType Directory -Force -Path (Join-Path $DataDir 'profiles'), (Split-Path $LogFile) | Out-Null

# 4. Task: local Administrator (S4U, no stored password), at boot (after 3 minutes) + watchdog every 15 minutes,
#    restart after failure, no run-time limit
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}
Stop-RobotProcesses
$robotJs = Join-Path $RobotDir 'robot.js'
$argLine = "`"$robotJs`" --base-url $BaseUrl --data-dir `"$DataDir`" --log `"$LogFile`""
$action = New-ScheduledTaskAction -Execute $NodeExe -Argument $argLine -WorkingDirectory $RobotDir
$boot = New-ScheduledTaskTrigger -AtStartup
$boot.Delay = 'PT3M'
$watchdog = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType S4U -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Description 'MiniBank v1.4 browser robot (robot.js, Node.js + Edge headless): simulated customers, incident note' `
    -Action $action -Trigger @($boot, $watchdog) -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 20
$t = Get-ScheduledTask -TaskName $taskName
'{0}: {1}, runs as {2} ({3}), node {4} ({5}), Edge {6}, run-time limit {7} (PT0S = none)' -f $taskName, $t.State,
    $t.Principal.UserId, $t.Principal.LogonType, $nodeVersion, $NodeExe, (Get-Item $edge).VersionInfo.ProductVersion, $t.Settings.ExecutionTimeLimit
if (Test-Path $LogFile) { Get-Content $LogFile -Tail 5 }
