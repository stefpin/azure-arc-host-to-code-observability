# 16. Database-internal monitoring of Oracle and PostgreSQL

<sub>Part D - Build MiniBank, database monitoring, dashboards and alerts &nbsp;|&nbsp; [Guide index](README.md)</sub>


This chapter builds the two routes that the bank agreed for looking inside the databases:

|   | Route A - snapshots as logs | Route B - Prometheus metrics |
|---|---|---|
| What it collects | Every 60 seconds: sessions, wait events, top SQL statements, blocked sessions and ORA- errors from the Oracle alert log | Hundreds of standard database metrics from two well-known exporters: Oracle AI Database Metrics Exporter and postgres_exporter |
| How the data travels | A script writes JSON lines to a file; the Azure Monitor Agent on APP-RHEL (Azure Arc) sends them to the custom table MiniBankDbSnap_CL in law-appmon | The managed Prometheus agent that already runs on the Arc-enabled OpenShift cluster scrapes the exporters and writes to amw-appmon |
| How you look at it | KQL in Log Analytics, workbooks, log search alerts (Appendix A.14 to A.16, printed in Chapter 16.1) | PromQL in Prometheus explorer and Grafana (Appendix A.20, printed in Chapter 16.2) |
| Why it is useful | Shows WHICH SQL statement is slow and WHICH wait event is behind it | Shows trends and health over time with ready-made metrics |

> [!NOTE]
> **Approval Gate**
>
> G4 (custom table, data collection rule and association) and G5 (Prometheus scrape configuration on the cluster).

> [!TIP]
> **Beginner tip**
>
> Route B uses the cluster's own Prometheus agent to scrape the exporters on APP-RHEL. This avoids a separate Prometheus server and a separate Microsoft Entra application with a secret.

## 16.1 Route A: database snapshots to Log Analytics

Step 1. Install the snapshot job on APP-RHEL.

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

```bash
sudo mkdir -p /opt/minibank/dbsnap /var/log/minibank
cd ~/minibank/monitoring/route-a
sudo cp minibank-dbsnap.sh oracle-snap.sql pg-snap.sql /opt/minibank/dbsnap/
sudo chmod 750 /opt/minibank/dbsnap/minibank-dbsnap.sh
read -rsp 'Oracle MINIBANK_MON password: ' ORA_MON; echo
read -rsp 'PostgreSQL postgres_exporter password: ' PG_MON; echo
sed -e "s|<ORACLE-MON-PASSWORD>|$ORA_MON|" -e "s|<PG-EXPORTER-PASSWORD>|$PG_MON|" dbsnap.env.example \
  | sudo tee /etc/minibank/dbsnap.env > /dev/null
unset ORA_MON PG_MON
sudo chown root:root /etc/minibank/dbsnap.env && sudo chmod 600 /etc/minibank/dbsnap.env
sudo /opt/minibank/dbsnap/minibank-dbsnap.sh && sudo tail -n 5 /var/log/minibank/dbsnap.json
sudo cp minibank-dbsnap.service minibank-dbsnap.timer /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now minibank-dbsnap.timer
systemctl list-timers minibank-dbsnap.timer --no-pager
```

