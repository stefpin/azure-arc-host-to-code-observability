# P1-DC-DEPLOY - MiniBank source pack v1.4 (P1 build): features D (business impact in IDR) and C (customer journey + browser robot)

Pack folder: `minibank/` next to this file (MANIFEST.md section 0 lists every new and changed file). Build approved by the lab owner
12 Nov 2026 15:06 WIB; Azure changes only in `rg-appmon-openshift-demo` (workbook update + 2 alert rules). Machines changed:
APP-SQL, APP-WIN, HV-HOST-02. Feature B (minibank-rates, collector) is deployed by its own notes; nothing below depends on it.

Order (each step has a check and a rollback):

| Step | Machine | What | Needs |
|---|---|---|---|
| 0 | HV-HOST-02 | pack into the host and the guests, backups | - |
| 1 | APP-SQL | migration 02-p1-tiers-customers.sql + v1.4 top-up | 0 |
| 2 | APP-WIN | API 1.2.0 (publish) + web 1.2.0 (build) | 0 (works before or after 1) |
| 3 | APP-WIN | browser robot + task minibank-robot | 1, 2 |
| 4 | HV-HOST-02 | traffic.ps1 / probe.ps1 (header), incident.ps1, traffic task -SlowPercent 2 | 1 (the generator restarts with all 66 accounts) |
| 5 | Azure (Cloud Shell, Portal) | workbook group "Business impact (IDR)", 2 alert rules | 2, 3 (+10 minutes of robot data) |

Do not run the steps during a demo or rehearsal: Step 2 stops the API for about 1-2 minutes (wait for the worker process to exit before copying, see Step 2).

Tier choice (decided in the build): ANDI.WIJAYA, SITI.RAHAYU and BUDI.SANTOSO are **Prioritas** (not Reguler as first
suggested). Reason: traffic.ps1 (unchanged, it logs in all 3 original users) sends transfers to every account it gets from
GET /api/accounts; with 66 accounts about 92 % of that money now leaves the 3 users, about IDR 100 million per user per hour.
A Reguler balance (IDR 25-75 million) would be empty within the hour and the generator would then produce "Insufficient
balance" declines (decline alert). A Prioritas balance (about IDR 1 billion) lasts about 10 hours; the top-up runs every 6
hours. Counts stay 24 / 7 / 2: the 24 Reguler customers are all new, Prioritas = the 3 original + 4 new, Solitaire = 2 new.

---

## Step 0 - Pack into HV-HOST-02, APP-WIN and APP-SQL (HV-HOST-02, PowerShell as Administrator)

The host folder `F:\Build\minibank` has local changes that must stay (for example `openshift\10-deployment.yaml` with the ACR
name, `transfer\applicationinsights-oracle.json`), so the new pack goes into its own folder and only the needed files are copied.

```powershell
$zip = 'F:\Build\MiniBank-source-pack-v1.4.zip'          # the v1.4 pack (zip of the minibank folder)
Expand-Archive $zip -DestinationPath F:\Build\pack-v1.4 -Force
Test-Path F:\Build\pack-v1.4\minibank\MANIFEST.md
$cred = Get-Credential Administrator                     # guest Administrator (PowerShell Direct, Chapter 5.6)
foreach ($vm in 'APP-WIN', 'APP-SQL') {
  Copy-VMFile -Name $vm -SourcePath $zip -DestinationPath C:\Build\MiniBank-source-pack-v1.4.zip -CreateFullPath -FileSource Host -Force
  Invoke-Command -VMName $vm -Credential $cred -ScriptBlock {
    # backup of the v1.3 folder (without node_modules), then the v1.4 files over it; extra files (the logo, node_modules,
    # build output) stay because robocopy /E never deletes
    robocopy C:\Build\minibank C:\Build\minibank-v1.3-backup /E /XD node_modules /NFL /NDL /NJH /NJS | Out-Null
    Expand-Archive C:\Build\MiniBank-source-pack-v1.4.zip -DestinationPath C:\Build\pack-v1.4 -Force
    robocopy C:\Build\pack-v1.4\minibank C:\Build\minibank /E /NFL /NDL /NJH /NJS | Out-Null
    [pscustomobject]@{ VM = $env:COMPUTERNAME; Manifest = (Get-Content C:\Build\minibank\MANIFEST.md -TotalCount 1)
                       Logo = (Test-Path C:\Build\minibank\web\public\brand\logo.*) }
  }
}
```

