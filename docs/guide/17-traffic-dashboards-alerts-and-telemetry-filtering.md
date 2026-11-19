# 17. Traffic, dashboards, alerts and telemetry filtering

<sub>Part D - Build MiniBank, database monitoring, dashboards and alerts &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 17.1 Continuous traffic and the availability probe

From version 1.3 two scheduled tasks on HV-HOST-02 keep the lab busy all the time: minibank-traffic runs the load generator traffic.ps1, and minibank-probe runs the availability probe probe.ps1. Both run as SYSTEM, start by themselves after a host start and keep running when you close the Bastion session. You install them once, in this section.

The load generator traffic.ps1 (version 1.3) works like this. Every minute it logs in ANDI.WIJAYA, SITI.RAHAYU and BUDI.SANTOSO, refreshes their accounts and sends -PerMinute operations, spread evenly over the minute: Transfer 60 percent, QRIS 25 percent and Statement 15 percent.

| Parameter | Default | What it does |
|---|---|---|
| -Minutes | 30 | How long the script runs; 0 means until it is stopped (used by the task) |
| -PerMinute | 30 | Operations per minute |
| -Scenario | mix | mix, or one of the 9 scenarios of Chapter 4.4 for every operation |
| -FailPercent | 0.05 | Technical failures in the mix: 0.05 is 1 in 2,000 operations, split 3:2:3:2 over fail-oracle, fail-java, fail-python and fail-api |
| -SlowPercent | 6 | Slow calls in the mix, split equally over slow-sql, slow-oracle, slow-python and slow-postgres |
| -DeclinesPerHour | 0 | Business declines per hour (the task uses 4) |
| -LogFile | none | Also writes every line to this file; at 5 MB the file is renamed to .1 |

Business declines: each decline is a transfer from the demo user's smaller account (normally the Giro) for IDR 10 to 25 million more than its balance. The API answers "Insufficient balance." (HTTP 409, code INSUFFICIENT_FUNDS). No money moves and nothing is written to the databases (Chapter 4.4).

If the API is not reachable when the script starts, it waits and tries again every minute (with -Minutes 0) instead of stopping; an interactive run gives up after about 2 minutes. The script writes one line per minute, for example:

> [!NOTE]
> **Where to run it**
>
> Nothing to run: this is an example line of C:\BuildLog\traffic.log on HV-HOST-02. To see the live lines, run Get-Content C:\BuildLog\traffic.log -Tail 5 in HV-HOST-02 - PowerShell (Admin).

```text
2026-11-11 12:31 ok=30 failed=0 declined=0 slow>1s=2 avg=180ms p95=1540ms scenario=mix
```

When a technical failure happened in that minute, the line ends with lastFailedTrace= and the Trace ID of the failed call.

Why the task uses these values:

| Setting | Value | Why |
|---|---|---|
| -FailPercent | 0.05 (about one technical failure per hour) | With 1 percent, as in version 1.2, the healthy lab measured 99.35 percent success (16 failures in 2,443 requests), 6.5 times the whole 0.1 percent error budget: the Success tile was never green, and the failure alert fired about 30 to 40 times a day by chance. At 0.05 percent the 3-hour Success tile is green about 98 percent of the time and a random alert happens about once in three months; there are still failures for the tables and the trace drill-down. 0.1 percent would leave the 3-hour tile orange about a quarter of the time |
| -DeclinesPerHour | 4 | Small and steady, and independent of the balances. If declines were counted as failures, even 3 per hour would keep the Success tile orange |

Step 1. Create the probe task. Do this only on a new build: skip it if the task minibank-probe already exists. Every minute the probe makes a small transfer of IDR 10,000 between the two accounts of BUDI.SANTOSO and back again, so the balances stay the same, and sends one availability result to Application Insights. The task reads the Application Insights connection string from a machine variable, so the string is not stored in the task itself.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
$appi = Read-Host 'Application Insights connection string'
[Environment]::SetEnvironmentVariable('APPLICATIONINSIGHTS_CONNECTION_STRING', $appi, 'Machine')
Remove-Variable appi
New-Item -ItemType Directory -Force -Path C:\BuildLog | Out-Null
$probe = "& F:\Build\minibank\scripts\probe.ps1 -ConnectionString ([Environment]::GetEnvironmentVariable('APPLICATIONINSIGHTS_CONNECTION_STRING', 'Machine')) *> C:\BuildLog\probe.log"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$probe`""
Register-ScheduledTask -TaskName 'minibank-probe' -Description 'MiniBank availability probe (probe.ps1)' -Action $action `
  -Trigger (New-ScheduledTaskTrigger -AtStartup) -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Get-ScheduledTask -TaskName minibank-probe | Format-Table TaskName, State
```

> [!TIP]
> **What you should see**
>
> minibank-probe with State Ready. Step 2 starts it.

Step 2. Install the continuous traffic and give both tasks the watchdog. Run the script of the source pack once.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\install-traffic-tasks.ps1
```

The script creates (or replaces) the task minibank-traffic, which runs as SYSTEM:

