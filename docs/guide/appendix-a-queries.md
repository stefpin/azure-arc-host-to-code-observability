# Appendix A. Queries

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


Run the KQL queries in the Azure Portal: open **law-appmon**, click **Logs**, switch the editor to **KQL mode** if it opens in simple mode, paste the query, set the time range to **Set in query** and click **Run**. All times in results are UTC (WIB minus 7 hours). The same queries are in the source pack file monitoring\kql\minibank-queries.kql. Since version 1.4 every step that uses a query also prints it, so this appendix is the full collection for reference.

## A.1 Telemetry arrives from every service

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
union AppRequests, AppDependencies, AppExceptions, AppPageViews, AppAvailabilityResults
| where TimeGenerated > ago(30m)
| summarize Items = count(), Last = max(TimeGenerated) by Table = Type, AppRoleName
| order by AppRoleName asc, Table asc
```

## A.2 Technical failure rate and business declines per business transaction, 5-minute steps

Technical failures are result codes 500 and higher; business declines are result code 409 (Chapter 4.4).

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppRequests
| where TimeGenerated > ago(1h) and AppRoleName == "minibank-api" and Name startswith "POST /api/"
| summarize Total = count(), TechnicalFailed = countif(toint(ResultCode) >= 500), Declines = countif(ResultCode == "409")
            by bin(TimeGenerated, 5m), Name
| extend TechnicalFailedPct = round(100.0 * TechnicalFailed / Total, 2)
| order by TimeGenerated desc, Name asc
```

## A.3 Availability from the probe (SLA)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppAvailabilityResults
| where TimeGenerated > ago(24h)
| summarize Runs = count(), Passed = countif(Success == true) by Name
| extend AvailabilityPct = round(100.0 * Passed / Runs, 3)
```

## A.4 Latency percentiles per transaction

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppRequests
| where TimeGenerated > ago(1h) and AppRoleName == "minibank-api"
| summarize Calls = count(), P50 = percentile(DurationMs, 50), P95 = percentile(DurationMs, 95),
            P99 = percentile(DurationMs, 99) by Name
| order by P95 desc
```

## A.5 Slowest and failing dependencies

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppDependencies
| where TimeGenerated > ago(30m)
| summarize Calls = count(), AvgMs = round(avg(DurationMs), 0), P95 = round(percentile(DurationMs, 95), 0),
            Failed = countif(Success == false) by AppRoleName, DependencyType, Target
| order by P95 desc
```

## A.6 Exceptions by service

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppExceptions
| where TimeGenerated > ago(30m)
| summarize Count = count(), Example = take_any(OuterMessage) by AppRoleName, ExceptionType
| order by Count desc
```

## A.7 One transaction by its Trace ID

Replace &lt;TRACE-ID&gt; with the 32-character Trace ID shown on the MiniBank failure screen.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
let tid = "<TRACE-ID>";
union AppRequests, AppDependencies, AppExceptions, AppTraces
| where OperationId == tid
| project TimeGenerated, Type, AppRoleName, AppRoleInstance, Name, Target, DurationMs, Success, ResultCode
| order by TimeGenerated asc
```

## A.8 Requests handled by each transfer pod (and no health checks)

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

## A.9 OpenShift node status

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
KubeNodeInventory
| where TimeGenerated > ago(15m)
| summarize arg_max(TimeGenerated, Status, KubeletVersion) by Computer
| project Computer, Status, KubeletVersion, LastSeen = TimeGenerated
| order by Computer asc
```

## A.10 Nodes that are not ready (used by alert alr-ocp-node-not-ready)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
KubeNodeInventory
| where TimeGenerated > ago(5m)
| summarize arg_max(TimeGenerated, Status) by Computer
| where Status != "Ready"
```

## A.11 MiniBank pods and the node they run on

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
KubePodInventory
| where TimeGenerated > ago(10m) and Namespace == "minibank"
| summarize arg_max(TimeGenerated, PodStatus, Computer, PodRestartCount) by Name
| project Pod = Name, Node = Computer, PodStatus, PodRestartCount
```

## A.12 Recent log lines of the transfer service

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
ContainerLogV2
| where TimeGenerated > ago(15m) and PodNamespace == "minibank"
| project TimeGenerated, PodName, LogMessage
| order by TimeGenerated desc
| take 50
```

## A.13 Container log volume by namespace

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
ContainerLogV2
| where TimeGenerated > ago(1h)
| summarize MB = round(sum(_BilledSize) / 1024.0 / 1024.0, 2) by PodNamespace
| order by MB desc
```

## A.14 Latest database snapshot (Route A)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(10m)
| summarize arg_max(TimeGenerated, Value, Detail, Computer) by DbEngine, SnapshotType, Name
| order by DbEngine asc, SnapshotType asc, Value desc
```

## A.15 Top SQL statements by average time per execution (Route A)

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(10m) and SnapshotType == "topsql"
| summarize arg_max(TimeGenerated, Value, Detail) by DbEngine, Name
| project DbEngine, SqlId = Name, AvgMsPerExecution = round(Value, 1), SqlTextAndExecutions = Detail
| order by AvgMsPerExecution desc
| take 20
```

## A.16 Wait events, and the link to slow Oracle calls (Route A)