Check: both guests print `# MANIFEST – MiniBank source pack v1.4 (P1 build)`; APP-WIN prints `Logo True` if the presenter had
placed the logo before. Run Step 1 right after this step: until the migration has run, a scheduled top-up (00/06/12/18 WIB)
would only log `FAILED` (the v1.4 SQL needs the new view; balances stay as they are).
Rollback: `robocopy C:\Build\minibank-v1.3-backup C:\Build\minibank /E` in the guest (files only; nothing runs from the folder until
the next steps). Delete `C:\Build\pack-v1.4` and `F:\Build\pack-v1.4` when the build is accepted.

---

## Step 1 - APP-SQL: tiers, 30 customers, top-up (PowerShell Direct into APP-SQL, Administrator)

```powershell
# 1a. Backup (COPY_ONLY, default backup folder of the instance)
$cn = New-Object System.Data.SqlClient.SqlConnection 'Server=localhost;Database=master;Integrated Security=True'; $cn.Open()
$cmd = $cn.CreateCommand(); $cmd.CommandTimeout = 300
$cmd.CommandText = "BACKUP DATABASE MiniBankDemo TO DISK = N'MiniBankDemo-before-p1.bak' WITH COPY_ONLY, INIT"
[void]$cmd.ExecuteNonQuery(); $cn.Close()
# 1b. Migration (define Invoke-SqlFile first: runbook Chapter 14.1). Safe to run again.
Invoke-SqlFile C:\Build\minibank\db\sqlserver\02-p1-tiers-customers.sql
# 1c. Check: tiers and accounts
$cn = New-Object System.Data.SqlClient.SqlConnection 'Server=localhost;Database=MiniBankDemo;Integrated Security=True'; $cn.Open()
$cmd = $cn.CreateCommand()
$cmd.CommandText = 'SELECT c.Tier, COUNT(DISTINCT c.CustomerId), COUNT(a.AccountNo) FROM dbo.Customers c LEFT JOIN dbo.Accounts a ON a.CustomerId = c.CustomerId GROUP BY c.Tier ORDER BY c.Tier'
$r = $cmd.ExecuteReader(); while ($r.Read()) { '{0,-10} customers {1,2}  accounts {2,2}' -f $r[0], $r[1], $r[2] }; $cn.Close()
# 1d. v1.4 top-up now (the scheduled task minibank-topup keeps its action and uses the new SQL from now on)
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\topup-demo-balances.ps1
```

Check: `Prioritas customers 7 accounts 14`, `Reguler customers 24 accounts 48`, `Solitaire customers 2 accounts 4`. The top-up line
reads `... OK 66 accounts, N changed | Prioritas 14 accounts ... | Reguler 48 accounts ... | Solitaire 4 accounts ... | generator
9901000011 ... -> 974,625,000; 9901000012 ... -> 26,650,000; ...` (ANDI Tabungan IDR 974,625,000, SITI 1,049,250,000, BUDI
1,111,375,000). The Oracle ledger and PostgreSQL need nothing: a new account has an empty statement until its first payment.
Optional: re-run `install-topup-task.ps1` only to refresh the task description (it also runs one top-up).

Rollback (undo the migration, keeps all Transfers rows): first remove the robot (Step 3 rollback) and put the v1.3 top-up files back,
then run in SQL (Invoke-SqlFile on a file with this text, or sqlcmd):

```sql
USE MiniBankDemo;
DELETE FROM dbo.Accounts WHERE CustomerId BETWEEN 4 AND 33;
DELETE FROM dbo.Customers WHERE CustomerId BETWEEN 4 AND 33;
DROP VIEW IF EXISTS dbo.DemoBalanceTargets;
ALTER TABLE dbo.Customers DROP CONSTRAINT IF EXISTS CK_Customers_Tier;
ALTER TABLE dbo.Customers DROP CONSTRAINT IF EXISTS DF_Customers_Tier;
IF COL_LENGTH(N'dbo.Customers', N'Tier') IS NOT NULL ALTER TABLE dbo.Customers DROP COLUMN Tier;
```

