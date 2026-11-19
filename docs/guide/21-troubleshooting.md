# 21. Troubleshooting

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


Diagnose first, change second. Record what you saw before you change anything.

| Symptom | Most likely cause | What to check and do |
|---|---|---|
| Bastion connection fails | Wrong password or Bastion not ready | Azure Portal &gt; bas-appmon &gt; Overview shows Succeeded; reset nothing, retry with the password from ENVIRONMENT.txt |
| HV-HOST-02 has no internet | NAT gateway not attached | Azure Portal &gt; vnet-appmon &gt; Subnets: snet-appmon-host must show natgw-appmon |
| Lab VMs have no internet | Lab NAT missing | HV-HOST-02 - PowerShell (Admin): Get-NetNat must show AppMonNAT 192.168.110.0/24; the guest gateway must be 192.168.110.1 |
| Names do not resolve in the lab | DNS role or record missing | HV-HOST-02 - PowerShell (Admin): Resolve-DnsName &lt;name&gt; -Server 192.168.110.1; compare with Chapter 9.4 |
| Arc agent refuses: machine is an Azure VM | Metadata block missing | Chapter 11.5 on that guest |
| Arc machine Connected but no data | No data collection rule associated yet | Chapters 16 and 17 attach the rules; data starts a few minutes later |
| Assisted Installer: host stays Insufficient | A validation failed (NTP, disk, network) | Click the host's status to read the failed validation; Chapter 12.4 lists the usual ones |
| Cluster API not reachable after a host restart | Nodes still starting, or certificates waiting for approval | Wait up to 45 minutes; then, in HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: run oc get csr and approve Pending requests (Chapter 12.8 step 6) |
| arc-ocp-minibank shows Offline | Arc agents cannot reach Azure | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get pods -n azure-arc (all Running?); check the internet access of HV-HOST-02; Chapter 13.3 |
| Kubernetes resources in the Portal shows Error (599) "Unable to reach the api server" or "Failed to fetch" | Two known causes: the presenter has no read permission inside OpenShift (the Portal signs in with the presenter's Microsoft Entra account), or, as on 13 November 2026, the Arc cluster-connect agent receives no sessions after an Arc agent restart while the permissions and the cluster are fine. Since 14 November 2026 the error has come back and stayed: neither the agent restart (14 November) nor switching the cluster-connect feature off and on (15 November, Chapter 38.9) fixed it, because the Portal's requests never reach the agent | Select Try again once. Then in HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc auth can-i list deployments -A --as=&lt;SIGN-IN-NAME&gt; must answer yes; if not, create the binding and the Azure role of Chapter 13.4. If it answers yes: oc rollout restart deployment/clusterconnect-agent -n azure-arc, then oc rollout status deployment/clusterconnect-agent -n azure-arc, wait about 1 minute and reload the page. If the error stays, do not repeat this during the demo: use Insights, tab Controllers instead (Scene 1), or the OpenShift web console (Scene 0A). The open fix is described in Chapter 38.9 |
| Extension shows Failed | Missing permission on OpenShift or wrong workspace ID | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get pods -n kube-system (ama-logs, ama-metrics); Chapter 13 notes |
| Extensions is missing from the cluster's left menu | The Portal moved it under Settings | Azure Portal &gt; arc-ocp-minibank &gt; Settings &gt; Extensions, or Overview &gt; Properties &gt; Extensions (Chapter 13.8) |
| minibank-transfer pods ImagePullBackOff | Registry token wrong, image name wrong, or the pull token expired (30 days) | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc describe pod -n minibank; recreate the acr-pull secret (Chapter 15.2) or renew the pull token (Chapter 22.2) |
| minibank-transfer pods CrashLoopBackOff | Oracle not reachable or wrong password | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc logs -n minibank deploy/minibank-transfer; then check the firewall rule for 1521 in APP-RHEL - Bash (Chapter 14.2) |
| Two transfer pods on the same node | A rolling restart, or Scenes 9 and 10; Kubernetes does not move running pods back | Delete the newer pod on that node (Chapter 20.2) |
| Oracle calls show the type SQL again | The setting APPLICATIONINSIGHTS_CONFIGURATION_FILE or the ConfigMap minibank-transfer-ai-config is missing, or a newer Java agent turns oracle.db into SQL | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc exec deploy/minibank-transfer -n minibank -- printenv APPLICATIONINSIGHTS_CONFIGURATION_FILE; Chapter 15.2 Step 3 |
| Transfers hang 30 s, Oracle port 1521 open but no answer | A firewall-cmd --reload on APP-RHEL after the Oracle container started removed podman's (netavark) NAT rules | APP-RHEL - Bash: sudo podman network reload --all. Keep netavark-firewalld-reload.service enabled and open firewall ports before starting containers (Chapter 14.2) |
| ORA-00959 when the users MINIBANK and MINIBANK_MON are created | The latest-lite Oracle image has no USERS tablespace in FREEPDB1 | In APP-RHEL - Bash, use 01-minibank-user.sql of source pack v1.3, which creates the tablespace; run the block of Chapter 14.2 again and check dba_users |
| MiniBank shows HTTP 500.30 | API cannot start | VM console of APP-WIN (Hyper-V Manager on HV-HOST-02, double-click APP-WIN, sign in as Administrator): Event Viewer &gt; Windows Logs &gt; Application, look for IIS AspNetCore Module V2 |
| Login failed for user APP-SQL\minibank-svc | Mirrored passwords differ | Set the same minibank-svc password on APP-WIN and APP-SQL (Chapters 14.1 and 15.3) |
| No telemetry from one service | Connection string missing or outbound blocked | Check the environment variable or secret, then run query A.1 (below the table) in the Azure Portal, law-appmon &gt; Logs, after 5 minutes |
| Application Map shows a service as a separate island | Trace context not passed | Check that the call goes through the instrumented HTTP client (rerun Chapter 15.5) |
| Prometheus targets for Oracle or PostgreSQL down | Firewall on APP-RHEL or exporter stopped | APP-RHEL - Bash: sudo podman ps; firewall rules for 9161 and 9187 (Chapter 16.2) |
| Oracle exporter stops right after the start | Exporter 2.5.x without its configuration file | APP-RHEL - Bash: check /etc/minibank/oracle-exporter.yaml and the setting CONFIG_FILE (Chapter 16.2) |
| No rows in MiniBankDbSnap_CL | Timer, file or rule wrong | APP-RHEL - Bash: systemctl status minibank-dbsnap.timer; tail /var/log/minibank/dbsnap.json; then the data collection rule association in the Azure Portal (Chapter 16.1) |
| Grafana panels say No data, insufficient access or 403 | The Grafana identity lacks read access, or its new role assignment is not active yet | Chapter 10.7 role assignments; in the first 10 minutes after assigning, wait and change nothing |
| traffic.log shows waiting for the MiniBank API | APP-WIN or its site minibank-api is not up, for example right after a host start | Nothing to do while the lab starts: the task tries again every minute. Otherwise open http://192.168.110.31:8080/api/health in Edge on HV-HOST-02, or run Invoke-RestMethod http://192.168.110.31:8080/api/health in HV-HOST-02 - PowerShell (Chapter 15.3) |
| Many Insufficient balance declines, or alr-minibank-decline-spike fired | Balances ran low because the top-up is missing or failed, or a bug makes balances read as zero | APP-SQL - PowerShell Direct: Get-Content C:\BuildLog\topup.log -Tail 4; query A.22 (below the table) in law-appmon &gt; Logs for the latest declines; run the top-up by hand (Chapter 17.10) |
| An alert named Failure Anomalies - appi-minibank | The automatic smart detection rule saw an unusual failure rate, for example after the incident window of Scene 6 | Expected after Scene 6; close it (Chapter 20.3) and see Chapter 17.5 |
| Everything is slow | Too many VMs running at once | HV-HOST-02 - PowerShell (Admin): Get-VM; keep OCP-NODE-4 off when not needed; check the host CPU in Task Manager on HV-HOST-02 |
| HV-HOST-02 was stopped by governance | Cost-control automation | Azure Portal &gt; virtual machine HV-HOST-02 &gt; Start; wait 45 minutes for OpenShift; approve CSRs in HV-HOST-02 - PowerShell (Admin) (oc get csr, Chapter 12.8 step 6); check the &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; tags (Chapter 22.2) and raise the exception again (Chapter 6.5) |
| Cross-layer board stays Pending longer than 5 minutes | A slower source is missing (VM performance, network probe, OpenShift inventory or Oracle schema check), or no rule matches | Verdict details name the source it waits for; run the query of Chapter 31.5. After 3.5 minutes the board shows Unclassified: reveal and explain (Scene 7C) |
| Verdict history has a gap or stops | The observer task on HV-HOST-02 does not run, or the host identity cannot write | HV-HOST-02 - PowerShell (Admin): Get-ScheduledTask minibank-verdict-observer (Ready, starts every minute); Start-ScheduledTask minibank-verdict-observer; Chapter 32.3 |
| fault.ps1 says Not started: a fault run is active | A series, draw or labelled run is still active, or the Scene 5 and 6 incident runs | HV-HOST-02 - PowerShell (Admin) in F:\Build\minibank\scripts: .\fault.ps1 -Status; wait, or .\fault.ps1 -Stop (all undo steps); incident.ps1 -Stop for the incident |
| fault.ps1 -Mystery says VOID | The fault did not take effect within 90 seconds, for example APP-WIN or APP-RHEL did not answer | Everything is already reset; ask the bank for a new number; read C:\BuildLog\fault.log on HV-HOST-02 |
| No alert e-mail arrives | Mail filtered, the action group disabled, or the rule has no action group | Outlook: search for azure-noreply@microsoft.com, also in Junk. Azure Portal &gt; Monitor &gt; Alerts &gt; Action groups &gt; ag-appmon-email: enabled, receiver alerts@example.com; Test action group (Chapter 34.3) |
| Leak check lists giveaway words | A card name or one of the words mystery, fault.ps1, netem, report-export, statement-header is in the telemetry | Do not run a blind draw until the words are older than the check window; the traffic generator labels fail-oracle, fail-java, fail-python and fail-api are expected and listed apart (Chapter 33.7) |

The queries of this table, to run in law-appmon, **Logs**. Paste an OperationId from A.22 into A.7 to see the whole transaction of a decline.

**Query A.1** - Telemetry arrives from every service

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

**Query A.22** - Latest business declines with trace ID

Paste an OperationId into query A.7 to see the whole transaction of that decline.

```kusto
AppRequests
| where TimeGenerated > ago(24h) and AppRoleName == "minibank-api" and ResultCode == "409"
| project TimeGenerated, Name, DurationMs, OperationId
| top 20 by TimeGenerated desc
```

**Query A.7** - One transaction by its Trace ID

Replace &lt;TRACE-ID&gt; with the 32-character Trace ID shown on the MiniBank failure screen.

```kusto
let tid = "<TRACE-ID>";
union AppRequests, AppDependencies, AppExceptions, AppTraces
| where OperationId == tid
| project TimeGenerated, Type, AppRoleName, AppRoleInstance, Name, Target, DurationMs, Success, ResultCode
| order by TimeGenerated asc
```

---

[&larr; 20. Reset between rehearsals and after the demo](20-reset-between-rehearsals-and-after-the-demo.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [22. Daily operations, cost and removal &rarr;](22-daily-operations-cost-and-removal.md)
