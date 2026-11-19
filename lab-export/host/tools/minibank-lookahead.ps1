<#
  MiniBank Look-ahead collector v1.0 - HV-HOST-02, scheduled task 'minibank-lookahead' (hourly at :05, SYSTEM).
  Every hour : capacity figures - host memory/drives/VM totals, Windows and Linux VM disks, memory, network and disk
               averages, OpenShift requests and the room left if one node fails, Oracle/PostgreSQL/SQL Server figures.
  Once a day : (first run at or after 10:00 WIB) calendar dates (licence end, password expiry, certificate), posture
               (last updates, last backup, OpenShift health and updates) and the day-ahead forecast for the scorecard.
  Rows go to MiniBankLookahead_CL (Logs Ingestion API, rule dcr-minibank-lookahead; the host identity may send only to
  that rule). Read-only towards the lab: nothing on the VMs, databases or OpenShift is changed. A run is skipped while a
  lab drill is in progress, or while the file pause.on exists in its folder (quiet switch for demo time).
  Files: C:\ProgramData\MiniBank\lookahead (config.json, state.json, rows-<date>.jsonl, collector.log, pause.on)
  Switches: -NoUpload (keep the rows local), -Daily (do the daily part now), -NoDaily (hourly part only).
#>
param([switch]$NoUpload, [switch]$Daily, [switch]$NoDaily)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Version = '1.0'
$Dir = 'C:\ProgramData\MiniBank\lookahead'
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$LogF = Join-Path $Dir 'collector.log'
$Inv = [Globalization.CultureInfo]::InvariantCulture
$t0 = Get-Date
$Utc = [DateTime]::UtcNow
$RunId = 'LA' + $t0.ToString('yyyyMMdd-HHmm')
$Rows = New-Object System.Collections.Generic.List[object]
$Notes = New-Object System.Collections.Generic.List[string]
$Done = New-Object System.Collections.Generic.List[string]

function Write-Log([string]$t) { Add-Content -LiteralPath $LogF -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' ' + $t) -Encoding UTF8 }
function ConvertTo-Num([string]$s) { return [double]::Parse($s.Trim(), $Inv) }
function Get-R($v) { if ($null -eq $v -or "$v" -eq '') { return $null }; return [Math]::Round([double]$v, 4) }
function Get-T($v) { if ($null -eq $v -or "$v" -eq '') { return $null }; return ([DateTime]$v).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function Add-Row([string]$Kind, [string]$Area, [string]$Resource, [string]$Item, $Value = $null, [string]$Unit = '', $Limit = $null, $Low = $null, $High = $null, $StartUtc = $null, $DueUtc = $null, [string]$Text = '') {
    $script:Rows.Add([ordered]@{ TimeGenerated = $script:Utc.ToString('yyyy-MM-ddTHH:mm:ssZ'); RunId = $script:RunId; Kind = $Kind; Area = $Area
            Resource = $Resource; Item = $Item; Value = (Get-R $Value); Unit = $Unit; Limit = (Get-R $Limit); Low = (Get-R $Low); High = (Get-R $High)
            StartUtc = (Get-T $StartUtc); DueUtc = (Get-T $DueUtc); Text = $Text; Version = $script:Version })
}
function Add-Note([string]$Where, $Err) {
    $m = "$Err"; if ($Err -is [System.Management.Automation.ErrorRecord]) { $m = $Err.Exception.Message }
    $m = ($m -replace '\s+', ' ').Trim(); if ($m.Length -gt 140) { $m = $m.Substring(0, 140) }
    $script:Notes.Add($Where + ': ' + $m)
}

# ---------- drill check: skip while a lab drill runs (no names are logged) ----------
function Test-Drill {
    $busy = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'bg-*' -and $_.State -eq 'Running' })
    if ($busy.Count -gt 0) { return $true }
    try {
        $st = (& 'F:\Build\minibank\scripts\fault.ps1' -Status 6>&1 2>&1 | Out-String)
        return ($st -cmatch '\) ACTIVE: start')
    } catch { Add-Note 'drill check' 'status not readable'; return $false }
}

# ---------- state (raw counters for hourly averages, last daily run) ----------
function Read-State {
    $s = @{ LastDaily = ''; Raw = @{} }
    $f = Join-Path $Dir 'state.json'
    if (Test-Path -LiteralPath $f) {
        try {
            $j = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
            $s.LastDaily = [string]$j.LastDaily
            if ($j.Raw) { foreach ($p in $j.Raw.PSObject.Properties) { $h = @{}; foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }; $s.Raw[$p.Name] = $h } }
        } catch { Add-Note 'state' $_ }
    }
    return $s
}
function Save-State($s) { ConvertTo-Json -InputObject $s -Depth 5 | Set-Content -LiteralPath (Join-Path $Dir 'state.json') -Encoding UTF8 }