```powershell
Copy-Item C:\Build\minibank-v1.3-backup\scripts\topup-demo-balances.* C:\Build\minibank\scripts -Force
Copy-Item C:\Build\minibank-v1.3-backup\scripts\reset-demo-balances.sql C:\Build\minibank\scripts -Force
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\topup-demo-balances.ps1   # v1.3 targets again
```
Then restart the traffic task on HV-HOST-02 (`Stop-ScheduledTask minibank-traffic; Start-ScheduledTask minibank-traffic`) so it
forgets the 60 removed accounts. Full alternative: restore `MiniBankDemo-before-p1.bak` (set the database SINGLE_USER first;
this also removes the Transfers rows written since the backup). API v1.4 keeps working on the v1.3 schema (tags without tier).

---

## Step 2 - APP-WIN: API 1.2.0 and web 1.2.0 (PowerShell Direct into APP-WIN, Administrator)

Optional, avoids failed probe results during the 1-2 minute stop: on HV-HOST-02 `Stop-ScheduledTask minibank-traffic;
Stop-ScheduledTask minibank-probe` now and `Start-ScheduledTask` both at the end of this step (Step 4 restarts them anyway).

```powershell
Import-Module WebAdministration
robocopy C:\inetpub\minibank-api C:\inetpub\minibank-api-v1.3 /E /NFL /NDL /NJH /NJS | Out-Null   # backup of the running site
# Node.js 24 for this window (portable install of runbook Chapter 15.4)
$node = Get-ChildItem C:\tools -Directory -Filter 'node-v24*-win-x64' | Sort-Object Name -Descending | Select-Object -First 1
$env:Path = "$($node.FullName);" + $env:Path; node --version
# web first (the site keeps running while it builds)
Set-Location C:\Build\minibank\web
npm.cmd install
npm.cmd run build
# API: publish to a staging folder first (the running site is not touched while it builds)
Set-Location C:\Build\minibank\api
dotnet publish MiniBank.Api.csproj -c Release -r win-x64 --self-contained true -o C:\Build\publish\minibank-api-1.2.0
Test-Path C:\Build\publish\minibank-api-1.2.0\MiniBank.Api.dll      # must be True before you go on
# Swap: stop the pool and WAIT until its worker process (w3wp) has really exited. Stop-WebAppPool reports 'Stopped' at once,
# but w3wp keeps the DLLs locked while it shuts down (up to 90 s); copying before that fails (robocopy exit code 8 or more).
Stop-WebAppPool -Name minibank
for ($i = 0; $i -lt 50 -and @(Get-ChildItem IIS:\AppPools\minibank\WorkerProcesses).Count; $i++) { Start-Sleep -Seconds 2 }
Get-ChildItem IIS:\AppPools\minibank\WorkerProcesses | ForEach-Object { Stop-Process -Id $_.processId -Force }   # only if still running
robocopy C:\Build\publish\minibank-api-1.2.0 C:\inetpub\minibank-api /E /R:10 /W:3 /NFL /NDL /NJH /NJS; "robocopy exit $LASTEXITCODE (0-7 = OK)"
Copy-Item C:\Build\minibank\web\dist\* C:\inetpub\minibank-api\wwwroot -Recurse -Force
Start-WebAppPool -Name minibank
Start-Sleep -Seconds 5
Invoke-RestMethod http://localhost:8080/api/health
```

Check: health returns `version 1.2.0` (v1.3 returned 1.1.0); the page footer shows `MiniBank 1.2.0`; log in as ANDI.WIJAYA:
Tabungan about IDR 974,625,000 after Step 1. After 3-5 minutes, in law-appmon > Logs: query E1 shows `people` for your
clicks and `traffic` / `probe` once Step 4 is done (until then the generator and probe show as `unknown`); query E6 shows tier and
outcome on the payments. Where `enduser.id` landed (UserId or UserAuthenticatedId depends on the exporter version):
`AppRequests | where TimeGenerated > ago(30m) and AppRoleName == "minibank-api" and isnotempty(tostring(Properties["minibank.userId"])) | project TimeGenerated, Name, UserId, UserAuthenticatedId, Properties | take 5`.

Rollback: the same three swap lines (Stop-WebAppPool, wait for WorkerProcesses to be empty, robocopy) with the source
`C:\inetpub\minibank-api-v1.3`, then `Start-WebAppPool minibank` (health returns 1.1.0 again). Build lesson (12 Nov 2026): a copy
without the wait left the API down with HTTP 503 for about 10 minutes. The v1.3 page works with the v1.4 API and the v1.4 page with the v1.3 API (extra headers are ignored).

