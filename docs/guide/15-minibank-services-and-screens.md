# 15. MiniBank services and screens

<sub>Part D - Build MiniBank, database monitoring, dashboards and alerts &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 15.1 minibank-fraud (Python) on APP-RHEL

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash.

For Python, the onboarding change is one package (azure-monitor-opentelemetry, in requirements.txt) and two lines at the top of app.py (the import and configure_azure_monitor()). The connection string comes from the environment file, not from the code.

```bash
sudo useradd --system --home-dir /opt/minibank --shell /sbin/nologin minibank
sudo mkdir -p /opt/minibank/fraud /etc/minibank
sudo cp ~/minibank/fraud/app.py ~/minibank/fraud/requirements.txt /opt/minibank/fraud/
sudo python3.11 -m venv /opt/minibank/fraud/.venv
sudo /opt/minibank/fraud/.venv/bin/pip install --upgrade pip
sudo /opt/minibank/fraud/.venv/bin/pip install -r /opt/minibank/fraud/requirements.txt
sudo chown -R minibank:minibank /opt/minibank/fraud
read -rsp 'PostgreSQL password of minibank_app: ' PGPW; echo
read -rp 'Application Insights connection string: ' APPICS
printf 'PG_DSN=postgresql://minibank_app:%s@127.0.0.1:5432/minibank\nAPPLICATIONINSIGHTS_CONNECTION_STRING=%s\nOTEL_SERVICE_NAME=minibank-fraud\n' \
  "$PGPW" "$APPICS" | sudo tee /etc/minibank/fraud.env > /dev/null
unset PGPW APPICS
sudo chown root:root /etc/minibank/fraud.env && sudo chmod 600 /etc/minibank/fraud.env
sudo cp ~/minibank/fraud/minibank-fraud.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now minibank-fraud
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.110.0/24" port port="8082" protocol="tcp" accept'
sudo firewall-cmd --reload
sleep 5
curl -s http://127.0.0.1:8082/health; echo
curl -s -X POST http://127.0.0.1:8082/fraud/check -H 'Content-Type: application/json' \
  -d '{"referenceNo":"TEST0001","channel":"TRANSFER","amount":100000,"scenario":"normal"}'; echo
```

> [!TIP]
> **What you should see**
>
> pip ends with Successfully installed ... azure-monitor-opentelemetry-1.8.12. The health call returns status ok, and the test call returns a decision APPROVE.

> [!TIP]
> **Beginner tip**
>
> The firewall reload in this block does not break the Oracle container, because netavark-firewalld-reload.service (Chapter 14.2) restores podman's rules after every reload.

> [!WARNING]
> **If something goes wrong**
>
> In APP-RHEL - Bash run sudo journalctl -u minibank-fraud -n 50 --no-pager. "connection refused" to 127.0.0.1:5432 means PostgreSQL is stopped; "password authentication failed" means the password in /etc/minibank/fraud.env is wrong.

## 15.2 minibank-transfer (Java) on OpenShift

> [!NOTE]
> **Approval Gate**
>
> G5.

Step 1. Build the container image with podman on APP-RHEL and push it to the registry with the push token of Chapter 10.4. ACR Tasks (az acr build) is not available in Indonesia Central, so the build cannot run inside Azure: the fallback of version 1.2 is now the main path. You do not need Docker anywhere.

> [!NOTE]
> **Where to run it**
>
> APP-RHEL - Bash (ssh -i F:\Build\ocp\id_ed25519 labadmin@192.168.110.32 from HV-HOST-02).

```bash
cd ~/minibank/transfer
read -rp 'Container registry name (ACR-NAME): ' ACR
sudo podman build -t "$ACR.azurecr.io/minibank-transfer:1.1.0" .
sudo podman login "$ACR.azurecr.io" -u minibank-push
sudo podman push "$ACR.azurecr.io/minibank-transfer:1.1.0"
```

When podman login asks for the password, paste the password of the push token minibank-push from ENVIRONMENT.txt. Then check the registry.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block with $ACR filled in.

```powershell
az acr repository show-tags -n $ACR --repository minibank-transfer -o table
```

