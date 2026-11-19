# 14. Databases

<sub>Part D - Build MiniBank, database monitoring, dashboards and alerts &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 14.1 APP-SQL: SQL Server 2022 Developer and the MiniBankDemo database

> [!NOTE]
> **Approval Gate**
>
> G4 (new software and a firewall rule on APP-SQL).

> [!NOTE]
> **Where to run it**
>
> APP-SQL - PowerShell Direct (Chapter 5.6). The prompt must start with [APP-SQL].

Step 1. Download and install SQL Server 2022 Developer (about 1 GB download, 10 to 15 minutes in total). As built, the SQL Server downloader (SSEI) hung for 48 minutes without fetching any media, so the block downloads the ISO directly with curl.exe. The link worked on 10 November 2026.

```powershell
New-Item -ItemType Directory -Path C:\SQLMedia -Force | Out-Null
curl.exe -L --fail -o C:\SQLMedia\SQLServer2022-x64-ENU-Dev.iso `
  https://download.microsoft.com/download/3/8/d/<GUID>/SQLServer2022-x64-ENU-Dev.iso
$iso = Get-ChildItem C:\SQLMedia -Filter *.iso | Select-Object -First 1
$drive = (Mount-DiskImage -ImagePath $iso.FullName -PassThru | Get-Volume).DriveLetter
Start-Process "$($drive):\setup.exe" -Wait -ArgumentList '/Q','/ACTION=Install','/IACCEPTSQLSERVERLICENSETERMS',
  '/SUPPRESSPRIVACYSTATEMENTNOTICE','/FEATURES=SQLENGINE','/INSTANCENAME=MSSQLSERVER',
  '/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"','/TCPENABLED=1','/UpdateEnabled=False'
Dismount-DiskImage -ImagePath $iso.FullName | Out-Null
Get-Service MSSQLSERVER | Format-Table Name, Status, StartType
```

> [!TIP]
> **What you should see**
>
> curl.exe shows its progress and ends without an error, then MSSQLSERVER Running, StartType Automatic.

Fallback, only if the direct link no longer works: use the SQL Server downloader (SSEI) with a time limit. The block stops it after 15 minutes if it has not finished. When an ISO file is listed at the end, run the block above again from the line that starts with $iso down to the end.

```powershell
Invoke-WebRequest -UseBasicParsing -OutFile C:\SQLMedia\SQL2022-SSEI-Dev.exe `
  -Uri 'https://go.microsoft.com/fwlink/p/?linkid=2215158&clcid=0x409&culture=en-us&country=us'
$p = Start-Process C:\SQLMedia\SQL2022-SSEI-Dev.exe -PassThru -ArgumentList '/ACTION=Download','/MEDIAPATH=C:\SQLMedia','/MEDIATYPE=ISO','/QUIET'
$p | Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; 'Downloader stopped after 15 minutes' }
Get-ChildItem C:\SQLMedia -Filter *.iso | Format-Table Name, Length
```

> [!WARNING]
> **If something goes wrong**
>
> If neither download works, open https://www.microsoft.com/sql-server/sql-server-downloads on HV-HOST-02, download the free Developer edition that is offered (SQL Server 2025 Developer works the same for this demo), copy it to APP-SQL with Copy-VMFile and run the same setup.exe line. Setup writes its log to C:\Program Files\Microsoft SQL Server\&lt;version&gt;\Setup Bootstrap\Log\Summary.txt.

Step 2. Create the service account and open the SQL port for APP-WIN only. The IIS application of MiniBank runs as a local account called minibank-svc on APP-WIN; an account with the same name and the same password on APP-SQL lets it sign in to SQL Server with Windows authentication without a domain (a "mirrored account").

```powershell
$pw = Read-Host 'New password for minibank-svc (write it into ENVIRONMENT.txt)' -AsSecureString
New-LocalUser -Name minibank-svc -Password $pw -PasswordNeverExpires -AccountNeverExpires `
  -Description 'MiniBank demo service account' | Out-Null
New-NetFirewallRule -DisplayName 'MiniBank SQL from APP-WIN' -Direction Inbound -Protocol TCP -LocalPort 1433 `
  -RemoteAddress 192.168.110.31 -Action Allow | Format-Table DisplayName, Enabled, Action
```

Step 3. Create the database with the script from the source pack. SQL Server setup does not always install the sqlcmd tool, so this runbook uses a small helper function, Invoke-SqlFile, that runs a SQL script with GO separators. Paste the helper first, then run the script and the check:

