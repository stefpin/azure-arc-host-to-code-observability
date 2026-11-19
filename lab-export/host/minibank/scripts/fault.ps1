#Requires -RunAsAdministrator
<#
  MiniBank cross-layer lab v1.5 - fault command (HV-HOST-02, Windows PowerShell 5.1 as Administrator).
  Injects ONE realistic fault in one layer of the MiniBank stack for a few minutes, with an automatic undo, so the
  cross-layer root-cause board (Grafana "MiniBank - Cross-layer root cause" + workbook group) can name the layer.
  Every fault runs with the same extra load (browser robot at incident pace with scenario "normal" + traffic generator
  +6 calls/min "normal"), so the load itself gives nothing away.

  Faults (card names):
    cpu-win        VM layer        : a runaway PowerShell job takes all CPU on APP-WIN (scheduled task in APP-WIN)
    oom-ocp        OpenShift layer : all minibank-transfer containers are OOMKilled (exit 137) every 100 s
    net-rhel       Network layer   : 120 ms +-20 ms delay and 3 % loss on APP-RHEL eth0 towards the OpenShift nodes,
                                     only for Oracle 1521 / PostgreSQL 5432 / fraud 8082 (tc netem, systemd timer undo)
    nullref-api    Application     : minibank-api Statement preview switch on -> NullReferenceException (HTTP 500)
    schema-oracle  Database layer  : table MINIBANK.LEDGER_ENTRY renamed to LEDGER_ENTRY_BAK (Oracle scheduler job undo)
    fail-oracle    Application     : the old scenario fail-oracle (code queries LEDGER_MISSING): same ORA-00942 error as
                                     schema-oracle, different root cause ("same error, two causes"); not in the mystery pool
    cpu-host       Host layer      : the end-of-day batch VM BATCH-EOD starts on HV-HOST-02 and keeps its vCPUs busy, so every VM
                                     waits for CPU (true host load high, Windows on the host still looks idle); VM turned off
                                     at the end, it also stops itself after 7 min; guard task minibank-batch-guard as 3rd stop
    none           (no fault)      : only the extra load (healthy slot of a test series)

  Usage (folder F:\Build\minibank\scripts):
    .\fault.ps1 -Fault net-rhel [-Minutes 5]     labelled run (rehearsal / known fault)
    .\fault.ps1 -Mystery [-Pick 3]               blind draw from the pool of 5: the bank picks a number 1-5 (no -Pick = random);
                                                 prints only the draw id and the sealed fingerprint; runs 8 minutes
    .\fault.ps1 -Reveal                          ends the fault, shows the card, checks the fingerprint, compares with the
                                                 board verdict and records the answer (table MiniBankMystery_CL)
    .\fault.ps1 -Stop                            ends every fault NOW (all undo steps, safe to run any time)
    .\fault.ps1 -Status                          what is running (no card name in mystery mode)
    .\fault.ps1 -Series [-SlotMinutes 16] [-FaultMinutes 7]   unattended blind test series: 5 cards + 1 healthy slot in a
                                                 random order (starts a background task, about 90 minutes)
    .\fault.ps1 -LeakCheck [-Hours 3]            searches the telemetry for giveaway words (card names, script names); background fail-* labels listed apart
  Logs: C:\BuildLog\fault.log (no card names in mystery mode); sealed records: C:\ProgramData\MiniBank\sealed (admins only).
#>
param(
    [ValidateSet('', 'cpu-win', 'oom-ocp', 'net-rhel', 'nullref-api', 'schema-oracle', 'fail-oracle', 'cpu-host', 'none')]
    [string]$Fault = '',
    [ValidateRange(1, 30)][int]$Minutes = 5,
    [switch]$Mystery,
    [ValidateRange(0, 6)][int]$Pick = 0,
    [switch]$Reveal,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Series,
    [ValidateRange(8, 40)][int]$SlotMinutes = 16,
    [ValidateRange(3, 20)][int]$FaultMinutes = 7,
    [switch]$LeakCheck,
    [ValidateRange(1, 48)][int]$Hours = 3,
    [switch]$Quiet,
    [string]$Runner = '',
    [string]$SeriesRun = ''
)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$inv = [Globalization.CultureInfo]::InvariantCulture
$ScriptsDir = 'F:\Build\minibank\scripts'
$StateDir = 'C:\ProgramData\MiniBank\fault'
$SealDir = 'C:\ProgramData\MiniBank\sealed'
$VerdictDir = 'C:\ProgramData\MiniBank\verdict'
$LogFile = 'C:\BuildLog\fault.log'
$StateFile = Join-Path $StateDir 'state.json'
$GenFile = Join-Path $StateDir 'generators.txt'
$OcExe = 'C:\Tools\oc\oc.exe'
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
$SshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'
$SshArgs = @('-i', 'F:\Build\ocp\id_ed25519', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=no', '-o',
             'UserKnownHostsFile=F:\Build\ocp\known_hosts', '-o', 'ConnectTimeout=10', 'labadmin@192.168.110.32')
$OcpNodes = @('192.168.110.21', '192.168.110.22', '192.168.110.23', '192.168.110.24')
$Pool = @('cpu-win', 'oom-ocp', 'net-rhel', 'nullref-api', 'schema-oracle')
# Host card cpu-host (14 Nov 2026): in the mystery pool only when mystery-host.on exists (after two clean blind series),
# in blind series when series-host.on or mystery-host.on exists (C:\ProgramData\MiniBank\fault).
if (Test-Path (Join-Path $StateDir 'mystery-host.on')) { $Pool += 'cpu-host' }
$SeriesPool = @($Pool); if ((Test-Path (Join-Path $StateDir 'series-host.on')) -and ($SeriesPool -notcontains 'cpu-host')) { $SeriesPool += 'cpu-host' }
$Layer = @{ 'cpu-win' = 'VM'; 'oom-ocp' = 'OpenShift'; 'net-rhel' = 'Network'; 'nullref-api' = 'Application';
            'schema-oracle' = 'Database'; 'fail-oracle' = 'Application'; 'cpu-host' = 'Host'; 'none' = 'Healthy' }
$Story = @{ 'cpu-win' = 'APP-WIN: a runaway PowerShell job takes all CPU (VM layer)';
            'oom-ocp' = 'OpenShift: minibank-transfer containers OOMKilled every 100 s (exit 137)';
            'net-rhel' = 'Network: 120 ms delay + 3 % loss between OpenShift and APP-RHEL (Oracle, fraud)';
            'nullref-api' = 'Application: minibank-api Statement preview throws NullReferenceException';
            'schema-oracle' = 'Database: table MINIBANK.LEDGER_ENTRY renamed (schema change)';
            'fail-oracle' = 'Application: minibank-transfer code queries table LEDGER_MISSING (ORA-00942)';
            'cpu-host' = 'HV-HOST-02: the end-of-day batch VM BATCH-EOD takes most of the host CPU (Host layer)';
            'none' = 'No fault (healthy slot)' }
# Logs Ingestion (DCR dcr-minibank-rca, kind Direct) and the workspace for the verdict history
$DceUri = 'https://dcr-minibank-rca-jnvj-indonesiacentral.logs.z1.ingest.monitor.azure.com'
$DcrImmutableId = 'dcr-<IMMUTABLE_ID>'
$WorkspaceId = '<WORKSPACE_ID>'
New-Item -ItemType Directory -Force -Path $StateDir, $VerdictDir, (Split-Path $LogFile) | Out-Null