# ---------- upload ----------
function Get-MiToken([string]$Resource) {
    $u = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + [uri]::EscapeDataString($Resource)
    return (Invoke-RestMethod -Headers @{ Metadata = 'true' } -Uri $u -TimeoutSec 15).access_token
}
function Send-Rows($cfg, $list) {
    $tok = Get-MiToken 'https://monitor.azure.com'
    $uri = $cfg.Endpoint.TrimEnd('/') + '/dataCollectionRules/' + $cfg.DcrImmutableId + '/streams/' + $cfg.Stream + '?api-version=2023-01-01'
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($r in $list) { $lines.Add((ConvertTo-Json -InputObject $r -Depth 4 -Compress)) }
    for ($i = 0; $i -lt $lines.Count; $i += 200) {
        $n = [Math]::Min(200, $lines.Count - $i)
        $body = '[' + ($lines.GetRange($i, $n) -join ',') + ']'
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $tok" } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60 | Out-Null
    }
}
function Invoke-La($cfg, [string]$Query) {
    $tok = Get-MiToken 'https://api.loganalytics.io'
    $body = ConvertTo-Json -Compress -InputObject @{ query = $Query }
    $r = Invoke-RestMethod -Method Post -Uri ('https://api.loganalytics.io/v1/workspaces/' + $cfg.WorkspaceId + '/query') -Headers @{ Authorization = "Bearer $tok" } -ContentType 'application/json' -Body $body -TimeoutSec 90
    $t = $r.tables[0]; $out = @()
    foreach ($row in $t.rows) { $h = @{}; for ($i = 0; $i -lt $t.columns.Count; $i++) { $h[$t.columns[$i].name] = $row[$i] }; $out += $h }
    return $out
}

# ---------- host ----------
function Read-Host2([bool]$DoDaily) {
    $hn = $env:COMPUTERNAME
    $os = Get-CimInstance Win32_OperatingSystem
    $tot = $os.TotalVisibleMemorySize / 1MB
    Add-Row 'capacity' 'Host' $hn 'Memory in use' ($tot - $os.FreePhysicalMemory / 1MB) 'GB' $tot
    foreach ($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.Size -gt 1GB })) {
        Add-Row 'capacity' 'Host' $hn ('Drive ' + $d.DeviceID + ' used') (($d.Size - $d.FreeSpace) / 1GB) 'GB' ($d.Size / 1GB)
    }
    $vms = @(Get-VM | Where-Object { $_.State -eq 'Running' })
    $lp = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $vcpu = ($vms | Measure-Object -Property ProcessorCount -Sum).Sum
    $vmem = ($vms | Measure-Object -Property MemoryAssigned -Sum).Sum / 1GB
    Add-Row 'capacity' 'Host' $hn 'Virtual CPUs of running VMs' $vcpu 'vCPU' -Text ('{0} running VMs on {1} logical processors' -f $vms.Count, $lp)
    Add-Row 'capacity' 'Host' $hn 'Memory given to running VMs' $vmem 'GB' $tot
    if ($DoDaily) {
        $hf = Get-HotFix -ErrorAction SilentlyContinue | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hf) { Add-Row 'posture' 'Host' $hn 'Days since last Windows update' (($t0 - $hf.InstalledOn).TotalDays) 'days' 35 -High 1 -Text ('{0} installed {1}' -f $hf.HotFixID, $hf.InstalledOn.ToString('yyyy-MM-dd')) }
    }
    $Done.Add('host')
}