> [!NOTE]
> **Where to run it**
>
> Nothing to run by hand: this is the command line that the scheduled task minibank-traffic runs on HV-HOST-02 (Task Scheduler &gt; Task Scheduler Library &gt; minibank-traffic &gt; Actions). To change it, run install-traffic-tasks.ps1 again (Step 2).

```powershell
traffic.ps1 -Minutes 0 -PerMinute 30 -Scenario mix -FailPercent 0.05 -SlowPercent 6 -DeclinesPerHour 4 -LogFile C:\BuildLog\traffic.log
```

- Triggers: at host start with a 10-minute delay, plus a watchdog every 15 minutes that starts the task again if it stopped. A running copy is never started twice.
- No run-time limit (Windows otherwise stops a task after 3 days), and a restart every 5 minutes after a failure.
- The log C:\BuildLog\traffic.log is renamed to traffic.log.1 at 5 MB.

The same script registers minibank-probe again with its action, no run-time limit and the same 15-minute watchdog, and restarts it.

> [!TIP]
> **What you should see**
>
> One line for minibank-traffic and one for minibank-probe, each with the state Running, run-time limit PT0S (which means none) and the triggers Boot + Time.

> [!TIP]
> **Beginner tip**
>
> Windows stops a scheduled task after 3 days unless the task says otherwise. As built in version 1.2, the probe task still had this default limit and would have been stopped by Windows on 13 November 2026 at 21:28 WIB. The script removes the limit for both tasks.

To watch, pause and resume the traffic, and to look at the probe:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator). These lines watch, pause and resume the two scheduled tasks on the host; Ctrl+C stops only the watching.

```powershell
Get-Content C:\BuildLog\traffic.log -Tail 5 -Wait                          # watch; Ctrl+C stops watching, not the traffic
Disable-ScheduledTask minibank-traffic; Stop-ScheduledTask minibank-traffic   # pause
Enable-ScheduledTask minibank-traffic; Start-ScheduledTask minibank-traffic   # resume
Get-Content C:\BuildLog\probe.log -Tail 3                                   # the probe
```

> [!TIP]
> **What you should see**
>
> One traffic line per minute with ok about 30 and failed=0, and declined=1 in about 4 lines per hour. The probe log shows lines such as 10:16:02 success=True ... accepted=1.

Interactive runs. You can also run traffic.ps1 by hand in a Bastion PowerShell window, next to the task: for example the incident window of Scene 6 or a burst of declines in Scene 7. These runs add to the background traffic. Run one line at a time; each run prints its own line per minute and stops by itself (or with Ctrl+C).

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (no need for Admin).

```powershell
Set-Location F:\Build\minibank\scripts
powershell -ExecutionPolicy Bypass -File .\traffic.ps1 -Minutes 30 -PerMinute 30 -Scenario mix          # 30 minutes of extra mixed traffic
powershell -ExecutionPolicy Bypass -File .\traffic.ps1 -Minutes 10 -PerMinute 6 -Scenario fail-oracle    # incident window
powershell -ExecutionPolicy Bypass -File .\traffic.ps1 -Minutes 5 -PerMinute 0 -DeclinesPerHour 240      # decline burst, about 20 declines
```

> [!TIP]
> **Beginner tip**
>
> The scheduled tasks keep running when you sign out of Windows or close the Bastion tab. Interactive runs stop when you sign out, so close the browser tab (disconnect) instead of using Sign out.

## 17.2 Check the telemetry (R1, R2 and R3)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; appi-minibank for the checks in the table below. The queries further down (rows 6 and 7 and the tip) run in law-appmon &gt; Logs (box above the queries). Wait at least 10 minutes after starting traffic.

| # | Where in the Portal | What you should see |
|---|---|---|
| 1 | Investigate, Application map | minibank-web, minibank-api, minibank-transfer and minibank-fraud connected by arrows, plus SQL Server, Oracle and PostgreSQL with call counts and average times |
| 2 | Investigate, Search (Transaction search). Filter Event types: Request, type transfer in the search box, open a POST /api/transfer row | The end-to-end transaction view: browser, .NET API, SQL Server, Java on OpenShift, Oracle, Python, PostgreSQL in one timeline |
| 3 | Investigate, Failures | Failed requests and the top failing dependency. Expect only a few technical failures from the mix (about one per hour), plus the business declines with result code 409, which Application Insights also counts as failed requests (Chapter 4.4) |
| 4 | Investigate, Performance | Duration percentiles (50th, 95th, 99th) per operation |
| 5 | Investigate, Live metrics | Incoming requests per second and failures, refreshed every second |
| 6 | law-appmon, Logs, query A.1 (below the table) | One row for every service: minibank-web, minibank-api, minibank-transfer, minibank-fraud and minibank-probe |
| 7 | law-appmon, Logs, query A.21 (below the table) | Business declines per hour: about 4 from the traffic task |

> [!TIP]
> **Beginner tip**
>
> Tell the two kinds apart by the result code: 500 and higher is a technical failure, 409 is a business decline. Query A.2 below shows both per business transaction.

The queries of rows 6 and 7 and of the tip, to run in law-appmon, **Logs**:

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

**Query A.1** - Telemetry arrives from every service

