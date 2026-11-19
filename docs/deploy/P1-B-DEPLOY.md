# P1-B-DEPLOY - MiniBank source pack v1.4 (P1 build): feature B (zero-code OpenShift onboarding with the Red Hat build of OpenTelemetry)

Pack folder: `minibank/` next to this file (MANIFEST.md section 0b lists every new and changed file and the placeholders). Build approved
by the lab owner 12 Nov 2026 15:06 WIB; built and verified the same day (gates G1-G4 passed), so the lab needs none of these steps again.
Use them to rebuild the feature (another lab, or after a rollback), as a health check (the Check lines) or to roll back.
Azure changes only in `rg-appmon-openshift-demo` (it also holds law-appmon, appi-minibank and amw-appmon). Places
changed: the Arc-enabled OpenShift cluster `ocp-minibank` (Arc resource `arc-ocp-minibank`), Azure, APP-RHEL (image build), HV-HOST-02
(`oc`, scripts). Features C and D (P1-DC-DEPLOY.md) do not depend on B.

What B adds: a new Java service minibank-rates (fee and limit check in the payment path) with NO monitoring agent in its image. The Red Hat
build of OpenTelemetry operator injects the OpenTelemetry Java agent when the pod carries one annotation. The agent sends OTLP to an
OpenTelemetry Collector in the cluster, which signs in to Azure with Arc workload identity (no secret) and sends traces, logs and metrics
to Azure Monitor (native OTLP ingestion in Indonesia Central). minibank-transfer 1.2.0 calls minibank-rates, so one payment shows both
agents (Microsoft and OpenTelemetry) in one end-to-end transaction.

Order (each step has a check and a rollback):

| Step | Where | What | Needs |
|---|---|---|---|
| 0 | HV-HOST-02 | pack files, cluster health, etcd backup | - |
| 1 | HV-HOST-02 (`az`, `oc`) | Arc OIDC issuer + workload identity; OpenShift service account issuer (kube-apiserver rollout) | 0 |
| 2 | Azure Cloud Shell (bash) | identity id-otelcol + federated credential, DCE dce-otlp, DCR dcr-otlp, role on the DCR | 1 (issuer URL) |
| 3 | APP-RHEL (bash, podman) | images into the ACR: collector 0.164.0 and Java agent 2.30.0 (mirrored), minibank-rates 1.0.0 and minibank-transfer 1.2.0 (built) | - |
| 4 | HV-HOST-02 (`oc`) | namespace minibank-otel, pull secret, collector otelcol | 2, 3 |
| 5 | HV-HOST-02 (`oc`) | Red Hat build of OpenTelemetry operator (manual approval), Instrumentation minibank-java | 3, 4, fresh etcd backup |
| 6 | HV-HOST-02 (`oc`) | minibank-rates (onboarded) and minibank-rates-copy (not onboarded, Route) | 5 |
| 7 | HV-HOST-02 (`oc`) | minibank-transfer 1.2.0 | 6 |
| 8 | Azure Portal | gates G1-G4 | 7 (+5 minutes of data) |
| 9 | HV-HOST-02 | Scene 2 live onboarding: onboard-live.ps1 / onboard-reset.ps1 | 6 |

Do not run Steps 1-7 during a demo or rehearsal: Step 1 restarts the OpenShift API servers one after the other (in the build the whole
step, etcd backup included, took about 17 minutes; the apps keep running), Step 7 replaces the minibank-transfer pods.

Values (none of them is a secret, none is stored in the pack): the ACR name (`ACR_NAME`) and the four values that Step 2 prints for the
collector (`OTELCOL_CLIENT_ID`, `DCE_LOGS_ENDPOINT`, `DCE_METRICS_ENDPOINT`, `DCR_IMMUTABLE_ID`). The tenant ID is not needed: the Arc
workload identity webhook puts it into the collector pod. ACR token passwords are typed in when asked and never written to a file.

---

## Step 0 - HV-HOST-02: pack files, health, etcd backup (PowerShell as Administrator)

```powershell
$zip = 'F:\Build\MiniBank-source-pack-v1.4.zip'          # the v1.4 pack; P1-DC-DEPLOY.md Step 0 may have unpacked it already
if (-not (Test-Path F:\Build\pack-v1.4\minibank\MANIFEST.md)) { Expand-Archive $zip -DestinationPath F:\Build\pack-v1.4 -Force }
New-Item -ItemType Directory -Force -Path F:\Build\minibank\openshift\p1\rendered, F:\Build\minibank\scripts | Out-Null
Copy-Item F:\Build\pack-v1.4\minibank\openshift\p1\* F:\Build\minibank\openshift\p1 -Force
Copy-Item F:\Build\pack-v1.4\minibank\scripts\onboard-live.ps1, F:\Build\pack-v1.4\minibank\scripts\onboard-reset.ps1 F:\Build\minibank\scripts -Force
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'             # oc = C:\Tools\oc\oc.exe (the onboard scripts use these two paths)
oc get nodes
oc get co
```

