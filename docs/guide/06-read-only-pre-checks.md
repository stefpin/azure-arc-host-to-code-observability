# 6. Read-only pre-checks

<sub>Part A - Understand and prepare &nbsp;|&nbsp; [Guide index](README.md)</sub>


Nothing in this chapter changes anything. If a check fails, stop and report it before Chapter 7.

## 6.1 Subscription and account

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block in Chapter 5.4.

> [!TIP]
> **What you should see**
>
> The start block already showed the right subscription and tenant. Also open the Azure Portal, search for Subscriptions, open &lt;YOUR_SUBSCRIPTION_NAME&gt;, click Access control (IAM), then View my access, and confirm that you are Owner (needed for role assignments in Chapters 10.7 and 13).

## 6.2 Quota and VM size

On 10 November 2026 this check showed: Standard ESv5 Family vCPUs 16 of 100 used, Total Regional vCPUs 32 of 100 used, and Standard_E20s_v5 offered without restrictions in zones 1, 2 and 3 of Indonesia Central. Run it again on the day you build, because other demos in the subscription can use quota.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az vm list-usage -l $LOC --query "[?name.value=='cores' || contains(name.value,'ESv5')].{Quota:localName, Used:currentValue, Limit:limit}" -o table
az vm list-skus -l $LOC --size Standard_E20s_v5 --all --query "[].{SKU:name, Zones:join(',', locationInfo[0].zones), Restrictions:length(restrictions)}" -o table
```

> [!TIP]
> **What you should see**
>
> At least 20 free vCPUs in both the ESv5 family and the regional quota, and Restrictions 0 for Standard_E20s_v5.

> [!WARNING]
> **If something goes wrong**
>
> Quota counts stopped (deallocated) VMs too. If fewer than 20 vCPUs are free, do not delete other demos' VMs. Ask for a quota increase in the Portal (Subscriptions, Usage + quotas) instead.

## 6.3 Resource providers

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
$providers = 'Microsoft.Compute','Microsoft.Network','Microsoft.Storage','Microsoft.ContainerRegistry',
  'Microsoft.OperationalInsights','Microsoft.Insights','Microsoft.Monitor','Microsoft.AlertsManagement',
  'Microsoft.Dashboard','Microsoft.HybridCompute','Microsoft.GuestConfiguration','Microsoft.HybridConnectivity',
  'Microsoft.Kubernetes','Microsoft.KubernetesConfiguration','Microsoft.ExtendedLocation','Microsoft.PolicyInsights'
$providers | ForEach-Object {
  [pscustomobject]@{ Provider = $_; State = (az provider show -n $_ --query registrationState -o tsv) } } | Format-Table
```

> [!TIP]
> **What you should see**
>
> Every provider shows Registered.

> [!NOTE]
> **Approval Gate**
>
> G1. Registering a provider changes the subscription. Only after gate G1 is approved, register each provider that is not Registered with az provider register -n &lt;PROVIDER&gt; in Cloud Shell - PowerShell, and repeat the check after five minutes until all show Registered.

## 6.4 Region availability for Arc-enabled Kubernetes and the Azure Monitor workspace

Azure services arrive in new regions at different times. This check reads the official list of regions directly from Azure.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```bash
az provider show -n Microsoft.Kubernetes --query "resourceTypes[?resourceType=='connectedClusters'].locations | [0]" -o tsv
az provider show -n Microsoft.Monitor --query "resourceTypes[?resourceType=='accounts'].locations | [0]" -o tsv
az provider show -n Microsoft.KubernetesConfiguration --query "resourceTypes[?resourceType=='extensions'].locations | [0]" -o tsv
```

> [!TIP]
> **What you should see**
>
> Three lists of region names. If Indonesia Central appears in the first list, keep ARCLOC = indonesiacentral; if not, set ARCLOC = southeastasia in your start block and worksheet. Do the same for the second list and AMWLOC. Write the result in the pre-check record.

> [!TIP]
> **Beginner tip**
>
> The region of the Arc resource is only where Azure keeps the record of the cluster. The cluster still runs inside HV-HOST-02, and its logs still go to law-appmon in Indonesia Central.

## 6.5 Red Hat account and the cost-control exception

1. On your computer, open https://console.redhat.com and sign in, or click Register to create a free Red Hat account with your work email.
1. Click OpenShift in the left menu, then Clusters, and confirm that you see the Create cluster button. Do not create anything yet.
1. Open https://developers.redhat.com, sign in with the same account and confirm that the no-cost Red Hat Developer subscription is active (it lets you install and register RHEL on APP-RHEL).
1. Ask the subscription's governance owner how to keep HV-HOST-02 running: the automation in this subscription stopped HV-HOST-01 on 11 October 2026 and later removed &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; tags. Record the agreed exception (or the decision to watch the host every day) in the pre-check record. This is part of gate G0.

As built on 10 and 11 November 2026: governance automation can stop or deallocate resources that are not exempt, so the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; was merged (not replaced) onto the resource group, every resource in it, the managed resource group MA_amw-appmon_indonesiacentral_managed and its resources (Chapter 7.1). Every new resource, such as Grafana and the alert rules, gets the tag when it is created, and the daily checks confirm that nothing lost it (Chapter 22.2).

## 6.6 Pre-check record

Copy this table into ENVIRONMENT.txt and fill it in.

| Check | Result | Date and time | Approved by (for gates) |
|---|---|---|---|
| Subscription, tenant, Owner role |   |   |   |
| Free ESv5 and regional vCPUs, E20s_v5 restrictions |   |   |   |
| Providers registered |   |   | G1 |
| ARCLOC and AMWLOC |   |   |   |
| Red Hat account and Developer subscription |   |   |   |
| Cost-control exception or daily-check decision |   |   | G0 |

---

[&larr; 5. Values, tools and the start of every session](05-values-tools-and-the-start-of-every-session.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [7. Resource group, network, NAT gateway and Bastion &rarr;](07-resource-group-network-nat-gateway-and-bastion.md)