# ---------- Windows VMs (PowerShell Direct, read-only) ----------
$GuestBlock = {
    param([bool]$DoDaily)
    $o = @{}
    $os = Get-CimInstance Win32_OperatingSystem
    $o.MemTot = $os.TotalVisibleMemorySize / 1MB; $o.MemFree = $os.FreePhysicalMemory / 1MB
    $o.Boot = $os.LastBootUpTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $o.TzH = [TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalHours
    $o.Disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.Size -gt 1GB } | ForEach-Object { '{0}|{1}|{2}' -f $_.DeviceID, $_.Size, $_.FreeSpace })
    $n = @(Get-CimInstance Win32_PerfRawData_Tcpip_NetworkInterface | Where-Object { $_.Name -notmatch 'isatap|Loopback|Teredo|Pseudo' })
    $o.NetBytes = [double](($n | Measure-Object -Property BytesTotalPersec -Sum).Sum)
    $o.NetTs = [double]($n | Select-Object -First 1).Timestamp_Sys100NS
    $pd = Get-CimInstance Win32_PerfRawData_PerfDisk_PhysicalDisk -Filter "Name='_Total'"
    $o.DiskX = [double]$pd.DiskTransfersPersec; $o.DiskB = [double]$pd.DiskBytesPersec; $o.DiskQ = [double]$pd.AvgDiskQueueLength; $o.DiskTs = [double]$pd.Timestamp_Sys100NS
    if ($DoDaily) {
        $p = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID='0d38e370-e122-508c-9d19-0a21e8d36010'" | Select-Object -First 1
        if ($p) { $o.LicDesc = [string]$p.Description; $o.GraceMin = [double]$p.GracePeriodRemaining }
        $hf = Get-HotFix -ErrorAction SilentlyContinue | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hf) { $o.HfId = [string]$hf.HotFixID; $o.HfDate = $hf.InstalledOn.ToString('yyyy-MM-dd') }
    }
    if ($env:COMPUTERNAME -eq 'APP-SQL' -and (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
        $q = "SET NOCOUNT ON; SELECT 'sql', SUM(CASE WHEN mf.type = 0 THEN CAST(mf.size AS bigint) ELSE 0 END) * 8 / 1024, SUM(CASE WHEN mf.type = 1 THEN CAST(mf.size AS bigint) ELSE 0 END) * 8 / 1024, ISNULL(CONVERT(varchar(19), (SELECT MAX(b.backup_finish_date) FROM msdb.dbo.backupset b WHERE b.database_name = 'MiniBankDemo' AND b.type = 'D'), 126), 'never') FROM sys.master_files mf WHERE mf.database_id = DB_ID('MiniBankDemo')"
        $o.Sql = ((& sqlcmd -S . -E -W -h -1 -s '|' -Q $q 2>&1) | ForEach-Object { "$_" } | Where-Object { $_ -like 'sql|*' } | Select-Object -First 1)
    }
    $o
}
function Get-GuestCred {
    $map = @{}
    Get-Content 'F:\Build\ENVIRONMENT.txt' | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $kv = $_ -split '=', 2; $map[$kv[0]] = $kv[1] }
    $c = New-Object System.Management.Automation.PSCredential('Administrator', (ConvertTo-SecureString $map['WIN_GUEST_PASSWORD'] -AsPlainText -Force))
    $map.Clear()
    return $c
}
function Read-Windows([string]$Vm, $Cred, [bool]$DoDaily, $State) {
    $j = Invoke-Command -VMName $Vm -Credential $Cred -ScriptBlock $GuestBlock -ArgumentList $DoDaily -AsJob
    if (-not (Wait-Job $j -Timeout 150)) { Stop-Job $j; Remove-Job $j -Force; throw ($Vm + ' did not answer within 150 s') }
    $r = Receive-Job $j; Remove-Job $j -Force
    if (-not $r) { throw ($Vm + ' returned nothing') }
    Add-Row 'capacity' 'VM' $Vm 'Memory in use' ($r.MemTot - $r.MemFree) 'GB' $r.MemTot
    foreach ($d in @($r.Disks)) {
        $p = "$d" -split '\|'
        Add-Row 'capacity' 'VM' $Vm ('Disk ' + $p[0] + ' used') (((ConvertTo-Num $p[1]) - (ConvertTo-Num $p[2])) / 1GB) 'GB' ((ConvertTo-Num $p[1]) / 1GB)
    }
    $pv = $State.Raw[$Vm]
    if ($pv -and [string]$pv.Boot -eq [string]$r.Boot) {
        $dt = ($r.NetTs - [double]$pv.NetTs) / 1e7
        if ($dt -ge 600 -and $dt -le 10800) {
            $mb = ($r.NetBytes - [double]$pv.NetBytes) / $dt / 1MB
            if ($mb -ge 0) { Add-Row 'capacity' 'VM' $Vm 'Network traffic (avg MB/s)' $mb 'MB/s' -Text ('average over the last {0:0} min' -f ($dt / 60)) }
        }
        $dt = ($r.DiskTs - [double]$pv.DiskTs) / 1e7
        if ($dt -ge 600 -and $dt -le 10800) {
            $x = $r.DiskX - [double]$pv.DiskX; if ($x -lt 0) { $x += 4294967296 }
            $iops = $x / $dt
            $mb = ($r.DiskB - [double]$pv.DiskB) / $dt / 1MB
            $q = ($r.DiskQ - [double]$pv.DiskQ) / ($r.DiskTs - [double]$pv.DiskTs)
            if ($mb -ge 0) { Add-Row 'capacity' 'VM' $Vm 'Disk throughput (avg MB/s)' $mb 'MB/s' -Text ('{0:0.0} transfers/s on average' -f $iops) }
            if ($iops -ge 0.5 -and $q -ge 0) { Add-Row 'capacity' 'VM' $Vm 'Disk response time (avg ms)' (1000.0 * $q / $iops) 'ms' 25 -Text ('average over the last {0:0} min' -f ($dt / 60)) }
        }
    }
    $State.Raw[$Vm] = @{ Boot = [string]$r.Boot; NetBytes = $r.NetBytes; NetTs = $r.NetTs; DiskX = $r.DiskX; DiskB = $r.DiskB; DiskQ = $r.DiskQ; DiskTs = $r.DiskTs }
    if ($r.Sql) {
        $p = "$($r.Sql)" -split '\|'
        if ($p.Count -ge 4) {
            Add-Row 'capacity' 'Database' 'SQL Server MiniBankDemo' 'Database size' (ConvertTo-Num $p[1]) 'MB' -Text 'data files'
            Add-Row 'capacity' 'Database' 'SQL Server MiniBankDemo' 'Log file size' (ConvertTo-Num $p[2]) 'MB'
            if ($DoDaily) {
                if ($p[3].Trim() -eq 'never') { Add-Row 'posture' 'Database' 'SQL Server MiniBankDemo' 'Days since last full backup' 9999 'days' 1 -High 1 -Text 'no full backup recorded' }
                else {
                    $bl = [DateTime]::ParseExact($p[3].Trim(), 'yyyy-MM-ddTHH:mm:ss', $Inv)
                    $bu = $bl.AddHours(-[double]$r.TzH)
                    Add-Row 'posture' 'Database' 'SQL Server MiniBankDemo' 'Days since last full backup' (($Utc - $bu).TotalDays) 'days' 1 -High 1 -Text ('last full backup ' + $bl.ToString('yyyy-MM-dd HH:mm') + ' (server time)')
                }
            }
        }
    }
    if ($DoDaily) {
        if ($r.LicDesc -and $r.LicDesc -match 'EVAL') { Add-Row 'calendar' 'VM' $Vm 'Windows evaluation ends' -DueUtc ($Utc.AddMinutes([double]$r.GraceMin)) -Text ('{0:0} days left' -f ([double]$r.GraceMin / 1440)) }
        if ($r.HfDate) {
            $hd = [DateTime]::ParseExact([string]$r.HfDate, 'yyyy-MM-dd', $Inv)
            Add-Row 'posture' 'VM' $Vm 'Days since last Windows update' (($t0.Date - $hd).TotalDays) 'days' 35 -High 1 -Text ('{0} installed {1}' -f $r.HfId, $r.HfDate)
        }
    }
    $Done.Add($Vm)
}

