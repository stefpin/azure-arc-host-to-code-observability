# 39. Look-ahead: what will need attention next (version 2.1)

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


The cross-layer board of Part G answers what is wrong now. Version 2.1 adds a board that answers what will need attention next, before customers feel it. It looks through four lenses: Capacity (trends towards a limit), Calendar (dates that expire), Posture (known weaknesses) and Service (the error budget of the business transactions), and it puts every risk in one register with the days left, the impact, the action and the owner. It shows the risks; it fixes nothing. The lab owner agreed decisions 3 to 11 of the plan at 21:40 WIB on 16 November 2026 and gave the go at 22:09 WIB: the full plan, built lighter parts first, with no impact on the existing demo and changes only in rg-appmon-openshift-demo and its managed resource group. It was built and checked on 17 November 2026, after the card 6 session.

## 39.1 Decisions

| Topic | Decision (16 November 2026) |
|---|---|
| Scope and order | The full plan, with the lighter parts built first: the risk register, capacity and calendar, then the service budget, posture and the prediction scorecard. |
| Where it is shown | A new, separate workbook MiniBank - Look-ahead and a new Grafana board MiniBank - Look-ahead. The existing boards and workbook are not changed. |
| Name on screen | Look-ahead. |
| Collector | A read-only script on HV-HOST-02: every hour for capacity, once a day for dates, posture and the forecast. It pauses while a lab drill runs. |
| VM disk and network figures | Read by the collector inside the VMs; no new data collection rule for the VMs. |
| Registry tokens | Entered by hand as fixed dates, because the registry does not report token expiry to Azure Monitor. |
| Targets and status rules | 99.5 % of the business transactions succeed and 95 % finish under 1 second. Act: a limit or a date within 7 days, or a break as soon as one part fails. Watch: within 30 days, or a known weakness. |
| Tests | Lab tests count as drills: their minutes are left out of trends, baselines and the error budget. |
| Show, not fix | Weaknesses are shown, not repaired. No Defender sensor is installed on OpenShift. |
| Registry push token | minibank-push lapses on 17 November 2026 at 20:48 WIB by design; no image pushes are planned. |
| Documents | This chapter, Scene 7D and the card 6 session in Chapter 38.7 (runbook version 2.1). |
| Boundary | Changes only in rg-appmon-openshift-demo and its managed resource group, with no impact on the existing demo. |

## 39.2 What was built

Every item is new; no existing item was changed. The plan estimated the new data at about 0.03 GB a month in law-appmon, under US$0.10.

| Item | Name | Where | What it does |
|---|---|---|---|
| Table | MiniBankLookahead_CL (15 columns, Analytics plan, 30 days) | law-appmon | The collector's rows: capacity readings, dates, weaknesses, forecasts and one record per run. |
| Upload rule | dcr-minibank-lookahead (direct, stream Custom-MiniBankLookahead) | rg-appmon-openshift-demo | Receives the rows through the Logs Ingestion API. Its diagnostic setting la-dcr-errors writes upload errors to the table DCRLogErrors. |
| Permission | Monitoring Metrics Publisher for the managed identity of HV-HOST-02 | dcr-minibank-lookahead only | The host may send rows to this rule and to no other. |
| Functions | MiniBankDrills, MiniBankDrillMinutes, MiniBankLaReadings, MiniBankErrorBudget, MiniBankLookahead, MiniBankLaDaily, MiniBankLaForecast, MiniBankLaScore | law-appmon (saved searches minibank-la-\*) | Drill windows, capacity readings, the error budget, the risk register, the daily figures, the forecast and the scorecard. |
| Workbook | MiniBank - Look-ahead | rg-appmon-openshift-demo | The register and the four lenses in six tabs. |
| Grafana board | MiniBank - Look-ahead (address /d/minibank-lookahead) | amg-appmon, folder MiniBank | The same register and charts for the demo (Scene 7D). |
| Collector | F:\Build\tools\minibank-lookahead.ps1 (version 1.0) | HV-HOST-02 | Reads the figures and sends the rows; its files are in C:\ProgramData\MiniBank\lookahead. |
| Scheduled task | minibank-lookahead (SYSTEM, every hour at minute 5, at most 20 minutes) | HV-HOST-02 | Runs the collector; the daily part runs in the first run from 10:00 WIB. |