```kusto
union AppRequests, AppDependencies, AppExceptions, AppPageViews, AppAvailabilityResults
| where TimeGenerated > ago(30m)
| summarize Items = count(), Last = max(TimeGenerated) by Table = Type, AppRoleName
| order by AppRoleName asc, Table asc
```

**Query A.21** - Business declines per hour

Business declines (result code 409, Insufficient balance) of the last 24 hours. The continuous traffic makes about 4 per hour; the alert alr-minibank-decline-spike counts these declines over 15 minutes (Chapter 17.5).

```kusto
AppRequests
| where TimeGenerated > ago(24h) and AppRoleName == "minibank-api" and ResultCode == "409"
| summarize Declines = count() by bin(TimeGenerated, 1h)
| render columnchart
```

**Query A.2** - Technical failure rate and business declines per business transaction, 5-minute steps

Technical failures are result codes 500 and higher; business declines are result code 409 (Chapter 4.4).

```kusto
AppRequests
| where TimeGenerated > ago(1h) and AppRoleName == "minibank-api" and Name startswith "POST /api/"
| summarize Total = count(), TechnicalFailed = countif(toint(ResultCode) >= 500), Declines = countif(ResultCode == "409")
            by bin(TimeGenerated, 5m), Name
| extend TechnicalFailedPct = round(100.0 * TechnicalFailed / Total, 2)
| order by TimeGenerated desc, Name asc
```

> [!WARNING]
> **If something goes wrong**
>
> If a service is missing, use the troubleshooting table in Chapter 21 (row "No telemetry from one service").

## 17.3 Import the SLA workbook (R4)

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell, then Microsoft Edge on HV-HOST-02 with the Azure Portal. Do this inside HV-HOST-02, because the workbook text is copied through the clipboard.

1. In PowerShell: Get-Content F:\Build\minibank\monitoring\workbook\minibank-sla-workbook.json -Raw | Set-Clipboard
1. In the Portal, open appi-minibank, then **Monitoring**, **Workbooks**, and click **+ New**.
1. In the toolbar of the empty workbook, click the **Advanced Editor** button (the icon &lt;/&gt;).
1. Make sure **Template Type** is **Gallery Template**. Click in the text box, press Ctrl+A, then Ctrl+V to replace the text with the clipboard.
1. Click **Apply**, then **Done Editing**.
1. Click **Save** (the disk icon). Title: MiniBank - SLA and Failure Rate. Subscription: &lt;YOUR_SUBSCRIPTION_NAME&gt;. Resource group: rg-appmon-openshift-demo. Location: Indonesia Central. Click **Save**.

> [!TIP]
> **What you should see**
>
> Five SLA tiles at the top: Availability % (internal probe), Technical failure rate % (5xx), Business declines (Insufficient balance), Success % (SLA 99.9, excl. business declines) and P95 latency ms. Below them: P95, TechnicalFailedPct and Declines per business transaction, the P95 chart, the technical failure rate and the technical failures per service (cloud role, both counting only 5xx), Business declines (409) vs technical failures (5xx) per 15 minutes, the latest business declines with their trace ID, the top failed dependencies and the availability of the internal probe. The parameter Application Insights resources selects appi-minibank by itself.

> [!TIP]
> **Beginner tip**
>
> To bring a workbook that was saved with version 1.2 up to date, open it, click Edit, then the Advanced Editor button, replace the text with the version 1.3 file (steps 1 and 4), click Apply, Done Editing and Save.

## 17.4 Grafana: Prometheus data source and two dashboards (R4)

> [!NOTE]
> **Approval Gate**
>
> G6. You add a data source, a folder and two dashboards to amg-appmon, the lab's own Grafana (Chapter 10.7). Nothing outside rg-appmon-openshift-demo is touched.

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on HV-HOST-02 (the dashboard files are on F:). Sign in to the Azure Portal and to Grafana with your lab account, which has the role Grafana Admin on amg-appmon (Chapter 10.7).

amg-appmon uses two data sources: the built-in Azure Monitor data source (managed identity) for the SLA dashboard, and a new Prometheus data source, AMW appmon (managed identity, query endpoint of amw-appmon), for the OpenShift and database dashboard.

Step 1. Copy the query address of the Azure Monitor workspace: Portal, amw-appmon, **Overview**, **Query endpoint**, click the copy icon. It looks like https://amw-appmon-xxxx.indonesiacentral.prometheus.monitor.azure.com.

Step 2. Open Grafana: Portal, resource group rg-appmon-openshift-demo, amg-appmon, **Overview**, click the **Endpoint** link.

Step 3. Add the data source. In Grafana: menu (top left), **Connections**, **Data sources**, **+ Add new data source**. Choose **Prometheus**, the built-in type that the dashboard files use (this is why the lab runs Grafana 12, Chapter 10.7). Then fill in:

| Field | Value |
|---|---|
| Name | AMW appmon |
| Connection, Prometheus server URL | The query endpoint from Step 1 |
| Authentication, Authentication method | Azure auth |
| Azure Authentication | Managed Identity |
| Everything else | Leave as it is |

Click **Save & test**.

