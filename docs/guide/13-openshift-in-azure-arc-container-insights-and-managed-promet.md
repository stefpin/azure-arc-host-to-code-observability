# 13. OpenShift in Azure Arc, Container insights and managed Prometheus

<sub>Part C - Build the virtual machines, OpenShift and the Azure Arc connection &nbsp;|&nbsp; [Guide index](README.md)</sub>


> [!NOTE]
> **Approval Gate**
>
> G5.

## 13.1 Sign in to Azure on HV-HOST-02

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block in Chapter 5.5.

```bash
az login --tenant <GUID> --use-device-code
az account set --subscription <SUBSCRIPTION_ID>
az extension add --upgrade -n connectedk8s -y
az extension add --upgrade -n k8s-extension -y
$ARCLOC = 'indonesiacentral'     # or southeastasia, as decided in Chapter 6.4
oc whoami
```

> [!TIP]
> **What you should see**
>
> The device-code sign-in succeeds (open https://microsoft.com/devicelogin on your computer and type the code), both extensions install, and oc whoami prints system:admin.

## 13.2 Connect the cluster to Azure Arc

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session, after the start block of Chapter 5.5 and the az login of Chapter 13.1: in this chapter oc and az both run on the host, not in Cloud Shell. Paste the block at the PS F:\Build&gt; prompt.

```bash
oc adm policy add-scc-to-user privileged system:serviceaccount:azure-arc:azure-arc-kube-aad-proxy-sa
az connectedk8s connect --name arc-ocp-minibank --resource-group $RG --location $ARCLOC `
  --distribution openshift --infrastructure generic `
  --tags purpose=appmon-openshift-demo demo=minibank owner=labadmin
az connectedk8s show -n arc-ocp-minibank -g $RG `
  --query "{Status:connectivityStatus, Distribution:distribution, Version:kubernetesVersion, Nodes:totalNodeCount}" -o table
oc get pods -n azure-arc
```

> [!TIP]
> **What you should see**
>
> The connect command runs for 5 to 10 minutes and ends with JSON that contains "provisioningState": "Succeeded". The show command prints Connected, openshift, 1.33.x and 3 (the version and node count can take up to 10 minutes to appear). All pods in the azure-arc namespace are Running.

> [!WARNING]
> **If something goes wrong**
>
> In HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: if the kube-aad-proxy pod stays Pending or shows a permissions error, run the oc adm policy line again, then oc -n azure-arc rollout restart deploy/kube-aad-proxy. If the connect command cannot reach the cluster, check that $env:KUBECONFIG points to F:\Build\ocp\kubeconfig.

> [!TIP]
> **Beginner tip**
>
> The Arc agents need about 850 MB of memory and a few percent of one CPU in the cluster. They only make outbound HTTPS connections to Azure; nothing connects into the cluster.

## 13.3 Check the cluster in the Azure Portal

1. In the Azure Portal, search for **Azure Arc**, then click **Kubernetes clusters** (under Infrastructure).
1. Open **arc-ocp-minibank**. On **Overview**, check Status Connected, Distribution openshift, Kubernetes version and Total node count 3.
## 13.4 Sign in to the Kubernetes resources view

The Portal shows the namespaces and workloads of an Arc-enabled cluster through cluster connect. It signs you in with your own Microsoft Entra account; there is no token field any more. Every presenter needs two read-only permissions: the Azure role Azure Arc Kubernetes Viewer on the cluster, so that the Portal may open the view, and a read-only binding inside OpenShift, because OpenShift's own role-based access control decides what you see. Without the OpenShift binding the view shows Error (599) "Unable to reach the api server" and "Failed to fetch". As built, both permissions were given to the lab owner on 11 November 2026.

> [!NOTE]
> **Approval Gate**
>
> G5. Both permissions are read-only and limited to the lab cluster.

Step 1. Give the presenter the Azure role on the cluster and note the presenter's object ID.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - PowerShell, after the start block in Chapter 5.4, signed in as the presenter.

```powershell
$oid = az ad signed-in-user show --query id -o tsv
$cid = az resource show -g $RG -n arc-ocp-minibank --resource-type Microsoft.Kubernetes/connectedClusters --query id -o tsv
az role assignment create --role "Azure Arc Kubernetes Viewer" --assignee-object-id $oid `
  --assignee-principal-type User --scope $cid --query "{role:roleDefinitionName, type:principalType}" -o table
"Object ID of the presenter: $oid"
```

> [!TIP]
> **What you should see**
>
> A small table with Azure Arc Kubernetes Viewer and User, then the object ID (a GUID). Write the sign-in name and the object ID into the worksheet (Chapter 5.1).

> [!TIP]
> **Beginner tip**
>
> For another presenter, run the block while signed in as that person, or set $oid to that person's object ID (Microsoft Entra ID, Users, the person, Object ID) before the role assignment.

Step 2. Give the presenter read access inside OpenShift.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block in Chapter 5.5.

```bash
$upn = '<LAB_ADMIN_UPN>'   # the presenter's sign-in name
$oid = Read-Host 'Object ID of the presenter (Step 1)'
oc create clusterrolebinding arc-portal-entra-reader --clusterrole=cluster-reader --user=$upn --user=$oid
oc label clusterrolebinding arc-portal-entra-reader purpose=appmon-openshift-demo demo=minibank owner=labadmin --overwrite
oc auth can-i list deployments -A --as=$upn
oc auth can-i delete deployments -n minibank --as=$upn
oc auth can-i get secrets -n minibank --as=$upn
```

> [!TIP]
> **What you should see**
>
> The binding is created and labelled, and the three checks answer yes, no and no: the presenter can read the workloads but cannot change anything or read secrets.

> [!TIP]
> **Beginner tip**
>
> The binding names both the sign-in name and the object ID, so it works whichever of the two the Azure Arc proxy passes to OpenShift. For another presenter, add that person in HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc adm policy add-cluster-role-to-user cluster-reader &lt;SIGN-IN-NAME&gt;.

Step 3. Open the view.

> [!NOTE]
> **Where to run it**
>
> Azure Portal, signed in as the presenter.

arc-ocp-minibank, **Kubernetes resources**, **Namespaces**, then **Workloads**. Filter on namespace minibank.

> [!TIP]
> **What you should see**
>
> The list of namespaces, including minibank, azure-arc and the openshift-\* namespaces. Under Workloads, the deployment minibank-transfer shows 3 of 3 pods; its detail page shows 3 desired, 3 available and the pods on ocp-node-1, ocp-node-2 and ocp-node-3.

> [!WARNING]
> **If something goes wrong**
>
> Error (599) "Unable to reach the api server" or "Failed to fetch": the binding of Step 2 is missing (check with oc auth can-i list deployments -A --as=&lt;SIGN-IN-NAME&gt;), or the role of Step 1 is still being applied: wait a few minutes and reload the page. If the Portal shows "access token expiry", reload the Portal and sign in again.

> [!CAUTION]
> **Be honest**
>
> The Kubernetes resources view is a preview feature. Azure role-based access control for Kubernetes authorization is not supported for OpenShift, so the Azure role only opens the view; OpenShift's own role-based access control decides what you see.

Optional: a read-only token for command-line access. Version 1.3 signed in to the Portal with a service account token. The Portal no longer uses it, but the token still lets you reach the cluster from the command line through Azure Arc (az connectedk8s proxy with --token). As built, the service account arc-portal-reader and its token secret exist. To create them on a new build:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator), after the start block of Chapter 5.5, which sets KUBECONFIG and the path of oc. Paste the block at the PS F:\Build&gt; prompt and press Enter.

