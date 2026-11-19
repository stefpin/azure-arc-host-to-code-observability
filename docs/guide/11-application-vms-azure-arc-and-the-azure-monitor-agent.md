# 11. Application VMs, Azure Arc and the Azure Monitor Agent

<sub>Part C - Build the virtual machines, OpenShift and the Azure Arc connection &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 11.1 Create the three application VMs

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
$vms = @(
  @{ Name = 'APP-WIN';  Mem = 8GB;  Iso = 'F:\ISO\WS2022-eval.iso' },
  @{ Name = 'APP-SQL';  Mem = 12GB; Iso = 'F:\ISO\WS2022-eval.iso' },
  @{ Name = 'APP-RHEL'; Mem = 12GB; Iso = 'F:\ISO\rhel-9-x86_64-dvd.iso' })
foreach ($v in $vms) {
  New-VM -Name $v.Name -Generation 2 -MemoryStartupBytes $v.Mem -SwitchName AppMonNAT `
    -NewVHDPath "F:\VMs\$($v.Name).vhdx" -NewVHDSizeBytes 127GB | Out-Null
  Set-VM -Name $v.Name -ProcessorCount 4 -StaticMemory -AutomaticCheckpointsEnabled $false `
    -AutomaticStartAction Start -AutomaticStopAction ShutDown
  Add-VMDvdDrive -VMName $v.Name -Path $v.Iso
  Set-VMFirmware -VMName $v.Name -FirstBootDevice (Get-VMDvdDrive -VMName $v.Name)
  Enable-VMIntegrationService -VMName $v.Name -Name 'Guest Service Interface'
}
Set-VMFirmware -VMName APP-RHEL -SecureBootTemplate MicrosoftUEFICertificateAuthority
Get-VM APP-* | Format-Table Name, State, ProcessorCount, @{n='MemoryGB';e={$_.MemoryStartup/1GB}}
```

> [!TIP]
> **What you should see**
>
> Three VMs, all Off, with 4 processors and 8, 12 and 12 GB of memory.

> [!TIP]
> **Beginner tip**
>
> Generation 2 VMs boot with UEFI. Windows uses the default Secure Boot template; Linux needs the template MicrosoftUEFICertificateAuthority, which the last Set-VMFirmware line sets for APP-RHEL.

## 11.2 Install Windows Server 2022 on APP-WIN and APP-SQL

Do these steps first for APP-WIN, then repeat them for APP-SQL.

> [!NOTE]
> **Where to run it**
>
> Hyper-V Manager and the VM console on HV-HOST-02.

1. In HV-HOST-02 PowerShell (Admin), run Start-VM APP-WIN; vmconnect.exe localhost APP-WIN.
1. The console window shows "Press any key to boot from CD or DVD". Click inside the window and press a key immediately. If you miss it and see a boot error, click **Action**, **Reset**, and press a key again.
1. Windows Setup: keep **English (United States)** and the US keyboard, click **Next**, then **Install now**.
1. Choose **Windows Server 2022 Standard Evaluation (Desktop Experience)** and click **Next**.
1. Tick **I accept the Microsoft Software License Terms**, click **Next**.
1. Choose **Custom: Install Microsoft Server Operating System only**. Select **Drive 0 Unallocated Space** and click **Next**. Installation takes about 10 minutes and restarts the VM by itself.
1. When asked, type the Windows guest Administrator password from ENVIRONMENT.txt twice and click **Finish**. Use the same password on APP-WIN and APP-SQL.
1. Close the console window. The VM keeps running.

Now give the VM its address, name and time zone. Run this once for APP-WIN and once for APP-SQL, changing the two values on the first line.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
$vm = 'APP-WIN'; $ip = '192.168.110.31'      # for the second run: 'APP-SQL' and '192.168.110.33'
$cred = Get-Credential Administrator
Invoke-Command -VMName $vm -Credential $cred -ArgumentList $vm, $ip -ScriptBlock {
  param($name, $addr)
  $nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
  New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $addr -PrefixLength 24 -DefaultGateway 192.168.110.1 | Out-Null
  Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 192.168.110.1
  Set-DnsClient -InterfaceIndex $nic.ifIndex -ConnectionSpecificSuffix 'minibank-demo.lab'
  Set-TimeZone -Id 'SE Asia Standard Time'
  New-Item -ItemType Directory -Path C:\Build -Force | Out-Null
  Rename-Computer -NewName $name -Force -Restart
}
Get-VMDvdDrive -VMName $vm | Set-VMDvdDrive -Path $null
```