> [!TIP]
> **What you should see**
>
> A green message: Successfully queried the Prometheus API.

> [!WARNING]
> **If something goes wrong**
>
> 403 or "unauthorized": the role assignment of Chapter 10.7 is missing or still being applied. Wait 10 minutes and click Save & test again. If the form offers no Azure authentication at all, use the Portal instead: amg-appmon, Integrations, Azure Monitor workspaces, + Add, choose amw-appmon and click Add. Azure then creates the Prometheus data source for you; use that data source in Step 6.

Step 4. Create the folder: menu, **Dashboards**, **New**, **New folder**, name MiniBank, click **Create**.

Step 5. Import the SLA dashboard: **Dashboards**, **New**, **Import**, **Upload dashboard JSON file**, choose F:\Build\minibank\monitoring\grafana\minibank-sla-dashboard.json (version 1.3). Folder: MiniBank. Under DS_AZURE_MONITOR choose **Azure Monitor**. Click **Import**. At the top of the dashboard choose your subscription in the **Subscription** picker and law-appmon in the **Workspace** picker, then click **Save dashboard** (disk icon) and **Save**.

Step 6. Import the OpenShift and database dashboard the same way with F:\Build\minibank\monitoring\grafana\minibank-openshift-db-dashboard.json. Folder: MiniBank. Under DS_PROMETHEUS choose **AMW appmon**. Click **Import**.

> [!TIP]
> **What you should see**
>
> The folder MiniBank with two dashboards: MiniBank - SLA and Failure Rate (address &lt;Grafana endpoint&gt;/d/minibank-sla) and MiniBank - OpenShift and Databases (address &lt;Grafana endpoint&gt;/d/minibank-openshift-db). The second one shows the three nodes, the transfer pods, and the Oracle and PostgreSQL panels from Route B.

The SLA dashboard of version 1.3 shows the last 3 hours (version 2.3 adds the service weather strip at the top, Chapter 41; a board imported again from the source pack does not have it until you add it as in Chapter 41.7):

| Part | What it shows |
|---|---|
| Top, under the logo header (version 2.3) | Service weather: now (the last 15 minutes), the last 7 days and the next 7 days, the error budget against the SLA, the heat advisory and the next risks to the service (Chapter 41) |
| Five tiles, under the weather strip | Availability % (probe), Technical failures % (5xx), Business declines, Success % (SLA 99.9), P95 latency ms (SLA 1000). The (i) icon of each tile explains it, for example that the Success tile counts only technical failures (HTTP 5xx) and not business declines |
| Charts | P95 per business transaction; Technical failure rate % by cloud role (5xx) |
| Tables | Per business transaction: P95, technical failures, declines; Technical failures by cloud role; Top failed dependencies |
| Bottom | Business declines vs technical failures per 15 minutes (bars: blue for declines, red for technical failures); Latest business declines, with time, transaction, result, duration and trace ID |

The tiles of both dashboards use fixed colours:

| Tile | Colours |
|---|---|
| Availability % and Success % | Red below 99, orange below 99.9, green from 99.9 |
| Technical failures % (5xx) | Green below 1, orange below 2, red from 2 |
| P95 latency ms | Green below 800, orange below 1,000, red from 1,000 ms |
| OpenShift nodes Ready and minibank-transfer ready replicas | Red below 2, orange at 2, green from 3 |
| Oracle up and PostgreSQL up | Red at 0, green at 1 |
| Business declines | Blue: information only, no good or bad colour |

> [!WARNING]
> **If something goes wrong**
>
> Panels that say No data on the SLA dashboard: check the Subscription and Workspace choices at the top. Panels that say "insufficient access" or 403 in the first 10 minutes after the role assignment of Chapter 10.7: wait, and do not change anything. On the OpenShift dashboard: check the data source of Step 3 and that Prometheus explorer shows data (Chapter 16.2 Step 3).

## 17.5 Alert rules without notifications (R4)

> [!NOTE]
> **Approval Gate**
>
> G7. All three rules are created without an action group, so nobody receives an email or a Teams message. Alerts are only visible in the Portal. The automatic Failure Anomalies rule described below is the one exception.

| Rule | Severity | Checks | Fires when |
|---|---|---|---|
| alr-minibank-failure-rate-high | 2 | Every 5 minutes, over the last 5 minutes | More than 2 percent of at least 5 business requests ended with a technical failure (result code 500 or higher) |
| alr-minibank-decline-spike | 3 (informational) | Every 5 minutes, over the last 15 minutes | More than 10 business declines (result code 409). The normal background is about 4 declines per hour, so it fires only for an unusual pattern, for example a bug that makes balances read as zero |
| alr-ocp-node-not-ready | 1 | Every 5 minutes, over the last 5 minutes | An OpenShift node is not Ready |

All three rules resolve by themselves when the condition clears (auto-resolve), and they get the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; when they are created. Since version 1.3 the failure-rate rule counts only technical failures: business declines are correct answers of the bank (Chapter 4.4).