Check: every node `Ready`; every cluster operator `True False False` (Available, Progressing, Degraded; 34 operators in the lab).
Then take a fresh etcd backup (runbook Chapter 12.7; the build keeps the last 3 under `F:\Build\backup\etcd`), and another one right
before Step 5. `rendered\` holds the filled-in copies of Steps 4-6 (client ID, endpoints): keep it on the host, never put it into a pack.
Rollback: nothing runs yet; delete the copied files if wanted.

---

## Step 1 - HV-HOST-02: Arc OIDC issuer, workload identity, OpenShift service account issuer (PowerShell as Administrator)

Workload identity lets a pod sign in to Microsoft Entra ID with its own Kubernetes service account token: Entra trusts tokens from the
cluster's OIDC issuer, which Azure Arc publishes. So OpenShift must issue its service account tokens with the Arc issuer URL. This
restarts the kube-apiserver on every control-plane node: take the etcd backup of Step 0 first.

```powershell
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
$RG = 'rg-appmon-openshift-demo'; $CL = 'arc-ocp-minibank'
# az CLI signed in with rights on the Arc resource (the build used the host's managed identity: AZURE_CONFIG_DIR F:\Build\azcfg)
az extension add --name connectedk8s --upgrade --yes      # version 1.10.0 or later
oc get authentication.config.openshift.io cluster -o yaml | Set-Content F:\Build\backup\authentication-cluster-before-wi.yaml
oc get kubeapiserver cluster -o jsonpath='{.status.latestAvailableRevision}'        # note the revision before the change
'y' | az connectedk8s update -g $RG -n $CL --enable-oidc-issuer --enable-workload-identity --kube-config $env:KUBECONFIG   # about 4 minutes
$iss = (az connectedk8s show -g $RG -n $CL --query oidcIssuerProfile.issuerUrl -o tsv | Select-Object -Last 1).Trim()
$iss                                                       # https://... = the Arc OIDC issuer URL of this cluster
[IO.File]::WriteAllText('F:\Build\tools\wi-issuer-patch.json', '{"spec":{"serviceAccountIssuer":"' + $iss + '"}}')
oc patch authentication.config.openshift.io cluster --type merge --patch-file F:\Build\tools\wi-issuer-patch.json
# wait for the kube-apiserver rollout: run these two lines every minute until PROGRESSING is False and every node shows the new revision
oc get co kube-apiserver
oc get kubeapiserver cluster -o jsonpath='{.status.nodeStatuses[*].currentRevision}'
# then restart the Arc agents so that they pick up the new issuer
oc rollout restart deployment -n azure-arc
oc rollout restart deployment -n arc-workload-identity
```

Check: `oc get authentication.config.openshift.io cluster -o jsonpath='{.spec.serviceAccountIssuer}'` prints the issuer URL;
`az connectedk8s show -g $RG -n $CL --query securityProfile.workloadIdentity.enabled -o tsv` prints `true`; the pods in
`arc-workload-identity` and `azure-arc` are Running; `oc get co` shows all operators `True False False` again; minibank-transfer is still
3/3. In the build the kube-apiserver revision went up by one on all nodes, and a new service account token carried the Arc issuer
(`iss`) and the audience `api://AzureADTokenExchange`.

Rollback (only after Steps 9 to 2 are rolled back: the collector needs workload identity; take an etcd backup first):

```powershell
[IO.File]::WriteAllText('F:\Build\tools\wi-issuer-reset.json', '{"spec":{"serviceAccountIssuer":""}}')
oc patch authentication.config.openshift.io cluster --type merge --patch-file F:\Build\tools\wi-issuer-reset.json
# wait for the kube-apiserver rollout again (same two lines as above), then:
'y' | az connectedk8s update -g $RG -n $CL --disable-workload-identity --kube-config $env:KUBECONFIG
```

The value before the change is in `F:\Build\backup\authentication-cluster-before-wi.yaml` (it was empty, `''`, in the lab).

---

## Step 2 - Azure: identity, federated credential, DCE, DCR, role (Cloud Shell - bash)

Everything goes into `rg-appmon-openshift-demo` (Indonesia Central) and reuses the existing workspaces. The data collection rule
takes OTLP directly from the collector (no Azure Monitor agent involved): traces and logs go to the Log Analytics workspace
law-appmon (tables OTelSpans, OTelLogs, OTelResources) and are linked to the Application Insights resource appi-minibank, so its
Application map, Performance and Transaction search show them; metrics go to the Azure Monitor workspace amw-appmon. The identity
id-otelcol gets one role (Monitoring Metrics Publisher) on the DCR only, and its federated credential trusts exactly one Kubernetes
service account: `system:serviceaccount:minibank-otel:otelcol`. The template below is the one used in the build.