Wait one minute for the restart, then test:

```powershell
Invoke-Command -VMName $vm -Credential $cred -ScriptBlock {
  hostname; (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet*).IPAddress
  Resolve-DnsName api.ocp-minibank.minibank-demo.lab | Select-Object -ExpandProperty IPAddress
  (Invoke-WebRequest https://www.microsoft.com -UseBasicParsing).StatusCode }
```

> [!TIP]
> **What you should see**
>
> The new name (APP-WIN or APP-SQL), the expected IP address, 192.168.110.10 for the OpenShift API name, and 200 for the internet test.

> [!WARNING]
> **If something goes wrong**
>
> If the internet test fails, check on HV-HOST-02 that Get-NetNat shows AppMonNAT and that the guest's gateway is 192.168.110.1. Do not run Windows Update during the build: it can restart the guests. The evaluation edition activates itself over the internet and runs for 180 days.

As built, APP-WIN and APP-SQL were not installed through Setup in the VM console: the Windows image (WIM) from the ISO was applied to their virtual disks on HV-HOST-02. If you build the Windows guests that way, read the next box first.

> [!WARNING]
> **If something goes wrong**
>
> Writing the boot files with the bcdboot of HV-HOST-02 failed for the new EFI partition. What worked: create the EFI partition as a basic data partition with a drive letter, run the image's own bcdboot (&lt;OS drive&gt;:\Windows\System32\bcdboot.exe &lt;OS drive&gt;:\Windows /s &lt;EFI drive&gt;: /f UEFI), remove the drive letter, then switch the partition type to EFI System (Set-Partition -DiskNumber &lt;disk&gt; -PartitionNumber &lt;partition&gt; -GptType "{&lt;GUID&gt;}", or in diskpart set id=&lt;GUID&gt; override).

## 11.3 Install RHEL 9 on APP-RHEL

> [!NOTE]
> **Where to run it**
>
> Hyper-V Manager and the VM console on HV-HOST-02.

1. Run Start-VM APP-RHEL; vmconnect.exe localhost APP-RHEL. At the boot menu choose **Install Red Hat Enterprise Linux 9.x** (the version you downloaded) and press Enter.
1. Language: **English (United States)**, click **Continue**.
1. **Installation Destination**: select the 127 GiB disk, keep **Automatic**, click **Done**.
1. **Network & Host Name**: Host Name app-rhel.minibank-demo.lab, click **Apply**. Select the Ethernet adapter, click **Configure...**, open **IPv4 Settings**, Method **Manual**, click **Add**: Address 192.168.110.32, Netmask 24, Gateway 192.168.110.1. **DNS servers** 192.168.110.1, **Search domains** minibank-demo.lab. Click **Save**, switch the adapter **ON**, click **Done**.
1. **Time & Date**: Region Asia, City Jakarta, Network Time on. Click **Done**.
1. **Software Selection**: **Server** (without GUI). Click **Done**.
1. **Connect to Red Hat**: choose **Account**, type your Red Hat user name and password, click **Register**. (If registration fails here, skip it and use the command after installation.)
1. **Root Password**: leave the root account locked.
1. **User Creation**: Full name Lab Admin, User name labadmin, tick **Make this user administrator**, type the Linux guest password from ENVIRONMENT.txt twice, click **Done**.
1. Click **Begin Installation**. After about 10 minutes click **Reboot System**, then close the console.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), then APP-RHEL - Bash.

```bash
Get-VMDvdDrive -VMName APP-RHEL | Set-VMDvdDrive -Path $null
# copy the lab key to labadmin once (the last time you type the Linux guest password), then log in with the key
ssh labadmin@192.168.110.32 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(Get-Content F:\Build\ocp\id_ed25519.pub)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh -i F:\Build\ocp\id_ed25519 labadmin@192.168.110.32
# inside APP-RHEL: register (only if step 7 was skipped) and update the package lists
sudo subscription-manager register --username <RED-HAT-USER>     # asks for the password; skip if already registered
sudo subscription-manager status
sudo dnf -y install podman unzip jq tar curl python3.11 python3.11-pip
sudo timedatectl set-timezone Asia/Jakarta
hostnamectl --static; ip -4 addr show eth0 | grep inet; getent hosts api.ocp-minibank.minibank-demo.lab
```

