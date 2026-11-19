# 7. Resource group, network, NAT gateway and Bastion

<sub>Part B - Build the Azure foundation and the host &nbsp;|&nbsp; [Guide index](README.md)</sub>


> [!NOTE]
> **Approval Gate**
>
> G0 and G1. Continue only when the lab owner has approved the running cost (Chapter 22.1), the cost-control decision (Chapter 6.5) and the creation of the network items in this chapter.

## 7.1 Resource group

> [!NOTE]
> **Where to run it**
>
> Azure Portal for the Portal path, or Cloud Shell - PowerShell (after the start block in Chapter 5.4) for the CLI path. Use only one of the two paths.

Portal path:

1. In the search box at the top of the Azure Portal, type **Resource groups** and press Enter.
1. Click **+ Create**.
1. **Subscription**: &lt;YOUR_SUBSCRIPTION_NAME&gt;.
1. **Resource group name**: rg-appmon-openshift-demo.
1. **Region**: (Asia Pacific) Indonesia Central.
1. Click **Next: Tags**. Add three tags: Name purpose, Value appmon-openshift-demo; Name demo, Value minibank; Name owner, Value labadmin. Add a fourth tag, Name &lt;EXEMPT_TAG&gt;, Value &lt;EXEMPT_VALUE&gt; (Chapter 6.5).
1. Click **Review + create**, then **Create**.

CLI path:

```powershell
az group create -n $RG -l $LOC --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin <EXEMPT_TAG>=<EXEMPT_VALUE> -o table
```

> [!TIP]
> **What you should see**
>
> The resource group rg-appmon-openshift-demo in Indonesia Central with its four tags. It is empty.

The cost-control tag. governance automation in this subscription can stop or deallocate resources that are not exempt (Chapter 6.5). The exemption is the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt;. A resource group does not pass its tags on to the resources in it, so every item needs the tag itself. Always merge the tag and never replace the tags: Replace would delete purpose, demo and owner. For one item the command is:

```bash
az tag update --resource-id <RESOURCE-ID> --operation Merge --tags <EXEMPT_TAG>=<EXEMPT_VALUE> -o none
```

Run the next block at the end of every build day, and whenever the daily check finds an item without the tag (Chapter 22.2). It merges the tag onto the resource group, every resource in it, the managed resource group MA_amw-appmon_indonesiacentral_managed (Azure creates it in Chapter 10.3) and its resources. New items that the runbook creates later, such as Grafana (Chapter 10.7) and the alert rules (Chapter 17.5), get the tag when they are created.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block in Chapter 5.4 (for both the Portal path and the CLI path).

```powershell
$MRG = "MA_amw-appmon_$($AMWLOC)_managed"     # MA_amw-appmon_indonesiacentral_managed in this lab
foreach ($g in @($RG, $MRG)) {
  if ((az group exists -n $g) -ne 'true') { "$g does not exist yet"; continue }
  az tag update --resource-id (az group show -n $g --query id -o tsv) --operation Merge --tags <EXEMPT_TAG>=<EXEMPT_VALUE> -o none
  foreach ($id in (az resource list -g $g --query "[].id" -o tsv)) {
    az tag update --resource-id $id --operation Merge --tags <EXEMPT_TAG>=<EXEMPT_VALUE> -o none }
  "$g done"
}
```

> [!TIP]
> **What you should see**
>
> rg-appmon-openshift-demo done, and MA_amw-appmon_indonesiacentral_managed done (before Chapter 10.3: does not exist yet).

> [!TIP]
> **Beginner tip**
>
> As built on 10 and 11 November 2026, the tag was merged with az tag update --operation Merge onto both resource groups and every resource in them. The automation removed &lt;EXEMPT_TAG&gt; tags before (Chapter 6.5), so the daily checks in Chapter 22.2 look for items that lost it.

## 7.2 Virtual network and subnets

Portal path:

1. Search for **Virtual networks** and click **+ Create**.
1. **Basics** tab: Resource group rg-appmon-openshift-demo, **Virtual network name** vnet-appmon, **Region** Indonesia Central.
1. **IP addresses** tab: change the IPv4 address space to 10.60.0.0/16. Delete the proposed subnet named default (click the bin icon on its row).
1. Click **+ Add a subnet**. **Subnet purpose**: Default. **Name**: snet-appmon-host. **Starting address**: 10.60.1.0. **Size**: /24. Leave **Enable private subnet (no default outbound access)** ticked. Click **Add**.
1. Click **+ Add a subnet** again. **Subnet purpose**: Azure Bastion (the name AzureBastionSubnet is filled in for you). **Starting address**: 10.60.250.0. **Size**: /26. Click **Add**.
1. **Tags** tab: add the same three tags as in 7.1.
1. Click **Review + create**, then **Create**.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az network vnet create -g $RG -n $VNET -l $LOC --address-prefixes 10.60.0.0/16 `
  --subnet-name snet-appmon-host --subnet-prefixes 10.60.1.0/24 `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o none