```bash
RG=rg-appmon-openshift-demo; LOC=indonesiacentral
read -rp 'Owner tag (your alias): ' OWNER
cat > otlp-dcr.json <<'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {"type": "string"},
    "owner": {"type": "string"},
    "applicationInsightsResourceId": {"type": "string"},
    "azureMonitorWorkspaceResourceId": {"type": "string"},
    "logAnalyticsWorkspaceResourceId": {"type": "string"},
    "dceName": {"type": "string", "defaultValue": "dce-otlp"},
    "dcrName": {"type": "string", "defaultValue": "dcr-otlp"}
  },
  "variables": {
    "tags": {"demo": "minibank", "owner": "[parameters('owner')]", "purpose": "appmon-openshift-demo", "<EXEMPT_TAG>": "<EXEMPT_VALUE>", "feature": "p1-b-otlp"}
  },
  "resources": [
    {
      "type": "Microsoft.Insights/dataCollectionEndpoints", "apiVersion": "2024-03-11",
      "name": "[parameters('dceName')]", "location": "[parameters('location')]", "tags": "[variables('tags')]",
      "properties": {"description": "OTLP endpoint for the MiniBank OpenShift collector (P1 B)", "networkAcls": {"publicNetworkAccess": "Enabled"}}
    },
    {
      "type": "Microsoft.Insights/dataCollectionRules", "apiVersion": "2024-03-11",
      "name": "[parameters('dcrName')]", "location": "[parameters('location')]", "tags": "[variables('tags')]",
      "dependsOn": ["[resourceId('Microsoft.Insights/dataCollectionEndpoints', parameters('dceName'))]"],
      "properties": {
        "description": "OTLP traces, logs and metrics from the OpenTelemetry Collector on OpenShift (direct ingestion, P1 B)",
        "dataCollectionEndpointId": "[resourceId('Microsoft.Insights/dataCollectionEndpoints', parameters('dceName'))]",
        "references": {"applicationInsights": [{"resourceId": "[parameters('applicationInsightsResourceId')]", "name": "appi"}]},
        "directDataSources": {
          "otelMetrics": [{"streams": ["Custom-Metrics-Otel"], "enrichWithResourceAttributes": ["*"], "enrichWithReference": "appi", "name": "otelMetricsDirect"}],
          "otelLogs": [{"streams": ["Microsoft-OTel-Logs"], "enrichWithResourceAttributes": ["*"], "enrichWithReference": "appi", "replaceResourceIdWithReference": true, "name": "otelLogsDirect"}],
          "otelTraces": [{"streams": ["Microsoft-OTel-Traces-Spans", "Microsoft-OTel-Traces-Events", "Microsoft-OTel-Traces-Resources"], "enrichWithResourceAttributes": ["*"], "enrichWithReference": "appi", "replaceResourceIdWithReference": true, "name": "otelTracesDirect"}]
        },
        "destinations": {
          "monitoringAccounts": [{"accountResourceId": "[parameters('azureMonitorWorkspaceResourceId')]", "name": "amw"}],
          "logAnalytics": [{"workspaceResourceId": "[parameters('logAnalyticsWorkspaceResourceId')]", "name": "law"}]
        },
        "dataFlows": [
          {"streams": ["Custom-Metrics-Otel"], "destinations": ["amw"]},
          {"streams": ["Microsoft-OTel-Logs", "Microsoft-OTel-Traces-Spans", "Microsoft-OTel-Traces-Events", "Microsoft-OTel-Traces-Resources"], "destinations": ["law"]}
        ]
      }
    }
  ]
}
EOF
# 2a. user-assigned managed identity + federated credential (issuer = the Arc OIDC issuer of Step 1)
az identity create -g $RG -n id-otelcol -l $LOC -o none \
  --tags demo=minibank owner=$OWNER purpose=appmon-openshift-demo <EXEMPT_TAG>=<EXEMPT_VALUE> feature=p1-b-otlp
ISS=$(az resource show -g $RG -n arc-ocp-minibank --resource-type Microsoft.Kubernetes/connectedClusters \
  --api-version 2024-12-01-preview --query properties.oidcIssuerProfile.issuerUrl -o tsv)
az identity federated-credential create -g $RG --identity-name id-otelcol -n fic-otelcol-minibank-otel -o none \
  --issuer "$ISS" --subject system:serviceaccount:minibank-otel:otelcol --audiences api://AzureADTokenExchange
# 2b. DCE dce-otlp + DCR dcr-otlp
LAWID=$(az monitor log-analytics workspace show -g $RG -n law-appmon --query id -o tsv)
APPIID=$(az resource show -g $RG -n appi-minibank --resource-type Microsoft.Insights/components --query id -o tsv)
AMWID=$(az resource show -g $RG -n amw-appmon --resource-type Microsoft.Monitor/accounts --query id -o tsv)
az deployment group create -g $RG -n p1b-otlp-dce-dcr --template-file otlp-dcr.json --query properties.provisioningState -o tsv \
  --parameters location=$LOC owner=$OWNER applicationInsightsResourceId=$APPIID azureMonitorWorkspaceResourceId=$AMWID logAnalyticsWorkspaceResourceId=$LAWID
# 2c. role Monitoring Metrics Publisher for the identity, scope = the DCR only
PRID=$(az identity show -g $RG -n id-otelcol --query principalId -o tsv)
DCRID=$(az resource show -g $RG -n dcr-otlp --resource-type Microsoft.Insights/dataCollectionRules --query id -o tsv)
DCEID=$(az resource show -g $RG -n dce-otlp --resource-type Microsoft.Insights/dataCollectionEndpoints --query id -o tsv)
az role assignment create --assignee-object-id $PRID --assignee-principal-type ServicePrincipal \
  --role "Monitoring Metrics Publisher" --scope $DCRID -o none
# 2d. the four values for Step 4 (not secrets; keep them out of the pack)
echo "OTELCOL_CLIENT_ID    $(az identity show -g $RG -n id-otelcol --query clientId -o tsv)"
echo "DCE_LOGS_ENDPOINT    $(az resource show --ids $DCEID --query properties.logsIngestion.endpoint -o tsv)"
echo "DCE_METRICS_ENDPOINT $(az resource show --ids $DCEID --query properties.metricsIngestion.endpoint -o tsv)"
echo "DCR_IMMUTABLE_ID     $(az resource show --ids $DCRID --query properties.immutableId -o tsv)"
```