# ---------- APP-RHEL (SSH, read-only) ----------
$LinuxReader = @'
D=${1:-0}
echo "now|$(date +%s)"
echo "boot|$(date -d "$(uptime -s)" +%s)"
df -P -B1 / /var /opt /home 2>/dev/null | awk 'NR>1{print "df|"$6"|"$2"|"$3"|"$1}'
awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{print "mem|"t"|"a}' /proc/meminfo
dev=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
awk -v d="$dev" -F'[: ]+' '{for(i=1;i<=NF;i++) if($i==d){print "net|"$(i+1)"|"$(i+9); exit}}' /proc/net/dev
disk=$(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1; exit}')
awk -v d="$disk" '$3==d{print "dsk|"$4"|"$6"|"$7"|"$8"|"$10"|"$11; exit}' /proc/diskstats
cat > /tmp/la-ora.sql <<'SQL'
set lines 200 pages 0 feed off head off verify off
alter session set container=FREEPDB1;
select 'ora|userdata|'||round(nvl(sum(bytes),0)/1048576,1) from dba_segments where tablespace_name not in ('SYSTEM','SYSAUX','UNDOTBS1','UNDOTBS2','TEMP');
select 'ora|tsmax|'||round(nvl(max(used_percent),0),2) from dba_tablespace_usage_metrics;
select 'ora|ledger|'||count(*) from minibank.ledger_entry;
select 'ora|'||resource_name||'|'||current_utilization||'|'||trim(limit_value) from v$resource_limit where resource_name in ('processes','sessions');
SQL
if [ "$D" = "1" ]; then echo "select 'oraexp|'||username||'|'||nvl(to_char(expiry_date,'YYYY-MM-DD HH24:MI:SS'),'never') from dba_users where username like 'MINIBANK%' order by 1;" >> /tmp/la-ora.sql; fi
echo "exit" >> /tmp/la-ora.sql
timeout 90 podman exec -i minibank-oracle sqlplus -s / as sysdba < /tmp/la-ora.sql 2>&1 | grep '|' | head -20
rm -f /tmp/la-ora.sql
timeout 60 sudo -u postgres psql -At -F'|' -c "select 'pg', pg_database_size('minibank'), (select age(datfrozenxid) from pg_database where datname = 'minibank')" -c "select 'pgconn', count(*), current_setting('max_connections') from pg_stat_activity" 2>&1 | grep '|' | head -4
if [ "$D" = "1" ]; then
  echo "pkg|$(rpm -qa --qf '%{INSTALLTIME}\n' 2>/dev/null | sort -n | tail -1)|$(uname -r)"