az network vnet subnet create -g $RG --vnet-name $VNET -n AzureBastionSubnet --address-prefixes 10.60.250.0/26 -o none
az network vnet subnet list -g $RG --vnet-name $VNET --query "[].{Name:name, Prefix:addressPrefix}" -o table
```

> [!TIP]
> **What you should see**
>
> Two subnets: snet-appmon-host 10.60.1.0/24 and AzureBastionSubnet 10.60.250.0/26.

> [!TIP]
> **Beginner tip**
>
> New Azure subnets are private: virtual machines in them cannot reach the internet until you give the subnet an explicit outbound path. The NAT gateway in 7.3 is that path. Bastion only lets you in; it never lets the host out.

## 7.3 NAT gateway for outbound internet

Portal path:

1. Search for **NAT gateways** and click **+ Create**.
1. **Basics** tab: Resource group rg-appmon-openshift-demo, **NAT gateway name** natgw-appmon, **Region** Indonesia Central. If a **SKU** field is shown, choose **Standard**. **Availability zone**: No Zone. **TCP idle timeout (minutes)**: 10.
1. **Outbound IP** tab: next to **Public IP addresses**, click **Create a new public IP address**, name it pip-natgw-appmon and click **OK**.
1. **Networking** (or **Subnet**) tab: **Virtual network** vnet-appmon, tick only snet-appmon-host.
1. **Tags** tab: the same three tags. Click **Review + create**, then **Create**.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az network public-ip create -g $RG -n pip-natgw-appmon -l $LOC --sku Standard --allocation-method Static -o none
az network nat gateway create -g $RG -n natgw-appmon -l $LOC --public-ip-addresses pip-natgw-appmon --idle-timeout 10 -o none
az network vnet subnet update -g $RG --vnet-name $VNET -n snet-appmon-host --nat-gateway natgw-appmon --default-outbound false -o none
```

> [!TIP]
> **What you should see**
>
> Open vnet-appmon, click Subnets in the left menu: the NAT gateway column shows natgw-appmon for snet-appmon-host.

## 7.4 Network security group for the host subnet

Portal path:

1. Search for **Network security groups** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo, **Name** nsg-snet-appmon-host, **Region** Indonesia Central. Add the three tags. Click **Review + create**, then **Create**.
1. Open nsg-snet-appmon-host. In the left menu click **Settings**, then **Subnets**, then **+ Associate**.
1. **Virtual network** vnet-appmon, **Subnet** snet-appmon-host, click **OK**.
1. Do not add any inbound rule. The default rules already allow Bastion to reach the host from inside the virtual network and block the internet.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az network nsg create -g $RG -n nsg-snet-appmon-host -l $LOC --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o none
az network vnet subnet update -g $RG --vnet-name $VNET -n snet-appmon-host --network-security-group nsg-snet-appmon-host -o none
```

> [!TIP]
> **What you should see**
>
> The subnet snet-appmon-host shows nsg-snet-appmon-host in the Security group column.

## 7.5 Azure Bastion (Basic)

Portal path:

1. Search for **Bastions** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo, **Name** bas-appmon, **Region** Indonesia Central.
1. **Tier**: Basic. **Instance count** stays at 2.
1. **Virtual network**: vnet-appmon. The subnet AzureBastionSubnet is selected for you.
1. **Public IP address**: Create new, **Public IP address name** pip-bas-appmon.
1. **Tags** tab: the same three tags. Click **Review + create**, then **Create**. Deployment takes 10 to 20 minutes.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az network public-ip create -g $RG -n pip-bas-appmon -l $LOC --sku Standard --allocation-method Static -o none
az network bastion create -g $RG -n bas-appmon -l $LOC --vnet-name $VNET --public-ip-address pip-bas-appmon --sku Basic -o none
az network bastion show -g $RG -n bas-appmon --query "{Name:name, Sku:sku.name, State:provisioningState}" -o table
```

> [!TIP]
> **What you should see**
>
> bas-appmon, Sku Basic, State Succeeded.

> [!WARNING]
> **If something goes wrong**
>
> If Cloud Shell asks to install the bastion extension, answer Y. If the deployment fails with a subnet error, check that the subnet is named exactly AzureBastionSubnet and is /26.

---

[&larr; 6. Read-only pre-checks](06-read-only-pre-checks.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [8. Create the Hyper-V host HV-HOST-02 &rarr;](08-create-the-hyper-v-host-hv-host-02.md)
