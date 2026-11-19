# 5. Values, tools and the start of every session

<sub>Part A - Understand and prepare &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 5.1 Worksheet

Fill in this worksheet as you build. Keep the filled copy only in ENVIRONMENT.txt (Chapter 5.2), never in this document.

| Value | Example or format | Where it comes from |
|---|---|---|
| Subscription | &lt;SUBSCRIPTION_ID&gt; | Fixed |
| Tenant | &lt;GUID&gt; | Fixed |
| Resource group and region | rg-appmon-openshift-demo, indonesiacentral | Fixed |
| Region for the Arc Kubernetes resource (ARCLOC) | indonesiacentral, or southeastasia | Chapter 6.4 |
| Region for the Azure Monitor workspace (AMWLOC) | indonesiacentral, or southeastasia | Chapter 6.4 |
| Host administrator | labadmin and its password | You choose it in Chapter 8.1 |
| Windows guest administrator | Administrator and its password (APP-WIN, APP-SQL) | You choose it in Chapter 11.2 |
| Linux guest administrator | labadmin and its password (APP-RHEL) | You choose it in Chapter 11.3 |
| Service account minibank-svc | Same password on APP-WIN and APP-SQL | Chapter 14.1 |
| Container registry name (ACR-NAME) | &lt;ACR_NAME&gt; plus four digits, for example &lt;ACR_NAME&gt; | Chapter 10.4 |
| Registry token passwords (minibank-pull, minibank-push) and their expiry dates | Long random text; the pull token runs for 30 days, the push token for 7 days | Chapter 10.4 |
| Storage account name (STORAGE-NAME), optional | stminibank plus four digits | Chapter 10.5 |
| Source pack download link (PACK-URL), optional | https://... with a time limit | Chapter 10.5 |
| Application Insights connection string | InstrumentationKey=...;IngestionEndpoint=...;... | Chapter 10.2 |
| Log Analytics workspace resource ID | /subscriptions/.../workspaces/law-appmon | Chapter 10.1 |
| Azure Monitor workspace resource ID and Query endpoint | /subscriptions/.../accounts/amw-appmon and https://amw-appmon-....prometheus.monitor.azure.com | Chapter 10.3 |
| Grafana endpoint and Grafana identity (principal ID) | https://amg-appmon-....grafana.azure.com | Chapter 10.7 |
| Presenter sign-in name and object ID | &lt;LAB_ADMIN_UPN&gt; and a GUID | Chapter 13.4 |
| Red Hat account | Your Red Hat login | Chapter 6.5 |
| kubeadmin password | Shown once by the Assisted Installer | Chapter 12.6 |
| Oracle administrator password (ORACLE_PWD) | You choose it | Chapter 14.2 |
| Oracle MINIBANK and MINIBANK_MON passwords | You choose them | Chapter 14.2 |
| PostgreSQL minibank_app and postgres_exporter passwords | You choose them | Chapter 14.3 |
| Demo logins | ANDI.WIJAYA, SITI.RAHAYU, BUDI.SANTOSO, password Demo123!, PIN 123456 | Fixed, synthetic |

## 5.2 ENVIRONMENT.txt

Create one plain-text file named ENVIRONMENT.txt on HV-HOST-02 in F:\Build (after Chapter 9.1) and keep a second copy in a private, non-shared folder on your own computer. Write every value from the worksheet into it as you create it, one value per line. Never upload it to Teams, email, a shared OneDrive folder, the storage account or this document. Delete both copies when the lab is removed (Chapter 22.4).