> [!TIP]
> **What you should see**
>
> Five lines that each start with {"TimeGenerated": and contain "DbEngine": "Oracle" or "DbEngine": "PostgreSQL". The timer list shows minibank-dbsnap.timer with a NEXT time less than a minute away.

> [!WARNING]
> **If something goes wrong**
>
> "cannot read the Oracle alert log" means the alert log path is different in your Oracle image. In APP-RHEL - Bash run sudo podman exec minibank-oracle bash -c 'ls /opt/oracle/diag/rdbms/\*/\*/trace/alert_\*.log', put the path it shows into ORACLE_ALERT_LOG in /etc/minibank/dbsnap.env (sudo vi /etc/minibank/dbsnap.env) and run the script again. ORA-01017 means a wrong MINIBANK_MON password. "password authentication failed for user postgres_exporter" means a wrong PostgreSQL password.

Step 2. Create the custom table MiniBankDbSnap_CL in law-appmon. Microsoft Learn asks you to create a table for JSON logs with a PowerShell REST call, so this step uses Invoke-AzRestMethod. The table must exist before the data collection rule in Step 3.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block (Chapter 5.4).

```powershell
Set-Location ~
if (-not (Test-Path ~/minibank)) { Write-Host 'Pack missing: upload and unzip it as in Chapter 10.6' }
Set-AzContext -Subscription $SUB | Out-Null
$LAWID = az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv
$table = Get-Content ~/minibank/monitoring/route-a/MiniBankDbSnap_CL.table.json -Raw
$r = Invoke-AzRestMethod -Method PUT -Path "$($LAWID)/tables/MiniBankDbSnap_CL?api-version=2022-10-01" -Payload $table
$r.StatusCode
```

> [!TIP]
> **What you should see**
>
> 200 or 202. After a minute, the Portal shows the table: law-appmon, Settings, Tables, MiniBankDbSnap_CL with type Custom table.

> [!WARNING]
> **If something goes wrong**
>
> 403 means your account is not Owner or Contributor on the resource group (Chapter 6.1). 400 with a message about a column means the table file was changed; download the pack again.

Step 3. Create the data collection rule dcr-minibank-dbsnap and connect it to APP-RHEL. The rule tells the Azure Monitor Agent on APP-RHEL to read /var/log/minibank/dbsnap.json and send each line to the new table.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, same session as Step 2.

```powershell
$cols = @('TimeGenerated:datetime','Computer:string','FilePath:string','DbEngine:string','SnapshotType:string',
          'Name:string','Value:real','Detail:string') | ForEach-Object { $n, $t = $_ -split ':'; @{ name = $n; type = $t } }
$dcr = @{
  location = $LOC; kind = 'Linux'
  tags = @{ purpose = 'appmon-openshift-demo'; demo = 'minibank'; owner = 'labadmin' }
  properties = @{
    description = 'MiniBank Route A: Oracle and PostgreSQL snapshots from APP-RHEL'
    streamDeclarations = @{ 'Custom-Json-MiniBankDbSnap_CL' = @{ columns = @($cols) } }
    dataSources = @{ logFiles = @(@{ name = 'minibankDbSnapJson'; format = 'json'
        streams = @('Custom-Json-MiniBankDbSnap_CL'); filePatterns = @('/var/log/minibank/dbsnap.json') }) }
    destinations = @{ logAnalytics = @(@{ name = 'law'; workspaceResourceId = $LAWID }) }
    dataFlows = @(@{ streams = @('Custom-Json-MiniBankDbSnap_CL'); destinations = @('law')
        transformKql = 'source'; outputStream = 'Custom-MiniBankDbSnap_CL' })
  }
}
$dcr | ConvertTo-Json -Depth 10 | Set-Content ./dcr-minibank-dbsnap.json
$DCRID = "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Insights/dataCollectionRules/dcr-minibank-dbsnap"
az rest --method put --url "https://management.azure.com$($DCRID)?api-version=2023-03-11" `
  --body '@dcr-minibank-dbsnap.json' --query "{name:name, state:properties.provisioningState}" -o table
@{ properties = @{ dataCollectionRuleId = $DCRID; description = 'MiniBank Route A snapshots' } } |
  ConvertTo-Json -Depth 5 | Set-Content ./dcra-dbsnap.json
$RHELID = "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.HybridCompute/machines/APP-RHEL"
az rest --method put --url "https://management.azure.com$RHELID/providers/Microsoft.Insights/dataCollectionRuleAssociations/dcra-minibank-dbsnap?api-version=2023-03-11" `
  --body '@dcra-dbsnap.json' --query name -o tsv
```

> [!TIP]
> **What you should see**
>
> The first command prints dcr-minibank-dbsnap and Succeeded; the second prints dcra-minibank-dbsnap. In the Portal: Monitor, Settings, Data Collection Rules, dcr-minibank-dbsnap. Under Configuration, Data sources shows a custom JSON log data source, and Resources lists APP-RHEL.

> [!WARNING]
> **If something goes wrong**
>
> If the answer says that a data collection endpoint is required, create one in the same Cloud Shell - PowerShell session with az monitor data-collection endpoint create -g $RG -n dce-minibank -l $LOC --public-network-access Enabled, add the line dataCollectionEndpointId = '&lt;its id&gt;' inside properties in the $dcr block, and run Step 3 again. If the answer says that the stream or the table is unknown, wait five minutes after Step 2 and run Step 3 again.

Step 4. Check the data.

> [!NOTE]
> **Where to run it**
>
> Azure Portal - law-appmon, Logs. Switch from Simple mode to KQL mode at the top right of the query window.

Wait 15 to 30 minutes; the first rows of a new custom table take the longest. Then run the queries below: A.14 (latest snapshot), A.15 (top SQL) and A.16 (wait events).

**Query A.14** - Latest database snapshot (Route A)

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(10m)
| summarize arg_max(TimeGenerated, Value, Detail, Computer) by DbEngine, SnapshotType, Name
| order by DbEngine asc, SnapshotType asc, Value desc
```

**Query A.15** - Top SQL statements by average time per execution (Route A)

```kusto
MiniBankDbSnap_CL
| where TimeGenerated > ago(10m) and SnapshotType == "topsql"
| summarize arg_max(TimeGenerated, Value, Detail) by DbEngine, Name
| project DbEngine, SqlId = Name, AvgMsPerExecution = round(Value, 1), SqlTextAndExecutions = Detail
| order by AvgMsPerExecution desc
| take 20
```

**Query A.16** - Wait events, and the link to slow Oracle calls (Route A)

Oracle: seconds waited per wait event during the last hour (the value is cumulative, so the query takes the difference).

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

> [!TIP]
> **What you should see**
>
> A.14 returns rows for Oracle and PostgreSQL (sessions, waits, topsql, locks and errors) with Computer APP-RHEL. During the slow-oracle scenario, A.15 shows the statement that calls DBMS_SESSION.SLEEP at the top and A.16 shows the PL/SQL lock timer wait event growing.

> [!WARNING]
> **If something goes wrong**
>
> No rows after 30 minutes: on APP-RHEL check that the file grows (sudo tail -n 2 /var/log/minibank/dbsnap.json), and in the Portal check the association (rule, Resources). On APP-RHEL, sudo systemctl status azuremonitoragent must show active (running).

> [!TIP]
> **Beginner tip**
>
> The errors snapshot counts ORA- lines in the Oracle alert log, so it normally stays at 0. Application errors such as ORA-00942 from the fail-oracle scenario go back to the application and never reach the alert log; you see them in Application Insights (Failures) instead.

> [!CAUTION]
> **Be honest**
>
> Route A is a sample built for this demo: the queries in oracle-snap.sql and pg-snap.sql are small and readable on purpose. For production, the bank would choose the statements its DBAs already trust. Azure Monitor does not have a built-in Oracle or PostgreSQL agent for on-premises databases; Azure Arc and the Azure Monitor Agent provide the secure transport, the storage, the queries and the alerts.

## 16.2 Route B: Prometheus exporters scraped by the OpenShift cluster

Step 1. Start the two exporters on APP-RHEL. The block opens the firewall ports first, before the containers start (Chapter 14.2 explains why).

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

```bash
for p in 9161 9187; do sudo firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address=\"192.168.110.0/24\" port port=\"$p\" protocol=\"tcp\" accept"; done
sudo firewall-cmd --reload
cd ~/minibank/monitoring/route-b
read -rsp 'Oracle MINIBANK_MON password: ' ORA_MON; echo
read -rsp 'PostgreSQL postgres_exporter password: ' PG_MON; echo
sed -e "s|<ORACLE-MON-PASSWORD>|$ORA_MON|" -e "s|<PG-EXPORTER-PASSWORD>|$PG_MON|" exporters.env.example \
  | sudo tee /etc/minibank/exporters.env > /dev/null
unset ORA_MON PG_MON
sudo chown root:root /etc/minibank/exporters.env && sudo chmod 600 /etc/minibank/exporters.env
sudo bash ./run-exporters.sh
```

The Oracle exporter 2.5.x also needs a configuration file. In source pack v1.3, run-exporters.sh writes it for you: /etc/minibank/oracle-exporter.yaml, passed to the container with the setting CONFIG_FILE. The file has a databases section with an entry default (username, password and url) and a metrics section with an entry default, but it only holds references such as ${DB_PASSWORD}: the exporter fills them in from the environment, so the password stays in /etc/minibank/exporters.env and never goes into the YAML file.

> [!TIP]
> **What you should see**
>
> Two containers, minibank-oracle-exporter and minibank-postgres-exporter, with status Up, then the lines oracledb_up 1 and pg_up 1. The first start downloads both images and can take a few minutes.

> [!WARNING]
> **If something goes wrong**
>
> In APP-RHEL - Bash: oracledb_up 0 or missing: run sudo podman logs minibank-oracle-exporter; ORA-01017 means a wrong MINIBANK_MON password in /etc/minibank/exporters.env (fix it and run sudo bash ./run-exporters.sh again). A message about a missing configuration file means that /etc/minibank/oracle-exporter.yaml or the setting CONFIG_FILE is missing (see above). pg_up 0: run sudo podman logs minibank-postgres-exporter.

Step 2. Tell the cluster's Prometheus agent to scrape the two exporters.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block in Chapter 5.5.

```powershell
oc apply -f F:\Build\minibank\monitoring\route-b\ama-metrics-prometheus-config.yaml
Start-Sleep -Seconds 300
$pod = (oc get pods -n kube-system -o name | Where-Object { $_ -match '^pod/ama-metrics-[a-z0-9]{8,10}-[a-z0-9]{5}$' } |
        Select-Object -First 1) -replace '^pod/', ''
$pod
$job = Start-Job -ScriptBlock { param($p) oc port-forward -n kube-system $p 9090 } -ArgumentList $pod
Start-Sleep -Seconds 5
Start-Process msedge 'http://localhost:9090/targets'
```

> [!TIP]
> **What you should see**
>
> The pod name looks like ama-metrics-5c7d9b8f6c-x2k4p. Edge shows the target list of the agent, with the jobs minibank-oracle and minibank-postgres in state UP. When you are done, close the tab and run Stop-Job $job; Remove-Job $job.

> [!WARNING]
> **If something goes wrong**
>
> $pod is empty: run oc get pods -n kube-system, find the ama-metrics pod that has no -node-, -ksm- or -operator- in its name, type $pod = '&lt;that name&gt;' and run the last four lines of the block again. A job that is DOWN with "connection refused" or a timeout: check the firewall rules of Step 1 and that both containers run (sudo podman ps on APP-RHEL).

Step 3. Look at the metrics in Azure.

> [!NOTE]
> **Where to run it**
>
> Azure Portal - amw-appmon, Prometheus explorer (in the left menu, under Monitoring or at the top level, depending on the Portal version).

Type up{job=~"minibank-.\*"} in the query box and click **Run query**, then try oracledb_up, pg_up and the other queries below (Appendix A.20).

**Query A.20** - PromQL queries (Prometheus explorer in amw-appmon, or Grafana)

Paste one query at a time. Lines that start with # are explanations; do not paste them.

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

> [!TIP]
> **What you should see**
>
> Two series with value 1, one for job minibank-oracle and one for job minibank-postgres, each with the label cluster set to arc-ocp-minibank.

> [!CAUTION]
> **Be honest**
>
> The two exporters are open-source projects: the Oracle AI Database Metrics Exporter is published by Oracle, and postgres_exporter by the Prometheus community. Microsoft supports the managed Prometheus service that stores and queries the metrics, not the exporters themselves.

---

[&larr; 15. MiniBank services and screens](15-minibank-services-and-screens.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [17. Traffic, dashboards, alerts and telemetry filtering &rarr;](17-traffic-dashboards-alerts-and-telemetry-filtering.md)
