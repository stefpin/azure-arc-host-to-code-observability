# 12. Red Hat OpenShift 4.20 cluster

<sub>Part C - Build the virtual machines, OpenShift and the Azure Arc connection &nbsp;|&nbsp; [Guide index](README.md)</sub>


> [!NOTE]
> **Approval Gate**
>
> G5. The 60-day OpenShift trial starts when you create the cluster, and the cluster must then run without interruption for at least 24 hours. Start this chapter no later than two days before the demo and no earlier than about seven weeks before it.

## 12.1 Before you start

- HV-HOST-02 is running and you can keep it running (Chapter 6.5).
- DNS answers for api.ocp-minibank.minibank-demo.lab and \*.apps.ocp-minibank.minibank-demo.lab (Chapter 9.4).
- The SSH public key exists in F:\Build\ocp\id_ed25519.pub (Chapter 9.6).
- You do the Red Hat console steps in **Microsoft Edge on HV-HOST-02**, signed in with your Red Hat account, so that the discovery ISO and the kubeconfig file are downloaded straight onto the host.
## 12.2 Create the four OpenShift VMs

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

The VMs get fixed-size disks (better for etcd, the cluster database), fixed memory, fixed MAC addresses (the installer matches the static IP addresses to them), Secure Boot with the template for Linux, a higher CPU priority than the application VMs, and no checkpoints. Creating the four fixed-size disks takes about 15 minutes; they are created in parallel.

```powershell
$nodes = @(
  @{ N = 'OCP-NODE-1'; D = 'P'; Mac = '00155D6E0021'; Cpu = 6; Mem = 24GB; Auto = 'Start' },
  @{ N = 'OCP-NODE-2'; D = 'Q'; Mac = '00155D6E0022'; Cpu = 6; Mem = 24GB; Auto = 'Start' },
  @{ N = 'OCP-NODE-3'; D = 'R'; Mac = '00155D6E0023'; Cpu = 6; Mem = 24GB; Auto = 'Start' },
  @{ N = 'OCP-NODE-4'; D = 'S'; Mac = '00155D6E0024'; Cpu = 4; Mem = 16GB; Auto = 'Nothing' })
$jobs = foreach ($n in $nodes) {
  Start-Job -ArgumentList "$($n.D):\VMs\$($n.N).vhdx" -ScriptBlock { param($p) New-VHD -Path $p -SizeBytes 120GB -Fixed } }
$jobs | Wait-Job | Receive-Job | Format-Table Path, @{n='GB';e={$_.Size/1GB}}
foreach ($n in $nodes) {
  New-VM -Name $n.N -Generation 2 -MemoryStartupBytes $n.Mem -VHDPath "$($n.D):\VMs\$($n.N).vhdx" `
    -SwitchName AppMonNAT -Path "$($n.D):\VMs" | Out-Null
  Set-VM -Name $n.N -ProcessorCount $n.Cpu -StaticMemory -CheckpointType Disabled `
    -AutomaticStartAction $n.Auto -AutomaticStopAction ShutDown
  Set-VMProcessor -VMName $n.N -RelativeWeight 200
  Set-VMNetworkAdapter -VMName $n.N -StaticMacAddress $n.Mac -MacAddressSpoofing On
  Add-VMDvdDrive -VMName $n.N
  Set-VMFirmware -VMName $n.N -EnableSecureBoot On -SecureBootTemplate MicrosoftUEFICertificateAuthority
  Set-VMFirmware -VMName $n.N -BootOrder (Get-VMHardDiskDrive -VMName $n.N), (Get-VMDvdDrive -VMName $n.N)
}
Get-VM OCP-NODE-* | Format-Table Name, State, ProcessorCount, @{n='MemGB';e={$_.MemoryStartup/1GB}}
Get-VMNetworkAdapter -VMName OCP-NODE-* | Format-Table VMName, MacAddress
```