> [!TIP]
> **Beginner tip**
>
> Make every password at least 16 characters long, with upper-case and lower-case letters and digits. Avoid the characters $, `, ' and " in passwords so that they can be pasted into PowerShell and Bash without surprises.

## 5.3 Tools

| Where | Tool | How you get it |
|---|---|---|
| Your computer | Microsoft Edge or another modern browser | Already installed |
| Your computer | Azure Cloud Shell (PowerShell) with Azure CLI | Built into the Azure Portal; nothing to install |
| Your computer | Red Hat account | Created in Chapter 6.5 |
| HV-HOST-02 | Hyper-V Manager, Windows PowerShell 5.1, OpenSSH client, Microsoft Edge | Part of Windows Server 2025 (Hyper-V after Chapter 9.2) |
| HV-HOST-02 | Azure CLI, OpenShift CLI (oc and kubectl) | Installed in Chapter 9.6 |
| APP-WIN | IIS, ASP.NET Core Hosting Bundle, .NET 10 SDK, Node.js 24 (portable) | Installed in Chapters 15.3 and 15.4 |
| APP-RHEL | podman, PostgreSQL 16, Python 3.11 | Installed in Chapters 14.2, 14.3 and 15.1 |

## 5.4 Start of every Cloud Shell session

Cloud Shell forgets everything when it closes. Run this block every time you open it. Later chapters use the variables it creates.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell. If the prompt starts with labadmin [ ~ ]$, click Switch to PowerShell first.

```powershell
$SUB    = '<SUBSCRIPTION_ID>'
$TENANT = '<GUID>'
$RG     = 'rg-appmon-openshift-demo'
$LOC    = 'indonesiacentral'
$ARCLOC = 'indonesiacentral'   # change to southeastasia only if Chapter 6.4 says so
$AMWLOC = 'indonesiacentral'   # change to southeastasia only if Chapter 6.4 says so
$VNET   = 'vnet-appmon'
$HV     = 'HV-HOST-02'
$LAW    = 'law-appmon'
$APPI   = 'appi-minibank'
$AMW    = 'amw-appmon'
$AMG    = 'amg-appmon'
$ARCK8S = 'arc-ocp-minibank'
$ACR    = '<ACR-NAME>'       # fill in after Chapter 10.4
$ST     = '<STORAGE-NAME>'   # fill in after Chapter 10.5
az account set --subscription $SUB
az account show --query "{Name:name, Subscription:id, Tenant:tenantId, User:user.name}" -o table
```

> [!TIP]
> **What you should see**
>
> Name &lt;YOUR_SUBSCRIPTION_NAME&gt;, the subscription ID above, tenant &lt;GUID&gt; and your lab account.

> [!WARNING]
> **If something goes wrong**
>
> If the subscription is different or the command says you are not logged in, run az login --tenant $TENANT --use-device-code in the same Cloud Shell - PowerShell window, follow the instructions (open https://microsoft.com/devicelogin and type the code), and run the block again.

## 5.5 Start of every HV-HOST-02 session

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin). The window title must start with Administrator.

```powershell
Set-Location F:\Build
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'      # exists after Chapter 12.6
$env:Path = "C:\Tools\oc;$env:Path"              # oc.exe and kubectl.exe, after Chapter 9.6
$RG = 'rg-appmon-openshift-demo'; $SUB = '<SUBSCRIPTION_ID>'
Get-VM | Format-Table Name, State, CPUUsage, MemoryAssigned, Uptime
```

> [!TIP]
> **What you should see**
>
> A list of the lab virtual machines and their state. Before Chapter 11 the list is empty.

## 5.6 Opening guest sessions

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```bash
# Windows guests: PowerShell Direct (works even without network)
Enter-PSSession -VMName APP-WIN -Credential (Get-Credential Administrator)
Enter-PSSession -VMName APP-SQL -Credential (Get-Credential Administrator)
 
# Linux guest: SSH with the lab key, no password (after Chapter 11.3)
ssh -i F:\Build\ocp\id_ed25519 labadmin@192.168.110.32
 
# Fallback only: password login (the password is LINUX_GUEST_PASSWORD in F:\Build\ENVIRONMENT.txt)
ssh labadmin@192.168.110.32
```

> [!TIP]
> **What you should see**
>
> The prompt changes to [APP-WIN]: PS C:\Users\Administrator\Documents&gt;, [APP-SQL]: PS ...&gt; or [labadmin@app-rhel ~]$. With the lab key APP-RHEL asks for no password, and as built sudo needs none either. Type exit to return to the host. Only if you must use the password through Bastion: copy it on HV-HOST-02 with ((Get-Content F:\Build\ENVIRONMENT.txt) -match '^LINUX_GUEST_PASSWORD=') -replace '^LINUX_GUEST_PASSWORD=' | Set-Clipboard, right-click once at the password prompt (nothing is shown) and press Enter.

---

[&larr; 4. Demo design](04-demo-design.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [6. Read-only pre-checks &rarr;](06-read-only-pre-checks.md)