Check: the deployment prints `Succeeded`; `az role assignment list --scope $DCRID --query "[].roleDefinitionName" -o tsv` prints
`Monitoring Metrics Publisher`; `az identity federated-credential list -g $RG --identity-name id-otelcol --query "[].subject" -o tsv`
prints `system:serviceaccount:minibank-otel:otelcol`; `az resource show --ids $DCEID --query location -o tsv` and the same for the DCR print
`indonesiacentral` (the "data stays in Indonesia" part of gate G1). A new role assignment can take a few minutes to work.
The OTLP addresses that Step 4 builds from the printed values:
traces `<logs endpoint>/datacollectionRules/<DCR immutable ID>/streams/Microsoft-OTLP-Traces/otlp/v1/traces`, logs the same with
`Microsoft-OTLP-Logs/otlp/v1/logs`, metrics `<metrics endpoint>/datacollectionRules/<DCR immutable ID>/streams/Custom-Metrics-Otel/otlp/v1/metrics`.

Rollback (after Steps 9 to 4; in a new Cloud Shell set RG again with the first line of the block above, and PRID, DCRID and DCEID with
the lines of 2c):

```bash
az role assignment delete --assignee $PRID --role "Monitoring Metrics Publisher" --scope $DCRID
az resource delete --ids $DCRID          # the DCR first, then the DCE
az resource delete --ids $DCEID
az identity federated-credential delete -g $RG --identity-name id-otelcol -n fic-otelcol-minibank-otel --yes
az identity delete -g $RG -n id-otelcol
```

Data already ingested stays in law-appmon and amw-appmon until its retention ends.

---

## Step 3 - APP-RHEL: images into the ACR (bash, podman)

The cluster pulls every image of feature B from the ACR (no internet pull during a session). ACR Tasks (`az acr build`) are not
available in Indonesia Central, so the images are built with podman on APP-RHEL, as in v1.3. Copy the pack zip to APP-RHEL first, for
example from HV-HOST-02: `scp -i F:\Build\ocp\id_ed25519 F:\Build\MiniBank-source-pack-v1.4.zip labadmin@192.168.110.32:`

```bash
python3 -m zipfile -e ~/MiniBank-source-pack-v1.4.zip ~/p14      # keeps ~/minibank (v1.3)
read -rp 'ACR name (without .azurecr.io): ' ACR
read -rp 'ACR token name with push rights: ' PUSHUSER
sudo podman login "$ACR.azurecr.io" -u "$PUSHUSER"             # asks for the token password
# 3a. mirror the collector (community contrib 0.164.0) and the OpenTelemetry Java agent (2.30.0 = default of operator 0.158.0)
sudo podman pull docker.io/otel/opentelemetry-collector-contrib:0.164.0
sudo podman tag docker.io/otel/opentelemetry-collector-contrib:0.164.0 "$ACR.azurecr.io/otel/opentelemetry-collector-contrib:0.164.0"
sudo podman pull ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.30.0
sudo podman tag ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.30.0 "$ACR.azurecr.io/otel/autoinstrumentation-java:2.30.0"
# 3b. build minibank-rates 1.0.0 (no agent in the image) and minibank-transfer 1.2.0 (Microsoft Java agent 3.7.9, calls minibank-rates)
cd ~/p14/minibank/rates && sudo podman build -t "$ACR.azurecr.io/minibank-rates:1.0.0" .
cd ~/p14/minibank/transfer && sudo podman build -t "$ACR.azurecr.io/minibank-transfer:1.2.0" .
for img in otel/opentelemetry-collector-contrib:0.164.0 otel/autoinstrumentation-java:2.30.0 minibank-rates:1.0.0 minibank-transfer:1.2.0; do
  sudo podman push "$ACR.azurecr.io/$img"
done
sudo podman logout "$ACR.azurecr.io"
```