> [!TIP]
> **What you should see**
>
> The build downloads the Red Hat UBI base images and Maven packages, builds the jar and ends with the new image ID. podman login prints Login Succeeded!, and podman push ends with Writing manifest to image destination. The tag list in Cloud Shell shows 1.1.0.

> [!WARNING]
> **If something goes wrong**
>
> unauthorized at login or push means that the push token password is wrong or has expired (7 days). In Cloud Shell make a new one with az acr token credential generate -n minibank-push -r $ACR --password1 --expiration-in-days 7 --query "passwords[0].value" -o tsv and log in again.

> [!TIP]
> **Beginner tip**
>
> In a region that offers ACR Tasks, the same image can be built inside Azure: in Cloud Shell, in the folder ~/minibank/transfer, run az acr build --registry $ACR --image minibank-transfer:1.1.0 --file Dockerfile . (Indonesia Central does not offer it).

> [!TIP]
> **Beginner tip**
>
> Look at transfer\Dockerfile: the only monitoring change is that the Application Insights Java agent file is added to the image and started with -javaagent. The Java code itself is unchanged. The connection string is given to the container at runtime through a Kubernetes secret.

Step 2. Create the two secrets and deploy.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block in Chapter 5.5 (KUBECONFIG set).

```powershell
function Read-Secret([string]$Prompt) { [Net.NetworkCredential]::new('', (Read-Host $Prompt -AsSecureString)).Password }
$ACR  = Read-Host 'Container registry name (ACR-NAME)'
$tok  = Read-Secret 'Token password of minibank-pull'
$ora  = Read-Secret 'Oracle MINIBANK password'
$appi = Read-Host 'Application Insights connection string'
oc project minibank
oc create secret docker-registry acr-pull -n minibank --docker-server="$ACR.azurecr.io" `
  --docker-username=minibank-pull --docker-password=$tok
oc create secret generic minibank-transfer-secrets -n minibank `
  --from-literal=ORACLE_PASSWORD=$ora --from-literal=APPLICATIONINSIGHTS_CONNECTION_STRING=$appi
Remove-Variable tok, ora
$deploy = 'F:\Build\minibank\openshift\10-deployment.yaml'
(Get-Content $deploy) -replace 'ACR_NAME', $ACR | Set-Content $deploy
oc apply -f F:\Build\minibank\openshift\
oc rollout status deployment/minibank-transfer -n minibank --timeout=10m
oc get pods -n minibank -o wide
Invoke-RestMethod http://minibank-transfer.apps.ocp-minibank.minibank-demo.lab/actuator/health
```

> [!TIP]
> **What you should see**
>
> Three minibank-transfer pods Running, normally one on each of ocp-node-1, ocp-node-2 and ocp-node-3, and the health call returns status UP. If two pods share a node, use Chapter 20.2.

> [!WARNING]
> **If something goes wrong**
>
> ImagePullBackOff (oc describe pod -n minibank &lt;POD&gt;): the registry name or token password is wrong, or the pull token has expired (30 days, Chapter 22.2); delete the secret with oc delete secret acr-pull -n minibank and create it again. CrashLoopBackOff: run oc logs -n minibank deploy/minibank-transfer; an Oracle error means a wrong MINIBANK password or a missing firewall rule for 1521 on APP-RHEL (Chapter 14.2).

> [!TIP]
> **Beginner tip**
>
> The deployment spreads the three copies over the nodes (topology spread), allows at most one copy to be unavailable during maintenance (pod disruption budget minAvailable 2) and moves pods away from an unreachable node after 60 seconds instead of the default 5 minutes. These three settings are what make Scenes 9 and 10 work. The spread is a preference, not a hard rule: it lets Scene 9 move the lost pod to the two remaining nodes, but Kubernetes never moves running pods back by itself.

Step 3. Name the Oracle calls oracle.db in Application Insights (as built on 11 November 2026).

