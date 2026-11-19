# 24. Feature B - onboard a service with no code change

<sub>Part F - Priority 1 features (version 1.5) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 24.1 How it works

minibank-rates is a small Java service that the transfer service calls for every payment (GET /api/rates/check, 2-second timeout with a fallback, so a rates problem never fails a payment). Its image has no monitoring agent. The Red Hat build of OpenTelemetry operator watches for the pod annotation instrumentation.opentelemetry.io/inject-java: "true"; when a pod with it starts, the operator adds an init container that copies the OpenTelemetry Java agent into the pod and sets JAVA_TOOL_OPTIONS with -javaagent. The agent sends traces, logs and metrics to the OpenTelemetry Collector otelcol in namespace minibank-otel, and the collector sends them over OTLP to Azure Monitor (data collection endpoint dce-otlp, rule dcr-otlp) in Indonesia Central. The collector signs in with Microsoft Entra workload identity (managed identity id-otelcol, federated with the service account minibank-otel/otelcol through the Azure Arc OIDC issuer), so there is no secret in the cluster.

In Application Insights the service appears with the role name [minibank]/minibank-rates (namespace in brackets), next to the services that use the Microsoft Java agent, and one end-to-end transaction shows both: minibank-api, SQL, minibank-transfer (Microsoft agent), [minibank]/minibank-rates (OpenTelemetry agent), minibank-fraud, PostgreSQL and Oracle.

## 24.2 As built

| Object | Where | Detail |
|---|---|---|
| Operator subscription opentelemetry-product | namespace openshift-opentelemetry-operator | Red Hat build of OpenTelemetry, installPlanApproval Manual (CSV v0.158.0 at build time); approve every InstallPlan by hand |
| Collector otelcol (Deployment, ConfigMap otelcol-config, Service otelcol) | namespace minibank-otel | 2 replicas with a PodDisruptionBudget; image otel/opentelemetry-collector-contrib:0.164.0 from the ACR; extension azure_auth signs in with workload identity; exporter otlphttp/azuremonitor sends to dce-otlp; processor filter/health drops spans named \*/actuator/health\*. It is a plain Deployment, not an operator-managed collector |
| Service account otelcol | namespace minibank-otel | annotation azure.workload.identity/client-id = client ID of id-otelcol |
| Instrumentation minibank-java | namespace minibank | Java agent image otel/autoinstrumentation-java:2.30.0 from the ACR; exporter http://otelcol.minibank-otel.svc.cluster.local:4318 |
| Deployment minibank-rates | namespace minibank | 2 replicas, PodDisruptionBudget, annotation inject-java "true" |
| Deployment minibank-rates-copy | namespace minibank | 1 replica with Service and Route, NOT onboarded; used for the live act in Scene 2 |
| Deployment minibank-transfer | namespace minibank | version 1.2.0 (calls minibank-rates), 3 pods, one per node |
| Manifests and scripts | HV-HOST-02 | F:\Build\minibank\openshift\p1\ (templates) and rendered\ (filled in); F:\Build\minibank\scripts\onboard-live.ps1 and onboard-reset.ps1 |

Verified gates on 12 November 2026: G1 OTLP data stored in Indonesia Central; G2 no secret in the cluster (workload identity); G3 Application Map and the Performance view work for the OpenTelemetry role; G4 one end-to-end transaction across the Microsoft agent and the OpenTelemetry agent (193 of 193 rates calls joined a transfer trace).

## 24.3 Check that it is healthy

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5 (oc uses F:\Build\ocp\kubeconfig): the four oc lines below. The OTelSpans query after them runs in the Azure Portal, in law-appmon &gt; Logs (next box).

```bash
oc get pods -n minibank-otel -o wide
oc get instrumentation -n minibank
oc get pods -n minibank -l app=minibank-rates -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.initContainers[*].name}{"\n"}{end}'
oc logs -n minibank-otel deploy/otelcol --tail=20
```

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
OTelSpans
| where TimeGenerated > ago(30m) and ServiceName == "minibank-rates"
| summarize Spans = count(), Pods = dcount(tostring(ResourceAttributes["k8s.pod.name"])), P95Ms = percentile(DurationMs, 95)
            by Distro = tostring(ResourceAttributes["telemetry.distro.version"])