Check: every push ends with `Writing manifest to image destination`; in Cloud Shell `az acr repository show-tags -n <ACR name>
--repository minibank-rates -o tsv` prints `1.0.0` (the same for minibank-transfer `1.2.0`, otel/opentelemetry-collector-contrib `0.164.0`
and otel/autoinstrumentation-java `2.30.0`). Image sizes in the build: minibank-rates about 419 MB, minibank-transfer about 474 MB.
If `podman login` is refused, check the expiry date of the push token in the ACR (Tokens) and renew it; never store it in a file.
Rollback: nothing runs from the new images until Steps 4-7. To remove one: `az acr repository delete -n <ACR name> --image
minibank-rates:1.0.0 --yes`. Keep `minibank-transfer:1.1.0`: it is the rollback image of Step 7.

---

## Step 4 - HV-HOST-02: namespace minibank-otel, pull secret, collector otelcol (PowerShell as Administrator)

The collector is a plain Deployment `otelcol` (community contrib image 0.164.0 from the ACR, 2 replicas spread over the nodes,
PodDisruptionBudget, Service on 4317 gRPC and 4318 HTTP). Its configuration (ConfigMap `otelcol-config`): OTLP receiver,
memory_limiter, `filter/health` (drops spans whose name matches `.*/actuator/health.*`, the Kubernetes probes), batch, and the exporter
to the DCE/DCR with the `azure_auth` extension: workload identity with client_id, tenant_id and federated_token_file taken from the
AZURE_* variables of the pod, scope `https://monitor.azure.com/.default`. The service account `otelcol` carries the annotation
`azure.workload.identity/client-id` and the pull secret. No secret in the cluster. (The copy of the template on HV-HOST-02 from the
build used other token names; the filled-in result is the same.)

```powershell
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
$p1 = 'F:\Build\minibank\openshift\p1'
$ACR = Read-Host 'ACR name (without .azurecr.io)'
oc create namespace minibank-otel
oc label namespace minibank-otel demo=minibank purpose=p1-b-otlp --overwrite
# image pull secret: copy acr-pull from project minibank (same ACR pull token as minibank-transfer)
$pull = oc get secret acr-pull -n minibank -o json | Out-String | ConvertFrom-Json
[ordered]@{ apiVersion = 'v1'; kind = 'Secret'; type = $pull.type; metadata = @{ name = 'acr-pull'; namespace = 'minibank-otel' }; data = $pull.data } |
  ConvertTo-Json -Depth 5 | oc apply -f -
# fill in the placeholders with the values that Step 2 (2d) printed
$cid = Read-Host 'OTELCOL_CLIENT_ID'; $logsEp = Read-Host 'DCE_LOGS_ENDPOINT'
$metricsEp = Read-Host 'DCE_METRICS_ENDPOINT'; $imm = Read-Host 'DCR_IMMUTABLE_ID'
$tpl = (Get-Content "$p1\10-otelcol.yaml.tpl" -Raw).Replace('ACR_NAME', $ACR).Replace('OTELCOL_CLIENT_ID', $cid).Replace('DCE_LOGS_ENDPOINT', $logsEp).Replace('DCE_METRICS_ENDPOINT', $metricsEp).Replace('DCR_IMMUTABLE_ID', $imm)
Set-Content -Path "$p1\rendered\10-otelcol.yaml" -Value $tpl
oc apply -f "$p1\rendered\10-otelcol.yaml"
oc rollout status deployment/otelcol -n minibank-otel --timeout=300s
oc get pods -n minibank-otel -l app=otelcol -o wide
oc set env pods -l app=otelcol -n minibank-otel --list | Select-String 'AZURE_'
oc logs deployment/otelcol -n minibank-otel --tail=40
```

Check: 2/2 pods Running on two different nodes; the `AZURE_` lines show AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE and
AZURE_AUTHORITY_HOST (put there by the Arc workload identity webhook because of the pod label `azure.workload.identity/use: "true"`); the
log has no `401` or `403` lines. One known warning: the exporter alias `otlphttp` is deprecated; rename it to `otlp_http` at the next
collector change (it works today). `oc get secret -n minibank-otel` lists only image pull secrets (acr-pull and the ones OpenShift adds):
no key, no password, no connection string = gate G2. The data check (G1) follows in Step 8, once Step 6 sends spans. (The build proved
G1 and G2 before this step with a temporary test collector and a telemetrygen job, both deleted afterwards.)
Rollback (after Steps 9 to 5): `oc delete -f "$p1\rendered\10-otelcol.yaml"`, then `oc delete namespace minibank-otel` (also removes the
pull secret). Agents whose collector is gone only log export errors; the apps keep working.

---

## Step 5 - HV-HOST-02: operator and Instrumentation minibank-java (PowerShell as Administrator)