Oracle: seconds waited per wait event during the last hour (the value is cumulative, so the query takes the difference).

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(1h) and DbEngine == "Oracle" and SnapshotType == "waits"
| summarize SecondsWaited = round(max(Value) - min(Value), 2) by WaitEvent = Name
| order by SecondsWaited desc
| take 15
```

PostgreSQL: sessions per wait event type over time (slow-postgres shows as Timeout).

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(1h) and DbEngine == "PostgreSQL" and SnapshotType == "waits"
| summarize Sessions = max(Value) by WaitEventType = Name, bin(TimeGenerated, 1m)
| render timechart
```

Database view next to application view: seconds slept in the Oracle wait event PL/SQL lock timer next to the slow Oracle calls that Application Insights saw from minibank-transfer (use it during the slow-oracle scenario).

```kusto
let sleeps = MiniBankDbSnap_CL
| where TimeGenerated > ago(3h) and DbEngine == "Oracle" and SnapshotType == "waits" and Name == "PL/SQL lock timer"
| order by TimeGenerated asc
| extend Delta = Value - prev(Value)
| where Delta >= 0
| summarize SleepSeconds = sum(Delta) by bin(TimeGenerated, 5m);
let slowCalls = AppDependencies
| where TimeGenerated > ago(3h) and AppRoleName == "minibank-transfer" and DurationMs > 1500
| where DependencyType == "oracle.db" or Target has "FREEPDB1"
| summarize SlowOracleCalls = sum(ItemCount) by bin(TimeGenerated, 5m);
sleeps
| join kind=fullouter slowCalls on TimeGenerated
| project TimeGenerated = coalesce(TimeGenerated, TimeGenerated1), SleepSeconds, SlowOracleCalls
| render timechart
```

## A.17 IIS log lines by URL (ingestion filter check)

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

## A.18 Billable data by table (cost check)

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

## A.19 Technical failure rate over the last 5 minutes (used by alert alr-minibank-failure-rate-high)

Only technical failures count (result code 500 or higher); business declines do not (Chapter 4.4).

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppRequests
| where TimeGenerated > ago(5m) and AppRoleName == "minibank-api" and Name startswith "POST /api/"
| summarize Total = count(), Failed = countif(toint(ResultCode) >= 500)
| extend FailureRatePct = iff(Total == 0, 0.0, 100.0 * Failed / Total)
| where Total >= 5 and FailureRatePct > 2
```

## A.20 PromQL queries (Prometheus explorer in amw-appmon, or Grafana)

Paste one query at a time. Lines that start with # are explanations; do not paste them.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: amw-appmon &gt; open the Azure Monitor workspace &gt; Prometheus explorer (left menu, under Monitoring or at the top level, depending on the Portal version). Paste one query line, not the lines that start with #, into the PromQL box, choose the time range and click Run query; switch to Graph for a chart. Grafana alternative: Explore (compass icon), data source AMW appmon, Code, Run query.

```text
# OpenShift nodes that are Ready (3, or 4 after Scene 11)
sum(kube_node_status_condition{condition="Ready",status="true"})
 
# CPU percent per node
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))
 
# Ready copies of minibank-transfer (3 in normal operation)
sum(kube_deployment_status_replicas_available{namespace="minibank",deployment="minibank-transfer"})
 
# Pod restarts in project minibank
sum by (pod) (kube_pod_container_status_restarts_total{namespace="minibank"})
 
# The two exporters are reachable (1 = up)
up{job=~"minibank-.*"}
 
# Oracle is up, Oracle sessions, Oracle executions per second
max(oracledb_up)
sum by (status, type) (oracledb_sessions_value)
rate(oracledb_activity_execute_count[5m])
 
# Oracle wait time for user I/O and for commit
oracledb_wait_time_user_io
oracledb_wait_time_commit
 
# PostgreSQL is up, connections to database minibank, locks by mode
max(pg_up)
pg_stat_database_numbackends{datname="minibank"}
sum by (mode) (pg_locks_count{datname="minibank"})
```

The kube_\* and node_\* metrics above are part of the default (minimal) ingestion profile of the managed Prometheus agent, so no extra setting is needed for them.

## A.21 Business declines per hour

Business declines (result code 409, Insufficient balance) of the last 24 hours. The continuous traffic makes about 4 per hour; the alert alr-minibank-decline-spike counts these declines over 15 minutes (Chapter 17.5).

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppRequests
| where TimeGenerated > ago(24h) and AppRoleName == "minibank-api" and ResultCode == "409"
| summarize Declines = count() by bin(TimeGenerated, 1h)
| render columnchart
```

## A.22 Latest business declines with trace ID

Paste an OperationId into Appendix A.7 to see the whole transaction of that decline.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppRequests
| where TimeGenerated > ago(24h) and AppRoleName == "minibank-api" and ResultCode == "409"
| project TimeGenerated, Name, DurationMs, OperationId
| top 20 by TimeGenerated desc
```

## A.23 Dependency types of the transfer service (oracle.db check)

Since Chapter 15.2 Step 3 the Oracle calls carry the type oracle.db; calls recorded before that change keep the type SQL.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppDependencies
| where TimeGenerated > ago(15m) and AppRoleName == "minibank-transfer"
| summarize Calls = sum(ItemCount), Last = max(TimeGenerated) by DependencyType, Target
| order by Last desc
```

---

[&larr; 22. Daily operations, cost and removal](22-daily-operations-cost-and-removal.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [Appendix B. Contents of the source pack &rarr;](appendix-b-contents-of-the-source-pack.md)