A fourth rule exists that you do not create. When Application Insights is created, Azure also creates the smart detection rule **Failure Anomalies - appi-minibank** (severity 3, checked every minute). It learns the normal failure rate during the first 24 hours and then fires when the failure rate rises unusually, judged by machine learning over a rolling 20-minute window, so it may or may not fire after the incident window of Scene 6. It counts every request with a result code of 400 or higher as failed, so it cannot tell business declines from technical failures. A fired alert resolves by itself only after 8 to 24 hours without a new detection, so close it after a rehearsal (Chapter 20.3).

As built, the rule is linked to the subscription's shared action group Application Insights Smart Detection in resource group rg-ut-monitor-demo, outside the lab. That action group emails every user who holds Monitoring Contributor or Monitoring Reader on the subscription; on 11 November 2026 only a service principal held such a role, so no email went out. Leave the rule as it is: whether to keep it, remove its link to the shared action group or switch it off is still open (Appendix E.1). Never change the action group itself, because it belongs to another resource group.

> [!TIP]
> **Beginner tip**
>
> The older smart detection rules of Application Insights (slow responses, slower dependencies, trace and exception changes and similar) are switched on and email the subscription owners. After Scenes 5 and 6 you may receive such an email; it is harmless. Each rule can be switched off in appi-minibank, Investigate, Smart detection, Settings.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block (Chapter 5.4). Run this only after telemetry has arrived (17.2); otherwise the query check fails because the tables do not exist yet.

```powershell
az extension add --name scheduled-query --upgrade --only-show-errors
$LAWID = az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv
$q1 = 'AppRequests | where AppRoleName == "minibank-api" and Name startswith "POST /api/" | summarize Total = count(), Failed = countif(toint(ResultCode) >= 500) | extend FailureRatePct = iff(Total == 0, 0.0, 100.0 * Failed / Total) | where Total >= 5 and FailureRatePct > 2'
az monitor scheduled-query create -g $RG -n alr-minibank-failure-rate-high --scopes $LAWID --location $LOC `
  --condition "count 'FailRate' > 0" --condition-query "FailRate=$q1" `
  --window-size 5m --evaluation-frequency 5m --severity 2 `
  --description 'MiniBank technical failure rate (HTTP 5xx) above 2 percent (demo, no notifications)' `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin <EXEMPT_TAG>=<EXEMPT_VALUE> --query "{name:name, enabled:enabled}" -o table
$q2 = 'KubeNodeInventory | summarize arg_max(TimeGenerated, Status) by Computer | where Status != "Ready"'
az monitor scheduled-query create -g $RG -n alr-ocp-node-not-ready --scopes $LAWID --location $LOC `
  --condition "count 'NotReady' > 0" --condition-query "NotReady=$q2" `
  --window-size 5m --evaluation-frequency 5m --severity 1 `
  --description 'OpenShift node not ready (demo, no notifications)' `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin <EXEMPT_TAG>=<EXEMPT_VALUE> --query "{name:name, enabled:enabled}" -o table
$q3 = 'AppRequests | where AppRoleName == "minibank-api" and Name startswith "POST /api/" and ResultCode == "409" | summarize Declines = count() | where Declines > 10'
az monitor scheduled-query create -g $RG -n alr-minibank-decline-spike --scopes $LAWID --location $LOC `
  --condition "count 'DeclineSpike' > 0" --condition-query "DeclineSpike=$q3" `
  --window-size 15m --evaluation-frequency 5m --severity 3 `
  --description 'MiniBank business declines (HTTP 409) above 10 in 15 minutes (demo, informational, no notifications)' `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin <EXEMPT_TAG>=<EXEMPT_VALUE> --query "{name:name, enabled:enabled}" -o table
```

> [!TIP]
> **What you should see**
>
> Three small tables with the rule name and True. In the Portal: Monitor, Alerts, Alert rules lists the three rules, and their column Action groups is empty. The list also shows Failure Anomalies - appi-minibank, which Azure created.

> [!TIP]
> **Beginner tip**
>
> If alr-minibank-failure-rate-high was created with the query of version 1.2, which also counted the declines as failures, update it: open the rule in the Portal (Monitor, Alerts, Alert rules), click Edit, open the condition, replace the query with the text of $q1 (without the quotes) and save. Then merge the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; onto the older rules (Chapter 7.1).

> [!WARNING]
> **If something goes wrong**
>
> If the CLI rejects a command, create the rule in the Portal instead: Monitor, Alerts, + Create, Alert rule. Scope: Select scope, filter Resource type Log Analytics workspaces, choose law-appmon, Apply. Condition: Signal name Custom log search, paste the query ($q1, $q2 or $q3 text without the quotes). Measurement: Measure Table rows, Aggregation type Count, Aggregation granularity 5 minutes (15 minutes for the decline rule). Alert logic: Operator Greater than, Threshold value 0, Frequency of evaluation 5 minutes. Actions: add nothing. Details: Severity 2 - Warning (or 1 - Error for the node rule, 3 - Informational for the decline rule), the rule name, Region Indonesia Central. Tags: the three usual tags and &lt;EXEMPT_TAG&gt; = &lt;EXEMPT_VALUE&gt;. Click Review + create, then Create.

## 17.6 Filtering at the source and at collection (R7)

