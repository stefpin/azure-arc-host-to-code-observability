# 10. Monitoring and supporting Azure items

<sub>Part B - Build the Azure foundation and the host &nbsp;|&nbsp; [Guide index](README.md)</sub>


> [!NOTE]
> **Approval Gate**
>
> G3 for 10.1 to 10.6, and G6 for 10.7.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell after the start block in Chapter 5.4, or the Azure Portal for the Portal paths.

## 10.1 Log Analytics workspace law-appmon

Portal path:

1. Search for **Log Analytics workspaces** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo, **Name** law-appmon, **Region** Indonesia Central. Add the three tags. Click **Review + Create**, then **Create**.
1. Open law-appmon. In the left menu click **Settings**, then **Usage and estimated costs**. Click **Daily cap**, choose **On**, enter 10 GB/day and click **OK**. Click **Data Retention** and keep 30 days.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az monitor log-analytics workspace create -g $RG -n $LAW -l $LOC --retention-time 30 --quota 10 `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o none
$LAWID = az monitor log-analytics workspace show -g $RG -n $LAW --query id -o tsv
$LAWID
```

> [!TIP]
> **What you should see**
>
> A resource ID ending in /workspaces/law-appmon. Copy it into ENVIRONMENT.txt.

## 10.2 Application Insights appi-minibank

Portal path:

1. Search for **Application Insights** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo, **Name** appi-minibank, **Region** Indonesia Central, **Log Analytics Workspace** law-appmon. Click **Review + create**, then **Create**.
1. Open appi-minibank. On the **Overview** page, hover over **Connection String** and click the copy icon. Paste it into ENVIRONMENT.txt.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az monitor app-insights component create --app $APPI -g $RG -l $LOC --kind web --application-type web --workspace $LAWID `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o none
az monitor app-insights component show --app $APPI -g $RG --query connectionString -o tsv
```

> [!TIP]
> **What you should see**
>
> A connection string that starts with InstrumentationKey= and contains IngestionEndpoint=https://indonesiacentral-...

## 10.3 Azure Monitor workspace amw-appmon

Portal path:

1. Search for **Azure Monitor workspaces** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo, **Name** amw-appmon, **Region** the AMWLOC region from Chapter 6.4. Click **Review + create**, then **Create**.
1. Open amw-appmon. On **Overview**, copy the **Query endpoint**. Click **Properties** (or JSON View) and copy the **Resource ID**. Paste both into ENVIRONMENT.txt.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
az monitor account create -n $AMW -g $RG -l $AMWLOC --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o none
$AMWID = az monitor account show -n $AMW -g $RG --query id -o tsv
az monitor account show -n $AMW -g $RG --query "{Id:id, QueryEndpoint:metrics.prometheusQueryEndpoint}" -o json
```

> [!TIP]
> **What you should see**
>
> The resource ID and a query endpoint ending in .prometheus.monitor.azure.com.

> [!TIP]
> **Beginner tip**
>
> Azure creates a second resource group named MA_amw-appmon_&lt;region&gt;_managed that holds the workspace's own data collection endpoint and rule. This is normal. Leave it alone apart from the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; (Chapter 7.1); it is removed together with the workspace.

## 10.4 Container registry and its two tokens

The registry stores the minibank-transfer image. ACR Tasks (az acr build) is not available in Indonesia Central, so the image is built with podman on APP-RHEL and pushed with a push token (Chapter 15.2). OpenShift pulls it with a pull token. The pull token runs for 30 days and the push token for 7 days. As built, the push token expires on 17 November 2026 and the pull token on 10 December 2026.

Portal path:

1. Search for **Container registries** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo. **Registry name**: &lt;ACR_NAME&gt; followed by four digits of your choice, for example &lt;ACR_NAME&gt; (the portal tells you if the name is taken). **Location** Indonesia Central. **Pricing plan** Basic. Click **Review + create**, then **Create**.
1. Open the registry. In the left menu click **Repository permissions**, then **Tokens**, then **+ Add**.
1. **Name** minibank-pull, **Scope map** _repositories_pull, **Status** Enabled. Click **Create**.
1. Open the token minibank-pull, click **Generate** next to password1 (if the dialog offers an expiration date, choose 30 days from today), click **Generate** again to confirm, and copy the password into ENVIRONMENT.txt. It is shown only once.
1. Repeat steps 3 to 5 for the second token: **Name** minibank-push, **Scope map** _repositories_push, expiration 7 days.

CLI path:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
$ACR = '<ACR_NAME>' + (Get-Random -Minimum 1000 -Maximum 9999)
az acr check-name -n $ACR --query nameAvailable -o tsv          # must print true
az acr create -g $RG -n $ACR -l $LOC --sku Basic --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o table
az acr token create -n minibank-pull -r $ACR --scope-map _repositories_pull --no-passwords -o none
az acr token credential generate -n minibank-pull -r $ACR --password1 --expiration-in-days 30 --query "passwords[0].value" -o tsv
az acr token create -n minibank-push -r $ACR --scope-map _repositories_push --no-passwords -o none
az acr token credential generate -n minibank-push -r $ACR --password1 --expiration-in-days 7 --query "passwords[0].value" -o tsv
"ACR name: $ACR"
```