Take a fresh etcd backup first (runbook Chapter 12.7). The Red Hat build of OpenTelemetry operator comes from OperatorHub (package
`opentelemetry-product`, catalog redhat-operators, channel stable): Subscription `opentelemetry-product` in namespace
`openshift-opentelemetry-operator`, `installPlanApproval: Manual`, so every install and update waits until its InstallPlan is approved
(the lab runs CSV v0.158.0). The Instrumentation `minibank-java` (namespace minibank) tells the operator what to inject into pods with the
annotation `instrumentation.opentelemetry.io/inject-java: "true"`: the OpenTelemetry Java agent 2.30.0 from the ACR, exporter
`http://otelcol.minibank-otel.svc.cluster.local:4318`, W3C trace context + baggage, sampler parentbased_always_on, delta temporality.

```powershell
oc apply -f "$p1\00-otel-operator.yaml"
oc get installplan -n openshift-opentelemetry-operator             # repeat until one InstallPlan shows APPROVED false (1-3 minutes)
$ip = oc get installplan -n openshift-opentelemetry-operator -o jsonpath='{.items[0].metadata.name}'
oc patch installplan $ip -n openshift-opentelemetry-operator --type merge --patch-file "$p1\installplan-approve.json"
oc get csv -n openshift-opentelemetry-operator                     # repeat until the opentelemetry-operator CSV shows Succeeded (2-5 minutes)
oc apply -f "$p1\20-instrumentation.yaml"                           # if the operator webhook is not ready yet: wait 20 s, run it again
oc get instrumentation minibank-java -n minibank -o jsonpath='{.spec.java.image}'    # the operator default (ghcr.io/...:2.30.0)
# point the agent image to the ACR mirror of Step 3 (same tag), as in the build
[IO.File]::WriteAllText("$p1\rendered\instr-image-patch.json", '{"spec":{"java":{"image":"' + $ACR + '.azurecr.io/otel/autoinstrumentation-java:2.30.0"}}}')
oc patch instrumentation minibank-java -n minibank --type merge --patch-file "$p1\rendered\instr-image-patch.json"
oc get instrumentation minibank-java -n minibank -o jsonpath='{.spec.java.image}'    # now <ACR name>.azurecr.io/otel/autoinstrumentation-java:2.30.0
```

Check: the CSV `opentelemetry-operator.v0.158.0-...` is `Succeeded`; `oc get pods -n openshift-opentelemetry-operator` shows the
controller manager and the webhook pods Running; `oc get crd | Select-String opentelemetry` lists instrumentations, opampbridges,
opentelemetrycollectors and targetallocators; the Instrumentation points to the ACR image. If the operator default has another tag (a
newer operator version), mirror that tag in Step 3 and use it here. Nothing is injected yet: no pod carries the annotation. Later operator
updates appear as InstallPlans with APPROVED false: approve them on purpose, never in a demo week.
Rollback (after Steps 9 to 6): `oc delete instrumentation minibank-java -n minibank`; then
`oc delete subscription opentelemetry-product -n openshift-opentelemetry-operator`, `oc delete csv --all -n openshift-opentelemetry-operator`
and `oc delete namespace openshift-opentelemetry-operator`. The four opentelemetry.io CRDs stay; delete them only if nothing else uses them.

---

## Step 6 - HV-HOST-02: minibank-rates (onboarded) and minibank-rates-copy (not onboarded) (PowerShell as Administrator)

minibank-rates: Deployment with 2 replicas spread over the nodes, PodDisruptionBudget, Service on port 8080, and the pod annotation
`instrumentation.opentelemetry.io/inject-java: "true"`, the only monitoring setting. `-XX:MaxRAMPercentage=50` stays in the
Deployment env `JAVA_TOOL_OPTIONS` (not in the image), because the operator appends `-javaagent` to that variable.
minibank-rates-copy runs the same image (1 replica, Service, Route) WITHOUT the annotation, for the live act in Scene 2 (Step 9).

```powershell
foreach ($manifest in '30-rates.yaml', '40-rates-copy.yaml') {
  Set-Content -Path "$p1\rendered\$manifest" -Value ((Get-Content "$p1\$manifest" -Raw).Replace('ACR_NAME', $ACR))
}
oc apply -f "$p1\rendered\30-rates.yaml"
oc rollout status deployment/minibank-rates -n minibank --timeout=420s
oc apply -f "$p1\rendered\40-rates-copy.yaml"
oc rollout status deployment/minibank-rates-copy -n minibank --timeout=420s
oc get pods -n minibank -l 'app in (minibank-rates,minibank-rates-copy)' -o 'custom-columns=POD:.metadata.name,NODE:.spec.nodeName,INIT:.spec.initContainers[*].name'
oc set env pods -l app=minibank-rates -n minibank --list | Select-String 'JAVA_TOOL_OPTIONS|OTEL_SERVICE_NAME|OTEL_EXPORTER_OTLP_ENDPOINT'
oc logs deployment/minibank-rates -n minibank -c minibank-rates | Select-String 'opentelemetry-javaagent' | Select-Object -First 1
Invoke-RestMethod 'http://minibank-rates-copy.apps.ocp-minibank.minibank-demo.lab/api/rates/check?channel=QRIS&amount=85000'
```