Nothing has to be built in this section; the filters are already in place. Use it to understand what to show in Scene 13.

| Level | Where the filter is | What it does | How to prove it |
|---|---|---|---|
| Source - Java agent | transfer\applicationinsights.json inside the image; since 11 November 2026 the ConfigMap minibank-transfer-ai-config (file applicationinsights-oracle.json, Chapter 15.2 Step 3) replaces it | Sampling override: requests to /actuator/health are never sent (OpenShift calls them every few seconds). Processor: masks 10-digit account numbers in ledger URLs and in the attribute minibank.account, so only the last four digits leave the server. A second processor names the Oracle calls oracle.db | Query A.8 (below the table) shows no /actuator/health requests. Requests named GET /api/ledger/... show \*\*\*\*\*\*1234 |
| Source - .NET and Python | Program.cs and app.py | Sampling and filters can be set in code with the Azure Monitor OpenTelemetry Distro options. This demo keeps 100 percent so that every failure is visible | Show the one-line setup in each file |
| Collection - OpenShift logs | ConfigMap container-azm-ms-agentconfig (applied in Chapter 13.5) | Container logs from about 55 OpenShift system namespaces are not collected; environment variables are not collected | Query A.13 (below the table): log volume per namespace is dominated by minibank, not by openshift-\* namespaces. Compare with the minutes before the time you wrote down in Chapter 13.5 |
| Collection - Prometheus | ConfigMap ama-metrics-prometheus-config (Chapter 16.2) and the default minimal ingestion profile | Only the targets you list are scraped, and the default profile keeps only the metrics that the standard dashboards need | Prometheus explorer: only the minibank-oracle and minibank-postgres custom jobs exist |

The queries of this table, to run in law-appmon, **Logs**:

**Query A.8** - Requests handled by each transfer pod (and no health checks)

The OpenShift route keeps each client on one pod for a while (a cookie), so over a few minutes one pod can show most of the requests and another none. Over 30 to 60 minutes every pod shows requests.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppRequests
| where TimeGenerated > ago(30m) and AppRoleName == "minibank-transfer"
| summarize Requests = count(), Failed = countif(Success == false), HealthChecks = countif(Url has "/actuator/health")
          by AppRoleInstance
```

**Query A.13** - Container log volume by namespace

```kusto
ContainerLogV2
| where TimeGenerated > ago(1h)
| summarize MB = round(sum(_BilledSize) / 1024.0 / 1024.0, 2) by PodNamespace
| order by MB desc
```

> [!NOTE]
> **Where to run it**
>
> To show the Java configuration: HV-HOST-02 - PowerShell: Get-Content F:\Build\minibank\transfer\applicationinsights-oracle.json (or, from the cluster, oc get configmap minibank-transfer-ai-config -n minibank -o yaml)

> [!CAUTION]
> **Be honest**
>
> Telemetry processors (the masking and the oracle.db name) are a preview feature of the Java agent; sampling overrides are generally available. Masking at the source is the strongest protection, because the value never leaves the bank's network.

## 17.7 Filtering at ingestion: IIS logs with a transformation (R7)

A new data collection rule tells the Azure Monitor Agent on APP-WIN to collect the IIS logs of MiniBank. Its transformation, written in KQL, drops every log line for /api/health before the data is stored, so it is never paid for.

> [!NOTE]
> **Approval Gate**
>
> G4 (new data collection rule and association).

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block (Chapter 5.4).

```powershell
Set-Location ~
$LAWID = az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv
$kql = (Get-Content ~/minibank/monitoring/dcr/iis-transform.kql | Where-Object { $_ -notmatch '^\s*//' }) -join ' '
$dcr = @{
  location = $LOC; kind = 'Windows'
  tags = @{ purpose = 'appmon-openshift-demo'; demo = 'minibank'; owner = 'labadmin' }
  properties = @{
    description = 'MiniBank IIS logs from APP-WIN without health checks'
    dataSources = @{ iisLogs = @(@{ name = 'iisLogsDataSource'; streams = @('Microsoft-W3CIISLog') }) }
    destinations = @{ logAnalytics = @(@{ name = 'law'; workspaceResourceId = $LAWID }) }
    dataFlows = @(@{ streams = @('Microsoft-W3CIISLog'); destinations = @('law')
        outputStream = 'Microsoft-W3CIISLog'; transformKql = $kql.Trim() })
  }
}
$dcr | ConvertTo-Json -Depth 10 | Set-Content ./dcr-minibank-iis.json
$IISDCR = "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Insights/dataCollectionRules/dcr-minibank-iis"
az rest --method put --url "https://management.azure.com$($IISDCR)?api-version=2023-03-11" `
  --body '@dcr-minibank-iis.json' --query "{name:name, state:properties.provisioningState, kql:properties.dataFlows[0].transformKql}" -o table
@{ properties = @{ dataCollectionRuleId = $IISDCR; description = 'MiniBank IIS logs' } } |
  ConvertTo-Json -Depth 5 | Set-Content ./dcra-iis.json
$WINID = "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.HybridCompute/machines/APP-WIN"
az rest --method put --url "https://management.azure.com$WINID/providers/Microsoft.Insights/dataCollectionRuleAssociations/dcra-minibank-iis?api-version=2023-03-11" `
  --body '@dcra-iis.json' --query name -o tsv