> [!TIP]
> **What you should see**
>
> The registry is created and two commands print a long password each: first the pull token, then the push token. Write the registry name, both passwords and both expiry dates into ENVIRONMENT.txt, and set $ACR in your Cloud Shell start block.

> [!TIP]
> **Beginner tip**
>
> The pull token lets OpenShift read images and nothing else; the push token is needed only to push a new image (Chapter 15.2). When the pull token expires, every pod that restarts can no longer pull its image (ImagePullBackOff), and the always-on traffic then turns every dashboard red. Renew it before it expires (Chapter 22.2).

## 10.5 Optional: storage account, the source pack and a download link

> [!WARNING]
> **If something goes wrong**
>
> In this subscription a governance policy sets public network access to Disabled and turns shared-key access off on new storage accounts, so the SAS download link of this section does not work from Cloud Shell or from the host. As built, the source pack was copied to HV-HOST-02 without the storage account (Chapter 10.6). Keep the steps below only as an option for a subscription without this policy.

Get the source pack first: on your computer, open your OneDrive, find **MiniBank-source-pack-v1.3.zip** (it is delivered together with this runbook) and download it.

Portal path:

1. Search for **Storage accounts** and click **+ Create**.
1. Resource group rg-appmon-openshift-demo. **Storage account name**: stminibank plus four digits. **Region** Indonesia Central. **Primary service**: Azure Blob Storage or Azure Data Lake Storage Gen 2. **Performance** Standard. **Redundancy** Locally-redundant storage (LRS).
1. **Advanced** tab: leave **Allow enabling anonymous access on individual containers** unticked. Click **Review + create**, then **Create**.
1. Open the storage account. Click **Data storage**, then **Containers**, then **+ Container**. **Name** media, **Anonymous access level** Private. Click **Create**.
1. Open the container media, click **Upload**, choose MiniBank-source-pack-v1.3.zip from your computer and click **Upload**.
1. Click the uploaded file, open the **Generate SAS** tab. **Permissions**: Read. **Expiry**: 8 hours from now. **Allowed protocols**: HTTPS only. Click **Generate SAS token and URL** and copy the **Blob SAS URL** into ENVIRONMENT.txt as PACK-URL.

> [!WARNING]
> **If something goes wrong**
>
> If the upload or the SAS page says you are not authorised, open the storage account, click Access control (IAM), + Add, Add role assignment, choose Storage Blob Data Contributor, assign it to your own account, wait two minutes and try again. If Signing method offers only User delegation key, that is fine.

