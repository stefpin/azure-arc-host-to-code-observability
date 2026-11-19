# 20. Reset between rehearsals and after the demo

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 20.1 Scenario and data

After a rehearsal of the Priority 1 scenes, first end the incident and undo the live onboarding of Scene 2 (version 1.6):

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Stop        # only if an incident is still running
powershell -ExecutionPolicy Bypass -File .\onboard-reset.ps1         # removes the annotation from minibank-rates-copy
```

Both scripts print what they did; onboard-reset.ps1 takes about 20 seconds. The browser robot keeps running; pause it only for maintenance (Chapter 26.3). Then continue with the steps below.

1. Presenter page: choose **normal** and click **Apply**.
1. If an incident window or a decline burst still runs in a Bastion PowerShell window, stop it with Ctrl+C.
1. To restore the demo balances, run the top-up by hand in APP-SQL - PowerShell Direct: powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\topup-demo-balances.ps1 (Chapter 17.10). It replaces reset-demo-balances.sql of version 1.2, which is no longer used.
## 20.2 Nodes after Scenes 9 and 10

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator), after the start block of Chapter 5.5. The Hyper-V commands (Get-VM, Start-VM, Stop-VM) and the oc commands both run here. Paste the block at the PS F:\Build&gt; prompt.

```bash
Get-VM OCP-NODE-* | Format-Table Name, State
Start-VM OCP-NODE-3 -ErrorAction SilentlyContinue
oc adm uncordon ocp-node-2
oc get nodes
oc get pods -n minibank -l app=minibank-transfer -o wide
```

> [!TIP]
> **What you should see**
>
> All nodes Ready and three transfer pods Running, one on each node.

Kubernetes never moves running pods back by itself. After Scene 9 or 10, or after any restart of the deployment, two transfer pods can share a node. A rolling restart does not fix this reliably: it starts each new pod before it stops an old one, so a new pod can again land on a node that already has one, as happened on 11 November 2026. Instead, delete the newer of the two pods on the shared node; its replacement goes to the node without a transfer pod.

```bash
oc get pods -n minibank -l app=minibank-transfer -o wide --sort-by=.metadata.creationTimestamp
oc delete pod <NEWER-POD-ON-THE-SHARED-NODE> -n minibank
Start-Sleep -Seconds 40
oc get pods -n minibank -l app=minibank-transfer -o wide
```

> [!TIP]
> **What you should see**
>
> The deleted pod is replaced in about 30 seconds, and the three pods run on ocp-node-1, ocp-node-2 and ocp-node-3. The two other pods keep serving in the meantime.

> [!WARNING]
> **If something goes wrong**
>
> The new pod lands on a node that already has one: wait one minute and repeat the delete once. If it happens again, check in the same window (HV-HOST-02 - PowerShell (Admin)) that the empty node is Ready and not cordoned (oc get nodes).

> [!TIP]
> **Beginner tip**
>
> Making restarts end with one pod per node by themselves is still open (Appendix E.1).

## 20.3 Alerts

Fired alerts resolve by themselves when the condition clears. Do not delete alert rules to make them quiet. After a rehearsal, close the fired alerts of the MiniBank rules alr-minibank-failure-rate-high, alr-minibank-decline-spike, alr-minibank-failed-value-idr and alr-minibank-journey-success-low (and of alr-ocp-node-not-ready after Scene 9), and any alert Failure Anomalies - appi-minibank, which otherwise stays open for 8 to 24 hours, so that the alert list is empty for the demo. In the Azure Portal: search box **Monitor &gt; Alerts**, set the filter Resource group to rg-appmon-openshift-demo, select the alerts, click **Change user response** (in older Portal versions **Change alert state**) and choose Closed.

Version 1.7: every alert rule also e-mails alerts@example.com through the action group ag-appmon-email (Chapter 34): one e-mail when an alert fires and one when it resolves; closing an alert sends no e-mail. To close every resolved alert of the lab in one go:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
$u = "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.AlertsManagement/alerts?api-version=2019-05-05-preview&targetResourceGroup=$RG&timeRange=30d&alertState=New&monitorCondition=Resolved&pageCount=250"
$ids = @(az rest --method get --url $u --query "value[].id" -o tsv)
foreach ($id in $ids) { az rest --method post --url "https://management.azure.com$($id)/changestate?api-version=2019-05-05-preview&newState=Closed" -o none }
"Closed: $($ids.Count)"
```

> [!TIP]
> **What you should see**
>
> Closed: and the number of alerts. Monitor &gt; Alerts, filter Resource group rg-appmon-openshift-demo, then shows no open alert. An alert that is still firing is not closed: wait until it resolves, then run the block again.

## 20.4 Stage the fourth worker again (after a rehearsal)

After a rehearsal, ocp-node-4 is part of the cluster. Remove it and stage it again so that the real demo can add it live:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator), after the start block of Chapter 5.5. The Hyper-V commands (Get-VM, Start-VM, Stop-VM) and the oc commands both run here. Paste the block at the PS F:\Build&gt; prompt.

```powershell
oc adm cordon ocp-node-4
oc adm drain ocp-node-4 --ignore-daemonsets --delete-emptydir-data --timeout=5m
oc delete node ocp-node-4
Stop-VM OCP-NODE-4 -TurnOff
Remove-Item S:\VMs\OCP-NODE-4.vhdx
New-VHD -Path S:\VMs\OCP-NODE-4.vhdx -SizeBytes 120GB -Dynamic | Out-Null
Add-VMHardDiskDrive -VMName OCP-NODE-4 -Path S:\VMs\OCP-NODE-4.vhdx -ErrorAction SilentlyContinue
```

Then, in the Red Hat console, cluster ocp-minibank, tab **Add hosts**, remove the old ocp-node-4 host entry if it is still listed, and repeat Chapter 12.8 from step 1 (generate the add-hosts ISO again and boot from it until the host shows Ready). Do not click Install until the demo.

---

[&larr; 19. Demo scenes and talk track](19-demo-scenes-and-talk-track.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [21. Troubleshooting &rarr;](21-troubleshooting.md)