---

## Step 3 - APP-WIN: browser robot (same PowerShell Direct window as Step 2, Node.js on the PATH)

```powershell
Set-Location C:\Build\minibank\robot
npm.cmd ci                       # playwright-core 1.64.1 from package-lock.json, no browser download (Edge is installed)
#   if npm reports a lock file problem: npm.cmd install --no-audit --no-fund
node robot.js --plan             # the incident cycle, no browser: ends with IDR 240,685,000 and 6 customers
node robot.js --once --type statement --customer SITI.RAHAYU
node robot.js --once --type transfer --customer AGUS.SETIAWAN --amount 50000
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\robot\install-robot-task.ps1 -NodeExe "$($node.FullName)\node.exe"
Get-Content C:\BuildLog\robot.log -Tail 5
```

Check: each `--once` run prints one line `journey customer=... result=success ms=...` (exit code 0). The installer prints
`minibank-robot: Running, node v24...`, and robot.log shows `minibank-robot started ...` and, every 2 minutes, one `journey` line.
In Application Insights (5-10 minutes later): query E7 (journeys), E10 (page views by trafficSource: robot), and
`AppEvents | where Name == "minibank.journey" | take 10`. The profiles are in `C:\ProgramData\MiniBank\robot\profiles\<User ID>`.
Pause: `Disable-ScheduledTask minibank-robot; Stop-ScheduledTask minibank-robot`; resume with Enable/Start.

Rollback: `powershell -ExecutionPolicy Bypass -File C:\Build\minibank\robot\install-robot-task.ps1 -Remove` (task removed, node and
robot Edge processes stopped); optionally delete `C:\ProgramData\MiniBank\robot` and `C:\Build\minibank\robot\node_modules`.

---

## Step 4 - HV-HOST-02: scripts, incident command, traffic task argument (PowerShell as Administrator)

```powershell
Set-Location F:\Build\minibank\scripts
Copy-Item traffic.ps1 traffic-v1.3.ps1 -Force; Copy-Item probe.ps1 probe-v1.3.ps1 -Force
Copy-Item F:\Build\pack-v1.4\minibank\scripts\traffic.ps1, F:\Build\pack-v1.4\minibank\scripts\probe.ps1, F:\Build\pack-v1.4\minibank\scripts\incident.ps1 . -Force
# background slow share 6 % -> 2 % (agreed 12 Nov 13:10 WIB). Re-registers and restarts minibank-traffic (it now loads all 66
# accounts and sends X-MiniBank-Source: traffic) and restarts minibank-probe with its unchanged action (new probe.ps1 file).
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\install-traffic-tasks.ps1 -SlowPercent 2
(Get-ScheduledTask minibank-traffic).Actions[0].Arguments      # only the traffic task: the probe arguments hold the connection string
Start-Sleep -Seconds 90; Get-Content C:\BuildLog\traffic.log -Tail 2
```

Check: the arguments end with `-SlowPercent 2 -DeclinesPerHour 4 -LogFile C:\BuildLog\traffic.log`; traffic.log shows `ok=30 failed=0`
per minute; within 30 minutes the Transfer/QRIS P95 drops below 1,000 ms (workbook table SlaMet true). Query E1 shows `traffic`
and `probe` instead of `unknown`.

Incident command (rehearsal only, replaces the second-window command of Scenes 5/6):

```powershell
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\incident.ps1 -Scene 6   # fail-oracle 10 min
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\incident.ps1 -Scene 5   # slow-oracle 5 min, then fail-oracle 10 min
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\incident.ps1 -Stop      # end early (note expired, generators stopped)
Invoke-Command -VMName APP-WIN -Credential $cred { Get-Content C:\BuildLog\robot.log -Tail 8 }
```

Check: the command returns at once with one line in `C:\BuildLog\incident.log` (phases, `note copied to APP-WIN`, generator PIDs);
one minimized window `MiniBank incident Scene 6 - phase 1: fail-oracle 10 min ...` runs traffic.ps1; within 30 s robot.log shows
`incident window fail-oracle until ...` and then a payment journey every 30 s, every 3rd with `scenario=fail-oracle result=failed`.
After the last phase the robot logs `incident window ended: normal pace again`.