```powershell
function Invoke-SqlFile([string]$Path, [string]$Database = 'master') {
  $cn = New-Object System.Data.SqlClient.SqlConnection "Server=localhost;Database=$Database;Integrated Security=True"
  $cn.Open()
  try {
    foreach ($batch in ((Get-Content $Path -Raw) -split '(?im)^\s*GO\s*$')) {
      if ($batch.Trim()) { $cmd = $cn.CreateCommand(); $cmd.CommandText = $batch; $cmd.CommandTimeout = 300
                           [void]$cmd.ExecuteNonQuery() } }
  } finally { $cn.Close() }
}
Invoke-SqlFile C:\Build\minibank\db\sqlserver\01-minibank-db.sql
$cn = New-Object System.Data.SqlClient.SqlConnection 'Server=localhost;Database=MiniBankDemo;Integrated Security=True'
$cn.Open(); $cmd = $cn.CreateCommand()
$cmd.CommandText = 'SELECT (SELECT COUNT(*) FROM dbo.Customers), (SELECT COUNT(*) FROM dbo.Accounts)'
$r = $cmd.ExecuteReader(); [void]$r.Read(); "Customers: $($r[0])   Accounts: $($r[1])"; $cn.Close()
```

> [!TIP]
> **What you should see**
>
> Customers: 3   Accounts: 6.

> [!WARNING]
> **If something goes wrong**
>
> "Windows NT user or group 'APP-SQL\minibank-svc' not found" means Step 2 was skipped. "Login failed" means the session is not signed in as Administrator: exit and open the PowerShell Direct session again with the Administrator account.

## 14.2 APP-RHEL: Oracle AI Database Free

> [!NOTE]
> **Approval Gate**
>
> G4.

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash (ssh -i F:\Build\ocp\id_ed25519 labadmin@192.168.110.32 from HV-HOST-02).

Oracle Free runs in a Podman container named minibank-oracle. The administrator password is stored as a Podman secret, so it never appears on a command line.

Open the firewall port before you start the container, and let podman restore its network rules after every firewall reload. As built, a firewall-cmd --reload after the Oracle container had started removed podman's (netavark) NAT rules, so connections from APP-WIN and OpenShift to port 1521 hung (Java timeouts and failure alerts). The first three lines of the block prevent this.

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.110.0/24" port port="1521" protocol="tcp" accept'
sudo firewall-cmd --reload
sudo systemctl enable --now netavark-firewalld-reload.service
read -rsp 'New Oracle administrator password (SYS and SYSTEM): ' ORA_ADMIN_PW; echo
printf '%s' "$ORA_ADMIN_PW" | sudo podman secret create oracle_pwd -
unset ORA_ADMIN_PW
sudo podman pull container-registry.oracle.com/database/free:latest-lite
sudo podman run -d --name minibank-oracle --restart=always \
  --publish 1521:1521 --secret=oracle_pwd \
  --volume minibank-oradata:/opt/oracle/oradata \
  container-registry.oracle.com/database/free:latest-lite
sudo systemctl enable --now podman-restart.service
sudo podman logs -f minibank-oracle
```

> [!TIP]
> **What you should see**
>
> The pull downloads about 2 GB. After 3 to 10 minutes the log shows DATABASE IS READY TO USE!. Press Ctrl+C to stop following the log; the container keeps running.

Now create the users MINIBANK (used by the transfer service) and MINIBANK_MON (used by the monitoring routes), and the ledger table with 30 days of synthetic history. Passwords are typed hidden and passed on standard input. Use only letters and digits, starting with a letter.

```bash
cd ~/minibank
sudo podman cp db/oracle/01-minibank-user.sql minibank-oracle:/tmp/01-minibank-user.sql
sudo podman cp db/oracle/02-minibank-tables.sql minibank-oracle:/tmp/02-minibank-tables.sql
read -rsp 'SYSTEM password (the administrator password above): ' SYS_PW; echo
read -rsp 'New MINIBANK password: ' APP_PW; echo
read -rsp 'New MINIBANK_MON password: ' MON_PW; echo
printf 'CONNECT system/"%s"@FREEPDB1\n@/tmp/01-minibank-user.sql %s %s\nEXIT\n' "$SYS_PW" "$APP_PW" "$MON_PW" \
  | sudo podman exec -i minibank-oracle sqlplus -s /nolog; echo "sqlplus exit code: $?"
printf 'CONNECT system/"%s"@FREEPDB1\n@/tmp/02-minibank-tables.sql\nEXIT\n' "$SYS_PW" \
  | sudo podman exec -i minibank-oracle sqlplus -s /nolog; echo "sqlplus exit code: $?"