> [!TIP]
> **What you should see**
>
> subscription-manager shows Overall Status: Registered (or Simple Content Access), dnf ends with Complete!, the host name is app-rhel.minibank-demo.lab, the address is 192.168.110.32 and the API name resolves to 192.168.110.10.

> [!WARNING]
> **If something goes wrong**
>
> If ssh says Connection refused or times out, open the VM console and check the IP settings with nmcli. If the network adapter is not named eth0, use ip -4 addr to see its name.

## 11.4 Copy the source pack into the guests

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
foreach ($vm in 'APP-WIN','APP-SQL') {
  Copy-VMFile -Name $vm -SourcePath F:\Build\MiniBank-source-pack-v1.3.zip `
    -DestinationPath C:\Build\MiniBank-source-pack-v1.3.zip -CreateFullPath -FileSource Host -Force
  Invoke-Command -VMName $vm -Credential $cred -ScriptBlock {
    Expand-Archive C:\Build\MiniBank-source-pack-v1.3.zip -DestinationPath C:\Build -Force
    Test-Path C:\Build\minibank\MANIFEST.md }
}
scp -i F:\Build\ocp\id_ed25519 F:\Build\MiniBank-source-pack-v1.3.zip labadmin@192.168.110.32:/home/labadmin/
ssh -i F:\Build\ocp\id_ed25519 labadmin@192.168.110.32 "unzip -oq ~/MiniBank-source-pack-v1.3.zip -d ~ && ls ~/minibank"
```

> [!TIP]
> **What you should see**
>
> True twice (Windows guests) and the list of folders from APP-RHEL.

## 11.5 Block Azure metadata access inside the guests (lab only)

The application VMs are nested inside an Azure VM. Without this step, the Azure Arc agent would detect the Azure metadata service of HV-HOST-02 through the NAT and refuse to install. A real on-premises server never sees that service. This block exists only to make the lab behave like a real data centre; you never do it on real servers.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) for the Windows guests.

```powershell
Invoke-Command -VMName APP-WIN, APP-SQL -Credential $cred -ScriptBlock {
  if (-not (Get-NetFirewallRule -Name BlockAzureIMDS -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name BlockAzureIMDS -DisplayName 'Block Azure IMDS (lab only)' -Enabled True `
      -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254 | Out-Null }
  [pscustomobject]@{ Computer = $env:COMPUTERNAME
    IMDSReachable = (Test-NetConnection 169.254.169.254 -Port 80 -WarningAction SilentlyContinue).TcpTestSucceeded }
}
```

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

```bash
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -d 169.254.169.254/32 -j REJECT
sudo firewall-cmd --reload
curl --max-time 3 -sS -H Metadata:true 'http://169.254.169.254/metadata/instance?api-version=2021-02-01' || echo "IMDS blocked - OK"
```

> [!TIP]
> **What you should see**
>
> IMDSReachable False for APP-WIN and APP-SQL, and IMDS blocked - OK on APP-RHEL.

## 11.6 Connect the three guests to Azure Arc

> [!NOTE]
> **Approval Gate**
>
> G4.

The Portal can generate the onboarding script for you (Azure Arc, **Infrastructure**, **Machines**, **+ Onboard/Create**, **Onboard existing machines**, then follow the wizard to **Generate script**; the button names can change slightly over time). The commands below do the same thing in a way that is easier to copy. Each guest signs in with a device code: the command prints a short code, you open https://microsoft.com/devicelogin on your own computer, type the code and sign in with the lab account.

> [!NOTE]
> **Where to run it**
>
> APP-WIN - PowerShell Direct (Chapter 5.6). Repeat in APP-SQL - PowerShell Direct, changing the resource name and adding the extra tag shown in the comment.

```powershell
Invoke-WebRequest -UseBasicParsing -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile C:\Build\AzureConnectedMachineAgent.msi
Start-Process msiexec.exe -Wait -ArgumentList '/i C:\Build\AzureConnectedMachineAgent.msi /qn /l*v C:\Build\arc-install.log'
$arc = "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe"
& $arc check --location indonesiacentral
& $arc connect --resource-name APP-WIN --resource-group rg-appmon-openshift-demo `
  --tenant-id <GUID> --subscription-id <SUBSCRIPTION_ID> `
  --location indonesiacentral --cloud AzureCloud --use-device-code `
  --tags "purpose=appmon-openshift-demo,demo=minibank,owner=labadmin"
# APP-SQL: --resource-name APP-SQL and add ",ArcSQLServerExtensionDeployment=Disabled" inside the --tags text
& $arc show
```

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

