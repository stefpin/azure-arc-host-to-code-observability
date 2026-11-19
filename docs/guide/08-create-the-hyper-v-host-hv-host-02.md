# 8. Create the Hyper-V host HV-HOST-02

<sub>Part B - Build the Azure foundation and the host &nbsp;|&nbsp; [Guide index](README.md)</sub>


> [!NOTE]
> **Approval Gate**
>
> G2. This chapter creates the most expensive item in the lab. Do it only after G2 is approved.

## 8.1 Create the virtual machine

> [!NOTE]
> **Where to run it**
>
> Azure Portal (recommended for this step), or Cloud Shell - PowerShell for the CLI path.

Portal path, Basics tab:

1. Search for **Virtual machines**, click **+ Create**, then **Azure virtual machine**.
1. **Resource group** rg-appmon-openshift-demo. **Virtual machine name** HV-HOST-02. **Region** (Asia Pacific) Indonesia Central.
1. **Availability options**: No infrastructure redundancy required.
1. **Security type**: **Standard**. Do not choose Trusted launch: the host must run Hyper-V inside Azure (nested virtualization) and this lab uses the same setting as HV-HOST-01.
1. **Image**: click **See all images**, search for Windows Server, and choose **Windows Server 2025 Datacenter - x64 Gen2**. Do not choose Azure Edition or Server Core.
1. **Size**: click **See all sizes**, search for E20s, choose **Standard_E20s_v5** (20 vCPUs, 160 GiB memory), click **Select**.
1. **Administrator account**: Username labadmin, and a strong password that you write into ENVIRONMENT.txt.
1. **Public inbound ports**: None.
1. **Licensing**: leave the Azure Hybrid Benefit box unticked unless you are entitled to it.

Disks tab:

1. **OS disk size**: 128 GiB. **OS disk type**: Premium SSD (locally-redundant storage). Keep **Delete with VM** ticked.
1. Under **Data disks**, click **Create and attach a new disk** five times, each time with **Disk SKU** Premium SSD LRS:

| LUN | Name | Size | Used for |
|---|---|---|---|
| 0 | HV-HOST-02-data-apps | 512 GiB (P20) | Drive F: application VMs, ISO files, build files |
| 1 | HV-HOST-02-data-ocp1 | 256 GiB (P15) | Drive P: OCP-NODE-1 |
| 2 | HV-HOST-02-data-ocp2 | 256 GiB (P15) | Drive Q: OCP-NODE-2 |
| 3 | HV-HOST-02-data-ocp3 | 256 GiB (P15) | Drive R: OCP-NODE-3 |
| 4 | HV-HOST-02-data-ocp4 | 256 GiB (P15) | Drive S: OCP-NODE-4 |

1. After the five disks are listed, set **Host caching** to **Read/write** for each of them, as on HV-HOST-01. Tick **Delete with VM** for each data disk.

Networking tab:

1. **Virtual network** vnet-appmon, **Subnet** snet-appmon-host (10.60.1.0/24).
1. **Public IP**: None.
1. **NIC network security group**: None (the subnet's network security group already protects the host).
1. Tick **Delete NIC when VM is deleted**.

Management tab:

1. **Patch orchestration options**: Manual updates.
1. **Enable auto-shutdown**: unticked.

Monitoring tab: keep **Boot diagnostics** set to Enable with managed storage account.

Tags tab: purpose, demo and owner as before, and &lt;EXEMPT_TAG&gt; = &lt;EXEMPT_VALUE&gt; (Chapter 7.1). Click **Review + create**, check that the summary shows Standard_E20s_v5, Security type Standard and five data disks, then click **Create**.

CLI path (creates the VM first and then attaches the five named disks):

```powershell
$pw = Read-Host 'New labadmin password for HV-HOST-02' -AsSecureString
$plain = [System.Net.NetworkCredential]::new('', $pw).Password
az vm create -g $RG -n $HV -l $LOC --size Standard_E20s_v5 `
  --image MicrosoftWindowsServer:WindowsServer:2025-datacenter-g2:latest --security-type Standard `
  --admin-username labadmin --admin-password $plain --vnet-name $VNET --subnet snet-appmon-host `
  --public-ip-address "" --nsg "" --os-disk-size-gb 128 --storage-sku Premium_LRS `
  --patch-mode Manual --enable-auto-update false `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin <EXEMPT_TAG>=<EXEMPT_VALUE> -o table
Remove-Variable plain
$disks = @(@{n='HV-HOST-02-data-apps';s=512;l=0}, @{n='HV-HOST-02-data-ocp1';s=256;l=1},
           @{n='HV-HOST-02-data-ocp2';s=256;l=2}, @{n='HV-HOST-02-data-ocp3';s=256;l=3},
           @{n='HV-HOST-02-data-ocp4';s=256;l=4})
foreach ($d in $disks) {
  az disk create -g $RG -n $d.n -l $LOC --size-gb $d.s --sku Premium_LRS -o none
  az vm disk attach -g $RG --vm-name $HV --name $d.n --lun $d.l --caching ReadWrite -o none
}
az vm show -g $RG -n $HV -d --query "{Size:hardwareProfile.vmSize, Security:securityProfile.securityType, IP:privateIps, Power:powerState, DataDisks:length(storageProfile.dataDisks)}" -o table
```

> [!TIP]
> **What you should see**
>
> Size Standard_E20s_v5, Security Standard (or empty, which also means Standard), IP 10.60.1.4, Power VM running, DataDisks 5.

> [!WARNING]
> **If something goes wrong**
>
> If the size is not available, do not pick another family on your own: rerun Chapter 6.2 and ask. If Security shows TrustedLaunch, the host cannot run Hyper-V; ask the lab owner before deleting and recreating the VM.

## 8.2 Connect to HV-HOST-02 with Bastion

1. In the Azure Portal, open the virtual machine **HV-HOST-02**.
1. Click **Connect** at the top, then **Connect via Bastion**.
1. **Authentication Type**: VM Password. **Username**: labadmin. **VM Password**: the host password from ENVIRONMENT.txt.
1. Tick **Open in new browser tab** and click **Connect**. Allow pop-ups if the browser asks.
1. On the host desktop, click Start, type PowerShell, right-click **Windows PowerShell** and choose **Run as administrator**. Click **Yes**.

> [!TIP]
> **What you should see**
>
> A Windows Server 2025 desktop and a PowerShell window whose title starts with Administrator.

> [!TIP]
> **Beginner tip**
>
> Bastion Basic gives you the desktop in your browser. Copy and paste works through the small arrow on the left edge of the Bastion window (the clipboard panel). Paste long command blocks into the clipboard panel first, then press Ctrl+V in PowerShell.

## 8.3 Keep the host running

1. In the Portal, open HV-HOST-02, click **Operations**, then **Auto-shutdown**, and confirm that it is **Off**.
1. Write the host's private IP address (10.60.1.4) and the creation time into ENVIRONMENT.txt.
1. From now on, check every morning that HV-HOST-02 is Running (Chapter 22.2).

---

[&larr; 7. Resource group, network, NAT gateway and Bastion](07-resource-group-network-nat-gateway-and-bastion.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [9. Prepare HV-HOST-02 &rarr;](09-prepare-hv-host-02.md)
