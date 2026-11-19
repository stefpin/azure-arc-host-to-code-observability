# 9. Prepare HV-HOST-02

<sub>Part B - Build the Azure foundation and the host &nbsp;|&nbsp; [Guide index](README.md)</sub>


Every step in this chapter runs inside HV-HOST-02.

## 9.1 Data disks, folders and basic settings

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
# Initialise only the five new, empty (RAW) data disks, chosen by their Azure LUN number
$plan = @{ 0 = @('F','APPS'); 1 = @('P','OCP1'); 2 = @('Q','OCP2'); 3 = @('R','OCP3'); 4 = @('S','OCP4') }
foreach ($lun in 0..4) {
  $disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Location -match "LUN $lun$" }
  if (-not $disk) { Write-Host "LUN $lun - no RAW disk found (already done?)"; continue }
  $letter = $plan[$lun][0]; $label = $plan[$lun][1]
  Initialize-Disk -Number $disk.Number -PartitionStyle GPT
  New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $letter |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false | Out-Null
  Write-Host "LUN $lun -> $($letter): $label"
}
New-Item -ItemType Directory -Force -Path F:\VMs, F:\ISO, F:\Build, F:\Build\ocp, P:\VMs, Q:\VMs, R:\VMs, S:\VMs | Out-Null
Set-TimeZone -Id 'SE Asia Standard Time'
Set-LocalUser -Name labadmin -PasswordNeverExpires $true
Get-Volume | Where-Object DriveLetter | Sort-Object DriveLetter | Format-Table DriveLetter, FileSystemLabel, Size
```

> [!TIP]
> **What you should see**
>
> Volumes C (OS), F (APPS, about 512 GB), P, Q, R and S (OCP1 to OCP4, about 256 GB each).

> [!WARNING]
> **If something goes wrong**
>
> If a LUN shows "no RAW disk found" on a fresh host, open Disk Management (right-click Start, Disk Management) and check that five unallocated disks exist. Never initialise the OS disk.

Now create ENVIRONMENT.txt in F:\Build with Notepad (notepad F:\Build\ENVIRONMENT.txt) and copy the worksheet values you already have.

## 9.2 Install Hyper-V and the DNS Server role

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
Install-WindowsFeature -Name Hyper-V, DNS -IncludeManagementTools
Restart-Computer   # initial build only
```

Wait two minutes, reconnect through Bastion (Chapter 8.2), open PowerShell (Admin) again and check:

```powershell
Get-WindowsFeature Hyper-V, DNS | Format-Table Name, InstallState
Get-CimInstance Win32_ComputerSystem | Format-List Name, HypervisorPresent, NumberOfLogicalProcessors, TotalPhysicalMemory
```

> [!TIP]
> **What you should see**
>
> Hyper-V and DNS Installed, HypervisorPresent True, 20 logical processors, about 171,000,000,000 bytes (160 GiB) of memory.

## 9.3 Internal switch and NAT for the lab network

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
if (-not (Get-VMSwitch -Name AppMonNAT -ErrorAction SilentlyContinue)) {
  New-VMSwitch -Name AppMonNAT -SwitchType Internal | Out-Null }
if (-not (Get-NetIPAddress -InterfaceAlias 'vEthernet (AppMonNAT)' -IPAddress 192.168.110.1 -ErrorAction SilentlyContinue)) {
  New-NetIPAddress -InterfaceAlias 'vEthernet (AppMonNAT)' -IPAddress 192.168.110.1 -PrefixLength 24 | Out-Null }
if (-not (Get-NetNat -Name AppMonNAT -ErrorAction SilentlyContinue)) {
  New-NetNat -Name AppMonNAT -InternalIPInterfaceAddressPrefix 192.168.110.0/24 | Out-Null }