## 39.3 How the data is collected

The collector runs as SYSTEM on HV-HOST-02 every hour at minute 5 and takes about 10 to 20 seconds. It only reads: nothing on the VMs, the databases or OpenShift is changed. It skips a run while a lab drill is in progress (a test series, a labelled pair or a mystery draw, as recorded in MiniBankMystery_CL) and while the switch file C:\ProgramData\MiniBank\lookahead\pause.on exists; the next run reads the figures again. Each run appends its rows to rows-&lt;date&gt;.jsonl and one line to collector.log in C:\ProgramData\MiniBank\lookahead, then sends the rows through the upload rule with the host's managed identity.

| When | What | How it is read |
|---|---|---|
| Every hour | HV-HOST-02: memory in use, drives, and the virtual CPUs and memory given to the running VMs | Windows and Hyper-V on the host |
| Every hour | APP-WIN and APP-SQL: memory, disks, network traffic, disk throughput and response time; the size of the SQL Server database and its log | PowerShell Direct into the VMs |
| Every hour | APP-RHEL: memory, disks, network and disk figures; Oracle user data, the fullest tablespace, ledger rows, sessions and processes; PostgreSQL size, transaction ID age and connections | SSH with the lab key, then sqlplus and psql on APP-RHEL |
| Every hour | OpenShift: CPU and memory requests and pods per node, and the spare CPU and memory if one node fails | oc on HV-HOST-02 |
| Once a day | Dates: the end of the Windows evaluation, the expiry of the Oracle passwords and of the ingress certificate | The VMs, Oracle and OpenShift |
| Once a day | Posture: days since the last Windows or package update and since the last SQL Server full backup; OpenShift operators, updates and deprecated API calls | The VMs, SQL Server and OpenShift |
| Once a day | The forecast for the next 24 hours of five figures (data into Log Analytics per day, business transactions per hour, host CPU P95, transfer pod memory, the fullest node disk) | The functions MiniBankLaDaily and MiniBankLaForecast |

Some figures need no collector because Azure Monitor already has them: the host CPU (the hypervisor counters of Chapter 37.2), the OpenShift node disks and the memory of the busiest transfer pod (Container insights), the data into Log Analytics per day (the Usage table) and the business transactions (AppRequests). These have readings since 13 November 2026, so they show a trend from the first day.

## 39.4 The risk register

MiniBankLookahead() returns one row per risk with the columns Status, Lens, Area, Resource, Item, Now, Limit, DaysLeft, Impact, Action, Owner and Basis. It is sorted by status (Act, Watch, Planned, OK, Info) and then by the days left. The status follows fixed rules:

| Status | When | Example on 17 November 2026 |
|---|---|---|
| Act | A limit or a date is reached within 7 days; a room-left figure, such as the spare CPU if one OpenShift node fails, is at or below zero; a weakness rated high is over its limit; an error budget is used up or runs out within 7 days. | None. |
| Watch | Within 30 days; at 90 % of a limit or more; a room-left figure at its warning level; a known weakness over its limit; less than 25 % of an error budget left; no collector run for more than 2 hours. | ocp-node-3 node disk 61.03 % used, 85 % in about 10.7 days; the registry pull token, due on 10 December 2026 at 20:17 WIB. |
| Planned | Known and accepted, entered by hand. | The registry push token, which lapses on 17 November 2026 at 20:48 WIB by design. |
| OK | Has a limit, and nothing reaches it within 30 days. | Data into Log Analytics 5.88 GB a day against the daily cap of 10 GB. |
| Info | Context only: no limit, or a note such as the 30-day retention of the lab data. | Ledger rows, network traffic, the oldest lab data ageing out from 10 December 2026. |