Azure Monitor shows every Oracle call of minibank-transfer with the type SQL: its exporter turns the database name "oracle" into SQL and keeps a name of its own only for MySQL and PostgreSQL. A rule in the Java agent renames the type to oracle.db, the OpenTelemetry name for Oracle Database, and keeps the target 192.168.110.32 | freepdb1. The rule lives in a ConfigMap next to the image, so the image is not rebuilt.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block in Chapter 5.5.

The file below is the original transfer\applicationinsights.json with one more processor at the end; the original file stays unchanged.

```powershell
$f = 'F:\Build\minibank\transfer\applicationinsights-oracle.json'
@'
{
  "role": { "name": "minibank-transfer" },
  "selfDiagnostics": { "destination": "console", "level": "INFO" },
  "sampling": {
    "percentage": 100,
    "overrides": [
      {
        "telemetryType": "request",
        "attributes": [
          { "key": "url.path", "value": "/actuator/health.*", "matchType": "regexp" }
        ],
        "percentage": 0
      }
    ]
  },
  "preview": {
    "processors": [
      {
        "type": "attribute",
        "actions": [
          {
            "key": "url.path",
            "pattern": "(?<prefix>/api/ledger/)\\d{6}(?<last4>\\d{4})",
            "replace": "${prefix}******${last4}",
            "action": "mask"
          },
          {
            "key": "minibank.account",
            "pattern": "\\d{6}(?<last4>\\d{4})",
            "replace": "******${last4}",
            "action": "mask"
          }
        ]
      },
      {
        "type": "attribute",
        "include": {
          "matchType": "strict",
          "attributes": [
            { "key": "db.system", "value": "oracle" }
          ]
        },
        "actions": [
          { "key": "peer.service", "value": "192.168.110.32", "action": "insert" },
          { "key": "db.system", "value": "oracle.db", "action": "update" }
        ]
      }
    ]
  }
}
'@ | Set-Content -Path $f -Encoding ascii
Get-Content $f -Raw | ConvertFrom-Json | Out-Null; "JSON OK"
```

Load the file into the cluster and point the Java agent at it. The pause and resume make all changes land in one rolling restart.

```bash
oc create configmap minibank-transfer-ai-config -n minibank --from-file=applicationinsights.json=$f
oc label configmap minibank-transfer-ai-config -n minibank app=minibank-transfer purpose=appinsights-config
oc rollout pause deployment/minibank-transfer -n minibank
oc set volume deployment/minibank-transfer -n minibank --add --name=ai-config --type=configmap `
  --configmap-name=minibank-transfer-ai-config --mount-path=/config/appinsights
oc set env deployment/minibank-transfer -n minibank APPLICATIONINSIGHTS_CONFIGURATION_FILE=/config/appinsights/applicationinsights.json
oc rollout resume deployment/minibank-transfer -n minibank
oc rollout status deployment/minibank-transfer -n minibank --timeout=10m
oc get pods -n minibank -o wide
```

> [!TIP]
> **What you should see**
>
> JSON OK, then configmap created and labeled, the deployment paused, updated and resumed, "successfully rolled out" after one to two minutes, and three new pods Running. If two of them share a node, use Chapter 20.2.

Check the result after about 5 minutes in law-appmon, **Logs**:

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
AppDependencies
| where TimeGenerated > ago(15m) and AppRoleName == "minibank-transfer"
| summarize Calls = sum(ItemCount), Last = max(TimeGenerated) by DependencyType, Target
```

> [!TIP]
> **What you should see**
>
> A row with the type oracle.db and the target 192.168.110.32 \| freepdb1 (INSERT and SELECT on freepdb1.LEDGER_ENTRY), next to HTTP for 192.168.110.32:8082 (the fraud service). Rows with the type SQL for the same target are older than the restart.

> [!WARNING]
> **If something goes wrong**
>
> Check in HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5. A new pod stays in ContainerCreating: the ConfigMap name is wrong (oc describe pod -n minibank &lt;POD&gt;). The type stays SQL: check oc exec deploy/minibank-transfer -n minibank -- printenv APPLICATIONINSIGHTS_CONFIGURATION_FILE, and that oc logs -n minibank deploy/minibank-transfer shows "Application Insights Java Agent 3.7.9 started successfully"; an error in the JSON stops the agent. To undo the change, run oc set env deployment/minibank-transfer -n minibank APPLICATIONINSIGHTS_CONFIGURATION_FILE- and the pods use the file inside the image again.