```powershell
oc create serviceaccount arc-portal-reader -n default
oc create clusterrolebinding arc-portal-reader --clusterrole cluster-reader --serviceaccount default:arc-portal-reader
@'
apiVersion: v1
kind: Secret
metadata:
  name: arc-portal-reader-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: arc-portal-reader
type: kubernetes.io/service-account-token
'@ | oc apply -f -
Start-Sleep -Seconds 5
$t = oc get secret arc-portal-reader-token -n default -o jsonpath='{.data.token}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($t)) | Set-Clipboard
"Token copied to the clipboard"
```

Keep the token only in ENVIRONMENT.txt.

## 13.5 Container insights

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session, after the start block of Chapter 5.5 and the az login of Chapter 13.1: in this chapter oc and az both run on the host, not in Cloud Shell. Paste the block at the PS F:\Build&gt; prompt.

```bash
$LAWID = az monitor log-analytics workspace show -g $RG -n law-appmon --query id -o tsv
az k8s-extension create --name azuremonitor-containers --cluster-name arc-ocp-minibank --resource-group $RG `
  --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers `
  --configuration-settings logAnalyticsWorkspaceResourceID=$LAWID amalogs.useAADAuth=true
oc get ds ama-logs -n kube-system
oc get deploy ama-logs-rs -n kube-system
```