printf "CONNECT system/\"%s\"@FREEPDB1\nSELECT username, account_status FROM dba_users WHERE username LIKE 'MINIBANK%%';\nEXIT\n" "$SYS_PW" \
  | sudo podman exec -i minibank-oracle sqlplus -s /nolog
printf 'CONNECT system/"%s"@FREEPDB1\nSELECT COUNT(*) AS ledger_rows FROM MINIBANK.LEDGER_ENTRY;\nEXIT\n' "$SYS_PW" \
  | sudo podman exec -i minibank-oracle sqlplus -s /nolog
unset SYS_PW APP_PW MON_PW
```

> [!TIP]
> **What you should see**
>
> User created, Grant succeeded and Table created messages, and sqlplus exit code: 0 after each of the two scripts. The check query lists two rows, MINIBANK and MINIBANK_MON, both OPEN. The last query prints LEDGER_ROWS 30. Write the MINIBANK and MINIBANK_MON passwords into ENVIRONMENT.txt now.

> [!WARNING]
> **If something goes wrong**
>
> An exit code other than 0, or ORA-00959 at CREATE USER: the latest-lite image of Oracle AI Database Free has no USERS tablespace in FREEPDB1. Because of WHENEVER SQLERROR EXIT the script stops there, and the users MINIBANK and MINIBANK_MON and the table LEDGER_ENTRY are never created. 01-minibank-user.sql of source pack v1.3 creates the USERS tablespace first when it is missing (with its datafile next to the SYSTEM datafile). Check that ~/minibank comes from the v1.3 pack and run the block again.

> [!TIP]
> **Beginner tip**
>
> Always look at the exit codes and the dba_users rows (two rows, OPEN). In the as-built lab the first run stopped at CREATE USER, and the later checks looked fine because they did not test the user.

> [!WARNING]
> **If something goes wrong**
>
> If connections to port 1521 from OpenShift or APP-WIN hang although the port is open (transfers wait about 30 seconds, then fail), a firewall reload removed podman's NAT rules. On APP-RHEL run sudo podman network reload --all and check that netavark-firewalld-reload.service is enabled (Chapter 21).

> [!TIP]
> **Beginner tip**
>
> Do not create a table called LEDGER_MISSING. The fail-oracle scenario depends on that table not existing, which produces the error ORA-00942.

## 14.3 APP-RHEL: PostgreSQL 16

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

```bash
sudo dnf -y module reset postgresql
sudo dnf -y module enable postgresql:16
sudo dnf -y install postgresql-server postgresql-contrib
sudo postgresql-setup --initdb
sudo sed -i -E 's/^(host\s+all\s+all\s+(127\.0\.0\.1\/32|::1\/128)\s+)ident$/\1scram-sha-256/' /var/lib/pgsql/data/pg_hba.conf
printf "%s\n" "# MiniBank demo settings" "password_encryption = 'scram-sha-256'" \
  "shared_preload_libraries = 'pg_stat_statements'" "pg_stat_statements.track = all" \
  "log_min_duration_statement = 1000" | sudo tee -a /var/lib/pgsql/data/postgresql.conf > /dev/null
sudo systemctl enable --now postgresql
cd /tmp
read -rsp 'New minibank_app password: ' APP_PW; echo
read -rsp 'New postgres_exporter password: ' EXP_PW; echo
sudo -u postgres psql -v ON_ERROR_STOP=1 -v app_pw="$APP_PW" -v exp_pw="$EXP_PW" -d postgres < ~/minibank/db/postgres/01-minibank-db.sql
unset APP_PW EXP_PW
psql -h 127.0.0.1 -U minibank_app -d minibank -c 'SELECT count(*) FROM fraud_check;'
sudo -u postgres psql -d minibank -c 'SELECT extname FROM pg_extension;'
```

> [!TIP]
> **What you should see**
>
> initdb prints Initializing database ... OK. The psql test asks for the minibank_app password and prints count 0. The extension list includes pg_stat_statements. Write both passwords into ENVIRONMENT.txt.

> [!WARNING]
> **If something goes wrong**
>
> "password authentication failed" means the pg_hba.conf change or the password is wrong: run sudo grep -E '^host' /var/lib/pgsql/data/pg_hba.conf and check that the 127.0.0.1 line ends with scram-sha-256. Never set the method to trust. PostgreSQL stays local to APP-RHEL; no firewall rule is needed for port 5432.

---

[&larr; 13. OpenShift in Azure Arc, Container insights and managed Prometheus](13-openshift-in-azure-arc-container-insights-and-managed-promet.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [15. MiniBank services and screens &rarr;](15-minibank-services-and-screens.md)