fi
'@
function Read-Rhel([bool]$DoDaily, $State) {
    $vm = 'APP-RHEL'
    $ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
    $o = @('-i', 'F:\Build\ocp\id_ed25519', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=F:\Build\ocp\known_hosts', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15')
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($LinuxReader -replace "`r", '')))
    $dArg = $(if ($DoDaily) { '1' } else { '0' })
    $res = @(& $ssh @o labadmin@192.168.110.32 ("echo $b64 | base64 -d > /tmp/la-read.sh && sudo bash /tmp/la-read.sh $dArg; rm -f /tmp/la-read.sh") 2>&1 | ForEach-Object { "$_".Trim() })
    $k = @{}; $dfSeen = @{}
    foreach ($l in $res) {
        $p = $l -split '\|'
        switch ($p[0]) {
            'now' { $k.Now = ConvertTo-Num $p[1] }
            'boot' { $k.Boot = $p[1] }
            'df' {
                if ($p.Count -ge 5 -and -not $dfSeen.ContainsKey($p[4])) {
                    $dfSeen[$p[4]] = 1
                    Add-Row 'capacity' 'VM' $vm ('Disk ' + $p[1] + ' used') ((ConvertTo-Num $p[3]) / 1GB) 'GB' ((ConvertTo-Num $p[2]) / 1GB)
                }
            }
            'mem' { $t = ConvertTo-Num $p[1]; $a = ConvertTo-Num $p[2]; Add-Row 'capacity' 'VM' $vm 'Memory in use' (($t - $a) / 1MB) 'GB' ($t / 1MB) }
            'net' { $k.Net = (ConvertTo-Num $p[1]) + (ConvertTo-Num $p[2]) }
            'dsk' { $k.Ops = (ConvertTo-Num $p[1]) + (ConvertTo-Num $p[4]); $k.Sec = (ConvertTo-Num $p[2]) + (ConvertTo-Num $p[5]); $k.Ms = (ConvertTo-Num $p[3]) + (ConvertTo-Num $p[6]) }
            'ora' {
                $ora = 'Oracle FREEPDB1'
                if ($p[1] -eq 'userdata') { Add-Row 'capacity' 'Database' $ora 'Oracle user data' (ConvertTo-Num $p[2]) 'MB' 12288 -Text 'Oracle Database Free limit 12 GB' }
                elseif ($p[1] -eq 'tsmax') { Add-Row 'capacity' 'Database' $ora 'Tablespace used, fullest' (ConvertTo-Num $p[2]) '%' 100 }
                elseif ($p[1] -eq 'ledger') { Add-Row 'capacity' 'Database' $ora 'Ledger rows' (ConvertTo-Num $p[2]) 'rows' -Text 'MINIBANK.LEDGER_ENTRY' }
                elseif ($p[1] -in @('processes', 'sessions') -and $p.Count -ge 4) {
                    $lim = $null; if ($p[3] -match '^\d+$') { $lim = ConvertTo-Num $p[3] }
                    Add-Row 'capacity' 'Database' $ora ($(if ($p[1] -eq 'processes') { 'Processes in use' } else { 'Sessions in use' })) (ConvertTo-Num $p[2]) 'count' $lim
                }
            }
            'oraexp' {
                if ($p.Count -ge 3 -and $p[2] -ne 'never') {
                    $due = [DateTime]::SpecifyKind([DateTime]::ParseExact($p[2], 'yyyy-MM-dd HH:mm:ss', $Inv), [DateTimeKind]::Utc)
                    Add-Row 'calendar' 'Database' 'Oracle FREEPDB1' ('Password expires: ' + $p[1]) -DueUtc $due -Text 'database account of the application'
                }
            }
            'pg' {
                Add-Row 'capacity' 'Database' 'PostgreSQL minibank' 'Database size' ((ConvertTo-Num $p[1]) / 1MB) 'MB'
                Add-Row 'capacity' 'Database' 'PostgreSQL minibank' 'Transaction ID age' (ConvertTo-Num $p[2]) 'xids' 200000000 -Text 'autovacuum freeze age 200 million'
            }
            'pgconn' { Add-Row 'capacity' 'Database' 'PostgreSQL minibank' 'Connections in use' (ConvertTo-Num $p[1]) 'count' (ConvertTo-Num $p[2]) }
            'pkg' {
                if ($p[1] -match '^\d+$') {
                    $it = (New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)).AddSeconds((ConvertTo-Num $p[1]))
                    Add-Row 'posture' 'VM' $vm 'Days since last package update' (($Utc - $it).TotalDays) 'days' 35 -High 1 -Text ('last package installed ' + $it.AddHours(7).ToString('yyyy-MM-dd') + ' WIB; kernel ' + $p[2])
                }
            }
        }
    }
    if (-not $k.Now) { throw ('no answer: ' + (($res | Select-Object -First 2) -join ' ')) }
    $pv = $State.Raw[$vm]
    if ($pv -and [string]$pv.Boot -eq [string]$k.Boot) {
        $dt = $k.Now - [double]$pv.Now
        if ($dt -ge 600 -and $dt -le 10800) {
            if ($null -ne $k.Net -and $null -ne $pv.Net) { $mb = ($k.Net - [double]$pv.Net) / $dt / 1MB; if ($mb -ge 0) { Add-Row 'capacity' 'VM' $vm 'Network traffic (avg MB/s)' $mb 'MB/s' -Text ('average over the last {0:0} min' -f ($dt / 60)) } }
            if ($null -ne $k.Ops -and $null -ne $pv.Ops) {
                $ops = $k.Ops - [double]$pv.Ops; $mb = ($k.Sec - [double]$pv.Sec) * 512 / $dt / 1MB; $ms = $k.Ms - [double]$pv.Ms
                if ($mb -ge 0) { Add-Row 'capacity' 'VM' $vm 'Disk throughput (avg MB/s)' $mb 'MB/s' -Text ('{0:0.0} transfers/s on average' -f ($ops / $dt)) }
                if ($ops -gt 0 -and $ms -ge 0) { Add-Row 'capacity' 'VM' $vm 'Disk response time (avg ms)' ($ms / $ops) 'ms' 25 -Text ('average over the last {0:0} min' -f ($dt / 60)) }
            }
        }
    }
    $State.Raw[$vm] = @{ Boot = [string]$k.Boot; Now = $k.Now; Net = $k.Net; Ops = $k.Ops; Sec = $k.Sec; Ms = $k.Ms }
    $Done.Add($vm)
}