> [!TIP]
> **What you should see**
>
> Four VMs, Off, with 6, 6, 6 and 4 processors, 24, 24, 24 and 16 GB, and MAC addresses 00155D6E0021 to 00155D6E0024.

> [!TIP]
> **Beginner tip**
>
> The boot order is hard disk first, DVD second. On the first start the disk is empty, so the VM boots the discovery ISO. After the installer has written to the disk, every restart boots from the disk, so a node never starts the installer twice. MAC address spoofing is not strictly required for OpenShift's virtual IP addresses; it is switched on as a harmless lab precaution.

## 12.3 Create the cluster in the Assisted Installer

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on HV-HOST-02, https://console.redhat.com, signed in with your Red Hat account.

1. Click **OpenShift** in the left menu, then **Clusters**, then **Create cluster**.
1. Open the **Datacenter** tab. Under **Assisted Installer**, click **Create cluster**.
1. **Cluster details** page:
1. **Cluster name**: ocp-minibank
1. **Base domain**: minibank-demo.lab
1. **OpenShift version**: choose the newest **OpenShift 4.20.x**. The list also offers newer versions (4.21, 4.22, 5.0); if 4.20 is not shown, click **Show all available versions**.
1. **CPU architecture**: x86_64
1. **Integrate with external partner platforms**: No platform integration
1. **Number of control plane nodes**: 3
1. **Hosts' network configuration**: **Static IP, bridges, and bonds**
1. Leave encryption off. Click **Next**.
1. **Static network configurations** page, **Form view**:
1. **Networking stack type**: IPv4. **Use VLAN**: off.
1. **DNS**: 192.168.110.1. **Machine network**: 192.168.110.0/24. **Default gateway**: 192.168.110.1. Click **Next**.
1. **Host specific configurations**: MAC address 00:15:5D:6E:00:21, IP address 192.168.110.21. Click **Add another host configuration**: 00:15:5D:6E:00:22 and 192.168.110.22. Add a third: 00:15:5D:6E:00:23 and 192.168.110.23. Do not add the fourth node here. Click **Next**.
1. **Operators** page: select nothing. Click **Next**.
1. **Host discovery** page: click **Add hosts**.
1. **Provisioning type**: **Full image file: Provision with physical media**.
1. **SSH public key**: paste the single line from F:\Build\ocp\id_ed25519.pub (open it with notepad F:\Build\ocp\id_ed25519.pub).
1. Click **Generate Discovery ISO**, then click **Download Discovery ISO**. When Edge has finished (about 1 GB), close the dialog.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
Move-Item "$env:USERPROFILE\Downloads\*discovery*.iso" F:\ISO\ocp-minibank-discovery.iso -Force
foreach ($n in 'OCP-NODE-1','OCP-NODE-2','OCP-NODE-3') {
  Set-VMDvdDrive -VMName $n -Path F:\ISO\ocp-minibank-discovery.iso
  Start-VM $n }