Capacity rows fit a straight line through the readings of up to 7 days (never before 13 November 2026 14:00 WIB; the minutes of each drill and 5 minutes after it are left out) and divide the room left by the daily growth. A trend needs at least 1 day of history and at least 6 readings (3 for a figure counted per day). Until then the row says Too little history for a trend yet and is judged on its current value only. Calendar rows count the days to the date. Posture rows compare a figure with its limit, for example at most 35 days since the last update or at most 1 day since the last full backup.

## 39.5 The board and the workbook

The Grafana board MiniBank - Look-ahead opens with the same logo header as the other boards of the demo. Below it come six sections:

- Look-ahead: Risks by status, one count per status in the status colours, and the risk register.
- Capacity trends over the last 7 days, with the limit as a dashed red line: host CPU busy (P95 per hour), OpenShift CPU requests per node, data into Log Analytics per day, the memory of the busiest transfer pod, disk used on the VMs and the OpenShift nodes, and the spare CPU if one OpenShift node fails.
- Calendar: since version 2.5 the Look-ahead trail and the month view with fast-forward (Chapter 43); the Expiry dates table with the days left, the impact and the action is in the collapsed row Calendar details: expiry dates table (click to open) below them.
- Service budget: the error budget left, the budget details and the failed and slow business transactions per hour.
- Posture: the weaknesses found by the collector and, from Azure Resource Graph, the open Defender for Cloud findings, the Azure Advisor recommendations and the non-compliant Azure Policy results of the demo resource group.
- Prediction scorecard: the hit rate and the forecast checks.

Version 2.2 (Chapter 40): the Look-ahead radar now sits above these sections, directly under the logo header, and the Service budget section has two more panels for the speed item. The workbook has three more items on its Service budget tab.

Version 2.5 (Chapter 43): the Calendar section now shows the trail and the month view, and the board has one setting at the top, Look ahead to, that moves both panels to a later date. The radar, the tiles and the register stay on today; the workbook is unchanged.

The workbook MiniBank - Look-ahead shows the same content in six tabs: Capacity, Calendar, Service budget, Posture, Prediction scorecard and Collector (the last runs and what they sent). Both read only the eight functions and the tables named above.