# ---------- OpenShift (oc, read-only) ----------
function ConvertTo-Cores([string]$q) {
    if (-not $q) { return 0.0 }
    if ($q.EndsWith('m')) { return (ConvertTo-Num $q.TrimEnd('m')) / 1000.0 }
    if ($q.EndsWith('n')) { return (ConvertTo-Num $q.TrimEnd('n')) / 1e9 }
    if ($q.EndsWith('u')) { return (ConvertTo-Num $q.TrimEnd('u')) / 1e6 }
    return (ConvertTo-Num $q)
}
function ConvertTo-Bytes([string]$q) {
    if (-not $q) { return 0.0 }
    $m = [regex]::Match($q, '^([0-9.eE+]+)([A-Za-z]*)$')
    if (-not $m.Success) { return 0.0 }
    $n = ConvertTo-Num $m.Groups[1].Value
    switch -CaseSensitive ($m.Groups[2].Value) {
        'Ki' { return $n * 1024 } 'Mi' { return $n * 1048576 } 'Gi' { return $n * 1073741824 } 'Ti' { return $n * 1099511627776 }
        'k' { return $n * 1e3 } 'M' { return $n * 1e6 } 'G' { return $n * 1e9 } 'T' { return $n * 1e12 } 'm' { return $n / 1000 }
        default { return $n }
    }
}
function Read-OpenShift([bool]$DoDaily) {
    $oc = 'C:\Tools\oc\oc.exe'; $env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
    $nl = @(& $oc get nodes --request-timeout=40s -o "jsonpath={range .items[*]}{.metadata.name}{'|'}{.status.allocatable.cpu}{'|'}{.status.allocatable.memory}{'|'}{.status.allocatable.pods}{'|'}{.spec.unschedulable}{'|'}{range .status.conditions[?(@.type=='Ready')]}{.status}{end}{'\n'}{end}" 2>&1 | ForEach-Object { "$_" })
    $nodes = @{}
    foreach ($l in $nl) {
        $p = $l -split '\|'
        if ($p.Count -ge 6 -and $p[0]) { $nodes[$p[0]] = @{ Cpu = (ConvertTo-Cores $p[1]); Mem = (ConvertTo-Bytes $p[2]); Pods = (ConvertTo-Num $p[3]); Ok = ($p[5] -eq 'True' -and $p[4] -ne 'true'); RC = 0.0; RM = 0.0; MC = 0.0; MM = 0.0; N = 0 } }
    }
    if ($nodes.Count -eq 0) { throw ('no nodes: ' + (($nl | Select-Object -First 1) -join ' ')) }
    $pl = @(& $oc get pods -A --request-timeout=60s --field-selector 'status.phase!=Succeeded,status.phase!=Failed' -o "jsonpath={range .items[*]}{.spec.nodeName}{'|'}{.metadata.ownerReferences[0].kind}{'|'}{range .spec.containers[*]}{.resources.requests.cpu}{','}{.resources.requests.memory}{';'}{end}{'\n'}{end}" 2>&1 | ForEach-Object { "$_" })
    foreach ($l in $pl) {
        $p = $l -split '\|'
        if ($p.Count -lt 3 -or -not $nodes.ContainsKey($p[0])) { continue }
        $c = 0.0; $m = 0.0
        foreach ($ct in ($p[2] -split ';')) { if ($ct) { $q = $ct -split ','; $c += ConvertTo-Cores $q[0]; if ($q.Count -gt 1) { $m += ConvertTo-Bytes $q[1] } } }
        $n = $nodes[$p[0]]; $n.RC += $c; $n.RM += $m; $n.N += 1
        if ($p[1] -and $p[1] -ne 'DaemonSet' -and $p[1] -ne 'Node') { $n.MC += $c; $n.MM += $m }
    }
    $ready = @($nodes.Keys | Where-Object { $nodes[$_].Ok })
    foreach ($name in ($nodes.Keys | Sort-Object)) {
        $n = $nodes[$name]
        if (-not $n.Ok) { continue }
        Add-Row 'capacity' 'OpenShift' $name 'CPU requests' (100.0 * $n.RC / $n.Cpu) '%' 100 -Text ('{0:0.00} of {1:0.00} cores requested' -f $n.RC, $n.Cpu)
        Add-Row 'capacity' 'OpenShift' $name 'Memory requests' (100.0 * $n.RM / $n.Mem) '%' 100 -Text ('{0:0.0} of {1:0.0} GB requested' -f ($n.RM / 1GB), ($n.Mem / 1GB))
        Add-Row 'capacity' 'OpenShift' $name 'Pods on node' $n.N 'pods' $n.Pods
        $fc = 0.0; $fm = 0.0
        foreach ($o in $ready) { if ($o -ne $name) { $fc += [Math]::Max(0.0, $nodes[$o].Cpu - $nodes[$o].RC); $fm += [Math]::Max(0.0, $nodes[$o].Mem - $nodes[$o].RM) } }
        $txt = 'sum of free requests on the other {0} ready nodes minus the movable pods of this node; ignores pod placement rules' -f ($ready.Count - 1)
        Add-Row 'capacity' 'OpenShift' $name 'Spare CPU if this node fails' ($fc - $n.MC) 'cores' -Low 0 -High 0.5 -Text $txt
        Add-Row 'capacity' 'OpenShift' $name 'Spare memory if this node fails' (($fm - $n.MM) / 1GB) 'GB' -Low 0 -High 1 -Text $txt
    }
    if ($DoDaily) {
        $cv = ((& $oc get clusterversion version --request-timeout=40s -o "jsonpath={.status.desired.version}{'|'}{.spec.channel}{'|'}{.status.availableUpdates[*].version}" 2>&1) -join '').Split('|')
        if ($cv.Count -ge 2) {
            $ups = @(); if ($cv.Count -ge 3 -and $cv[2].Trim()) { $ups = @($cv[2].Trim() -split '\s+') }
            Add-Row 'posture' 'OpenShift' 'arc-ocp-minibank' 'OpenShift updates available' $ups.Count 'updates' -Text ('version {0}, channel {1}{2}' -f $cv[0], $cv[1], $(if ($ups.Count) { ', newer: ' + (($ups | Select-Object -First 4) -join ' ') } else { '' }))
        }
        $bad = @(& $oc get co --no-headers --request-timeout=40s 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() -and $_ -notmatch '\sTrue\s+False\s+False' })
        Add-Row 'posture' 'OpenShift' 'arc-ocp-minibank' 'Cluster operators not healthy' $bad.Count 'operators' 0 -High 2 -Text $(if ($bad.Count) { 'not healthy: ' + (($bad | ForEach-Object { ($_ -split '\s+')[0] }) -join ', ') } else { 'all Available, none Degraded' })
        $dep = @(& $oc get apirequestcounts --request-timeout=40s -o "jsonpath={range .items[?(@.status.removedInRelease)]}{.metadata.name}{'\n'}{end}" 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        Add-Row 'posture' 'OpenShift' 'arc-ocp-minibank' 'Deprecated API calls' $dep.Count 'APIs' 0 -High 1 -Text $(if ($dep.Count) { ($dep | Select-Object -First 3) -join ', ' } else { 'none in use' })
        try {
            $crt = (& $oc get secret router-certs-default -n openshift-ingress --request-timeout=40s -o "jsonpath={.data.tls\.crt}" 2>&1) -join ''
            $pem = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($crt))
            $b = (($pem -split '-----BEGIN CERTIFICATE-----')[1] -split '-----END CERTIFICATE-----')[0]
            $x = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(, [Convert]::FromBase64String(($b -replace '\s', '')))
            Add-Row 'calendar' 'OpenShift' 'arc-ocp-minibank' 'Ingress certificate expires' -DueUtc $x.NotAfter -Text ('default ingress certificate ' + $x.Subject)
        } catch { Add-Note 'ingress certificate' $_ }
    }
    $Done.Add('openshift')
}

