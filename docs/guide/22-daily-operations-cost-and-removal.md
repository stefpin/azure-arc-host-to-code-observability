# 22. Daily operations, cost and removal

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 22.1 Cost

The largest cost is HV-HOST-02: about US$2.29 per hour at list price for Standard_E20s_v5 with Windows in Indonesia Central (checked 10 November 2026), which is about US$1,670 for a full month of continuous running. The managed disks (one 512 GiB and four 256 GiB Premium SSD plus the OS disk) cost the same whether the host runs or not.

Two more items have measured or listed prices since version 1.3:

| Item | Cost |
|---|---|
| Azure Managed Grafana amg-appmon (Standard X1) | About US$0.086 per hour, about US$2 per day, about US$63 per month (list price checked 10 November 2026) |
| Log Analytics data | About 5.3 GB per day with the continuous traffic (measured 11 November 2026, Chapter 17.8). At US$2.691 per GB (Analytics Logs, Indonesia Central, checked 11 November 2026) that is about US$14 per day |

Bastion Basic, the NAT gateway, three public IP addresses, the container registry and the storage account add a smaller amount; use the Azure pricing calculator for a total before gate G0. The Log Analytics daily cap (10 GB) limits the monitoring cost, and pausing the traffic after the demo lowers it (Chapter 22.3).

To watch actual spending: Azure Portal, **Cost Management**, **Cost analysis**, scope rg-appmon-openshift-demo, view **Daily costs**.

## 22.2 Daily checks while the lab is in use