Rollback: `Copy-Item traffic-v1.3.ps1 traffic.ps1 -Force; Copy-Item probe-v1.3.ps1 probe.ps1 -Force` (the header is harmless, so
this is optional), `install-traffic-tasks.ps1 -SlowPercent 6` for the v1.3 slow share, and use the v1.3 Scene 6 line
`.\traffic.ps1 -Minutes 10 -PerMinute 6 -Scenario fail-oracle` instead of incident.ps1. A running incident: `incident.ps1 -Stop`.

---

## Step 5 - Azure: workbook and alerts (Portal + Cloud Shell; only rg-appmon-openshift-demo)

Upload the pack zip into Cloud Shell, then `unzip -oq MiniBank-source-pack-v1.4.zip -d ~/p14 && cd ~/p14/minibank` (keeps ~/minibank).

5a. Workbook "MiniBank – SLA and Failure Rate" (appi-minibank): Monitor > Workbooks > open it > Edit > Advanced Editor >
Gallery Template: first copy the current text into a file (`workbook-before-p1.json`, the rollback), then paste
`monitoring/workbook/minibank-sla-workbook.json` > Apply > Save (same workbook, tags kept). Check: the existing 11 items are
unchanged; at the end the group **Business impact (IDR)** with 4 tiles (failed value in the time range, failed value last 10 min,
customers affected, failed payments), tables by tier / amount band / traffic source, a 5-minute chart and the latest failed
payments (time, User ID, tier, channel, amount, trace ID). With no incident the IDR tiles show 0.
Rollback: Advanced Editor > paste `workbook-before-p1.json` > Apply > Save.

5b. Alerts - wait until the robot has run for at least 10 minutes (the journey query needs customEvents data to pass validation):

```powershell
pwsh    # Cloud Shell PowerShell
Set-Location ~/p14/minibank/monitoring/alerts
./create-p1-alerts.ps1              # finds appi-minibank (APPI_ID) by name; or -AppiId '<resource ID>'
```

Check: provisioning state `Succeeded`, and the table lists alr-minibank-failed-value-idr and alr-minibank-journey-success-low
(enabled, severity 2, every PT5M, window PT10M) next to the 2 v1.3 MiniBank rules. Portal > Alert rules: Action groups empty,
tags demo / owner / purpose / &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt;. If the portal rejects the IDR measure, use the count-based fallback query in
`alr-minibank-failed-value-idr.kql` (Table rows > 0).
Rollback: `az monitor scheduled-query delete -g rg-appmon-openshift-demo -n alr-minibank-failed-value-idr --yes` and the same for
`alr-minibank-journey-success-low` (optional: `az deployment group delete -g rg-appmon-openshift-demo -n p1-minibank-alerts`).

5c. End-to-end rehearsal (outside a demo): `incident.ps1 -Scene 6`. Expected in 10-15 minutes: the robot's 6 failed payments
(KEVIN.HALIM 25M, MELINDA.KUSNADI 60M, HARYANTO.TJAHJADI 150M, IWAN.KURNIAWAN 85k, FAJAR.NUGROHO 600k, ASEP.SURYANA 5M = IDR
240,685,000) plus about 51 failed generator payments (about IDR 11 million, customers ANDI/SITI/BUDI); the IDR alert fires after
the 150M failure (journey 9, about 4 minutes into the window, plus ingestion and the 5-minute evaluation), the journey alert
fires once 2 journeys failed and success is below 90 % (journey 6, about 2.5 minutes in; whole robot window: 14 of 20 succeed =
70 %), alr-minibank-failure-rate-high fires as before. Close the fired alerts afterwards (runbook Chapter 20.3).

---

## Notes for the runbook / storyline (v1.5) - documents only

- Scenes 5 and 6: the second-window command becomes `incident.ps1 -Scene 5` (or `-Scene 6`); `-Stop` in the reset chapter.
- 15.3 health check: version 1.2.0. 17.10 top-up table: 66 accounts by tier (ANDI Tabungan IDR 974,625,000).
- 17.1 traffic task: `-SlowPercent 2`. New chapter: robot task, log `C:\BuildLog\robot.log`, profiles, pause/resume.
- Alerts table (17.5): add the two rules; queries E1-E10 in Appendix A.
- Ingestion: about +0.19 GB/day (robot + tags), 2 more log alerts about US$3/month (12 Nov estimate).