CLI path for the storage account and the link (the upload itself is easiest in the Portal, step 5 above):

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell on your own computer: Azure Portal (https://portal.azure.com) &gt; Cloud Shell icon (&gt;_) in the top bar. If the prompt is labadmin [ ~ ]$, click Switch to PowerShell. Run the start block of Chapter 5.4 once per session, then paste the block at the PS /home/labadmin&gt; prompt and press Enter.

```powershell
$ST = 'stminibank' + (Get-Random -Minimum 1000 -Maximum 9999)
az storage account create -n $ST -g $RG -l $LOC --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 `
  --allow-blob-public-access false --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin -o none
az storage container create --account-name $ST -n media --auth-mode login -o none
# after uploading the zip in the Portal:
$expiry = (Get-Date).ToUniversalTime().AddHours(8).ToString('yyyy-MM-ddTHH:mmZ')
az storage blob generate-sas --account-name $ST -c media -n MiniBank-source-pack-v1.3.zip --permissions r `
  --expiry $expiry --auth-mode login --as-user --https-only --full-uri -o tsv
```

> [!TIP]
> **What you should see**
>
> A URL that starts with https://stminibank and ends with a long query string. This is PACK-URL.

## 10.6 Copy the source pack onto HV-HOST-02 and into Cloud Shell

As built, the pack was copied to HV-HOST-02 without the storage account: download it in Microsoft Edge on HV-HOST-02 from your own OneDrive, then unzip it to F:\Build\minibank.

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on HV-HOST-02 (inside the Bastion session), then HV-HOST-02 - PowerShell (Admin).

1. In Edge on HV-HOST-02, open your OneDrive and sign in with your work account.
1. Find MiniBank-source-pack-v1.3.zip and download it. Edge saves it in your Downloads folder.
1. Unzip it:
```powershell
Move-Item "$env:USERPROFILE\Downloads\MiniBank-source-pack-v1.3.zip" F:\Build\MiniBank-source-pack-v1.3.zip -Force
Expand-Archive F:\Build\MiniBank-source-pack-v1.3.zip -DestinationPath F:\Build -Force
Get-ChildItem F:\Build\minibank | Format-Table Name
```

> [!TIP]
> **What you should see**
>
> The folders api, db, fraud, monitoring, openshift, scripts, transfer and web, and the files README.md and MANIFEST.md, under F:\Build\minibank.

Optional, only if the download link of Chapter 10.5 works in your subscription (instead of steps 1 to 3):

```powershell
$PackUrl = Read-Host 'Paste PACK-URL'
Invoke-WebRequest -Uri $PackUrl -OutFile F:\Build\MiniBank-source-pack-v1.3.zip -UseBasicParsing
Expand-Archive F:\Build\MiniBank-source-pack-v1.3.zip -DestinationPath F:\Build -Force
```

> [!TIP]
> **Beginner tip**
>
> PACK-URL stops working after 8 hours. If you need the pack again later, generate a new link (step 6 of 10.5).

Cloud Shell needs the pack too: for the table definition in Chapter 16.1 and the IIS transformation in Chapter 17.7. In Cloud Shell, click **Manage files**, then **Upload**, and choose MiniBank-source-pack-v1.3.zip from your own computer. Then unzip it:

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell.

```powershell
Expand-Archive ~/MiniBank-source-pack-v1.3.zip -DestinationPath ~ -Force
Get-ChildItem ~/minibank | Select-Object Name
```

> [!TIP]
> **What you should see**
>
> The same folders and files under ~/minibank.

> [!TIP]
> **Beginner tip**
>
> Cloud Shell can lose its files when it closes. If ~/minibank is missing later, upload and unzip the pack again.

> [!TIP]
> **Beginner tip**
>
> To bring a lab that was built with an older pack to version 1.3, unzip the new pack over the old folder with the same Expand-Archive line (-Force replaces the changed files), then copy the new top-up scripts to APP-SQL (Chapter 17.10). The unzip also brings back the placeholder ACR_NAME in openshift\10-deployment.yaml: replace it again before you apply that folder (Chapter 15.2).

## 10.7 Azure Managed Grafana amg-appmon and its read access

> [!NOTE]
> **Approval Gate**
>
> G6. Create amg-appmon in the lab resource group, give it read access, add the Prometheus data source and import two dashboards (the data source and the dashboards follow in Chapter 17.4). Nothing in rg-hyperv-arc-monitor-demo is touched.

The lab has its own Azure Managed Grafana, amg-appmon, inside rg-appmon-openshift-demo, so deleting the resource group later removes it too. A Managed Grafana instance is needed because "Azure Monitor dashboards with Grafana", the free Grafana feature of the Azure Portal, is not available in Indonesia Central.

| Setting | Value |
|---|---|
| Name and resource group | amg-appmon in rg-appmon-openshift-demo |
| Region | Indonesia Central |
| Pricing plan | Standard (instance size X1) |
| Grafana version | 12 |
| Public network access | Enabled |
| API keys | Disabled |
| Zone redundancy | Disabled |
| Tags | purpose, demo and owner as in Chapter 7.1, plus &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; |
| Cost | About US$0.086 per hour, about US$2 per day, about US$63 per month (Standard X1, list price checked 10 November 2026) |

> [!TIP]
> **Beginner tip**
>
> Use Grafana 12, not 13. Grafana 13 needs the separate Azure Prometheus plugin, and the dashboard files of the source pack use the built-in "prometheus" data source type.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell after the start block (Chapter 5.4) for the CLI path, or the Azure Portal for the Portal path. Use only one of the two paths.

CLI path:

```powershell
az extension add --name amg --upgrade --only-show-errors
az grafana create -g $RG -n $AMG -l indonesiacentral --sku-tier Standard --grafana-major-version 12 --skip-role-assignments `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin <EXEMPT_TAG>=<EXEMPT_VALUE> -o none
$G = az grafana show -g $RG -n $AMG --query "{Id:id, Endpoint:properties.endpoint, PrincipalId:identity.principalId}" -o json | ConvertFrom-Json
$G
$AMWID = az monitor account show -n $AMW -g $RG --query id -o tsv
az role assignment create --assignee-object-id $G.PrincipalId --assignee-principal-type ServicePrincipal `
  --role "Monitoring Reader" --scope "/subscriptions/$SUB/resourceGroups/$RG" -o table
az role assignment create --assignee-object-id $G.PrincipalId --assignee-principal-type ServicePrincipal `
  --role "Monitoring Data Reader" --scope $AMWID -o table
$ME = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee-object-id $ME --assignee-principal-type User --role "Grafana Admin" --scope $G.Id -o table
az grafana show -g $RG -n $AMG --query "{Sku:sku.name, Version:properties.grafanaVersion, Public:properties.publicNetworkAccess, ApiKey:properties.apiKey, ZoneRedundancy:properties.zoneRedundancy}" -o table
```

> [!TIP]
> **Beginner tip**
>
> The option --skip-role-assignments matters. Without it, Azure gives the Grafana identity the role Monitoring Reader on the whole subscription. In this lab every role assignment stays inside the lab: the Grafana managed identity gets Monitoring Reader on the resource group and Monitoring Data Reader on amw-appmon, and you, the presenter, get Grafana Admin on amg-appmon.

Portal path:

1. Search for **Azure Managed Grafana** and click **+ Create**.
1. Fill in the values of the table above: resource group rg-appmon-openshift-demo, **Location** Indonesia Central, **Name** amg-appmon, pricing plan **Standard**, Grafana version **12**, API keys and zone redundancy disabled, public network access enabled. The fields are spread over several tabs whose names can change slightly over time.
1. **Permission** tab: keep the system-assigned managed identity on. Untick the box that gives this identity the Monitoring Reader role on the whole subscription, and keep yourself as Grafana administrator (**Include myself**).
1. **Tags** tab: the three tags of Chapter 7.1 plus &lt;EXEMPT_TAG&gt; = &lt;EXEMPT_VALUE&gt;. Click **Review + create**, then **Create**.
1. Open amw-appmon, click **Access control (IAM)**, **+ Add**, **Add role assignment**, choose **Monitoring Data Reader**, click **Next**, choose **Managed identity**, **+ Select members**, Managed identity **Azure Managed Grafana**, select **amg-appmon**, click **Select**, then **Review + assign**. Repeat on the resource group rg-appmon-openshift-demo with the role **Monitoring Reader**.

> [!TIP]
> **What you should see**
>
> amg-appmon with Sku Standard, a Grafana version that starts with 12, public network access Enabled, API key Disabled and zone redundancy Disabled. Three role assignments: Monitoring Reader and Monitoring Data Reader for the Grafana identity, and Grafana Admin for you. Write the Grafana endpoint and the principal ID into ENVIRONMENT.txt.

> [!WARNING]
> **If something goes wrong**
>
> If Cloud Shell asks to install the amg extension, answer Y. In the as-built lab, Log Analytics access for the new Grafana identity became active only about 10 minutes after the role assignment: until then Grafana panels show "insufficient access" or 403. Wait; do not change anything.

---

[&larr; 9. Prepare HV-HOST-02](09-prepare-hv-host-02.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [11. Application VMs, Azure Arc and the Azure Monitor Agent &rarr;](11-application-vms-azure-arc-and-the-azure-monitor-agent.md)