# ---------- main ----------
$cfg = $null
try { $cfg = Get-Content -LiteralPath (Join-Path $Dir 'config.json') -Raw | ConvertFrom-Json } catch { Add-Note 'config' $_ }
$state = Read-State
$doDaily = $Daily -or ((-not $NoDaily) -and $t0.Hour -ge 10 -and $state.LastDaily -ne $t0.ToString('yyyy-MM-dd'))
$skipped = $false
$paused = Test-Path -LiteralPath (Join-Path $Dir 'pause.on')
if ($paused -or (Test-Drill)) {
    $skipped = $true
} else {
    $steps = @('host', 'APP-WIN', 'APP-SQL', 'APP-RHEL', 'openshift')
    $cred = $null
    foreach ($s in $steps) {
        if ($s -ne 'host' -and (Test-Drill)) { Add-Note 'stopped early' 'a lab drill started'; $skipped = $true; break }
        try {
            switch ($s) {
                'host' { Read-Host2 $doDaily }
                'APP-WIN' { if (-not $cred) { $cred = Get-GuestCred }; Read-Windows 'APP-WIN' $cred $doDaily $state }
                'APP-SQL' { if (-not $cred) { $cred = Get-GuestCred }; Read-Windows 'APP-SQL' $cred $doDaily $state }
                'APP-RHEL' { Read-Rhel $doDaily $state }
                'openshift' { Read-OpenShift $doDaily }
            }
        } catch { Add-Note $s $_ }
    }
    $cred = $null
    if ($doDaily -and -not $skipped -and $cfg) {
        try {
            foreach ($f in (Invoke-La $cfg 'MiniBankLaForecast(1) | where not(Complete) | project Block, Item, Pred, Low, High')) {
                $bs = [DateTime]$f['Block']
                Add-Row 'forecast' 'Forecast' 'law-appmon' ([string]$f['Item']) $f['Pred'] '' -Low $f['Low'] -High $f['High'] -StartUtc $bs -DueUtc ($bs.ToUniversalTime().AddDays(1)) -Text 'day-ahead forecast saved at the start of the block'
            }
            $Done.Add('forecast')
        } catch { Add-Note 'forecast' $_ }
    }
}
$secs = ((Get-Date) - $t0).TotalSeconds
$cnt = @($Rows | Group-Object { $_.Kind } | ForEach-Object { '{0} {1}' -f $_.Name, $_.Count }) -join ', '
$summary = $(if ($skipped -and $Done.Count -eq 0) { $(if ($paused) { 'skipped: paused by switch (pause.on)' } else { 'skipped: lab drill in progress' }) } else { 'read ' + ($Done -join ', ') + ' | rows: ' + $cnt + $(if ($doDaily) { ' | daily part included' } else { '' }) })
if ($Notes.Count) { $summary += ' | notes: ' + ($Notes -join ' ; ') }
Add-Row 'collector' 'Monitoring' $env:COMPUTERNAME 'run' $secs 'seconds' -Text $summary
$rf = Join-Path $Dir ('rows-' + $t0.ToString('yyyyMMdd') + '.jsonl')
foreach ($r in $Rows) { Add-Content -LiteralPath $rf -Value (ConvertTo-Json -InputObject $r -Compress) -Encoding UTF8 }
$up = 'not sent (-NoUpload)'
if (-not $NoUpload) {
    if ($cfg) { try { Send-Rows $cfg $Rows; $up = 'sent' } catch { $up = 'SEND FAILED: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ': ' + $_.InvocationInfo.Line.Trim() + ')' } } else { $up = 'not sent (no config)' }
}
if ($doDaily -and -not $skipped -and -not $NoUpload -and $up -eq 'sent' -and $Done.Count -ge 4) { $state.LastDaily = $t0.ToString('yyyy-MM-dd') }
Save-State $state
Get-ChildItem -LiteralPath $Dir -Filter 'rows-*.jsonl' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item -Force -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $LogF) -and (Get-Item -LiteralPath $LogF).Length -gt 1MB) { Move-Item -LiteralPath $LogF -Destination ($LogF + '.old') -Force }
Write-Log ('{0} | {1:0} s | {2} rows | {3} | {4}' -f $RunId, $secs, $Rows.Count, $up, $summary)
if ($NoUpload) { foreach ($r in $Rows) { ('{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}' -f $r.Kind, $r.Resource, $r.Item, $r.Value, $r.Unit, $r.Limit, $r.Low, $r.DueUtc) } }
('{0} | {1:0} s | {2} rows | {3}' -f $RunId, $secs, $Rows.Count, $up)
$summary