> [!CAUTION]
> **Be honest**
>
> Telemetry processors are a preview feature of the Java agent; the masking of account numbers already uses them. Exactly "oracle" is not possible, because that is the name Azure Monitor turns into SQL. Calls recorded before the change keep the type SQL, the Application Map shows a plain icon for oracle.db, and after an upgrade of the Java agent (version 3.7.9 in the Dockerfile) check that the type is still oracle.db.

> [!TIP]
> **Beginner tip**
>
> In a fresh build you can run this step straight after Step 2. Whether to keep the rule in a ConfigMap or to build it into the image is still open (Appendix E.1).

## 15.3 minibank-api (.NET) on APP-WIN

> [!NOTE]
> **Approval Gate**
>
> G4 (IIS, .NET and a firewall rule on APP-WIN).

> [!NOTE]
> **Where to run it**
>
> APP-WIN - PowerShell Direct. Run all blocks of 15.3 and 15.4 in one session. If the session closes, open it again and run the two $env lines at the end of Step 2 before you continue.

Step 1. IIS and the mirrored service account (same password as on APP-SQL):

```powershell
Install-WindowsFeature Web-Server -IncludeManagementTools | Select-Object Success, RestartNeeded
$pw = Read-Host 'Password of minibank-svc (the same as on APP-SQL)' -AsSecureString
New-LocalUser -Name minibank-svc -Password $pw -PasswordNeverExpires -AccountNeverExpires `
  -Description 'MiniBank demo service account' | Out-Null
Add-LocalGroupMember -Group IIS_IUSRS -Member minibank-svc
```

Step 2. ASP.NET Core Hosting Bundle (lets IIS run .NET applications) and the .NET 10 SDK (for building). As built, Invoke-WebRequest to the Hosting Bundle permalink returned HTTP 400 or an HTML page instead of the installer. The block therefore reads the .NET 10.0 release list with curl.exe, takes the Hosting Bundle URL of the newest release (10.0.14 on 10 November 2026) and downloads it with curl.exe:

```powershell
New-Item -ItemType Directory -Path C:\tools -Force | Out-Null
curl.exe -sSL --fail -o C:\tools\releases-10.0.json https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json
$meta = Get-Content C:\tools\releases-10.0.json -Raw | ConvertFrom-Json
$rel = $meta.releases | Where-Object { $_.'release-version' -eq $meta.'latest-release' } | Select-Object -First 1
$hb = $rel.'aspnetcore-runtime'.files | Where-Object { $_.name -like 'dotnet-hosting*win.exe' } | Select-Object -First 1
"Hosting Bundle $($rel.'release-version'): $($hb.url)"
curl.exe -L --fail -o C:\tools\dotnet-hosting-bundle.exe $hb.url
Start-Process C:\tools\dotnet-hosting-bundle.exe -ArgumentList '/install','/quiet','/norestart' -Wait
net stop was /y; net start w3svc
Invoke-WebRequest -UseBasicParsing -OutFile C:\tools\dotnet-install.ps1 -Uri https://dot.net/v1/dotnet-install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\tools\dotnet-install.ps1 -Channel 10.0 -InstallDir C:\tools\dotnet
$env:Path = 'C:\tools\dotnet;' + $env:Path
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
dotnet --version
Test-Path 'C:\Program Files\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll'
```

> [!TIP]
> **What you should see**
>
> A line such as Hosting Bundle 10.0.14 followed by its download URL (a newer release is fine), dotnet --version prints a version that starts with 10.0, and Test-Path prints True. The health call at the end of Step 4 proves that IIS can run the API.

> [!WARNING]
> **If something goes wrong**
>
> If the Hosting Bundle line shows no URL, open https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json in Edge on HV-HOST-02, copy the hosting bundle URL of the newest release by hand and run the curl.exe and Start-Process lines with it.

Step 3. Build and publish the API. For .NET, the monitoring change is one package (Azure.Monitor.OpenTelemetry.AspNetCore in MiniBank.Api.csproj) and one line in Program.cs (UseAzureMonitor()).

```powershell
Set-Location C:\Build\minibank\api
dotnet publish -c Release -r win-x64 --self-contained true -o C:\inetpub\minibank-api
New-Item -ItemType Directory -Path C:\inetpub\minibank-api\wwwroot -Force | Out-Null
```

> [!TIP]
> **What you should see**
>
> The build ends with MiniBank.Api -&gt; C:\inetpub\minibank-api\ and 0 errors.

Step 4. Telemetry settings, application pool, website and firewall:

```powershell
$appi = Read-Host 'Application Insights connection string'
[Environment]::SetEnvironmentVariable('APPLICATIONINSIGHTS_CONNECTION_STRING', $appi, 'Machine')
[Environment]::SetEnvironmentVariable('OTEL_SERVICE_NAME', 'minibank-api', 'Machine')
Import-Module WebAdministration
New-WebAppPool -Name minibank | Out-Null
Set-ItemProperty IIS:\AppPools\minibank -Name managedRuntimeVersion -Value ''
$c = Get-Credential -UserName 'APP-WIN\minibank-svc' -Message 'Password of minibank-svc'
Set-ItemProperty IIS:\AppPools\minibank -Name processModel -Value @{
  userName = $c.UserName; password = $c.GetNetworkCredential().Password; identityType = 3 }