```

> [!TIP]
> **What you should see**
>
> dcr-minibank-iis, Succeeded and the transformation text, which starts with source and filters out csUriStem /api/health. The second command prints dcra-minibank-iis.

Check after 15 to 30 minutes with traffic running:

1. law-appmon, **Logs**: run query A.17 below. It lists /api/transfer, /api/login and the static files, but no /api/health.

**Query A.17** - IIS log lines by URL (ingestion filter check)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
W3CIISLog
| where TimeGenerated > ago(1h)
| summarize Lines = count() by csUriStem
| order by Lines desc
```

1. For the comparison, count the health lines that IIS wrote locally on APP-WIN. A large number proves that the lines exist on the server but were filtered out before storage.

> [!NOTE]
> **Where to run it**
>
> APP-WIN - PowerShell Direct.

```powershell
netsh http flush logbuffer | Out-Null
$id = (Get-Website minibank-api).Id
Get-ChildItem "C:\inetpub\logs\LogFiles\W3SVC$id" -Filter *.log | Select-String -Pattern '/api/health' |
  Measure-Object | Select-Object Count
```

> [!WARNING]
> **If something goes wrong**
>
> No W3CIISLog rows at all after 30 minutes: check the association (Portal, the rule, Resources) and run netsh http flush logbuffer on APP-WIN; IIS writes its log buffer to disk only every minute or so.

## 17.8 Cost guard

- law-appmon has a daily cap of 10 GB (Chapter 10.1). When the cap is reached, collection stops until the next day (07:00 WIB), so the demo would lose data: check usage every day (Chapter 22.2).
- Query A.18 (after this list) shows the billable data per table. Measured on 11 November 2026, with the filters of 17.6 and 17.7: without traffic about 194 MB per hour, which is about 4.7 GB per day, mostly OpenShift performance counters (Perf) and the inventory tables of Container insights. The continuous traffic adds about 0.7 GB per day, mostly Application Insights dependencies, requests and traces. In total that is about 5.3 GB per day, under the daily cap of 10 GB. This replaces the estimate of 1 to 3 GB per day of version 1.2.
- At the list price of US$2.691 per GB (Analytics Logs, Indonesia Central, checked 11 November 2026), 5.3 GB per day costs about US$14 per day.
- Error storms raise the volume: the hour of the Oracle fault on 10 November 2026 had 1.7 times the normal volume. To stop all traffic, for example after the demo, pause the task minibank-traffic (Chapter 22.3).
- Portal: law-appmon, **Settings**, **Usage and estimated costs** shows the trend for the last 31 days.

**Query A.18** - Billable data by table (cost check)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
Usage
| where TimeGenerated > ago(1d) and IsBillable == true
| summarize GB = round(sum(Quantity) / 1024.0, 3) by DataType
| order by GB desc
```

Measured on 11 November 2026: about 4.7 GB per day without traffic, mostly Perf and the inventory tables of Container insights, plus about 0.7 GB per day from the continuous traffic, mostly AppDependencies, AppRequests and AppTraces. That is about 5.3 GB per day in total (Chapter 17.8).

## 17.9 Optional: send OpenTelemetry (OTLP) data from an existing collector (G10)

Many the bank teams already use OpenTelemetry. This optional module shows that an OpenTelemetry Collector can forward OTLP traces to Application Insights. Build it only if the bank asks for it and gate G10 is approved.

> [!NOTE]
> **Approval Gate**
>
> G10.

> [!CAUTION]
> **Be honest**
>
> There are two ways. (1) Azure Monitor's own OTLP ingestion, which was in preview when this runbook was written: follow the current Microsoft Learn article if the bank wants the Microsoft-supported path. (2) The azuremonitor exporter of the OpenTelemetry Collector Contrib distribution, used below. It is maintained by the OpenTelemetry community, not supported by Microsoft, but it is easy to show in a lab.

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

```bash
read -rp 'Application Insights connection string: ' APPICS
printf 'APPLICATIONINSIGHTS_CONNECTION_STRING=%s\n' "$APPICS" | sudo tee /etc/minibank/otelcol.env > /dev/null
unset APPICS
sudo chmod 600 /etc/minibank/otelcol.env
sudo tee /etc/minibank/otelcol.yaml > /dev/null <<'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 127.0.0.1:4317
processors:
  batch: {}
exporters:
  azuremonitor:
    connection_string: ${env:APPLICATIONINSIGHTS_CONNECTION_STRING}
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [azuremonitor]
EOF
sudo podman run -d --name minibank-otelcol --network host --env-file /etc/minibank/otelcol.env \
  -v /etc/minibank/otelcol.yaml:/etc/otelcol-contrib/config.yaml:Z,ro docker.io/otel/opentelemetry-collector-contrib:latest