Check: minibank-rates 2/2 on two nodes, each with the init container `opentelemetry-auto-instrumentation-java`; OTEL_SERVICE_NAME
`minibank-rates`, OTEL_EXPORTER_OTLP_ENDPOINT `http://otelcol.minibank-otel.svc.cluster.local:4318`, JAVA_TOOL_OPTIONS
`-XX:MaxRAMPercentage=50 -javaagent:/otel-auto-instrumentation-java.../javaagent.jar`; the log line shows
`opentelemetry-javaagent - version: 2.30.0`; minibank-rates-copy 1/1 with INIT `<none>`; the Route call returns channel QRIS, fee 0,
withinLimit True, ruleSet MINIBANK-2026-11.
Rollback (after Step 7 is rolled back; otherwise minibank-transfer 1.2.0 books every payment with the fallback rate):
`oc delete -f "$p1\rendered\40-rates-copy.yaml"` and `oc delete -f "$p1\rendered\30-rates.yaml"`. To keep minibank-rates without the
agent instead: `oc patch deployment/minibank-rates -n minibank --type json --patch-file "$p1\onboard-remove.json"` (new pods start
without the agent).

---

## Step 7 - HV-HOST-02: minibank-transfer 1.2.0 (PowerShell as Administrator)

minibank-transfer 1.2.0 calls minibank-rates (`GET /api/rates/check`, only channel and amount, never an account number) before the fraud
check of every Transfer and QRIS payment, with a 2 s timeout (connect 1 s) and a fallback: on any error it books with the fallback rate
(rule set `FALLBACK`), so a rates problem never fails a payment. Address: `RATES_URL`, default
`http://minibank-rates.minibank.svc.cluster.local:8080`, so the Deployment needs no new setting. minibank-transfer keeps the Microsoft
Application Insights Java agent 3.7.9 of its image (no annotation, nothing injected).

```powershell
oc get deployment minibank-transfer -n minibank -o yaml | Set-Content F:\Build\backup\minibank-transfer-deployment-before-p1.yaml
oc set image deployment/minibank-transfer minibank-transfer="$ACR.azurecr.io/minibank-transfer:1.2.0" -n minibank
oc rollout status deployment/minibank-transfer -n minibank --timeout=600s
oc get pods -n minibank -l app=minibank-transfer -o wide        # 3 pods, one per node (Scene 9 expects it)
Start-Sleep -Seconds 120
$tlog = oc logs -l app=minibank-transfer -n minibank --since=2m --tail=2000
'rates answer {0}, fallback {1}, rates unavailable {2}' -f @($tlog | Select-String 'rules MINIBANK-2026-11').Count,
  @($tlog | Select-String 'rules FALLBACK').Count, @($tlog | Select-String 'minibank-rates unavailable').Count
```

Check: 3 pods, one per node (if two share a node, delete the newer of the two; the Deployment starts it again, usually on the free node);
the count line shows rates answers with `fallback 0, rates unavailable 0` (build: 48 bookings with a rates answer and 0 fallbacks in 2
minutes); `Invoke-RestMethod http://minibank-transfer.apps.ocp-minibank.minibank-demo.lab/actuator/health` returns `UP`.
Important: `openshift/10-deployment.yaml` of the pack still names `minibank-transfer:1.1.0`. After this step, change the tag to 1.2.0
before you apply that file again; an `oc apply -f openshift\` with 1.1.0 rolls back to the version without the rates call.
Rollback: `oc rollout undo deployment/minibank-transfer -n minibank` (back to 1.1.0; the backup yaml shows the earlier image), then
`oc rollout status deployment/minibank-transfer -n minibank`.

---

## Step 8 - Gates G1-G4 (Azure Portal, about 5 minutes after Step 7)

In Application Insights an OpenTelemetry service shows with the role name `[namespace]/service`, for example `[minibank]/minibank-rates`;
the services with Microsoft agents keep their plain names (minibank-api, minibank-transfer, minibank-fraud).

- G1 - OTLP data stored in Indonesia Central: law-appmon > Logs, first query below, lists minibank-rates with agent 2.30.0; the DCE,
  the DCR and the workspace are in Indonesia Central (Step 2 check).
- G2 - no secret: the collector signs in with workload identity (Step 4 check); the cluster holds no key, password or connection
  string for Azure Monitor.
- G3 - appi-minibank > Application map shows `[minibank]/minibank-rates` under minibank-transfer; Performance works for the role
  `[minibank]/minibank-rates` (operation `GET /api/rates/check`).
- G4 - Transaction search > a Transfer request > End-to-end transaction: one view with api -> SQL -> transfer (Microsoft Java agent) ->
  `[minibank]/minibank-rates` (OpenTelemetry agent) -> fraud -> PostgreSQL -> Oracle. The third query checks all calls (build: 193 of 193
  rates calls shared the trace of a transfer request).

```kusto
// G1 and Scene 2 ("query B.1" in onboard-live.ps1): OpenTelemetry services that send data, with the agent version
OTelSpans
| where TimeGenerated > ago(15m)
| summarize spans = count(), lastSeen = max(TimeGenerated) by ServiceName, RoleName, agent = tostring(ResourceAttributes["telemetry.distro.version"])
| order by lastSeen desc