```bash
curl -sSL -o ~/install_linux_azcmagent.sh https://aka.ms/azcmagent
sudo bash ~/install_linux_azcmagent.sh
sudo azcmagent check --location indonesiacentral
sudo azcmagent connect --resource-name APP-RHEL --resource-group rg-appmon-openshift-demo \
  --tenant-id <GUID> --subscription-id <SUBSCRIPTION_ID> \
  --location indonesiacentral --cloud AzureCloud --use-device-code \
  --tags "purpose=appmon-openshift-demo,demo=minibank,owner=labadmin"
sudo azcmagent show
```

> [!TIP]
> **What you should see**
>
> azcmagent check lists every endpoint as reachable, and azcmagent show ends with Agent Status: Connected. In the Portal, Azure Arc, Infrastructure, Machines, filtered to the new resource group, shows APP-WIN, APP-SQL and APP-RHEL as Connected.

> [!WARNING]
> **If something goes wrong**
>
> "The machine is an Azure VM" means the metadata block in 11.5 is missing on that guest. Run 11.5 again, then azcmagent connect again. Never disable the firewall or SELinux to make onboarding work.

> [!TIP]
> **Beginner tip**
>
> The tag ArcSQLServerExtensionDeployment=Disabled on APP-SQL stops Azure Arc from installing the SQL Server extension automatically. SQL Server internals are already part of the Hyper-V demo; this lab watches SQL Server from the application side only.

## 11.7 Install the Azure Monitor Agent on the three guests

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell after the start block (CLI path), or the Azure Portal.

Portal path: Azure Arc, **Infrastructure**, **Machines**, open APP-WIN, click **Extensions**, **+ Add**, choose **Azure Monitor Agent for Windows**, click **Next**, then **Review + create**, then **Create**. Repeat for APP-SQL (Windows) and APP-RHEL (choose **Azure Monitor Agent for Linux**).

CLI path:

```powershell
az extension add -n connectedmachine --upgrade -y 2>$null
foreach ($m in 'APP-WIN','APP-SQL') {
  az connectedmachine extension create -g $RG --machine-name $m -n AzureMonitorWindowsAgent -l $LOC `
    --publisher Microsoft.Azure.Monitor --type AzureMonitorWindowsAgent --enable-auto-upgrade true -o none }
az connectedmachine extension create -g $RG --machine-name APP-RHEL -n AzureMonitorLinuxAgent -l $LOC `
  --publisher Microsoft.Azure.Monitor --type AzureMonitorLinuxAgent --enable-auto-upgrade true -o none
foreach ($m in 'APP-WIN','APP-SQL','APP-RHEL') {
  az connectedmachine extension list -g $RG --machine-name $m --query "[].{Machine:'$m', Name:name, State:provisioningState}" -o table }
```

> [!TIP]
> **What you should see**
>
> Each machine lists its Azure Monitor Agent with State Succeeded. The agent starts sending data only after a data collection rule is attached (Chapters 16 and 17).

> [!TIP]
> **Beginner tip**
>
> The list can also show the extensions MDE.Windows and MDE.Linux (Microsoft Defender for Servers). A subscription policy adds them to the Arc machines automatically. They are not part of this build; leave them.

---

[&larr; 10. Monitoring and supporting Azure items](10-monitoring-and-supporting-azure-items.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [12. Red Hat OpenShift 4.20 cluster &rarr;](12-red-hat-openshift-4-20-cluster.md)