New-Website -Name minibank-api -Port 8080 -ApplicationPool minibank -PhysicalPath C:\inetpub\minibank-api | Out-Null
New-NetFirewallRule -DisplayName 'MiniBank web and API 8080' -Direction Inbound -Protocol TCP -LocalPort 8080 `
  -RemoteAddress 192.168.110.0/24 -Action Allow | Out-Null
iisreset
Invoke-RestMethod http://localhost:8080/api/health
```

> [!TIP]
> **What you should see**
>
> The health call returns status ok, service minibank-api and version 1.1.0.

> [!WARNING]
> **If something goes wrong**
>
> HTTP 500.30 or 502.5 means the API could not start: open Event Viewer on APP-WIN (in the VM console), Windows Logs, Application, and look for IIS AspNetCore Module V2 errors.

## 15.4 minibank-web (React screens)

Step 1 (optional). Add your own logo. Without a logo file the header shows the text wordmark MiniBank, which is all the demo needs.

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on HV-HOST-02, then HV-HOST-02 - PowerShell (Admin).

1. Save your logo in Downloads on HV-HOST-02, then copy it into the web project on APP-WIN. Use the name logo.svg for an SVG file and logo.png for a PNG file (a JPG file also works under the name logo.png):
```powershell
$logo = Get-ChildItem "$env:USERPROFILE\Downloads" | Sort-Object LastWriteTime -Descending |
  Where-Object Extension -in '.svg','.png','.jpg' | Select-Object -First 1
$target = if ($logo.Extension -eq '.svg') { 'logo.svg' } else { 'logo.png' }
Copy-VMFile -Name APP-WIN -SourcePath $logo.FullName -FileSource Host -CreateFullPath -Force `
  -DestinationPath "C:\Build\minibank\web\public\brand\$target"