// minibank-rates calls: count and p95 duration
OTelSpans
| where TimeGenerated > ago(30m) and ServiceName == "minibank-rates" and Name == "GET /api/rates/check"
| summarize calls = count(), p95ms = percentile(DurationMs, 95)

// G4: every rates call shares its trace with a minibank-transfer request (ratesCalls == sameTrace)
let transfers = AppRequests | where TimeGenerated > ago(30m) and AppRoleName == "minibank-transfer" | summarize by TransferTrace = OperationId;
OTelSpans
| where TimeGenerated > ago(30m) and ServiceName == "minibank-rates" and Name == "GET /api/rates/check"
| join kind=leftouter transfers on $left.TraceId == $right.TransferTrace
| summarize ratesCalls = count(), sameTrace = countif(isnotempty(TransferTrace))

// collector filter/health: no health-probe spans (expected 0)
OTelSpans
| where TimeGenerated > ago(15m) and Name contains "/actuator/health"
| count
```

Check: the four gates as described. Rollback: none (read only).

---

## Step 9 - HV-HOST-02: Scene 2 live onboarding (second PowerShell window)

```powershell
Set-Location F:\Build\minibank\scripts
.\onboard-live.ps1        # the live act, about 28 s
.\onboard-reset.ps1       # after the session or a rehearsal, about 20 s
```

What the audience sees: BEFORE (pod without init container, JAVA_TOOL_OPTIONS only `-XX:MaxRAMPercentage=50`, OTEL_* not set) -> the
patch file with ONE annotation -> `oc patch` and the rollout (the new pod is ready in about 18 s, with or without the agent) -> AFTER
(init container `opentelemetry-auto-instrumentation-java`, JAVA_TOOL_OPTIONS with `-javaagent`, OTEL_SERVICE_NAME `minibank-rates-copy`,
the collector endpoint, `Same image, no rebuild, no code change: True`) -> 3 test calls through the Route.
`[minibank]/minibank-rates-copy` appears in Application Insights within 1-2 minutes (first query of Step 8, Application map).
Check: the AFTER block and 3 answered calls; the reset ends with `init containers (none) - ready for the next live onboarding.`
Leave the copy reset (not onboarded) before every session.
Rollback: `.\onboard-reset.ps1` (it does nothing when the copy is not onboarded).
The scripts use `F:\Build\ocp\kubeconfig`, `C:\Tools\oc\oc.exe`, the patch files in `F:\Build\minibank\openshift\p1\` (Step 0) and the
Route `minibank-rates-copy.apps.ocp-minibank.minibank-demo.lab`.

---

## Full rollback of feature B (reverse order)

Step 9 reset -> Step 7 (minibank-transfer back to 1.1.0) -> Step 6 (minibank-rates and the copy) -> Step 5 (Instrumentation, operator)
-> Step 4 (collector, namespace minibank-otel) -> Step 2 (role, DCR, DCE, federated credential, identity) -> Step 1 (service account
issuer back to `''`, then `--disable-workload-identity`; etcd backup first) -> Step 3 (images, optional). Features C and D keep working
at every point.

---

## Notes for the runbook / storyline (v1.5) - documents only

- Scene 2 (runbook 19.5) grows to about 10 minutes (live act +3, collector settings +1): `onboard-live.ps1`, then the ConfigMap of
  `10-otelcol.yaml.tpl`; the collector settings are shown again in Scene 15. `onboard-reset.ps1` goes into the reset chapter.
- Scene 2 HONEST line: "Azure Monitor does not inject agents automatically into OpenShift workloads" no longer holds as written: the
  Red Hat build of OpenTelemetry operator injects the OpenTelemetry Java agent into annotated workloads (zero code). Onboarding stays per
  workload and per runtime, not per host like OneAgent.
- Scene 15 OpenTelemetry bullet and Chapter 17.9 (optional OTLP module): the OTLP path to Azure Monitor is now built, so 17.9 is
  superseded.
- "query B.1" in the output of onboard-live.ps1 = the first query of Step 8 (runbook v1.5); it is not query B1 (node status) of
  `monitoring/kql/minibank-queries.kql`.
- Support (documentation checked 11-12 Nov 2026): the collector is the community contrib build that Microsoft documents for native
  OTLP ingestion (collector components are community-supported; Azure supports the endpoint, DCE, DCR and workspaces); Java
  auto-instrumentation in the Red Hat build of OpenTelemetry is a Technology Preview.
- Collector: rename the exporter alias `otlphttp` to `otlp_http` at the next collector change.
- Both namespaces (minibank, minibank-otel) use the ACR pull token in secret `acr-pull`: when the token is renewed, update both secrets.
- Ingestion: minibank-rates spans and logs about 0.11 GB/day (12 Nov estimate, part of the 0.19 GB/day P1 total).