function Utc([DateTime]$t) { $t.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $inv) }
function Wib([DateTime]$t) { $t.ToUniversalTime().AddHours(7).ToString('HH:mm:ss', $inv) }
function Write-FaultLog([string]$Text, [switch]$Show) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text
    try { Add-Content -Path $LogFile -Value $line -Encoding ASCII } catch { }
    if ($Show -and -not $Quiet) { Write-Host $Text }
}
function Read-State { if (Test-Path $StateFile) { try { return (Get-Content $StateFile -Raw | ConvertFrom-Json) } catch { } }; return $null }
function Save-State($obj) { ConvertTo-Json -InputObject $obj -Depth 5 | Set-Content -Path $StateFile -Encoding ASCII }

function Initialize-SealDir {
    if (-not (Test-Path $SealDir)) { New-Item -ItemType Directory -Force -Path $SealDir | Out-Null }
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($who in 'NT AUTHORITY\SYSTEM', 'BUILTIN\Administrators') {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($who, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -Path $SealDir -AclObject $acl
}
function Get-RandomInt([int]$Max) {   # 0 .. Max-1, cryptographic RNG
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $b = New-Object byte[] 4
    $rng.GetBytes($b); return [int]([BitConverter]::ToUInt32($b, 0) % [uint32]$Max)
}
function Get-Shuffled([string[]]$Items) {
    $a = [Collections.ArrayList]@($Items)
    for ($i = $a.Count - 1; $i -gt 0; $i--) { $j = Get-RandomInt ($i + 1); $tmp = $a[$i]; $a[$i] = $a[$j]; $a[$j] = $tmp }
    return [string[]]$a.ToArray()
}
function Get-Fingerprint([string]$RunId, [int]$Slot, [int]$Number, [string]$Card, [string]$Salt) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $h = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$RunId|$Slot|$Number|$Card|$Salt"))
    return ([BitConverter]::ToString($h)).Replace('-', '')
}
function Format-Fingerprint([string]$Hex) { ($Hex.Substring(0, 16) -split '(.{4})' | Where-Object { $_ }) -join ' ' }

# ---- guest access -------------------------------------------------------------------------------------------
$script:GuestCred = $null
function Get-GuestCred {
    if (-not $script:GuestCred) {
        $map = @{}
        Get-Content F:\Build\ENVIRONMENT.txt | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $kv = $_ -split '=', 2; $map[$kv[0]] = $kv[1] }
        $script:GuestCred = New-Object System.Management.Automation.PSCredential('Administrator', (ConvertTo-SecureString $map['WIN_GUEST_PASSWORD'] -AsPlainText -Force))
    }
    return $script:GuestCred
}
function Invoke-AppWin([scriptblock]$Block, [object[]]$Arguments = @()) {
    try { return @(Invoke-Command -VMName APP-WIN -Credential (Get-GuestCred) -ScriptBlock $Block -ArgumentList $Arguments -ErrorAction Stop) }
    catch { return @("APP-WIN error: $($_.Exception.Message)") }
}
function Invoke-Rhel([string]$Bash) {   # runs a bash script as root on APP-RHEL (base64, so no quoting problems)
    $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Bash.Replace("`r`n", "`n")))
    return @(& $SshExe @SshArgs "echo $b64 | base64 -d | sudo bash" 2>&1 | ForEach-Object { "$_" })
}
function Invoke-Oracle([string]$Sql) {   # SQL*Plus as SYSDBA inside the Oracle container, PDB FREEPDB1
    $text = "SET FEEDBACK OFF HEADING OFF PAGESIZE 0 VERIFY OFF`nALTER SESSION SET CONTAINER=FREEPDB1;`n" + $Sql + "`nEXIT`n"
    $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($text.Replace("`r`n", "`n")))
    return Invoke-Rhel "echo $b64 | base64 -d | timeout 90 podman exec -i minibank-oracle sqlplus -s / as sysdba"
}

# ---- load: robot note + generator ---------------------------------------------------------------------------
function Write-RobotNote([DateTime]$EndUtc, [string]$Scenario) {
    $now = [DateTime]::UtcNow
    if ($EndUtc -gt $now) { $phases = '[ { "scenario": "' + $Scenario + '", "endUtc": "' + (Utc $EndUtc) + '" } ]' } else { $phases = '[]' }
    $json = '{ "scene": 0, "writtenUtc": "' + (Utc $now) + '", "phases": ' + $phases + ', "writtenBy": "HV-HOST-02" }'
    $local = Join-Path $StateDir 'robot-note.json'
    [IO.File]::WriteAllText($local, $json, (New-Object Text.UTF8Encoding $false))
    try { Copy-VMFile -Name APP-WIN -SourcePath $local -DestinationPath 'C:\ProgramData\MiniBank\robot\incident.json' -FileSource Host -CreateFullPath -Force -ErrorAction Stop; return $true }
    catch { Write-FaultLog ("robot note not copied: " + $_.Exception.Message); return $false }
}
function Start-Load([int]$Mins, [string]$Scenario) {
    $traffic = Join-Path $ScriptsDir 'traffic.ps1'
    $cmd = "& '$traffic' -BaseUrl 'http://192.168.110.31:8080' -Minutes $Mins -PerMinute 6 -Scenario $Scenario -LogFile 'C:\BuildLog\fault-traffic.log'"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $p = Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-EncodedCommand', $enc -WindowStyle Hidden -PassThru
    Add-Content -Path $GenFile -Value ("{0} {1}" -f $p.Id, $p.StartTime.ToUniversalTime().Ticks) -Encoding ASCII
}
function Stop-Load {
    $n = 0
    if (Test-Path $GenFile) {
        foreach ($line in @(Get-Content $GenFile)) {
            $f = "$line".Trim().Split(' ')
            if ($f.Count -lt 2) { continue }
            $proc = Get-Process -Id ([int]$f[0]) -ErrorAction SilentlyContinue
            if ($proc -and [Math]::Abs($proc.StartTime.ToUniversalTime().Ticks - [long]$f[1]) -lt [TimeSpan]::TicksPerSecond) { Stop-Process -Id $proc.Id -Force; $n++ }
        }
        Remove-Item $GenFile -Force -ErrorAction SilentlyContinue
    }
    return $n
}

