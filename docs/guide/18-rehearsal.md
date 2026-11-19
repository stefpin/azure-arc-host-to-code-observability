# 18. Rehearsal

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


> [!NOTE]
> **Approval Gate**
>
> G8 for the disruptive scenes (node power-off, drain, adding the fourth worker). Rehearse the day before the demo, never on the same morning.

## 18.1 Rehearsal timeline

| When | What to do | Where |
|---|---|---|
| T minus 26 hours or earlier | OpenShift has been installed for more than 24 hours, so the first certificate rotation is finished | Chapter 12 |
| T minus 24 hours | Take an etcd backup (Chapter 12.7) and check the health checklist in 18.2 | HV-HOST-02 |
| T minus 23 hours | Check the continuous traffic: the task minibank-traffic is Running and the last lines of C:\BuildLog\traffic.log show ok about 30 and failed=0 (Chapter 17.1). Check that C:\BuildLog\topup.log on APP-SQL shows OK lines (Chapter 17.10). The traffic runs all the time, so there is nothing to start | HV-HOST-02, APP-SQL |
| T minus 22 hours | Run Scenes 0 to 15 once, in order, with a stopwatch. Start the incident window only during Scene 6. Reset after each disruptive scene (Chapter 20) | All windows |
| T minus 20 hours | Stage the fourth worker again for the real demo (Chapter 20.4) | HV-HOST-02, Red Hat console |
| T minus 2 hours | Health checklist again; open all browser tabs (Chapter 19.1) | Your computer, HV-HOST-02 |
| T minus 30 minutes | Run the top-up by hand: topup-demo-balances.ps1 on APP-SQL (Chapter 17.10) | APP-SQL |

## 18.2 Acceptance checklist

Every line must be true before the demo. If one is false, use Chapter 21 before the session.