Set-VMHost -VirtualHardDiskPath F:\VMs -VirtualMachinePath F:\VMs -EnableEnhancedSessionMode $true
Get-VMSwitch AppMonNAT | Format-Table Name, SwitchType
Get-NetNat AppMonNAT | Format-Table Name, InternalIPInterfaceAddressPrefix
```

> [!TIP]
> **What you should see**
>
> Switch AppMonNAT of type Internal, and NAT AppMonNAT for 192.168.110.0/24.

> [!TIP]
> **Beginner tip**
>
> Hyper-V Manager shows the same switch under Virtual Switch Manager. Never create an External switch on an Azure VM: it would cut the host off from the network.

## 9.4 DNS for the lab (zone minibank-demo.lab)

OpenShift needs names for its API and its applications. The DNS Server role on HV-HOST-02 answers for the lab zone minibank-demo.lab and forwards every other question to Azure DNS.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
$z = 'minibank-demo.lab'
Add-DnsServerPrimaryZone -Name $z -ZoneFile "$z.dns"
Add-DnsServerPrimaryZone -NetworkId '192.168.110.0/24' -ZoneFile '110.168.192.in-addr.arpa.dns'
$records = [ordered]@{
  'hv-host-02'='192.168.110.1'; 'api.ocp-minibank'='192.168.110.10'; 'api-int.ocp-minibank'='192.168.110.10'
  'ocp-node-1'='192.168.110.21'; 'ocp-node-2'='192.168.110.22'; 'ocp-node-3'='192.168.110.23'; 'ocp-node-4'='192.168.110.24'
  'app-win'='192.168.110.31'; 'app-rhel'='192.168.110.32'; 'app-sql'='192.168.110.33' }
foreach ($r in $records.GetEnumerator()) {
  Add-DnsServerResourceRecordA -ZoneName $z -Name $r.Key -IPv4Address $r.Value -CreatePtr }
Add-DnsServerResourceRecordA -ZoneName $z -Name '*.apps.ocp-minibank' -IPv4Address 192.168.110.11
Set-DnsServerForwarder -IPAddress 168.63.129.16
# Let the host itself use this DNS server for the lab zone only
Add-DnsClientNrptRule -Namespace '.minibank-demo.lab' -NameServers '192.168.110.1'
Resolve-DnsName api.ocp-minibank.minibank-demo.lab | Format-Table Name, IPAddress
Resolve-DnsName test.apps.ocp-minibank.minibank-demo.lab | Format-Table Name, IPAddress
Resolve-DnsName www.microsoft.com -Server 192.168.110.1 | Select-Object -First 2 | Format-Table Name, Type
```

> [!TIP]
> **What you should see**
>
> api.ocp-minibank.minibank-demo.lab resolves to 192.168.110.10, test.apps.ocp-minibank.minibank-demo.lab to 192.168.110.11, and www.microsoft.com resolves through 192.168.110.1.

> [!TIP]
> **Beginner tip**
>
> The wildcard record \*.apps.ocp-minibank means that every application route of the cluster, such as the OpenShift console or MiniBank's transfer service, finds the ingress address without a separate DNS record.

## 9.5 Download the operating-system media

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on HV-HOST-02 (inside the Bastion session), then HV-HOST-02 - PowerShell (Admin).

1. Open Edge and go to https://www.microsoft.com/evalcenter/download-windows-server-2022. Fill in the short form and download the **ISO, 64-bit edition, English**.
1. Open https://developers.redhat.com/products/rhel/download, sign in with your Red Hat account and download the newest **Red Hat Enterprise Linux 9.x, x86_64 DVD ISO** (for example 9.7 or later). Do not choose RHEL 10.
1. Move both files into F:\ISO and give them short names:
```powershell
Move-Item "$env:USERPROFILE\Downloads\*SERVER_EVAL*x64FRE_en-us.iso" F:\ISO\WS2022-eval.iso
Get-ChildItem "$env:USERPROFILE\Downloads\rhel-9*-x86_64-dvd.iso" | Select-Object -First 1 | Move-Item -Destination F:\ISO\rhel-9-x86_64-dvd.iso
Get-ChildItem F:\ISO | Format-Table Name, @{n='GB';e={[math]::Round($_.Length/1GB,1)}}
```

> [!TIP]
> **What you should see**
>
> WS2022-eval.iso (about 5 GB) and rhel-9-x86_64-dvd.iso (about 11 GB) in F:\ISO.

> [!WARNING]
> **If something goes wrong**
>
> If a file name differs, use File Explorer to rename it. Later chapters use exactly these two names.

## 9.6 Tools on the host: Azure CLI and the OpenShift CLI

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
# Azure CLI
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile F:\Build\AzureCLI.msi -UseBasicParsing
Start-Process msiexec.exe -Wait -ArgumentList '/I F:\Build\AzureCLI.msi /quiet /norestart'
# OpenShift CLI 4.20 (oc.exe and kubectl.exe)
New-Item -ItemType Directory -Force -Path C:\Tools\oc | Out-Null
Invoke-WebRequest -Uri https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.20/openshift-client-windows.zip `
  -OutFile F:\Build\openshift-client-windows.zip -UseBasicParsing
Expand-Archive F:\Build\openshift-client-windows.zip -DestinationPath C:\Tools\oc -Force
[Environment]::SetEnvironmentVariable('Path', "C:\Tools\oc;" + [Environment]::GetEnvironmentVariable('Path','Machine'), 'Machine')
# SSH key that the Assisted Installer puts on the OpenShift nodes
ssh-keygen -t ed25519 -f F:\Build\ocp\id_ed25519 -q -N '""'
Get-Content F:\Build\ocp\id_ed25519.pub
```

Close PowerShell and open a new PowerShell (Admin) window so that the new Path is used, then check:

```bash
az version --query '"azure-cli"'
oc version --client
```

> [!TIP]
> **What you should see**
>
> An Azure CLI version number and Client Version 4.20.x.

---

[&larr; 8. Create the Hyper-V host HV-HOST-02](08-create-the-hyper-v-host-hv-host-02.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [10. Monitoring and supporting Azure items &rarr;](10-monitoring-and-supporting-azure-items.md)