```

> [!TIP]
> **What you should see**
>
> Two otelcol pods Running on different nodes; the Instrumentation minibank-java; each minibank-rates pod lists the init container opentelemetry-auto-instrumentation-java; no export errors in the collector log (one known warning: the exporter alias otlphttp is deprecated, rename it to otlp_http at the next collector change); spans from both pods in the last 30 minutes

## 24.4 The live act in Scene 2

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02, PowerShell as Administrator, folder F:\Build\minibank\scripts (the presenter's window, large font)

```powershell
powershell -ExecutionPolicy Bypass -File .\onboard-live.ps1
powershell -ExecutionPolicy Bypass -File .\onboard-reset.ps1
```

onboard-live.ps1 shows the pod of minibank-rates-copy BEFORE (no init container, no -javaagent), shows the one-line patch (the annotation), applies it with oc patch, waits for the new pod and shows it AFTER (init container opentelemetry-auto-instrumentation-java, -javaagent in JAVA_TOOL_OPTIONS, the same image digest), then makes three test calls through the Route so a real trace arrives. It takes about 28 seconds; the new pod is ready in about 18 seconds. onboard-reset.ps1 removes the annotation again (about 20 seconds) and is part of the reset after every rehearsal.

Query B.1 (onboard-live.ps1 points to it): run it in law-appmon &gt; Logs, where the OpenTelemetry tables are. minibank-rates-copy appears 1 to 2 minutes after the three test calls.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
OTelSpans
| where TimeGenerated > ago(15m)
| summarize spans = count(), lastSeen = max(TimeGenerated) by ServiceName, RoleName, agent = tostring(ResourceAttributes["telemetry.distro.version"])
| order by lastSeen desc
```

> [!TIP]
> **What you should see**
>
> BEFORE: no init container. AFTER: init container and -javaagent, same image digest. In Application Insights &gt; Application map, [minibank]/minibank-rates-copy appears within 2 to 4 minutes; Transaction search shows the three test calls

> [!IMPORTANT]
> **Say this**
>
> We did not change the code, the image or the build. One annotation, and the operator from Red Hat put the OpenTelemetry agent into the pod. The data goes over the open OTLP protocol into Azure Monitor in Indonesia Central, without a password in the cluster.

> [!CAUTION]
> **Be honest**
>
> The operator and the collector are open source and supported by Red Hat; Java auto-instrumentation through the operator is Technology Preview. The services that use the Microsoft Java agent stay as they are; both kinds appear in one view.

## 24.5 If something goes wrong

> [!WARNING]
> **If something goes wrong**
>
> Run these checks in HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5. No new pod after the patch: oc describe deploy minibank-rates-copy -n minibank, and check that the operator pod in openshift-opentelemetry-operator is Running. Pod has no init container: the Instrumentation minibank-java is missing or in another namespace (oc get instrumentation -A). No spans in Azure: oc logs -n minibank-otel deploy/otelcol; an HTTP 403 means the role assignment on dcr-otlp or the federated credential is wrong; an HTTP 401 or a token error means the workload identity (service account annotation, Arc OIDC issuer). If the live act fails in front of the audience: show the already onboarded minibank-rates instead and run onboard-reset.ps1 later

## 24.6 Rollback

| Change | Undo |
|---|---|
| Live act | HV-HOST-02 - PowerShell (Admin), the presenter's window in F:\Build\minibank\scripts: powershell -ExecutionPolicy Bypass -File .\onboard-reset.ps1 |
| Services | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc delete deploy/minibank-rates deploy/minibank-rates-copy svc/minibank-rates svc/minibank-rates-copy route/minibank-rates-copy -n minibank; roll minibank-transfer back to 1.1.x from F:\Build\backup\minibank-transfer-deployment-before-p1-\*.yaml (transfer 1.2.0 also works without rates: it uses its fallback) |
| Operator and collector | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5: oc delete instrumentation minibank-java -n minibank; oc delete project minibank-otel; delete the subscription and CSV in openshift-opentelemetry-operator |
| Azure | Cloud Shell - PowerShell, after the start block of Chapter 5.4: az monitor data-collection rule delete (dcr-otlp); az monitor data-collection endpoint delete (dce-otlp); az identity delete (id-otelcol) |
| Workload identity | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5 and the az login of Chapter 13.1: oc patch authentication.config cluster --type merge -p '{"spec":{"serviceAccountIssuer":""}}' (kube-apiserver rolls out), then az connectedk8s update -g rg-appmon-openshift-demo -n arc-ocp-minibank --disable-workload-identity |

---

[&larr; 23. What version 1.5 adds](23-what-version-1-5-adds.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [25. Feature D - business impact in IDR &rarr;](25-feature-d-business-impact-in-idr.md)
