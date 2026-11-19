#Requires -RunAsAdministrator
<#
  MiniBank v1.4 incident command - HV-HOST-02, Windows PowerShell 5.1 as Administrator (Hyper-V host of APP-WIN).
  One command starts the incident window of Scene 5 or Scene 6 for BOTH load drivers:
   1. it writes the incident note (scenario phases with their end time in UTC) and copies it into APP-WIN with Hyper-V
      Copy-VMFile (Guest Service Interface, no guest credentials) as C:\ProgramData\MiniBank\robot\incident.json.
      The browser robot reads the note every 30 s: while a phase is active it runs 1 payment journey every 30 s and every
      3rd journey carries the phase scenario; after the last phase it returns to its normal pace by itself.
   2. it starts the traffic generator window(s) of the former Scene 6 command as background processes (minimized windows),
      so this window returns at once:
        Scene 6: traffic.ps1 -Minutes 10 -PerMinute 6 -Scenario fail-oracle
        Scene 5: traffic.ps1 -Minutes 5 -PerMinute 6 -Scenario slow-oracle, then (5 minutes later) the 10-minute
                 fail-oracle window above
  -Scene 6 : fail-oracle for 10 minutes from now.
  -Scene 5 : slow-oracle for 5 minutes, then fail-oracle for 10 minutes (15 minutes from now).
  -Stop    : writes an expired note (the robot is back to normal pace within 30 s) and stops the generator processes
             that the last -Scene run started (process IDs in C:\ProgramData\MiniBank\incident\incident-generators.json).
  A new -Scene run first stops the generators of the previous run.
  Examples (PowerShell as Administrator on HV-HOST-02, folder F:\Build\minibank\scripts):
    powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Scene 6
    powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Scene 5
    powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Stop
  Log: C:\BuildLog\incident.log; the generator lines also go to C:\BuildLog\incident-traffic.log.
#>
param(
    [ValidateSet(0, 5, 6)][int]$Scene = 0,
    [switch]$Stop,
    [string]$VMName = 'APP-WIN',
    [string]$GuestNote = 'C:\ProgramData\MiniBank\robot\incident.json',
    [string]$BaseUrl = 'http://192.168.110.31:8080',
    [int]$PerMinute = 6,
    [string]$ScriptsDir = $PSScriptRoot,
    [string]$StateDir = 'C:\ProgramData\MiniBank\incident',
    [string]$LogFile = 'C:\BuildLog\incident.log',
    [ValidateSet('Normal', 'Minimized')][string]$WindowStyle = 'Minimized'
)
$ErrorActionPreference = 'Stop'
if ($Stop -and $Scene) { throw 'Use either -Scene 5, -Scene 6 or -Stop.' }
if (-not $Stop -and -not $Scene) { throw 'Usage: .\incident.ps1 -Scene 5 | -Scene 6 | -Stop' }
$inv = [Globalization.CultureInfo]::InvariantCulture
$pidFile = Join-Path $StateDir 'incident-generators.json'
New-Item -ItemType Directory -Force -Path $StateDir, (Split-Path $LogFile) | Out-Null

function Format-Utc([DateTime]$Time) { $Time.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $inv) }
function Format-Local([DateTime]$Time) { $Time.ToLocalTime().ToString('HH:mm:ss', $inv) }

function Write-IncidentLog([string]$Text) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text
    Write-Host $line
    try { Add-Content -Path $LogFile -Value $line -Encoding ASCII } catch { }
}

# Writes the note (UTF-8 without BOM) and copies it into the robot's VM. Returns $true when the copy worked.
function Write-Note([int]$SceneNo, $Phases, [DateTime]$WrittenUtc) {
    $items = @(foreach ($p in $Phases) { '    {{ "scenario": "{0}", "endUtc": "{1}" }}' -f $p.Scenario, (Format-Utc $p.EndUtc) })
    if ($items.Count -gt 0) { $phaseText = "[`r`n" + ($items -join ",`r`n") + "`r`n  ]" } else { $phaseText = '[]' }
    $json = "{`r`n  `"scene`": $SceneNo,`r`n  `"writtenUtc`": `"$(Format-Utc $WrittenUtc)`",`r`n  `"phases`": $phaseText,`r`n" +
            "  `"writtenBy`": `"incident.ps1 on $env:COMPUTERNAME`"`r`n}`r`n"
    $local = Join-Path $StateDir 'incident.json'
    [IO.File]::WriteAllText($local, $json, (New-Object Text.UTF8Encoding $false))
    try {
        Copy-VMFile -Name $VMName -SourcePath $local -DestinationPath $GuestNote -FileSource Host -CreateFullPath -Force
        return $true
    } catch {
        $text = 'The note could not be copied into {0}: {1}. The robot does NOT follow this incident (check that {0} ' +
                'is running and Guest Service Interface is enabled); the traffic generator part still works.'
        Write-Warning ($text -f $VMName, $_.Exception.Message)
        return $false
    }
}