"Copied $($logo.Name) as $target"
```

> [!TIP]
> **Beginner tip**
>
> The logo appears only on the white header bar. Use a logo you own or are allowed to use.

Step 2. Install Node.js (portable) and build the screens. As built, Invoke-WebRequest returned HTTP 400 for the Node.js download, so the block uses curl.exe: it reads https://nodejs.org/dist/index.json, picks the newest v24.x and downloads its zip file.

> [!NOTE]
> **Where to run it**
>
> APP-WIN - PowerShell Direct (same session as 15.3).

```powershell
curl.exe -sSL --fail -o C:\tools\node-index.json https://nodejs.org/dist/index.json
$v = ((Get-Content C:\tools\node-index.json -Raw | ConvertFrom-Json) | Where-Object { $_.version -like 'v24.*' } | Select-Object -First 1).version
curl.exe -L --fail -o C:\tools\node.zip "https://nodejs.org/dist/$v/node-$v-win-x64.zip"
Expand-Archive C:\tools\node.zip -DestinationPath C:\tools -Force
$env:Path = "C:\tools\node-$v-win-x64;" + $env:Path
node --version
Set-Location C:\Build\minibank\web
npm.cmd install
npm.cmd run build
Copy-Item C:\Build\minibank\web\dist\* C:\inetpub\minibank-api\wwwroot -Recurse -Force
Get-ChildItem C:\inetpub\minibank-api\wwwroot, C:\inetpub\minibank-api\wwwroot\brand | Format-Table Name
```

> [!TIP]
> **What you should see**
>
> node --version prints v24.x. npm install ends with added ... packages, and the build prints dist/index.html and built in ... s. wwwroot holds index.html, an assets folder and a brand folder (with your logo, if you added one).

> [!WARNING]
> **If something goes wrong**
>
> Use npm.cmd, not npm: in some PowerShell windows npm is blocked by the script execution policy. Expand-Archive can take 3 to 5 minutes without showing progress.

> [!TIP]
> **Beginner tip**
>
> For React, the monitoring change is one package (@microsoft/applicationinsights-web) and one small file (src\telemetry.js). The browser reads the connection string from the API at start-up (GET /api/config), so the same build works in every environment.

## 15.5 Test the whole chain

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin).

```powershell
$base = 'http://192.168.110.31:8080'
Invoke-RestMethod "$base/api/health"
$login = Invoke-RestMethod -Method Post -Uri "$base/api/login" -ContentType 'application/json' `
  -Body (@{ userId = 'ANDI.WIJAYA'; password = 'Demo123!' } | ConvertTo-Json)
$login
$acc = Invoke-RestMethod "$base/api/accounts?customerId=$($login.customerId)"   # no @( ) here: Windows PowerShell 5.1 would wrap the whole list as one item
$acc | Format-Table accountNo, productName, balance
$body = @{ fromAccount = $acc[0].accountNo; toAccount = $acc[1].accountNo; amount = 250000
           note = 'chain test'; pin = '123456'; scenario = 'normal' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$base/api/transfer" -ContentType 'application/json' -Body $body
```

> [!TIP]
> **What you should see**
>
> The login returns customerId and fullName Andi Wijaya, two accounts are listed, and the transfer returns a reference number with status SUCCESS.

Now test the screens. In Microsoft Edge on HV-HOST-02, open http://192.168.110.31:8080 and check:

1. The white header bar shows the word MiniBank (and your logo, if you added one), with the EN/ID switch on the right, and the yellow DEMO banner is visible.
1. Log in as ANDI.WIJAYA with Demo123!. The Home screen shows the blue greeting band, the account card with a hidden balance and the round menu icons.
1. Make one transfer (PIN 123456): the proof of transaction appears.
1. Open http://192.168.110.31:8080/#/demo, choose **fail-oracle**, click **Apply**, make one more transfer: the failure screen shows a Trace ID. Choose **normal** again.

> [!TIP]
> **What you should see**
>
> After 3 to 5 minutes, appi-minibank, Application map in the Azure Portal shows minibank-web, minibank-api, minibank-transfer and minibank-fraud connected by arrows, plus SQL Server (192.168.110.33), Oracle (shown as 192.168.110.32 \| freepdb1, with the type oracle.db after Chapter 15.2 Step 3) and PostgreSQL.

> [!WARNING]
> **If something goes wrong**
>
> A missing service on the map: minibank-web means the page was not opened yet; minibank-api means the machine environment variable is missing (rerun 15.3 Step 4 and iisreset); minibank-transfer means the secret has a wrong connection string (oc logs -n minibank deploy/minibank-transfer shows the agent's messages); minibank-fraud means /etc/minibank/fraud.env is wrong (journalctl -u minibank-fraud). "Login failed for user APP-SQL\minibank-svc" means the two minibank-svc passwords differ.

---

[&larr; 14. Databases](14-databases.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [16. Database-internal monitoring of Oracle and PostgreSQL &rarr;](16-database-internal-monitoring-of-oracle-and-postgresql.md)