Get-VM OCP-NODE-* | Format-Table Name, State, Uptime
```

## 12.4 Host discovery

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on HV-HOST-02, Assisted Installer page of ocp-minibank.

1. Within 2 to 5 minutes, three hosts appear in the **Host Inventory** table. Their names come from DNS (ocp-node-1, ocp-node-2, ocp-node-3). If a name differs, click it and change it to the right ocp-node name.
1. Set **Role** to **Control plane node** for all three (or leave Auto-assign, which chooses the same for a three-node cluster).
1. Wait until every host shows **Ready**. Click **Next**.
1. **Storage** page: each host shows its 120 GB disk (/dev/sda) as the installation disk. Click **Next**.

> [!WARNING]
> **If something goes wrong**
>
> If a host shows Insufficient or Not ready, click the status text to see which check failed. The usual causes are: a node's clock differs too much from the others (wait a few minutes; Hyper-V time synchronisation corrects it), too little memory or CPU (compare with Chapter 12.2), or the host cannot reach the internet (check Get-NetNat on HV-HOST-02). If a host never appears, open its console in Hyper-V Manager to see whether it booted from the ISO.

## 12.5 Networking, review and install

1. **Networking** page:
1. **Network management**: Cluster-Managed Networking.
1. **Networking stack type**: IPv4. **Network type**: OVN-Kubernetes.
1. **Machine network**: 192.168.110.0/24.
1. **API IP**: 192.168.110.10. **Ingress IP**: 192.168.110.11.
1. Keep **Use the same host discovery SSH key** ticked. Wait until all hosts show Ready again, then click **Next**.
1. **Review and create** page: check cluster name ocp-minibank, base domain minibank-demo.lab, version 4.20.x, three control plane nodes, API IP and Ingress IP. Click **Install cluster**.
1. The installation runs for about 60 to 90 minutes. The nodes restart several times by themselves. Do not touch the VMs.

> [!TIP]
> **What you should see**
>
> The status ends with Installed, and the page shows the Web Console URL (https://console-openshift-console.apps.ocp-minibank.minibank-demo.lab), the user kubeadmin and a password field.

> [!WARNING]
> **If something goes wrong**
>
> If a node shows "Pending user action", it restarted from the ISO instead of its disk. In HV-HOST-02 PowerShell run Set-VMDvdDrive -VMName &lt;NODE&gt; -Path $null, then Restart-VM &lt;NODE&gt; -Force. Never delete the cluster in the console to start over without asking the lab owner.

## 12.6 Save the access details and test

1. On the cluster page, click the eye icon next to the kubeadmin password and copy it into ENVIRONMENT.txt.
1. Click **Download kubeconfig**. (The download is offered for 20 days; keep the file.)

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```bash
Move-Item "$env:USERPROFILE\Downloads\kubeconfig*" F:\Build\ocp\kubeconfig -Force
foreach ($n in 'OCP-NODE-1','OCP-NODE-2','OCP-NODE-3') { Set-VMDvdDrive -VMName $n -Path $null }
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
oc whoami
oc get nodes -o wide
oc get clusteroperators
oc get clusterversion
oc new-project minibank
```

> [!TIP]
> **What you should see**
>
> oc whoami prints system:admin. Three nodes ocp-node-1 to ocp-node-3, STATUS Ready, ROLES control-plane,master,worker, VERSION v1.33.x. Every cluster operator shows AVAILABLE True, PROGRESSING False, DEGRADED False. The cluster version is 4.20.x. The project minibank is created.

1. Open the web console in Edge: https://console-openshift-console.apps.ocp-minibank.minibank-demo.lab. Edge warns about the certificate because the lab uses OpenShift's own certificate: click **Advanced**, then **Continue**. Log in with kubeadmin and the password.
1. Write the date and time of the installation into ENVIRONMENT.txt. The cluster must not be shut down until 24 hours after this time. As built, the installation finished at 20:21 WIB on 10 November 2026, so HV-HOST-02 had to keep running at least until 20:21 WIB on 11 November 2026.

> [!TIP]
> **Beginner tip**
>
> OpenShift's internal image registry is switched off (state Removed) on this kind of installation. That is expected: MiniBank's image comes from Azure Container Registry.

## 12.7 etcd backup (24 hours after the installation, and before any planned shutdown)

The rule is unchanged: do not stop the host for 24 hours after the installation, then take this backup. As built, the installation finished at 20:21 WIB on 10 November 2026, so the first backup was due after 20:21 WIB on 11 November 2026.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator), after the start block of Chapter 5.5, which sets KUBECONFIG and the path of oc. Paste the block at the PS F:\Build&gt; prompt and press Enter.

```bash
oc debug --as-root node/ocp-node-1 -- chroot /host /usr/local/bin/cluster-backup.sh /home/core/assets/backup
oc debug node/ocp-node-1 -- chroot /host ls -l /home/core/assets/backup
```

> [!TIP]
> **What you should see**
>
> Two files: snapshot_&lt;date-time&gt;.db and static_kuberesources_&lt;date-time&gt;.tar.gz. Run the backup on one control-plane node only, and never in the first 24 hours after the installation.

## 12.8 Prepare the fourth worker (the day before the demo)

> [!NOTE]
> **Approval Gate**
>
> G8.

Adding a node takes about 20 to 30 minutes, too long to wait for live. The VM is therefore booted and discovered in advance (decision D3), and the presenter only clicks Install during Scene 1.

1. Red Hat console in Edge on HV-HOST-02: open cluster **ocp-minibank**, tab **Add hosts**, click **Add hosts**.
1. **CPU architecture** x86_64. If the dialog offers **Hosts' network configuration**, choose **Static IP, bridges, and bonds** and enter: DNS 192.168.110.1, machine network 192.168.110.0/24, gateway 192.168.110.1, MAC 00:15:5D:6E:00:24, IP 192.168.110.24. If the dialog does not offer static settings, do the DHCP fallback below first.
1. **Provisioning type** Full image file, paste the same SSH public key, click **Generate Discovery ISO**, then **Download Discovery ISO**.
1. In HV-HOST-02 PowerShell (Admin):

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
Move-Item "$env:USERPROFILE\Downloads\*discovery*.iso" F:\ISO\ocp-minibank-addhost.iso -Force
Set-VMDvdDrive -VMName OCP-NODE-4 -Path F:\ISO\ocp-minibank-addhost.iso
Start-VM OCP-NODE-4
```