sleep 10
sudo podman run --rm --network host ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  traces --otlp-insecure --otlp-endpoint 127.0.0.1:4317 --traces 5 --service otel-test
```

> [!TIP]
> **What you should see**
>
> telemetrygen prints that it generated 5 traces. After 5 minutes, the query below returns rows. Run it in the Azure Portal: law-appmon &gt; Logs (left menu), switch to KQL mode, paste it into the query editor, set Time range to Last 30 minutes (the query has no time filter) and click Run.

```kusto
union AppRequests, AppDependencies
| where AppRoleName == "otel-test"
```

To remove the module afterwards, in APP-RHEL - Bash: sudo podman rm -f minibank-otelcol; sudo rm /etc/minibank/otelcol.env /etc/minibank/otelcol.yaml.

> [!TIP]
> **Beginner tip**
>
> For a production pilot, pin the collector to a fixed version instead of latest, and run it where your existing collectors run.

## 17.10 Balance top-up on APP-SQL

Why: QRIS payments leave the bank (the money goes to merchants), so at 30 operations per minute each demo customer loses about IDR 19 million per hour. With the seed balances of version 1.2, SITI.RAHAYU (IDR 95.3 million in total) runs out after about 4 to 6 hours; from then on payments fail with Insufficient balance at random. Topping up to the seed balances every 7 hours, or even every 4 hours, is not enough (modelled).

What: the scheduled task minibank-topup on APP-SQL runs topup-demo-balances.ps1 at 00:00, 06:00, 12:00 and 18:00 WIB. These fixed times are kept clear of the usual demo slots, and a run that was missed while the VM was off starts when it is back. The task runs as SYSTEM, which is a SQL Server sysadmin through BUILTIN\Administrators (Chapter 14.1). The top-up SETS the six balances to fixed targets; it does not add money:

| Account | Customer | Product | Target balance (IDR) |
|---|---|---|---|
| 9901000011 | ANDI.WIJAYA | Tabungan | 250,000,000 |
| 9901000012 | ANDI.WIJAYA | Giro | 15,250,000 |
| 9901000021 | SITI.RAHAYU | Tabungan | 250,000,000 |
| 9901000022 | SITI.RAHAYU | Giro | 7,800,000 |
| 9901000031 | BUDI.SANTOSO | Tabungan | 250,000,000 |
| 9901000032 | BUDI.SANTOSO | Giro | 32,400,000 |

With these targets and a top-up every 6 hours, the lowest customer total stayed above about IDR 100 million in a one-week model.

Step 1. Copy the scripts to APP-SQL. A lab built with the version 1.3 pack already has them in C:\Build\minibank\scripts (Chapter 11.4); a lab built with an older pack needs this copy from the host.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
foreach ($f in 'topup-demo-balances.ps1', 'topup-demo-balances.sql', 'install-topup-task.ps1') {
  Copy-VMFile -Name APP-SQL -SourcePath "F:\Build\minibank\scripts\$f" -DestinationPath "C:\Build\minibank\scripts\$f" `
    -CreateFullPath -FileSource Host -Force }
```

Step 2. Install the task. The script registers minibank-topup, runs the top-up once and shows the log line.

> [!NOTE]
> **Where to run it**
>
> APP-SQL - PowerShell Direct (Chapter 5.6), signed in as Administrator. The prompt must start with [APP-SQL].

```powershell
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\install-topup-task.ps1
```

For other times, add the times in WIB to the same line, for example -HoursWib 1,7,13,19.

> [!TIP]
> **What you should see**
>
> A line that starts with minibank-topup: last run, with result 0, the next run and the VM time zone SE Asia Standard Time. Then the log line of the first top-up, for example 2026-11-11 12:00:01 OK 9901000011 123,456,000 -&gt; 250,000,000; ... with all six accounts.

The log is C:\BuildLog\topup.log on APP-SQL, one line per run: OK with the balance before and after for every account, or FAILED with the reason. To run the top-up by hand, for example 30 minutes before the demo (Chapter 18.1) or after a rehearsal (Chapter 20.1):

```powershell
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\topup-demo-balances.ps1
Get-Content C:\BuildLog\topup.log -Tail 4
```

Effects to know:

- The top-up only sets dbo.Accounts.Balance. The Transfers rows and the Oracle ledger are not touched, so the transaction history shows no top-up line. The statement has no running balance, so nobody sees the gap.
- The balances on screen jump at a top-up. Avoid 00:00, 06:00, 12:00 and 18:00 WIB during the demo, or change the times with -HoursWib.
- reset-demo-balances.sql (the seed balances of version 1.2) stays in the pack but is no longer used.

> [!WARNING]
> **If something goes wrong**
>
> A FAILED line in topup.log gives the reason. If SQL Server cannot be reached, check that the service MSSQLSERVER is Running (Chapter 14.1), then run the top-up by hand.

> [!CAUTION]
> **Be honest**
>
> The top-up is a lab shortcut, not a banking transaction: it changes the balances directly in SQL Server. Say so if the bank asks why the demo balances never run out.

---

[&larr; 16. Database-internal monitoring of Oracle and PostgreSQL](16-database-internal-monitoring-of-oracle-and-postgresql.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [18. Rehearsal &rarr;](18-rehearsal.md)