Apply the log filter straight away. Without it, every openshift-\* namespace sends its container logs to Log Analytics, which costs money and can reach the workspace's daily cap. The file excludes the OpenShift platform namespaces and keeps minibank and other application namespaces.

```bash
oc apply -f F:\Build\minibank\monitoring\container-insights\container-azm-ms-agentconfig.yaml
oc get pods -n kube-system | Select-String ama-logs
```

> [!TIP]
> **What you should see**
>
> The extension command ends with "provisioningState": "Succeeded". The ama-logs DaemonSet shows 3 ready pods (one per node) and ama-logs-rs shows 1 ready. After the ConfigMap, the ama-logs pods restart once. Write the time of the oc apply command into the worksheet: Scene 13 compares the log volume before and after it. After about 10 minutes, arc-ocp-minibank, Insights shows the three nodes. The page opens with the title Monitor and the tabs Cluster, Nodes, Controllers, Containers, Networking and Dashboards.

> [!TIP]
> **Beginner tip**
>
> The Portal path for the same setting is arc-ocp-minibank, Insights, Monitor settings (or Configure monitoring), where you can also choose a collection preset. This runbook uses the CLI so that the workspace name is exact.

## 13.6 Managed Prometheus

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session, after the start block of Chapter 5.5 and the az login of Chapter 13.1: in this chapter oc and az both run on the host, not in Cloud Shell. Paste the block at the PS F:\Build&gt; prompt.

```powershell
$AMWID = az monitor account show -n amw-appmon -g $RG --query id -o tsv
az k8s-extension create --name azuremonitor-metrics --cluster-name arc-ocp-minibank --resource-group $RG `
  --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers.Metrics `
  --configuration-settings azure-monitor-workspace-resource-id=$AMWID
oc get pods -n kube-system | Select-String ama-metrics
```

> [!TIP]
> **What you should see**
>
> provisioningState Succeeded, and ama-metrics pods Running (one replica pod, one node pod per node, and the operator and target pods). After about 10 minutes, open amw-appmon in the Portal, click Prometheus explorer, type the query up and click Run query: you see time series from the cluster.

> [!TIP]
> **Beginner tip**
>
> The Prometheus extension brings its own node exporter on port 9110, so it does not collide with OpenShift's own node exporter on port 9100. The Grafana link is added by hand in Chapter 17.4, so the extension command does not need Grafana's resource ID.

## 13.7 Optional: Azure Policy for the cluster

Only if the lab owner wants Scene 14.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session, after the start block of Chapter 5.5 and the az login of Chapter 13.1: in this chapter oc and az both run on the host, not in Cloud Shell. Paste the block at the PS F:\Build&gt; prompt.

```bash
az k8s-extension create --cluster-type connectedClusters --cluster-name arc-ocp-minibank --resource-group $RG `
  --extension-type Microsoft.PolicyInsights --name azurepolicy
oc get pods -n kube-system | Select-String azure-policy
oc get pods -n gatekeeper-system
```

Then, in the Portal: arc-ocp-minibank, **Policies**, **Assign policy**. Search for the built-in policy **Kubernetes cluster should not allow privileged containers**. On the **Parameters** tab untick **Only show parameters that need input or review**, set **Effect** to **audit** and **Namespace inclusions** to ["minibank"]. Click **Review + create**, then **Create**. Compliance results appear after about 15 to 30 minutes.

> [!CAUTION]
> **Be honest**
>
> OpenShift's own system pods are privileged by design. Limiting the policy to the minibank namespace keeps the demo result meaningful. Audit mode reports without blocking anything.

## 13.8 Check the extensions

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session, after the start block of Chapter 5.5 and the az login of Chapter 13.1: in this chapter oc and az both run on the host, not in Cloud Shell. Paste the block at the PS F:\Build&gt; prompt.

```powershell
az k8s-extension list --cluster-name arc-ocp-minibank -g $RG --cluster-type connectedClusters `
  --query "[].{Name:name, Type:extensionType, State:provisioningState}" -o table
```

> [!TIP]
> **What you should see**
>
> azuremonitor-containers and azuremonitor-metrics (and azurepolicy if installed), all Succeeded. The Portal shows the same under arc-ocp-minibank, Settings, Extensions.

> [!TIP]
> **Beginner tip**
>
> Settings is a collapsed group in the left menu of the cluster: click Settings to open it. Overview, Properties, Extensions opens the same page. Never click Uninstall on an extension during the demo.

---

[&larr; 12. Red Hat OpenShift 4.20 cluster](12-red-hat-openshift-4-20-cluster.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [14. Databases &rarr;](14-databases.md)