> [!NOTE]
> **Where to run it**
>
> Grafana: Microsoft Edge on your own computer &gt; amg-appmon (https://&lt;GRAFANA_HOST&gt;) &gt; Dashboards &gt; folder MiniBank &gt; MiniBank - Look-ahead (address /d/minibank-lookahead), time range Last 7 days, refresh every 15 minutes. Workbook: Azure Portal &gt; rg-appmon-openshift-demo &gt; MiniBank - Look-ahead (type Azure Workbook).

## 39.6 The service budget and the prediction scorecard

The service budget looks at the business transactions of minibank-api (/api/transfer, /api/qris/pay and /statement) over the last 7 days, never before 13 November 2026 14:00 WIB, with the drill minutes left out. A transaction fails when it returns HTTP 5xx and is slow when it takes more than 1 second. The budget is the number of failed (0.5 %) or slow (5 %) transactions that the target allows. The board shows how much of it is left, the burn rate of the last 24 hours (1.0 means the budget is used exactly at the allowed pace) and the days until it would run out. Less than 25 % left, or running out within 30 days, is Watch; used up or running out within 7 days is Act.

| Target | Actual (7 days) | Budget left | Burn rate, last 24 hours | Status |
|---|---|---|---|---|
| 99.5 % succeed | 99.94 % | 88.3 % | 0.13 | OK |
| 95 % under 1 second | 98.32 % | 66.4 % | 0.36 | OK |

Read at about 11:40 WIB on 17 November 2026.

The prediction scorecard keeps the board honest. Every day, in the first run from 10:00 WIB, the collector saves a forecast for the next 24 hours of five figures: data into Log Analytics per day, business transactions per hour (drills left out), host CPU busy (P95), the memory of the busiest transfer pod and the fullest OpenShift node disk. Each forecast follows the trend line through up to 7 earlier complete days (at least 3), with a band of plus or minus 15 % or 2 standard errors, whichever is wider. The next day the scorecard checks whether the actual figure fell inside the band (Hit) or not (Miss). Back-tests apply the same method to past days and are labelled as such. On 17 November 2026 the back-tests gave 4 hits out of 4; the first live check is due on 18 November 2026 at about 10:00 WIB.

Version 2.2 adds a sixth item, the business transactions P95, from 18 November 2026 (Chapter 40.2).

## 39.7 The register on 17 November 2026

Read at about 11:40 WIB, with the first collector rows included: 72 rows, of which 0 Act, 6 Watch, 1 Planned, 52 OK and 13 Info. The rows that are not OK or Info, and a few OK rows for scale:

| Status | Resource | Item | Now | Limit or due | Days left |
|---|---|---|---|---|---|
| Watch | ocp-node-3 | Node disk used | 61.03 % | 85 % | 10.7 |
| Watch | &lt;ACR_NAME&gt; | Image pull token expires | - | 10 Dec 2026 20:17 WIB | 23.4 |
| Watch | ocp-node-1 | Node disk used | 39.23 % | 85 % | 26.6 |
| Watch | SQL Server MiniBankDemo | Days since last full backup | 4.72 days | at most 1 day | - |
| Watch | APP-SQL | Days since last Windows update | 1,720 days | at most 35 days | - |
| Watch | APP-WIN | Days since last Windows update | 1,720 days | at most 35 days | - |
| Planned | &lt;ACR_NAME&gt; | Image push token expires | - | 17 Nov 2026 20:48 WIB | 0.4 |
| OK | law-appmon | Data into Log Analytics per day | 5.88 GB | 10 GB | 88.7 |
| OK | minibank-transfer | Memory used, busiest pod | 490 MB | 768 MB | 98.2 |
| OK | Oracle FREEPDB1 | Password expires: MINIBANK and MINIBANK_MON | - | 9 May 2027 | 173.4 |
| OK | APP-SQL and APP-WIN | Windows evaluation ends | - | 10 May 2027 | 174 |
| OK | arc-ocp-minibank | Ingress certificate expires | - | 9 Nov 2028 19:59 WIB | 723.3 |
| OK | Oracle FREEPDB1 | Oracle user data | 82 MB | 12,288 MB | - |

The Windows update and backup rows are weaknesses the lab keeps on purpose (show, not fix). The node disk rows come from Container insights with readings since 13 November, so they already have a trend; most collector rows say Too little history for a trend yet until about 18 November 2026.

Version 2.2 adds the speed row (Business transactions P95, Watch), so the register has 73 rows and Watch reads 7. The push token lapsed at 20:48 WIB on 17 November 2026 as planned and stays Planned with 0 days left; the radar shows it in its centre (Chapters 40.2 and 40.3).

## 39.8 Safety and the no-impact checks

Before anything was created, a read-only fingerprint of the existing demo was taken: every saved function with a checksum of its query (42, including rules v2.10 in MiniBankRootCause), the workbooks, the 9 upload rules, the custom tables, the alert rules, action groups and processing rules, every Grafana board with its version and a checksum of its panels (51), and the roles of the host identity. HV-HOST-02 was fingerprinted as well: the demo scripts, the scheduled tasks, the VMs, the switch files and the last verdict readings.

The same check ran after the new items were created (09:37 WIB) and again after the last fixes (11:45 to 12:10 WIB), together with the Azure activity log of the three resource groups since 08:55 WIB:

| What was checked | Result after the build |
|---|---|
| Saved functions | 42 existing functions unchanged, rules v2.10 included; 8 new Look-ahead functions. |
| Workbooks | MiniBank - SLA and Failure Rate unchanged (last saved on 16 November 2026); 1 new workbook. |
| Upload rules and custom tables | 9 existing rules and 3 existing tables unchanged; 1 new rule and 1 new table. |
| Alert rules, action groups and processing rules | 6, unchanged. |
| Grafana boards | 51 existing boards unchanged and none saved since 08:55 WIB (Cross-layer root cause still version 12); 1 new board. |
| Roles of the host identity | 4 existing roles unchanged; 1 new role, on the new upload rule only. |
| HV-HOST-02 | Demo scripts, tasks, VMs and switch files unchanged; the only files written that day were the collector and the card 6 runner; the last readings Healthy and no observer error. |
| Activity log since 08:55 WIB | rg-appmon-openshift-demo: every change by the lab account was a new Look-ahead item or a run command on HV-HOST-02; the other writes were the routine heartbeats of the Arc agent. MA_amw-appmon_indonesiacentral_managed: no change. rg-hyperv-arc-monitor-demo: only its own automation and Arc SQL inventory updates, nothing by the lab account. |

Result: the existing demo is unchanged. The collector only reads, and the host identity can send rows only to the new upload rule.

## 39.9 Operating it

Check that the collector runs: the register row Look-ahead collector last run must read less than 2 hours ago, and the Collector tab of the workbook lists the last runs. On HV-HOST-02 the log has one line per run (time, run, seconds, rows, sent or not, and what was read):

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02, in the Bastion session: PowerShell (Admin), after the start block of Chapter 5.5.

```powershell
Get-ScheduledTaskInfo -TaskName minibank-lookahead | Select-Object LastRunTime, LastTaskResult, NextRunTime
Get-Content C:\ProgramData\MiniBank\lookahead\collector.log -Tail 5
```

Quiet switch: the first line below pauses the collector, for example for a whole demo session, and the second line resumes it. A skipped hour is simply missing from the trends; the next run reads the figures again.

```powershell
New-Item C:\ProgramData\MiniBank\lookahead\pause.on -ItemType File
Remove-Item C:\ProgramData\MiniBank\lookahead\pause.on
```

Run it once by hand: -NoUpload keeps the rows on the host (C:\ProgramData\MiniBank\lookahead\rows-&lt;date&gt;.jsonl) without sending them, and -Daily runs the daily part as well.

```powershell
& F:\Build\tools\minibank-lookahead.ps1 -NoUpload -Daily
```

If rows do not arrive although the log says sent, look at the metrics of dcr-minibank-lookahead (rows received and transformation errors) and at the table DCRLogErrors in law-appmon, which the diagnostic setting la-dcr-errors fills (Chapter 39.10, lessons). The Act and Watch rows of the register in Log Analytics:

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankLookahead()
| where Status in ('Act', 'Watch')
| project Status, Lens, Resource, Item, Now, Limit, DaysLeft, Action, Owner
```

## 39.10 Build record, lessons, open items and undo

| Time (WIB) | What happened |
|---|---|
| 13 Nov 20:11-20:35 | The Outlook board, later called Look-ahead, first advised: four lenses, a risk register and a prediction scorecard. |
| 16 Nov 21:15 | Plan advised again after the readiness tests: the full plan 11.5 to 17.25 hours, the lighter version 7 to 10.25 hours, new data estimated at under US$1 a month. |
| 16 Nov 21:40 | Decisions 3 to 11 agreed (Chapter 39.1); the demo is this week, date not fixed. |
| 16 Nov 22:09 | Go: work overnight on the full plan with the lighter parts first, changes only in rg-appmon-openshift-demo and its managed resource group, no impact on the existing demo. |
| 16 Nov 22:12 - 17 Nov 05:18 | The overnight build did not take place: the working session was disconnected. Nothing was changed. |
| 17 Nov 08:26-08:55 | While the card 6 draws ran: the eight functions, the collector with its install, check and undo scripts and the builders of the workbook and the board were written and checked, without touching the lab. |
| 17 Nov 09:00-09:15 | Read-only fingerprint of the existing demo and of HV-HOST-02 (Chapter 39.8). |
| 17 Nov 09:15-09:19 | Every query tested once against a stand-in table: two test-query errors (a reserved word) fixed and two small query changes; the second test had no problem. |
| 17 Nov 09:19-09:25 | New items created: the table, the upload rule, the permission, the eight functions, the workbook and the Grafana board. Collector copied to HV-HOST-02, dry run (56 rows, nothing sent) and scheduled task registered at 09:25. |
| 17 Nov 09:25-10:16 | The first sends failed: first on a PowerShell list quirk (fixed at 09:33), then the upload rule dropped every batch (transformation errors). |
| 17 Nov 09:37 | No-impact check after the creation: the existing demo unchanged. |
| 17 Nov 09:48-10:20 | Board version 2 (readable status counts) and the status colours of the workbook; every function and every panel query verified. Diagnostic setting la-dcr-errors added to the new upload rule at 10:14. |
| 17 Nov 10:39 | Cause of the dropped batches found and fixed (lessons below); 66 rows sent and stored. |
| 17 Nov 11:05 | First scheduled run with the fixed collector: 48 rows sent. |
| 17 Nov 11:45-12:10 | Final no-impact check after the last fixes: the existing demo unchanged (Chapter 39.8). Runbook version 2.1 written. |

Lessons:

- Windows PowerShell 5.1 turns an array passed to ConvertTo-Json -InputObject into {"value":[...],"Count":n}. The upload rule then saw one record without TimeGenerated and dropped the whole batch: its metrics showed the API call and a transformation error, but no rows received. The collector now converts each row on its own and joins them into one JSON array, as the verdict observer already did.
- When uploads do not arrive, look first at the metrics of the upload rule (API calls received, rows received, transformation errors) and at its LogErrors diagnostic setting.
- Writing the queries, scripts and board definitions during the card 6 draws, and testing every query against a stand-in table before creating anything, kept the lab untouched until the build step.

Open items:

- First live forecast check on 18 November 2026 at about 10:00 WIB; until then the scorecard shows back-tests only.
- The collector's own figures have readings only since 17 November 2026, so their rows say Too little history for a trend yet until about 18 November.
- Renew the registry pull token minibank-pull before 10 December 2026 20:17 WIB (Watch). The push token minibank-push lapsed on 17 November 2026 at 20:48 WIB by design (Planned; the radar shows it in its centre).
- The diagnostic setting la-dcr-errors can be removed when it is no longer needed; it is deleted together with the upload rule.
- Update the table of contents in desktop Word: References &gt; Update Table &gt; Update entire table.
- Optional, later: an alert when a register row turns Act.

How to undo version 2.1, in this order (each step only if you want that part back; no existing item needs to be restored):

| Step | What to do |
|---|---|
| 1 | Collector on HV-HOST-02: Unregister-ScheduledTask -TaskName minibank-lookahead -Confirm:$false, then delete F:\Build\tools\minibank-lookahead.ps1 and the folder C:\ProgramData\MiniBank\lookahead. |
| 2 | Grafana: delete the board MiniBank - Look-ahead (Dashboard settings &gt; Delete), or az grafana dashboard delete -g rg-appmon-openshift-demo -n amg-appmon --dashboard minibank-lookahead. |
| 3 | Workbook: Azure Portal &gt; rg-appmon-openshift-demo &gt; MiniBank - Look-ahead &gt; Delete. |
| 4 | Functions: delete the eight saved searches minibank-la-\* of law-appmon (az monitor log-analytics workspace saved-search delete -g rg-appmon-openshift-demo --workspace-name law-appmon -n &lt;name&gt;). |
| 5 | Permission: az role assignment delete --assignee &lt;HOST_IDENTITY_PRINCIPAL_ID&gt; --role "Monitoring Metrics Publisher" --scope &lt;resource ID of dcr-minibank-lookahead&gt;. |
| 6 | Upload rule: az monitor data-collection rule delete -g rg-appmon-openshift-demo -n dcr-minibank-lookahead (the diagnostic setting la-dcr-errors goes with it). |
| 7 | Table: az monitor log-analytics workspace table delete -g rg-appmon-openshift-demo --workspace-name law-appmon -n MiniBankLookahead_CL. |
| 8 | Runbook: skip Scene 7D (the session is 5 minutes shorter since version 2.5). The card 6 session needs no undo of its own: its runner and task are covered by step 5 of the version 2.0 undo table. |

---

[&larr; 38. Version 2.0: the Mystery control window, the approved grading and the readiness tests](38-version-2-0-the-mystery-control-window-the-approved-grading.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [40. Look-ahead radar and the speed item (version 2.2) &rarr;](40-look-ahead-radar-and-the-speed-item-version-2-2.md)