1. In the Add hosts list, wait until ocp-node-4 shows **Ready**. If a role is asked, choose **Worker**. **Stop here.** Do not click Install until Scene 1.
1. During Scene 1 (or the rehearsal), click **Install ready hosts**. In a second HV-HOST-02 PowerShell (Admin) window, run the certificate approval loop below. It approves the node's certificate requests as they arrive and stops after 30 minutes.

> [!NOTE]
> **Where to run it**
>
> A second HV-HOST-02 - PowerShell (Admin) window in the Bastion session (Start, right-click Windows PowerShell &gt; Run as administrator). The block sets KUBECONFIG itself; leave the window open while the node joins.

```powershell
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
for ($i = 0; $i -lt 60; $i++) {
  oc get csr --no-headers 2>$null | Where-Object { $_ -match 'Pending' } |
    ForEach-Object { oc adm certificate approve ($_ -split '\s+')[0] }
  Start-Sleep -Seconds 30 }
```

> [!TIP]
> **What you should see**
>
> About 20 to 30 minutes after Install, oc get nodes shows ocp-node-4 Ready with role worker.

DHCP fallback (only if step 2 offered no static settings): give OCP-NODE-4 its address through a DHCP reservation on HV-HOST-02, limited to the lab switch.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null
Add-DhcpServerv4Scope -Name 'AppMon lab' -StartRange 192.168.110.200 -EndRange 192.168.110.220 -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.110.0 -Router 192.168.110.1 -DnsServer 192.168.110.1 -DnsDomain minibank-demo.lab
Add-DhcpServerv4Reservation -ScopeId 192.168.110.0 -IPAddress 192.168.110.24 -ClientId '00-15-5D-6E-00-24' -Name ocp-node-4
Get-DhcpServerv4Binding | Where-Object InterfaceAlias -ne 'vEthernet (AppMonNAT)' | Set-DhcpServerv4Binding -BindingState $false
Set-DhcpServerv4Binding -InterfaceAlias 'vEthernet (AppMonNAT)' -BindingState $true
Restart-Service DHCPServer
Get-DhcpServerv4Binding | Format-Table InterfaceAlias, BindingState
```

> [!TIP]
> **What you should see**
>
> Only vEthernet (AppMonNAT) has BindingState True. The DHCP server never answers on the Azure network adapter.

---

[&larr; 11. Application VMs, Azure Arc and the Azure Monitor Agent](11-application-vms-azure-arc-and-the-azure-monitor-agent.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [13. OpenShift in Azure Arc, Container insights and managed Prometheus &rarr;](13-openshift-in-azure-arc-container-insights-and-managed-promet.md)