| Check | How to check | Expected |
|---|---|---|
| HV-HOST-02 running | Azure Portal, virtual machine HV-HOST-02, Overview | Status Running |
| Lab VMs running | HV-HOST-02 - PowerShell (Admin): Get-VM | OCP-NODE-1 to 3, APP-WIN, APP-RHEL, APP-SQL Running; OCP-NODE-4 Running and discovered (Chapter 12.8) |
| OpenShift healthy | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get nodes; oc get clusteroperators | 3 nodes Ready; all operators Available True, Degraded False |
| Arc connection | Azure Portal &gt; Azure Arc &gt; Kubernetes clusters &gt; arc-ocp-minibank | Status Connected |
| Kubernetes resources view | Azure Portal &gt; arc-ocp-minibank &gt; Kubernetes resources &gt; Workloads, namespace minibank (Chapter 13.4) | minibank-transfer 3 of 3, no Error (599) |
| Monitoring extensions | Azure Portal &gt; arc-ocp-minibank &gt; Settings &gt; Extensions | azuremonitor-containers and azuremonitor-metrics Installed (Succeeded) |
| MiniBank works | Microsoft Edge on HV-HOST-02: http://192.168.110.31:8080 | Log in as ANDI.WIJAYA, a normal transfer succeeds |
| Transfer service | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get pods -n minibank -o wide | 3 pods Running, one on each node; if two share a node, use Chapter 20.2 |
| Telemetry | Query A.1 (below the table) in the Azure Portal, law-appmon &gt; Logs | Rows for minibank-web, minibank-api, minibank-transfer, minibank-fraud in the last 30 minutes |
| Application Map | Azure Portal &gt; appi-minibank &gt; Application map | Four services, SQL Server, Oracle (192.168.110.32 \\| freepdb1), PostgreSQL |
| Oracle calls named oracle.db | Query A.23 (below the table) in the Azure Portal, law-appmon &gt; Logs | The type oracle.db for the target 192.168.110.32 \\| freepdb1 in the last 15 minutes |
| Probe | Query A.3 (below the table) in the Azure Portal, law-appmon &gt; Logs | Availability 100 percent in the last hour |
| Continuous traffic | HV-HOST-02 - PowerShell (Admin): Get-ScheduledTask minibank-traffic, minibank-probe; Get-Content C:\BuildLog\traffic.log -Tail 5 | Both tasks Running; the last lines show ok about 30 and failed=0 |
| Balance top-up | APP-SQL - PowerShell Direct (Chapter 5.6): Get-Content C:\BuildLog\topup.log -Tail 4 | OK lines from the last scheduled runs, no FAILED line |
| Container insights | Azure Portal &gt; arc-ocp-minibank &gt; Insights (page Monitor) &gt; Nodes | Three nodes with CPU and memory values |
| Prometheus | Grafana (amg-appmon) &gt; Dashboards &gt; MiniBank &gt; MiniBank - OpenShift and Databases | Nodes Ready 3, Oracle up 1, PostgreSQL up 1, all green |
| SLA dashboard | Grafana (amg-appmon) &gt; Dashboards &gt; MiniBank &gt; MiniBank - SLA and Failure Rate | The Business declines tile shows a few declines (about 4 per hour) in blue; the Success tile is green; the service weather strip at the top reads Sunny (Cloudy for up to 15 minutes after one stray technical failure, and a red budget bar within 24 hours of an incident rehearsal, are expected: Chapter 41.4) |
| Route A | Query A.14 (below the table) in the Azure Portal, law-appmon &gt; Logs | Snapshot rows from the last 5 minutes for Oracle and PostgreSQL |
| Alerts | Azure Portal &gt; Monitor &gt; Alerts | No open alerts before the demo starts (alr-minibank-failure-rate-high, alr-minibank-decline-spike, alr-ocp-node-not-ready and Failure Anomalies - appi-minibank); close old ones (Chapter 20.3) |
| Screens | Microsoft Edge on HV-HOST-02: the MiniBank screens | MiniBank wordmark on the white header bar, DEMO banner visible, English labels, EN/ID switch works |
| Browser robot (Priority 1) | APP-WIN - PowerShell Direct (Chapter 5.6): Get-Content C:\BuildLog\robot.log -Tail 5 | A journey every 2 minutes with result=success and mode=normal (Chapter 26) |
| OpenTelemetry collector and live onboarding (Priority 1) | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get pods -n minibank-otel; oc get deploy -n minibank; oc get deploy minibank-rates-copy -n minibank -o jsonpath='{.spec.template.metadata.annotations}' | otelcol 2 pods Running; minibank-transfer 3/3, minibank-rates 2/2 and minibank-rates-copy 1/1; the annotations of minibank-rates-copy do not contain instrumentation.opentelemetry.io/inject-java (after every rehearsal run onboard-reset.ps1, Chapter 20.1) |
| Incident command ready (Priority 1) | HV-HOST-02 - PowerShell (Admin): Get-Content C:\BuildLog\incident.log -Tail 2 | The last line is a finished or stopped window, not a running incident (Chapter 26.4) |
| Cross-layer board (version 1.7) | Grafana amg-appmon &gt; Dashboards &gt; MiniBank &gt; MiniBank - Cross-layer root cause | Status Healthy; Recovery banner No recovery in progress; a reading every 30 seconds in the verdict history |
| Verdict sources (version 1.7) | Query of Chapter 31.5 in the Azure Portal, law-appmon &gt; Logs | Seven sources, each with rows from the last 2 minutes |
| Fault command and morning history (version 1.7) | HV-HOST-02 - PowerShell (Admin) in F:\Build\minibank\scripts: .\fault.ps1 -Status and .\fault.ps1 -LeakCheck -Hours 6; the scorecard on the board | No active run; no giveaway word; the morning series and the pair RIGHT LAYER, no false alarm |
| Alert e-mail (version 1.7) | Azure Portal &gt; Monitor &gt; Alerts &gt; Action groups &gt; ag-appmon-email; Outlook | Enabled with the e-mail receiver alerts@example.com; the morning test alerts arrived as e-mails and are closed (Chapter 20.3) |
| Telemetry walkthrough (version 2.4) | Queries W1 (Scene 13A), W2 (Scene 13B) and W3 (Scene 13C) in the Azure Portal, law-appmon &gt; Logs; Azure Portal &gt; Monitor &gt; Data Collection Rules filtered to rg-appmon-openshift-demo | W1: minibank-api, minibank-fraud, minibank-probe, minibank-transfer and minibank-web; W2: minibank-rates from 2 pods; W3: eight tables, each with rows in the last hour; 10 rules in the list |
| Look-ahead trail and fast-forward (version 2.5) | Grafana amg-appmon &gt; Dashboards &gt; MiniBank &gt; MiniBank - Look-ahead: the heading Calendar: dates that will bite; click Fri 11 Dec at the top right of the trail, then Today, then Back to dashboard | The trail and the month view draw within half a minute with a grey TODAY line; Fri 11 Dec opens the trail on its own with the amber FAST-FORWARD banner and YOU WOULD BE HERE; Today brings it back; Look ahead to reads Today at the end |

The queries of this checklist, to run in law-appmon, **Logs**:

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

**Query A.3** - Availability from the probe (SLA)

```kusto
AppAvailabilityResults
| where TimeGenerated > ago(24h)
| summarize Runs = count(), Passed = countif(Success == true) by Name
| extend AvailabilityPct = round(100.0 * Passed / Runs, 3)
```

**Query A.14** - Latest database snapshot (Route A)

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(10m)
| summarize arg_max(TimeGenerated, Value, Detail, Computer) by DbEngine, SnapshotType, Name
| order by DbEngine asc, SnapshotType asc, Value desc
```

**Query A.23** - Dependency types of the transfer service (oracle.db check)

Since Chapter 15.2 Step 3 the Oracle calls carry the type oracle.db; calls recorded before that change keep the type SQL.

```kusto
AppDependencies
| where TimeGenerated > ago(15m) and AppRoleName == "minibank-transfer"
| summarize Calls = sum(ItemCount), Last = max(TimeGenerated) by DependencyType, Target
| order by Last desc
```

---

[&larr; 17. Traffic, dashboards, alerts and telemetry filtering](17-traffic-dashboards-alerts-and-telemetry-filtering.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [19. Demo scenes and talk track &rarr;](19-demo-scenes-and-talk-track.md)