# Starts one generator window: it waits until the phase start, then runs traffic.ps1 for the phase.
function Start-Generator($Phase, [string]$Title) {
    $traffic = (Join-Path $ScriptsDir 'traffic.ps1').Replace("'", "''")
    $genLog = (Join-Path (Split-Path $LogFile) 'incident-traffic.log').Replace("'", "''")
    $scenario = $Phase.Scenario
    $script = @"
`$Host.UI.RawUI.WindowTitle = '$Title'
`$start = New-Object DateTime -ArgumentList $($Phase.StartUtc.Ticks), ([DateTimeKind]::Utc)
`$wait = (`$start - [DateTime]::UtcNow).TotalSeconds
if (`$wait -gt 1) {
    Write-Host ('Waiting {0:N0} s: the $scenario phase starts at {1:HH:mm:ss}' -f `$wait, `$start.ToLocalTime())
    Start-Sleep -Seconds ([int][Math]::Ceiling(`$wait))
}
try {
    & '$traffic' -BaseUrl '$BaseUrl' -Minutes $($Phase.Minutes) -PerMinute $PerMinute -Scenario $scenario -LogFile '$genLog'
} catch {
    Write-Host ('traffic.ps1 stopped: ' + `$_.Exception.Message) -ForegroundColor Red
    Start-Sleep -Seconds 120
}
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded `
        -WindowStyle $WindowStyle -PassThru
    [pscustomobject]@{ Pid = $p.Id; StartTicks = $p.StartTime.ToUniversalTime().Ticks; Scenario = $scenario
                       Minutes = $Phase.Minutes; PhaseStartUtc = (Format-Utc $Phase.StartUtc) }
}

# Stops the generator processes saved by the last -Scene run (only if the process ID still belongs to that process).
function Stop-Generators {
    if (-not (Test-Path $pidFile)) { return 0 }
    $stopped = 0
    $saved = Get-Content $pidFile -Raw | ConvertFrom-Json
    foreach ($g in $saved) {
        $proc = Get-Process -Id ([int]$g.Pid) -ErrorAction SilentlyContinue
        if ($proc -and [Math]::Abs($proc.StartTime.ToUniversalTime().Ticks - [long]$g.StartTicks) -lt [TimeSpan]::TicksPerSecond) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            $stopped++
        }
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    return $stopped
}

if (-not (Get-Command Copy-VMFile -ErrorAction SilentlyContinue)) {
    Write-Warning 'Copy-VMFile (Hyper-V PowerShell module) is not available: the robot cannot be told about the incident.'
}

if ($Stop) {
    $copied = Write-Note 0 @() ([DateTime]::UtcNow)
    $stopped = Stop-Generators
    $robotText = 'robot back to normal pace within 30 s'
    if (-not $copied) { $robotText = 'note NOT copied to the robot' }
    Write-IncidentLog ("Stop: expired note written ({0}); {1} generator process(es) stopped" -f $robotText, $stopped)
    return
}

$traffic = Join-Path $ScriptsDir 'traffic.ps1'
if (-not (Test-Path $traffic)) { throw "traffic.ps1 not found in $ScriptsDir" }
$previous = Stop-Generators
if ($previous) { Write-IncidentLog "Previous incident: $previous generator process(es) stopped" }

$now = [DateTime]::UtcNow
if ($Scene -eq 5) {
    $phases = @(
        [pscustomobject]@{ Scenario = 'slow-oracle'; Minutes = 5; StartUtc = $now; EndUtc = $now.AddMinutes(5) },
        [pscustomobject]@{ Scenario = 'fail-oracle'; Minutes = 10; StartUtc = $now.AddMinutes(5); EndUtc = $now.AddMinutes(15) }
    )
} else {
    $phases = @([pscustomobject]@{ Scenario = 'fail-oracle'; Minutes = 10; StartUtc = $now; EndUtc = $now.AddMinutes(10) })
}
$copied = Write-Note $Scene $phases $now
$generators = @()
$i = 0
foreach ($p in $phases) {
    $i++
    $title = 'MiniBank incident Scene {0} - phase {1}: {2} {3} min from {4}' -f $Scene, $i, $p.Scenario, $p.Minutes, (Format-Local $p.StartUtc)
    $generators += Start-Generator $p $title
}
ConvertTo-Json -InputObject @($generators) -Depth 3 | Set-Content -Path $pidFile -Encoding ASCII

$phaseText = ($phases | ForEach-Object { '{0} {1}-{2}' -f $_.Scenario, (Format-Local $_.StartUtc), (Format-Local $_.EndUtc) }) -join ', '
$robotText = "note copied to $VMName, robot follows within 30 s"
if (-not $copied) { $robotText = 'note NOT copied, robot stays at normal pace' }
Write-IncidentLog ("Scene {0} incident: {1} (host time); {2}; generator PID(s) {3}" -f $Scene, $phaseText, $robotText,
    (($generators | ForEach-Object { $_.Pid }) -join ', '))
Write-Host ("Ends by itself at {0}. Stop early: powershell -ExecutionPolicy Bypass -File {1} -Stop" -f
    (Format-Local $phases[-1].EndUtc), (Join-Path $ScriptsDir 'incident.ps1'))