# ---- the faults ---------------------------------------------------------------------------------------------
function Start-FaultCpuWin([int]$Mins) {
    return Invoke-AppWin -Arguments @($Mins) -Block { param($m)
        $dir = 'C:\ProgramData\MiniBank\jobs'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $end = [DateTime]::UtcNow.AddMinutes($m).Ticks
        $job = @(
            '# MiniBank lab: report export job (runaway loop, ends by itself)',
            '[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::AboveNormal',
            ('$end = New-Object DateTime -ArgumentList ' + $end + ', ([DateTimeKind]::Utc)'),
            '$work = { param($e) while ([DateTime]::UtcNow -lt $e) { $x = 0; for ($k = 0; $k -lt 300000; $k++) { $x = $x + $k } } }',
            '$all = @(); for ($i = 0; $i -lt 16; $i++) { $ps = [PowerShell]::Create(); [void]$ps.AddScript($work).AddArgument($end); $all += $ps.BeginInvoke() }',
            'while ([DateTime]::UtcNow -lt $end) { Start-Sleep -Seconds 5 }')
        Set-Content -Path "$dir\report-export.ps1" -Value $job -Encoding ASCII
        $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $dir\report-export.ps1"
        $set = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes ($m + 2)) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName 'MiniBank Report Export' -Action $act -Settings $set -User SYSTEM -RunLevel Highest -Force | Out-Null
        Start-ScheduledTask -TaskName 'MiniBank Report Export'
        'cpu job started on APP-WIN until ' + (New-Object DateTime -ArgumentList $end, ([DateTimeKind]::Utc)).ToString('HH:mm:ss') + ' UTC'
    }
}
function Stop-FaultCpuWin {
    return Invoke-AppWin -Block {
        $t = Get-ScheduledTask -TaskName 'MiniBank Report Export' -ErrorAction SilentlyContinue
        if ($t) { Stop-ScheduledTask -TaskName 'MiniBank Report Export' -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'MiniBank Report Export' -Confirm:$false -ErrorAction SilentlyContinue }
        $k = 0
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'report-export\.ps1' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $k++ }
        Remove-Item 'C:\ProgramData\MiniBank\api\statement-header.json' -Force -ErrorAction SilentlyContinue
        "APP-WIN reset (cpu job task $([bool]$t), killed $k, statement switch removed)"
    }
}
# ---- host card: noisy-neighbour VM BATCH-EOD (no network adapter, never starts by itself) ----------------------
function Get-HostVcpu {   # vCPUs given to BATCH-EOD for the next run: C:\ProgramData\MiniBank\fault\cpu-host.txt (2-16, default 12)
    $n = 12; $p = Join-Path $StateDir 'cpu-host.txt'
    if (Test-Path $p) { $v = 0; if ([int]::TryParse((Get-Content $p -Raw).Trim(), [ref]$v) -and $v -ge 2 -and $v -le 16) { $n = $v } }
    return $n
}
function Start-FaultCpuHost([int]$Mins) {
    $vm = Get-VM -Name 'BATCH-EOD' -ErrorAction SilentlyContinue
    if (-not $vm) { return 'BATCH-EOD VM missing' }
    if ($vm.State -ne 'Off') { Stop-VM -Name 'BATCH-EOD' -TurnOff -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
    $n = Get-HostVcpu
    Set-VMProcessor -VMName 'BATCH-EOD' -Count $n
    Start-VM -Name 'BATCH-EOD'
    return "BATCH-EOD started with $n vCPU (busy for up to 7 min, then it stops itself)"
}
function Stop-FaultCpuHost {
    $vm = Get-VM -Name 'BATCH-EOD' -ErrorAction SilentlyContinue
    if (-not $vm) { return 'BATCH-EOD: none' }
    if ($vm.State -ne 'Off') { Stop-VM -Name 'BATCH-EOD' -TurnOff -Force -ErrorAction SilentlyContinue; return "BATCH-EOD turned off (was $($vm.State))" }
    return 'BATCH-EOD off'
}
function Get-ReadyNodes {   # names of Ready OpenShift nodes, or $null when the API does not answer
    $out = @(& $OcExe get nodes --no-headers --request-timeout=10s 2>&1 | ForEach-Object { "$_" })
    $rows = @($out | Where-Object { $_ -match '^ocp-node-\d+\s+\S+' })
    if ($rows.Count -eq 0) { return $null }
    return @($rows | Where-Object { ($_ -split '\s+')[1] -match '^Ready' } | ForEach-Object { ($_ -split '\s+')[0] })
}
function Start-FaultNullRef([int]$Mins) {
    $until = Utc ([DateTime]::UtcNow.AddMinutes($Mins))
    return Invoke-AppWin -Arguments @($until) -Block { param($u)
        New-Item -ItemType Directory -Force -Path 'C:\ProgramData\MiniBank\api' | Out-Null
        Set-Content -Path 'C:\ProgramData\MiniBank\api\statement-header.json' -Value ('{"untilUtc":"' + $u + '"}') -Encoding ASCII
        "statement switch on until $u"
    }
}
function Start-FaultOomRound {
    $pods = @(& $OcExe get pods -n minibank -l app=minibank-transfer --field-selector=status.phase=Running -o name 2>&1 | Where-Object { "$_" -like 'pod/*' })
    foreach ($p in $pods) {
        Start-Process -FilePath $OcExe -ArgumentList "exec -n minibank $p -c minibank-transfer -- /usr/bin/tail /dev/zero" -WindowStyle Hidden | Out-Null
    }
    return "oom round: $($pods.Count) pods"
}
function Get-NetemBash([int]$Mins) {
    $filters = foreach ($ip in $OcpNodes) { foreach ($sp in 1521, 5432, 8082) { "tc filter add dev eth0 protocol ip parent 1: prio 1 u32 match ip dst $ip/32 match ip sport $sp 0xffff flowid 1:4" } }
    return @"
tc qdisc del dev eth0 root 2>/dev/null
tc qdisc add dev eth0 root handle 1: prio bands 4 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 || exit 1
tc qdisc add dev eth0 parent 1:4 handle 40: netem delay 250ms 30ms distribution normal loss 3% || { tc qdisc del dev eth0 root; exit 1; }
$($filters -join "`n")
systemctl stop minibank-net-restore.timer 2>/dev/null; systemctl reset-failed minibank-net-restore.timer minibank-net-restore.service 2>/dev/null
systemd-run --quiet --unit=minibank-net-restore --on-active=${Mins}min --timer-property=AccuracySec=1s /usr/sbin/tc qdisc del dev eth0 root
echo "netem on: `$(tc qdisc show dev eth0 | grep -c netem) netem qdisc, `$(tc filter show dev eth0 | grep -c 'flowid 1:4') filters"
"@
}
function Get-RhelResetBash {
    return @'
tc qdisc show dev eth0 | grep -q 'qdisc prio 1:' && tc qdisc del dev eth0 root
systemctl stop minibank-net-restore.timer 2>/dev/null; systemctl reset-failed minibank-net-restore.timer minibank-net-restore.service 2>/dev/null
echo "eth0 root qdisc now: $(tc qdisc show dev eth0 | head -1 | cut -c1-40)"
'@
}
$SqlRename = @"
ALTER SESSION SET DDL_LOCK_TIMEOUT = 15;
ALTER TABLE MINIBANK.LEDGER_ENTRY RENAME TO LEDGER_ENTRY_BAK;
BEGIN DBMS_SCHEDULER.CREATE_JOB(job_name => 'LEDGER_MAINT_RESTORE', job_type => 'PLSQL_BLOCK',
  job_action => 'BEGIN EXECUTE IMMEDIATE ''ALTER SESSION SET DDL_LOCK_TIMEOUT = 30''; EXECUTE IMMEDIATE ''ALTER TABLE MINIBANK.LEDGER_ENTRY_BAK RENAME TO LEDGER_ENTRY''; END;',
  start_date => SYSTIMESTAMP + NUMTODSINTERVAL(__MIN__, 'MINUTE'), enabled => TRUE, auto_drop => TRUE); END;
/
SELECT 'ledger tables: ' || LISTAGG(table_name, ',') WITHIN GROUP (ORDER BY table_name) FROM dba_tables WHERE owner = 'MINIBANK' AND table_name LIKE 'LEDGER_ENTRY%';
"@
$SqlRestore = @"
ALTER SESSION SET DDL_LOCK_TIMEOUT = 15;
DECLARE n NUMBER; BEGIN SELECT COUNT(*) INTO n FROM dba_tables WHERE owner = 'MINIBANK' AND table_name = 'LEDGER_ENTRY_BAK';
  IF n = 1 THEN EXECUTE IMMEDIATE 'ALTER TABLE MINIBANK.LEDGER_ENTRY_BAK RENAME TO LEDGER_ENTRY'; END IF; END;
/
BEGIN DBMS_SCHEDULER.DROP_JOB('LEDGER_MAINT_RESTORE', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
/
SELECT 'ledger tables: ' || LISTAGG(table_name, ',') WITHIN GROUP (ORDER BY table_name) FROM dba_tables WHERE owner = 'MINIBANK' AND table_name LIKE 'LEDGER_ENTRY%';
"@

function Start-Card([string]$Card, [int]$Mins) {
    switch ($Card) {
        'cpu-win'       { return (Start-FaultCpuWin $Mins) -join ' ' }
        'nullref-api'   { return (Start-FaultNullRef $Mins) -join ' ' }
        'net-rhel'      { return (Invoke-Rhel (Get-NetemBash $Mins)) -join ' ' }
        'schema-oracle' { return (Invoke-Oracle ($SqlRename.Replace('__MIN__', "$Mins"))) -join ' ' }
        'oom-ocp'       { return Start-FaultOomRound }
        'cpu-host'      { return Start-FaultCpuHost $Mins }
        default         { return "no guest change ($Card)" }
    }
}
# Silent check that the fault really took effect (within about 60 s); $true / $false
function Test-Card([string]$Card) {
    switch ($Card) {
        'cpu-win' {
            $lp = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors   # Get-VM CPUUsage is % of the whole host
            for ($i = 0; $i -lt 6; $i++) { Start-Sleep -Seconds 10; $vm = Get-VM APP-WIN; if ($vm.ProcessorCount -gt 0 -and ($vm.CPUUsage * $lp / $vm.ProcessorCount) -ge 70) { return $true } }
            return $false
        }
        'nullref-api' {
            Start-Sleep -Seconds 8
            try { Invoke-WebRequest -UseBasicParsing -Uri 'http://192.168.110.31:8080/api/accounts/9901000011/statement?days=7' -Headers @{ 'X-MiniBank-Source' = 'probe' } -TimeoutSec 20 | Out-Null; return $false }
            catch { return ([int]$_.Exception.Response.StatusCode -eq 500) }
        }
        'cpu-host' {
            $lp = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors   # Get-VM CPUUsage is % of the whole host
            for ($i = 0; $i -lt 15; $i++) { Start-Sleep -Seconds 8; $vm = Get-VM -Name 'BATCH-EOD' -ErrorAction SilentlyContinue; if ($vm -and $vm.State -eq 'Running' -and $vm.ProcessorCount -gt 0 -and ($vm.CPUUsage * $lp / $vm.ProcessorCount) -ge 70) { return $true } }
            return $false
        }
        'net-rhel' { return ((Invoke-Rhel 'tc qdisc show dev eth0 | grep -c netem') -contains '1') }
        'schema-oracle' { return (((Invoke-Oracle "SELECT 'n=' || COUNT(*) FROM dba_tables WHERE owner = 'MINIBANK' AND table_name = 'LEDGER_ENTRY';") -join ' ') -match 'n=0') }
        'oom-ocp' {
            Start-Sleep -Seconds 20
            $st = (& $OcExe get pods -n minibank -l app=minibank-transfer -o jsonpath='{range .items[*]}{.status.containerStatuses[0].lastState.terminated.reason}{.status.containerStatuses[0].lastState.terminated.finishedAt} {end}' 2>&1) -join ' '
            $recent = [DateTime]::UtcNow.AddMinutes(-2)
            foreach ($m in [regex]::Matches($st, 'OOMKilled(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)')) {
                if ([DateTime]::Parse($m.Groups[1].Value).ToUniversalTime() -gt $recent) { return $true }
            }
            return $false
        }
        default { return $true }
    }
}
# Undo of EVERY fault (idempotent, safe any time). Returns text lines.
function Reset-All {
    $out = @()
    $st = Read-State
    if ($st -and $st.RunnerPid) {
        $proc = Get-Process -Id ([int]$st.RunnerPid) -ErrorAction SilentlyContinue
        if ($proc -and $proc.Id -ne $PID -and [Math]::Abs($proc.StartTime.ToUniversalTime().Ticks - [long]$st.RunnerTicks) -lt [TimeSpan]::TicksPerSecond) { Stop-Process -Id $proc.Id -Force; $out += 'runner stopped' }
    }
    Get-CimInstance Win32_Process -Filter "Name='oc.exe'" | Where-Object { $_.CommandLine -match 'tail /dev/zero' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    $out += 'generators stopped: ' + (Stop-Load)
    [void](Write-RobotNote ([DateTime]::UtcNow) 'normal')
    $out += Stop-FaultCpuHost
    $out += (Stop-FaultCpuWin) -join ' '
    $out += (Invoke-Rhel (Get-RhelResetBash)) -join ' '
    $out += (Invoke-Oracle $SqlRestore) -join ' '
    Unregister-ScheduledTask -TaskName 'minibank-fault-watchdog' -Confirm:$false -ErrorAction SilentlyContinue
    return $out
}
function Register-Watchdog([DateTime]$AtUtc) {
    $act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptsDir\fault.ps1 -Stop -Quiet"
    $trg = New-ScheduledTaskTrigger -Once -At $AtUtc.ToLocalTime()
    Register-ScheduledTask -TaskName 'minibank-fault-watchdog' -Action $act -Trigger $trg -User SYSTEM -RunLevel Highest -Force | Out-Null
}
function Start-Runner([string]$Arg) {
    $p = Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "$ScriptsDir\fault.ps1", '-Runner', $Arg -WindowStyle Hidden -PassThru
    return $p
}

# ---- ledger (MiniBankMystery_CL) and verdict history -----------------------------------------------------------
function Get-MiToken([string]$Resource) {
    $u = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + [uri]::EscapeDataString($Resource)
    return (Invoke-RestMethod -Headers @{ Metadata = 'true' } -Uri $u -TimeoutSec 15).access_token
}
function Send-Ledger($Rows) {
    try {
        $tok = Get-MiToken 'https://monitor.azure.com'
        $uri = "$DceUri/dataCollectionRules/$DcrImmutableId/streams/Custom-MiniBankMystery?api-version=2023-01-01"
        $body = ConvertTo-Json -InputObject @($Rows) -Depth 4
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $tok" } -ContentType 'application/json' -Body $body -TimeoutSec 30 | Out-Null
        return 'ledger: ' + @($Rows).Count + ' row(s) sent'
    } catch { return 'ledger upload FAILED: ' + $_.Exception.Message }
}
# First board verdict between From and To, from the observer log: two readings in a row naming the same layer in red
# (RootCause/Unclassified), or (option B, 15 Nov 2026) two readings in a row naming the Host in yellow (Warning) or red;
# host CPU contention in this lab slows customers at most about 2x, so the host card's final answer is a yellow early warning
function Get-BoardVerdict([DateTime]$FromUtc, [DateTime]$ToUtc) {
    $rows = @()
    foreach ($f in Get-ChildItem $VerdictDir -Filter 'verdict-*.jsonl' -ErrorAction SilentlyContinue | Sort-Object Name) {
        foreach ($l in Get-Content $f.FullName) { try { $rows += ($l | ConvertFrom-Json) } catch { } }
    }
    $rows = @($rows | Where-Object { $t = [DateTime]::Parse($_.TimeGenerated).ToUniversalTime(); $t -ge $FromUtc -and $t -le $ToUtc } | Sort-Object { [DateTime]::Parse($_.TimeGenerated) })
    $prev = $null
    foreach ($r in $rows) {
        $red = $r.Status -in 'RootCause', 'Unclassified' -and $prev -and $prev.Status -in 'RootCause', 'Unclassified' -and $prev.Layer -eq $r.Layer
        $hostB = $prev -and $r.Layer -eq 'Host' -and $prev.Layer -eq 'Host' -and $r.Status -in 'Warning', 'RootCause' -and $prev.Status -in 'Warning', 'RootCause'
        if ($red -or $hostB) {
            return [pscustomobject]@{ Layer = $r.Layer; Status = $r.Status; Component = $r.Component; Evidence = $r.Evidence; AtUtc = [DateTime]::Parse($r.TimeGenerated).ToUniversalTime(); Rows = $rows.Count }
        }
        $prev = $r
    }
    return [pscustomobject]@{ Layer = ''; Status = ''; Component = ''; Evidence = ''; AtUtc = $null; Rows = $rows.Count }
}

# Reveal grade with the rules approved on 15 Nov 2026 22:35 WIB (the same rules as the scorecard and the test grader).
# Customers count as affected when two readings in a row show customer impact (Pending, RootCause or Unclassified).
# Affected: the first confirmed answer (two red readings in a row on one layer, or two host warnings in a row) must name the
# expected layer within 5 min of the start, or within 2.5 min of customers being affected if that came later.
# Not affected: that confirmed answer, or else the first layer shown twice in a row (yellow or red), within 5 min.
function Get-RevealGrade([DateTime]$FromUtc, [DateTime]$ToUtc, [string]$Expected) {
    $ci = [Globalization.CultureInfo]::InvariantCulture
    $lo = $FromUtc.AddMinutes(-10)
    $rows = New-Object System.Collections.Generic.List[object]
    for ($day = $lo.Date; $day -le $ToUtc.Date; $day = $day.AddDays(1)) {
        $p = Join-Path $VerdictDir ('verdict-' + $day.ToString('yyyyMMdd', $ci) + '.jsonl')
        if (-not (Test-Path -LiteralPath $p)) { continue }
        foreach ($ln in (Get-Content -LiteralPath $p)) {
            if ($ln -match '"TimeGenerated"\s*:\s*"([^"]+)"') {
                $tq = [DateTime]::Parse($Matches[1], $ci).ToUniversalTime()
                if ($tq -lt $lo -or $tq -gt $ToUtc) { continue }
            }
            try { $o = $ln | ConvertFrom-Json } catch { continue }
            $tr = [DateTime]::Parse([string]$o.TimeGenerated, $ci).ToUniversalTime()
            if ($tr -lt $lo -or $tr -gt $ToUtc) { continue }
            $rows.Add([pscustomobject]@{ T = $tr; Status = [string]$o.Status; Layer = [string]$o.Layer; Component = [string]$o.Component; Evidence = [string]$o.Evidence })
        }
    }
    $impSt = @('Pending', 'RootCause', 'Unclassified'); $redSt = @('RootCause', 'Unclassified'); $seenSt = @('Warning', 'RootCause')
    $noLayer = @('', 'Healthy', 'Pending', 'No layer at fault', 'Unclassified')
    $prev = $null; $nIn = 0; $affT = $null; $conf = $null; $shown = $null
    foreach ($r in @($rows | Sort-Object T)) {
        if ($r.T -ge $FromUtc) {
            $nIn++
            if ($prev) {
                if (-not $affT -and $r.Status -in $impSt -and $prev.Status -in $impSt) { $affT = $prev.T; if ($affT -lt $FromUtc) { $affT = $FromUtc } }
                $redPair = $r.Status -in $redSt -and $prev.Status -in $redSt -and $prev.Layer -eq $r.Layer
                $hostPair = $r.Layer -eq 'Host' -and $prev.Layer -eq 'Host' -and $r.Status -in $seenSt -and $prev.Status -in $seenSt
                if (-not $conf -and ($redPair -or $hostPair)) { $conf = $r }
                if (-not $shown -and $r.Status -in $seenSt -and $prev.Status -in $seenSt -and $prev.Layer -eq $r.Layer -and $r.Layer -notin $noLayer) { $shown = $r }
            }
        }
        $prev = $r
    }
    $affected = $null -ne $affT
    $useYel = (-not $conf) -and (-not $affected) -and ($null -ne $shown)
    $ans = $null; if ($conf) { $ans = $conf } elseif ($useYel) { $ans = $shown }
    $mins = $null; if ($ans) { $mins = [Math]::Round(($ans.T - $FromUtc).TotalMinutes, 1, [MidpointRounding]::AwayFromZero) }
    $impMin = $null; $dueMin = 5.0
    if ($affected) { $impMin = [Math]::Round(($affT - $FromUtc).TotalMinutes, 1, [MidpointRounding]::AwayFromZero); $dueMin = [Math]::Max(5.0, $impMin + 2.5) }
    if (-not $ans) { if ($affected) { $verdict = 'NO VERDICT - customers affected, no confirmed answer' } else { $verdict = 'NO VERDICT - no layer shown twice in a row' } }
    elseif ($ans.Layer -ne $Expected) { $verdict = 'WRONG LAYER: ' + $ans.Layer }
    elseif ($mins -gt $dueMin) { $verdict = 'RIGHT LAYER (late)' }
    elseif ($useYel) { $verdict = 'RIGHT LAYER - early warning, customers not affected' }
    elseif ($ans.Status -eq 'Warning') { $verdict = 'RIGHT LAYER - early warning' }
    else { $verdict = 'RIGHT LAYER' }
    $colour = ''; if ($ans) { if ($ans.Status -eq 'Warning') { $colour = 'yellow' } else { $colour = 'red' } }
    if ($affected) { $custText = "affected from $impMin min after the start (two impact readings in a row) - the answer was due by $dueMin min"; $custShort = "affected from $impMin min" }
    else { $custText = 'not affected (never two impact readings in a row) - the answer was due by 5 min'; $custShort = 'not affected' }
    $resLayer = ''; $resStatus = ''; $resComp = ''; $resEvid = ''; $resAt = $null
    if ($ans) { $resLayer = $ans.Layer; $resStatus = $ans.Status; $resComp = $ans.Component; $resEvid = $ans.Evidence; $resAt = $ans.T }
    return [pscustomobject]@{ Layer = $resLayer; Status = $resStatus; Colour = $colour; Component = $resComp; Evidence = $resEvid; AtUtc = $resAt
                              Rows = $nIn; Minutes = $mins; Affected = $affected; ImpMin = $impMin; DueMin = $dueMin; Verdict = $verdict
                              CustomersText = $custText; CustomersShort = $custShort }
}

# ---- runner (hidden background process): applies the card(s) and keeps OOM rounds going ----------------------
function Invoke-Runner([string]$RunId) {
    $plan = Get-Content (Join-Path $SealDir "$RunId.json") -Raw | ConvertFrom-Json
    foreach ($slot in @($plan.Slots)) {
        $start = [DateTime]::Parse($slot.StartUtc).ToUniversalTime(); $end = [DateTime]::Parse($slot.EndUtc).ToUniversalTime()
        $wait = ($start - [DateTime]::UtcNow).TotalSeconds; if ($wait -gt 0) { Start-Sleep -Seconds ([int][Math]::Ceiling($wait)) }
        $mins = [int][Math]::Max(1, [Math]::Round(($end - [DateTime]::UtcNow).TotalMinutes))
        $scenario = 'normal'; if ($slot.Card -eq 'fail-oracle') { $scenario = 'fail-oracle' }
        [void](Write-RobotNote $end $scenario)
        Start-Load $mins $scenario
        $ready0 = $null; $apiFail = 0; $safety = ''
        if ($slot.Card -eq 'cpu-host') { $ready0 = Get-ReadyNodes }
        $applied = Start-Card $slot.Card $mins
        Add-Content -Path (Join-Path $SealDir "$RunId.log") -Value ("{0} slot {1} {2}: {3}" -f (Utc ([DateTime]::UtcNow)), $slot.Slot, $slot.Card, $applied)
        $ok = Test-Card $slot.Card
        Add-Content -Path (Join-Path $SealDir "$RunId.log") -Value ("{0} slot {1} active-check: {2}" -f (Utc ([DateTime]::UtcNow)), $slot.Slot, $ok)
        $st = Read-State
        if ($st -and $st.RunId -eq $RunId) { $st | Add-Member -NotePropertyName ('Checked' + $slot.Slot) -NotePropertyValue ([bool]$ok) -Force; Save-State $st }
        if (-not $ok -and $plan.Mode -eq 'mystery') {
            Write-FaultLog "run ${RunId}: fault not active after the check -> draw VOID, everything reset"
            Reset-All | Out-Null
            [void](Send-Ledger @([ordered]@{ TimeGenerated = Utc ([DateTime]::UtcNow); RunId = $RunId; Mode = 'mystery'; Slot = 1; Number = [int]$slot.Number; Card = $slot.Card; ExpectedLayer = $Layer[$slot.Card]; StartUtc = $slot.StartUtc; EndUtc = Utc ([DateTime]::UtcNow); Fingerprint = $slot.Fingerprint; Result = 'void'; Note = 'fault did not take effect; draw again' }))
            $st = Read-State; if ($st) { $st.Active = $false; $st | Add-Member -NotePropertyName 'Void' -NotePropertyValue $true -Force; Save-State $st }
            return
        }
        while ([DateTime]::UtcNow -lt $end.AddSeconds(-5)) {
            $remain = ($end - [DateTime]::UtcNow).TotalSeconds
            $step = 100; if ($slot.Card -eq 'cpu-host') { $step = 15 }
            Start-Sleep -Seconds ([int][Math]::Max(1, [Math]::Min($step, $remain - 4)))
            if ($slot.Card -eq 'cpu-host' -and -not $safety) {   # safety: stop at the first NotReady node or when the API stops answering
                $r = Get-ReadyNodes
                if ($null -eq $r) { $apiFail++ } else { $apiFail = 0 }
                $lost = @(); if ($null -ne $r -and $null -ne $ready0) { $lost = @($ready0 | Where-Object { $r -notcontains $_ }) }
                if ($lost.Count -gt 0 -or $apiFail -ge 2) {
                    if ($lost.Count -gt 0) { $safety = 'node NotReady: ' + ($lost -join ',') } else { $safety = 'OpenShift API not answering twice' }
                    $sx = Stop-FaultCpuHost
                    Add-Content -Path (Join-Path $SealDir "$RunId.log") -Value ("{0} slot {1}: SAFETY STOP ({2}): {3}" -f (Utc ([DateTime]::UtcNow)), $slot.Slot, $safety, $sx)
                    Write-FaultLog ("run ${RunId}: SAFETY STOP of the host card ($safety)")
                }
            }
            if ($slot.Card -eq 'oom-ocp' -and [DateTime]::UtcNow -lt $end.AddSeconds(-30)) {
                $r = Start-FaultOomRound
                Add-Content -Path (Join-Path $SealDir "$RunId.log") -Value ("{0} slot {1}: {2}" -f (Utc ([DateTime]::UtcNow)), $slot.Slot, $r)
            }
        }
        $wait = ($end - [DateTime]::UtcNow).TotalSeconds; if ($wait -gt 0) { Start-Sleep -Seconds ([int][Math]::Ceiling($wait)) }
        $reset = (Reset-AllExceptRunner) -join ' | '
        Add-Content -Path (Join-Path $SealDir "$RunId.log") -Value ("{0} slot {1} ended: {2}" -f (Utc ([DateTime]::UtcNow)), $slot.Slot, $reset)
        if ($plan.Mode -eq 'series') {
            [void](Send-Ledger @([ordered]@{ TimeGenerated = Utc ([DateTime]::UtcNow); RunId = $RunId; Mode = 'series'; Slot = [int]$slot.Slot; Number = [int]$slot.Number; Card = $slot.Card; ExpectedLayer = $Layer[$slot.Card]; StartUtc = $slot.StartUtc; EndUtc = $slot.EndUtc; Fingerprint = $slot.Fingerprint; Result = 'series'; Note = "slot $($slot.Slot) of $(@($plan.Slots).Count); fault $($plan.FaultMinutes) min of $($plan.SlotMinutes) min" }))
            $nextStart = [DateTime]::Parse($slot.SlotEndUtc).ToUniversalTime()
            $wait = ($nextStart - [DateTime]::UtcNow).TotalSeconds; if ($wait -gt 0) { Start-Sleep -Seconds ([int][Math]::Ceiling($wait)) }
        }
    }
    $st = Read-State; if ($st -and $st.RunId -eq $RunId) { $st.Active = $false; $st | Add-Member -NotePropertyName 'EndedUtc' -NotePropertyValue (Utc ([DateTime]::UtcNow)) -Force; Save-State $st }
    if ($plan.Mode -eq 'series') { Write-FaultLog "series $RunId finished: $(@($plan.Slots).Count) slots" }
}
function Reset-AllExceptRunner {
    $out = @()
    Get-CimInstance Win32_Process -Filter "Name='oc.exe'" | Where-Object { $_.CommandLine -match 'tail /dev/zero' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    $out += 'generators stopped: ' + (Stop-Load)
    [void](Write-RobotNote ([DateTime]::UtcNow) 'normal')
    $out += Stop-FaultCpuHost
    $out += (Stop-FaultCpuWin) -join ' '
    $out += (Invoke-Rhel (Get-RhelResetBash)) -join ' '
    $out += (Invoke-Oracle $SqlRestore) -join ' '
    return $out
}
function Test-Busy {
    $st = Read-State
    if ($st -and $st.Active -and [DateTime]::Parse($st.EndUtc).ToUniversalTime() -gt [DateTime]::UtcNow) { return "a fault run is active ($($st.Mode) $($st.RunId) until $(Wib ([DateTime]::Parse($st.EndUtc))) WIB); use -Stop first" }
    $inc = 'C:\ProgramData\MiniBank\incident\incident-generators.json'
    if (Test-Path $inc) {
        $savedGen = Get-Content $inc -Raw | ConvertFrom-Json
        foreach ($g in $savedGen) {
            $proc = Get-Process -Id ([int]$g.Pid) -ErrorAction SilentlyContinue
            if ($proc -and [Math]::Abs($proc.StartTime.ToUniversalTime().Ticks - [long]$g.StartTicks) -lt [TimeSpan]::TicksPerSecond) { return 'the Scene 5/6 incident (incident.ps1) is running; stop it first: incident.ps1 -Stop' }
        }
    }
    return ''
}

# ================================================= main =======================================================
if ($Runner) { Invoke-Runner $Runner; return }

if ($Stop) {
    $st = Read-State
    $lines = Reset-All
    foreach ($l in $lines) { Write-FaultLog ("stop: " + $l) }
    if ($st -and $st.Active) {
        $st.Active = $false; $st | Add-Member -NotePropertyName 'StoppedUtc' -NotePropertyValue (Utc ([DateTime]::UtcNow)) -Force; Save-State $st
        Write-FaultLog ("stopped run $($st.RunId) ($($st.Mode))") -Show
        if ($st.Mode -eq 'mystery') { Write-Host 'The fault is reset. To see the answer: .\fault.ps1 -Reveal' }
    } else { Write-FaultLog 'stop: no active run (all undo steps ran anyway)' -Show }
    if (-not $Quiet) { $lines | ForEach-Object { Write-Host ('  ' + $_) } }
    return
}

if ($Status) {
    $st = Read-State
    if (-not $st) { Write-Host 'No fault run recorded.'; return }
    $state = 'ended'; if ($st.Active -and [DateTime]::Parse($st.EndUtc).ToUniversalTime() -gt [DateTime]::UtcNow) { $state = 'ACTIVE' }
    Write-Host ("Run {0} ({1}) {2}: start {3} WIB, end {4} WIB" -f $st.RunId, $st.Mode, $state, (Wib ([DateTime]::Parse($st.StartUtc))), (Wib ([DateTime]::Parse($st.EndUtc))))
    if ($st.Mode -eq 'labelled') { Write-Host ("Fault: {0} = {1}" -f $st.Card, $Story[$st.Card]) }
    if ($st.Mode -eq 'mystery') { Write-Host ("Number {0}, sealed fingerprint {1}, fault active check: {2}" -f $st.Number, (Format-Fingerprint $st.Fingerprint), $st.Checked1) }
    return
}

if ($LeakCheck) {
    # Giveaway words = the five pool cards + tool words. The background traffic generator (traffic.ps1 -FailPercent) labels its own
    # random technical failures fail-oracle / fail-java / fail-python / fail-api: expected, never a pool card -> listed separately.
    $words = @($Pool + 'cpu-host' + 'mystery' + 'fault.ps1' + 'netem' + 'report-export' + 'statement-header')
    $bgWords = @('fail-oracle', 'fail-java', 'fail-python', 'fail-api')
    $terms = ($words | ForEach-Object { '"' + $_ + '"' }) -join ' or '
    $q = "search in (AppRequests, AppDependencies, AppExceptions, AppTraces, AppEvents, AppPageViews, ContainerLogV2, MiniBankDbSnap_CL, W3CIISLog, OTelSpans, OTelLogs) $terms | where TimeGenerated > ago($($Hours)h) | summarize Hits = count() by `$table | order by Hits desc"
    try {
        $tok = Get-MiToken 'https://api.loganalytics.io'
        $r = Invoke-RestMethod -Method Post -Uri "https://api.loganalytics.io/v1/workspaces/$WorkspaceId/query" -Headers @{ Authorization = "Bearer $tok" } -ContentType 'application/json' -Body (ConvertTo-Json @{ query = $q }) -TimeoutSec 120
        $rows = @($r.tables[0].rows)
        if ($rows.Count -eq 0) { Write-Host "Leak check ($Hours h): no giveaway word found in the telemetry." }
        else { Write-Host "Leak check ($Hours h): giveaway words FOUND:"; $rows | ForEach-Object { Write-Host ('  ' + ($_ -join ' ')) } }
        $qb = $q.Replace($terms, (($bgWords | ForEach-Object { '"' + $_ + '"' }) -join ' or '))
        $rb = Invoke-RestMethod -Method Post -Uri "https://api.loganalytics.io/v1/workspaces/$WorkspaceId/query" -Headers @{ Authorization = "Bearer $tok" } -ContentType 'application/json' -Body (ConvertTo-Json @{ query = $qb }) -TimeoutSec 120
        $rowsB = @($rb.tables[0].rows)
        if ($rowsB.Count -gt 0) { Write-Host ('Background traffic labels (traffic generator, expected; not a giveaway): ' + (($rowsB | ForEach-Object { $_ -join ' ' }) -join ', ')) }
        else { Write-Host 'Background traffic labels (fail-oracle, fail-java, fail-python, fail-api): none in this period.' }
    } catch { Write-Host ('Leak check failed: ' + $_.Exception.Message) }
    return
}

if ($Reveal) {
    $st = Read-State
    if (-not $st -or $st.Mode -ne 'mystery') { Write-Host 'No mystery draw to reveal.'; return }
    if ($st.Active) { Reset-All | ForEach-Object { Write-FaultLog ("reveal reset: " + $_) }; $st.Active = $false; Save-State $st }
    $plan = Get-Content (Join-Path $SealDir "$($st.RunId).json") -Raw | ConvertFrom-Json
    $slot = @($plan.Slots)[0]
    $fp = Get-Fingerprint $plan.RunId 1 ([int]$slot.Number) $slot.Card $slot.Salt
    $match = ($fp -eq $slot.Fingerprint) -and ($fp -eq $st.Fingerprint)
    $start = [DateTime]::Parse($slot.StartUtc).ToUniversalTime()
    $revealGrade = Get-RevealGrade $start ([DateTime]::UtcNow) $Layer[$slot.Card]; $v = $revealGrade
    Write-Host ''
    Write-Host ("Draw {0}, number {1}: {2}" -f $plan.RunId, $slot.Number, $Story[$slot.Card])
    Write-Host ("Expected layer: {0}" -f $Layer[$slot.Card])
    Write-Host ("Fingerprint shown at the draw: {0}  recomputed now: {1}  -> {2}" -f (Format-Fingerprint $st.Fingerprint), (Format-Fingerprint $fp), $(if ($match) { 'MATCH (answer unchanged)' } else { 'DIFFERENT' }))
    Write-Host ("Customers: {0}" -f $revealGrade.CustomersText)
    if ($revealGrade.AtUtc) {
        $secs = [int]($revealGrade.AtUtc - $start).TotalSeconds
        Write-Host ("Board verdict: {0} ({1}) - {2} at {3} WIB ({4} min {5} s after the fault started) -> {6}" -f $revealGrade.Layer, $revealGrade.Colour, $revealGrade.Component, (Wib $revealGrade.AtUtc), [int][Math]::Floor($secs / 60), ($secs % 60), $revealGrade.Verdict)
        $note = "board $($revealGrade.Layer) $($revealGrade.Colour) after $secs s -> $($revealGrade.Verdict); customers $($revealGrade.CustomersShort)"
    } else { Write-Host ("Board verdict: none confirmed yet ({0} readings since the start) -> {1}" -f $revealGrade.Rows, $revealGrade.Verdict); $note = "$($revealGrade.Verdict); customers $($revealGrade.CustomersShort)" }
    Write-Host (Send-Ledger @([ordered]@{ TimeGenerated = Utc ([DateTime]::UtcNow); RunId = $plan.RunId; Mode = 'mystery'; Slot = 1; Number = [int]$slot.Number; Card = $slot.Card; ExpectedLayer = $Layer[$slot.Card]; StartUtc = $slot.StartUtc; EndUtc = Utc ([DateTime]::UtcNow); Fingerprint = $slot.Fingerprint; Result = 'revealed'; Note = $note }))
    Write-FaultLog ("revealed $($plan.RunId): $($slot.Card) / $note")
    return
}

if ($Mystery -or $Series -or $Fault) {
    $busy = Test-Busy
    if ($busy) { Write-Host "Not started: $busy"; return }
    Initialize-SealDir
    $now = [DateTime]::UtcNow.AddSeconds(5)
    if ($Mystery) {
        $order = Get-Shuffled $Pool
        $number = $Pick; if ($number -eq 0 -or $number -gt $Pool.Count) { $number = (Get-RandomInt $Pool.Count) + 1 }
        $card = $order[$number - 1]
        $runId = 'M' + [DateTime]::UtcNow.AddHours(7).ToString('yyyyMMdd-HHmmss', $inv)
        $salt = -join ((1..16) | ForEach-Object { '{0:x2}' -f (Get-RandomInt 256) })
        $end = $now.AddMinutes(8)
        $fp = Get-Fingerprint $runId 1 $number $card $salt
        $plan = [ordered]@{ RunId = $runId; Mode = 'mystery'; Order = $order; Slots = @([ordered]@{ Slot = 1; Number = $number; Card = $card; Salt = $salt; Fingerprint = $fp; StartUtc = Utc $now; EndUtc = Utc $end; SlotEndUtc = Utc $end }) }
        $mode = 'mystery'
    } elseif ($Series) {
        $cards = Get-Shuffled ($SeriesPool + 'none')
        $runId = 'S' + [DateTime]::UtcNow.AddHours(7).ToString('yyyyMMdd-HHmmss', $inv)
        $slots = @(); $t = $now
        for ($i = 0; $i -lt $cards.Count; $i++) {
            $salt = -join ((1..16) | ForEach-Object { '{0:x2}' -f (Get-RandomInt 256) })
            $slots += [ordered]@{ Slot = $i + 1; Number = $i + 1; Card = $cards[$i]; Salt = $salt; Fingerprint = (Get-Fingerprint $runId ($i + 1) ($i + 1) $cards[$i] $salt)
                                  StartUtc = Utc $t; EndUtc = Utc ($t.AddMinutes($FaultMinutes)); SlotEndUtc = Utc ($t.AddMinutes($SlotMinutes)) }
            $t = $t.AddMinutes($SlotMinutes)
        }
        $end = $t
        $plan = [ordered]@{ RunId = $runId; Mode = 'series'; SlotMinutes = $SlotMinutes; FaultMinutes = $FaultMinutes; Slots = $slots }
        $mode = 'series'; $number = 0; $fp = ''
    } else {
        if ($Fault -eq 'cpu-host' -and $Minutes -gt 7) { $Minutes = 7; $end = $now.AddMinutes(7) }   # safety limit: host card max 7 min
        $runId = 'L' + [DateTime]::UtcNow.AddHours(7).ToString('yyyyMMdd-HHmmss', $inv)
        $end = $now.AddMinutes($Minutes)
        $plan = [ordered]@{ RunId = $runId; Mode = 'labelled'; Slots = @([ordered]@{ Slot = 1; Number = 0; Card = $Fault; Salt = ''; Fingerprint = ''; StartUtc = Utc $now; EndUtc = Utc $end; SlotEndUtc = Utc $end }) }
        $mode = 'labelled'; $number = 0; $fp = ''
    }
    ConvertTo-Json -InputObject $plan -Depth 5 | Set-Content -Path (Join-Path $SealDir "$runId.json") -Encoding ASCII
    $runnerProc = Start-Runner $runId
    $state = [ordered]@{ RunId = $runId; Mode = $mode; StartUtc = Utc $now; EndUtc = Utc $end; Active = $true; Number = $number; Fingerprint = $fp
                         RunnerPid = $runnerProc.Id; RunnerTicks = $runnerProc.StartTime.ToUniversalTime().Ticks }
    if ($mode -eq 'labelled') { $state['Card'] = $Fault }
    Save-State $state
    Register-Watchdog $end.AddMinutes(2)
    if ($mode -eq 'labelled') {
        Write-FaultLog ("labelled run $runId started: $Fault for $Minutes min ($(Wib $now)-$(Wib $end) WIB)") -Show
        Write-Host ("Fault: {0}" -f $Story[$Fault])
        Write-Host ("Ends by itself at {0} WIB. Stop early: .\fault.ps1 -Stop" -f (Wib $end))
        if (-not $Quiet) {
            if ($Fault -ne 'none') { Send-Ledger @([ordered]@{ TimeGenerated = Utc ([DateTime]::UtcNow); RunId = $runId; Mode = 'labelled'; Slot = 1; Number = 0; Card = $Fault; ExpectedLayer = $Layer[$Fault]; StartUtc = Utc $now; EndUtc = Utc $end; Fingerprint = ''; Result = 'labelled'; Note = $Story[$Fault] }) | Out-Null }
        }
    } elseif ($mode -eq 'mystery') {
        Write-FaultLog ("mystery draw $runId started (number $number, fingerprint $(Format-Fingerprint $fp))")
        Write-Host ''
        Write-Host ("Draw {0}: number {1} is sealed." -f $runId, $number)
        Write-Host ("Sealed fingerprint: {0}   (write it down; -Reveal recomputes it)" -f (Format-Fingerprint $fp))
        Write-Host ("The fault runs 8 minutes, until {0} WIB. Checking that it took effect ..." -f (Wib $end))
        $checked = $null
        for ($i = 0; $i -lt 18 -and $null -eq $checked; $i++) {
            Start-Sleep -Seconds 5
            $s2 = Read-State
            if ($s2 -and $s2.PSObject.Properties['Checked1']) { $checked = [bool]$s2.Checked1 }
        }
        if ($checked -eq $true) { Write-Host 'Fault is active. Watch the board. When it shows a verdict: .\fault.ps1 -Reveal' }
        elseif ($checked -eq $false) { Write-Host 'The fault did not take effect: this draw is VOID and everything is reset. Ask the bank for a new number.' }
        else { Write-Host 'Check still running; see .\fault.ps1 -Status in a minute.' }
    } else {
        Write-FaultLog ("series $runId started: $(@($plan.Slots).Count) slots x $SlotMinutes min, fault $FaultMinutes min each") -Show
        Write-Host ("Blind series {0}: {1} slots of {2} min (fault {3} min each), ends about {4} WIB. Results: Grafana scorecard." -f $runId, @($plan.Slots).Count, $SlotMinutes, $FaultMinutes, (Wib $end))
    }
    return
}
Get-Help $PSCommandPath -Detailed | Out-String | Write-Host