| Check | Where | Expected |
|---|---|---|
| Host running | Azure Portal &gt; virtual machine HV-HOST-02 &gt; Overview | Running |
| OpenShift nodes | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get nodes | All Ready |
| Arc cluster and servers | Azure Portal &gt; Azure Arc &gt; Kubernetes clusters, and Azure Arc &gt; Machines | Connected |
| Data arriving | Query A.1 (below the table) in the Azure Portal, law-appmon &gt; Logs | Rows in the last 30 minutes |
| Traffic log | HV-HOST-02 - PowerShell (Admin): Get-Content C:\BuildLog\traffic.log -Tail 5 | ok about 30 and failed=0 in every line; declined=1 in about 4 lines per hour |
| Top-up log | APP-SQL - PowerShell Direct: Get-Content C:\BuildLog\topup.log -Tail 4 | Four OK lines per day (00:00, 06:00, 12:00 and 18:00 WIB) |
| Cost-control tags | Cloud Shell - PowerShell (start block of Chapter 5.4): the Cloud Shell block below | &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; on both resource groups, and no resource listed without it |
| Log Analytics usage | Query A.18 (below the table) in law-appmon &gt; Logs, or Azure Portal &gt; law-appmon &gt; Usage and estimated costs | About 5.3 GB per day, below the daily cap of 10 GB |
| Transfer pods | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get pods -n minibank -o wide | Three pods Running, one on each node (Chapter 20.2 if not) |
| Alert list | Azure Portal &gt; Monitor &gt; Alerts | No open alerts outside rehearsals and demos, including Failure Anomalies - appi-minibank |
| Registry token expiry | Cloud Shell - PowerShell (start block of Chapter 5.4, with $ACR filled in): the Cloud Shell block below | As built: push token 17 November 2026, pull token 10 December 2026. Renew the pull token before it expires |
| Trial days left | Red Hat Hybrid Cloud Console (https://console.redhat.com), cluster ocp-minibank, Overview | Enough days until the demo |
| Verdict observer (version 1.7) | HV-HOST-02 - PowerShell (Admin): Get-ScheduledTask minibank-verdict-observer, then the two commands of Chapter 32.3 | Task Ready (it starts every minute); two readings a minute, Healthy outside tests |
| Cross-layer board (version 1.7) | Grafana amg-appmon &gt; Dashboards &gt; MiniBank &gt; MiniBank - Cross-layer root cause | Status Healthy, Recovery banner No recovery in progress, no gap in the verdict history |
| Fault command (version 1.7) | HV-HOST-02 - PowerShell (Admin) in F:\Build\minibank\scripts: .\fault.ps1 -Status | The last run ended; nothing ACTIVE outside a test |
| Alert e-mail (version 1.7) | Outlook (alerts@example.com): e-mails from Microsoft Azure (azure-noreply@microsoft.com) | Fired and Resolved e-mails during tests; none on a quiet day |
| Kubernetes resources view | Azure Portal &gt; arc-ocp-minibank &gt; Kubernetes resources &gt; Workloads | The list loads with no Error (599); if it shows, Chapter 21 |

Run these two queries in law-appmon, **Logs**:

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

**Query A.18** - Billable data by table (cost check)

```kusto
Usage
| where TimeGenerated > ago(1d) and IsBillable == true
| summarize GB = round(sum(Quantity) / 1024.0, 3) by DataType
| order by GB desc
```

Measured on 11 November 2026: about 4.7 GB per day without traffic, mostly Perf and the inventory tables of Container insights, plus about 0.7 GB per day from the continuous traffic, mostly AppDependencies, AppRequests and AppTraces. That is about 5.3 GB per day in total (Chapter 17.8).

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block in Chapter 5.4, with $ACR filled in.

```powershell
foreach ($g in @($RG, "MA_amw-appmon_$($AMWLOC)_managed")) {
  "$g : <EXEMPT_TAG>=" + (az group show -n $g --query tags.<EXEMPT_TAG> -o tsv)
  az resource list -g $g --query "[?tags.<EXEMPT_TAG>!='<EXEMPT_VALUE>'].name" -o tsv }
foreach ($t in 'minibank-pull', 'minibank-push') {
  az acr token show -n $t -r $ACR --query "{Token:name, Expires:credentials.passwords[0].expiry}" -o table }
```

> [!TIP]
> **What you should see**
>
> &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; for both resource groups and no resource names under them, then the two tokens with their expiry dates.

> [!WARNING]
> **If something goes wrong**
>
> A resource name under a resource group means that this item lost the tag or never had it: run the merge block of Chapter 7.1.

Renew the pull token a few days before it expires. After it expires, any restarted pod cannot pull its image (ImagePullBackOff), and the always-on traffic then turns every dashboard red.

1. In Cloud Shell, make a new password for 30 days and write it and its expiry date into ENVIRONMENT.txt. The new password replaces the old password1 straight away.
```powershell
az acr token credential generate -n minibank-pull -r $ACR --password1 --expiration-in-days 30 --query "passwords[0].value" -o tsv
```

1. Update the acr-pull secret in the cluster at once.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block in Chapter 5.5.

```powershell
function Read-Secret([string]$Prompt) { [Net.NetworkCredential]::new('', (Read-Host $Prompt -AsSecureString)).Password }
$ACR = Read-Host 'Container registry name (ACR-NAME)'
$tok = Read-Secret 'New token password of minibank-pull'
oc delete secret acr-pull -n minibank
oc create secret docker-registry acr-pull -n minibank --docker-server="$ACR.azurecr.io" `
  --docker-username=minibank-pull --docker-password=$tok
Remove-Variable tok
oc get secret acr-pull -n minibank
```

> [!TIP]
> **What you should see**
>
> The old secret is deleted, the new one is created and listed. Running pods are not affected; pods that start later pull with the new password.

> [!TIP]
> **Beginner tip**
>
> The push token is needed only to push a new image (Chapter 15.2). Let it expire, or renew it the same way with minibank-push and 7 days when you need it.

## 22.3 Stopping and starting the lab (only after the demo, and never within 24 hours of the OpenShift installation)

To stop all traffic, for example after the demo to save Log Analytics cost, pause the task in HV-HOST-02 - PowerShell (Admin): Disable-ScheduledTask minibank-traffic, then Stop-ScheduledTask minibank-traffic. To resume: Enable-ScheduledTask minibank-traffic, then Start-ScheduledTask minibank-traffic.

Stop:

1. If the lab should stay quiet after the next start as well, pause the traffic as described above. Otherwise leave the scheduled tasks as they are.
1. Take an etcd backup (Chapter 12.7).
1. Shut down the cluster gracefully:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator), after the start block of Chapter 5.5, which sets KUBECONFIG and the path of oc. Paste the block at the PS F:\Build&gt; prompt and press Enter.

```bash
oc get nodes -o name | ForEach-Object { oc adm cordon $_ }
oc get nodes -o name | ForEach-Object { oc debug $_ -- chroot /host shutdown -h 1 }
```

1. After 3 minutes: Get-VM OCP-NODE-\* | Stop-VM -Force (only VMs still running), then Stop-VM APP-WIN, APP-SQL, APP-RHEL.
1. In the Portal, stop (deallocate) HV-HOST-02.

Start:

1. Start HV-HOST-02 in the Portal and connect through Bastion.
1. Start-VM APP-SQL, APP-RHEL, APP-WIN, OCP-NODE-1, OCP-NODE-2, OCP-NODE-3.
1. Wait up to 45 minutes. Approve pending certificates in HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc get csr, then oc adm certificate approve &lt;NAME&gt; for each Pending entry.
1. In the same window: oc get nodes -o name | ForEach-Object { oc adm uncordon $_ }, then the acceptance checklist (18.2).

After a host start you do not need to start any script. The traffic task starts by itself 10 minutes after the host start, and the watchdog keeps it running; until MiniBank answers, traffic.log shows waiting lines and the script tries again every minute. The probe starts at boot. A top-up that was missed while APP-SQL was off runs when APP-SQL is back.

## 22.4 Remove the lab

> [!NOTE]
> **Approval Gate**
>
> G9. Deletion cannot be undone. Do it only after the lab owner approves, after the demo and any follow-up sessions.

1. Red Hat console: **OpenShift**, **Clusters**, open ocp-minibank, **Actions**, **Archive cluster**.
1. Cloud Shell - PowerShell, after the start block:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az group delete -n $RG --yes --no-wait
az group list --query "[?starts_with(name, 'MA_amw-appmon')].name" -o tsv   # should become empty
```

1. Delete ENVIRONMENT.txt on your computer and any downloaded ISO or pack files, including ~/minibank and the zip file in Cloud Shell.

Deleting the resource group also removes amg-appmon with its data sources and dashboards, the alert rules and every other lab item. There is nothing to clean in the Hyper-V demo.

> [!TIP]
> **What you should see**
>
> After about 20 minutes the resource group rg-appmon-openshift-demo and the managed resource group MA_amw-appmon_..._managed no longer exist. The Hyper-V demo is unchanged.

---

[&larr; 21. Troubleshooting](21-troubleshooting.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [Appendix A. Queries &rarr;](appendix-a-queries.md)
