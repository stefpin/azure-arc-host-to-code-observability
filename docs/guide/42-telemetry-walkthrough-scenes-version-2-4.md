# 42. Telemetry walkthrough scenes (version 2.4)

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


Version 2.4 adds three walkthrough scenes after Scene 13 for the bank's engineers (Chapter 19.16A to 19.16C), on 18 November 2026. They show how the telemetry of the demo is set up today, on the running lab, in simple steps for beginners: each step says where to run it (a Portal page and field, the presenter's PowerShell window on HV-HOST-02, the APP-RHEL Bash session, the APP-WIN PowerShell Direct session or Cloud Shell), what to type and what you should see. Nothing was built or changed: the scenes walk through what Chapters 13, 15, 16, 17, 24, 31, 32, 37 and 39 built.

## 42.1 What version 2.4 adds

| Scene | What it shows | Where the presenter works | Minutes |
|---|---|---|---|
| 13A | The five sources of Application Insights: the Java agent of minibank-transfer, the .NET and Python packages, the browser package and the probe; where each keeps its connection string; query W1 | law-appmon &gt; Logs; the presenter's window on HV-HOST-02; APP-WIN - PowerShell Direct; APP-RHEL - Bash | 9 |
| 13B | The OpenTelemetry path of minibank-rates: operator, Instrumentation, annotation, injected agent, collector, endpoint and rule, workload identity; query W2 | The presenter's window; Azure Portal (dcr-otlp, id-otelcol); law-appmon &gt; Logs | 8 |
| 13C | The 10 data collection rules, one of them opened step by step; the cluster extensions and ConfigMaps; the Direct rules; queries W3 and W4; optional Azure CLI | Azure Portal (Monitor \| Data Collection Rules, arc-ocp-minibank); the presenter's window; APP-RHEL - Bash; law-appmon &gt; Logs; Cloud Shell | 9 |

Figure 19-1 maps the six telemetry paths of the demo, and twelve screenshots from 18 November 2026 (Figures 19-2 to 19-13) show the Portal pages and query results the presenter should see. Four new queries are printed in the scenes: W1 (who sends what to Application Insights), W2 (OpenTelemetry spans per service), W3 (rows per table in the last hour) and W4 (errors reported by the rules).

The scenes add 26 minutes: the session is now 150.5 minutes, or 154.5 with the optional Scene 14 (19.2). For a business audience, skip them or run them as a separate session for the bank's engineers. Each scene names a short version of about 3 minutes.

## 42.2 Read-only check record

Every fact in Scenes 13A to 13C comes from a read-only check of the lab on 18 November 2026, run the same way as the earlier checks: from Cloud Shell in the browser, with Azure Resource Manager reads, Log Analytics queries, and Run Command on HV-HOST-02 for the reads in OpenShift, in the files and on APP-RHEL.

| Time (WIB) | What was read | How |
|---|---|---|
| 09:27 | Request approved: walkthrough scenes after Scene 13 (full scenes, telemetry path diagram, read-only check, screenshots, runbook version 2.4) | - |
| 09:56 | Azure: the 10 rules, the 2 endpoints, the managed identity and its federated credential, the cluster and its extensions, the Arc machines and their agents, Application Insights, the two workspaces and the role assignments | Azure Resource Manager reads (GET) from Cloud Shell |
| 09:56 | law-appmon: who sends what, rows per table, the OpenTelemetry tables, the sources of Perf, rule errors | Log Analytics queries |
| 09:57-09:59 | OpenShift: the operator, the Instrumentation, the minibank-rates pods and their settings, the collector, its settings and log, the service account, the two ConfigMaps in kube-system, the agent pods, and the settings, ConfigMap and log of minibank-transfer | Run Command on HV-HOST-02: oc get, oc logs and oc set env --list (lists only) |
| 09:58-09:59 | Files on HV-HOST-02 (packages and the lines that switch telemetry on, the scheduled tasks, the machine setting of the probe) and on APP-RHEL (requirements.txt, app.py, the service, the settings file with every value hidden, the timer, the agent, the containers) | Run Command on HV-HOST-02: Select-String, Test-Path, Get-ScheduledTask; ssh to APP-RHEL with grep, systemctl, ls and sed without -i |
| 10:19 | A first follow-up was refused because a sign-in token had expired; nothing ran | - |
| 10:25-10:26 | Follow-up: the operator subscription, the Instrumentation and deployment details, the images, the collector deployment and service, the Dockerfiles | Run Command on HV-HOST-02: oc get, Get-ChildItem |
| After 10:26 | Activity log since 09:45 WIB. rg-appmon-openshift-demo: 13 Azure Arc heartbeats (system) and the 5 Run Command actions of the lab account. MA_amw-appmon_indonesiacentral_managed: none. rg-hyperv-arc-monitor-demo: 7 database and 1 SQL Server instance inventory updates by Azure Arc for SQL Server (system, automatic) | Activity log read |
| 10:38-11:41 | 12 screenshots in the Azure Portal (Figures 19-2 to 19-13) | Pages opened and filtered only; no button that changes anything |

Only the tools themselves wrote anything. The Run Command extension keeps a copy of each script it ran, and its output, in its own folder on HV-HOST-02 (under C:\Packages\Plugins), as it did for the earlier checks. The SSH client reported that it had added APP-RHEL to its list of known hosts, but that list was set to NUL, so nothing was saved. Nothing in Azure, in OpenShift or on the virtual machines was created or changed.

## 42.3 As-built telemetry inventory (18 November 2026)

The tables below list what Scenes 13A to 13C show, with the values read on 18 November 2026: names, versions and addresses only, no password, key or connection string. The 10 data collection rules are listed in Scene 13C, Step 1.

Application sources (paths 1 and 2):

| Service | Runs on | Package or agent | Where its settings come from | Agent text in W1 starts with |
|---|---|---|---|---|
| minibank-api | APP-WIN, IIS | Azure.Monitor.OpenTelemetry.AspNetCore 1.6.0 and one line UseAzureMonitor() in Program.cs | Two machine environment variables on APP-WIN: the connection string and OTEL_SERVICE_NAME (Chapter 15.3; not read again on 18 November) | dotnet10.0.14 |
| minibank-fraud | APP-RHEL, systemd service minibank-fraud | azure-monitor-opentelemetry 1.8.12 and configure_azure_monitor() in app.py | /etc/minibank/fraud.env, read by the service at start-up: database address, connection string and OTEL_SERVICE_NAME=minibank-fraud | ulm_py3.11.13 |
| minibank-transfer | OpenShift, namespace minibank, image minibank-transfer:1.2.0, 3 pods | Application Insights Java agent 3.7.9, in the image (transfer\Dockerfile, started with -javaagent) | Secret minibank-transfer-secrets (connection string), role name minibank-transfer, ConfigMap minibank-transfer-ai-config (agent settings) | java:3.7.9 |
| minibank-web | The customer's browser (screens served by APP-WIN) | @microsoft/applicationinsights-web ^3.4.2, started in web\src\telemetry.js | Asked from the API at start-up (GET /api/config), not built into the page | javascript:3.4.6 |
| minibank-probe | HV-HOST-02, scheduled task minibank-probe | None: probe.ps1 sends its availability results itself | Not confirmed on 18 November 2026 (42.4) | empty |
| minibank-rates | OpenShift, namespace minibank, image minibank-rates:1.0.0, 2 pods | OpenTelemetry Java agent 2.30.0, added by the operator (annotation inject-java) | Instrumentation minibank-java; OTEL_ settings that the operator adds to each pod | Not in W1: it sends OTLP (query W2) |

The OpenTelemetry chain (path 2):

| Object | Where | As built (18 November 2026) |
|---|---|---|
| Operator Red Hat build of OpenTelemetry | Namespace openshift-opentelemetry-operator | CSV opentelemetry-operator.v0.158.0-202611041238; subscription opentelemetry-product, channel stable, approval Manual; the controller-manager and two webhook pods Running |
| Instrumentation minibank-java | Namespace minibank | Java agent &lt;ACR_NAME&gt;.azurecr.io/otel/autoinstrumentation-java:2.30.0; exporter http://otelcol.minibank-otel.svc.cluster.local:4318; sampler parentbased_always_on; propagators tracecontext and baggage |
| Deployment minibank-rates | Namespace minibank | Annotation instrumentation.opentelemetry.io/inject-java "true"; 2 pods, each with the init container opentelemetry-auto-instrumentation-java |
| Collector otelcol | Namespace minibank-otel | Plain Deployment (not operator-managed), image &lt;ACR_NAME&gt;.azurecr.io/otel/opentelemetry-collector-contrib:0.164.0, 2 replicas on two nodes; service otelcol (ClusterIP, ports 4317 and 4318); ConfigMap otelcol-config with the extension azure_auth (workload identity), the processor filter/health and the exporter otlphttp/azuremonitor |
| Service account otelcol | Namespace minibank-otel | Annotation azure.workload.identity/client-id = &lt;OTELCOL_IDENTITY_CLIENT_ID&gt; |
| Managed identity id-otelcol | rg-appmon-openshift-demo | Client ID &lt;OTELCOL_IDENTITY_CLIENT_ID&gt;; federated credential fic-otelcol-minibank-otel (issuer: the Azure Arc OIDC issuer of arc-ocp-minibank; subject system:serviceaccount:minibank-otel:otelcol; audience api://AzureADTokenExchange); role Monitoring Metrics Publisher on dcr-otlp |
| Data collection endpoint dce-otlp | rg-appmon-openshift-demo | Logs https://&lt;DCE_NAME&gt;.indonesiacentral-1.ingest.monitor.azure.com, metrics https://&lt;DCE_NAME&gt;.indonesiacentral-1.metrics.ingest.monitor.azure.com; public network access enabled |
| Data collection rule dcr-otlp | rg-appmon-openshift-demo | Immutable ID dcr-&lt;IMMUTABLE_ID&gt;; Microsoft-OTel-Logs, -Traces-Spans, -Traces-Events and -Traces-Resources to law-appmon; Custom-Metrics-Otel to amw-appmon; no association |

Cluster, endpoints, agents and stores:

| Item | Where | As built (18 November 2026) |
|---|---|---|
| arc-ocp-minibank | rg-appmon-openshift-demo | Azure Arc-enabled Kubernetes: OpenShift, Kubernetes 1.33.13, Arc agent 1.39.3, Connected; OIDC issuer and workload identity enabled |
| Extension azuremonitor-containers | arc-ocp-minibank | Container insights 3.9.1 to law-appmon with Microsoft Entra sign-in (amalogs.useAADAuth=true); Succeeded |
| Extension azuremonitor-metrics | arc-ocp-minibank | Managed Prometheus 7.4.1 to amw-appmon; Succeeded |
| Extension wiextension | arc-ocp-minibank | Workload identity 1.0.13; Succeeded |
| ConfigMap container-azm-ms-agentconfig | kube-system | stdout and stderr logs on; kube-system, gatekeeper-system, azure-arc and the openshift-... namespaces excluded; environment variables off; schema v2 |
| ConfigMap ama-metrics-prometheus-config | kube-system | Scrape interval 30 s; jobs minibank-oracle (192.168.110.32:9161) and minibank-postgres (192.168.110.32:9187) |
| Data collection endpoint MSProm-indonesiacentral-arc-ocp-minibank | rg-appmon-openshift-demo | Used by the rule of the same name; public network access enabled |
| Azure Monitor agent | APP-WIN, APP-SQL, APP-RHEL, HV-HOST-02 | Windows agent 1.45.0.0 on APP-WIN and APP-SQL, Linux agent 1.45.1 on APP-RHEL, Windows agent 1.45 on HV-HOST-02 |
| appi-minibank | rg-appmon-openshift-demo | Application Insights, workspace-based (law-appmon), retention 90 days, ingestion endpoint https://indonesiacentral-0.in.applicationinsights.azure.com/ |
| law-appmon | rg-appmon-openshift-demo | Log Analytics workspace, pricing tier PerGB2018, retention 30 days, daily cap 10 GB |
| amw-appmon | rg-appmon-openshift-demo | Azure Monitor workspace; its default rule and endpoint amw-appmon are in MA_amw-appmon_indonesiacentral_managed (no association) |

## 42.4 Open items

- Update the table of contents in desktop Word (References &gt; Update Table &gt; Update entire table): the new headings 19.16A to 19.16C and Chapter 42 are not in it yet.
- Scene 2 (19.5) and Chapter 24.4 say in their BE HONEST boxes that the collector is supported by Red Hat. As built, it is the community OpenTelemetry Collector Contrib image 0.164.0 in a plain Deployment, as Chapter 24.2 records. Correct the two boxes before the next session, or move the collector to Red Hat's own build in a later change. Scene 13B already says it the right way.
- Availability probe: Chapter 17.1 says that the task minibank-probe reads the connection string from a machine environment variable on HV-HOST-02, but on 18 November 2026 that variable was not set, while the probe kept sending one result a minute. The running probe most likely read the value when it started. Before HV-HOST-02 is restarted, check the task's action (read only, without printing the string) and set the variable again if needed; otherwise the probe may stop sending after a restart, and the probe count on the SLA board would drop to zero.
- APP-WIN: the two machine settings of minibank-api (Scene 13A, Step 8) were not read again on 18 November 2026; run that step once in the rehearsal.
- There is no rates\Dockerfile in F:\Build\minibank on HV-HOST-02 (the source pack has it and builds the image on APP-RHEL). To show that the image of minibank-rates has no agent, use the BEFORE view of Scene 2 or open the Dockerfile from the source pack.
- The collector log warns that the exporter alias otlphttp is deprecated (Chapter 24.3): rename it to otlp_http at the next collector change. Version 2.4 changed nothing.
- The file /var/log/minibank/dbsnap.json on APP-RHEL was about 50 MB on 18 November 2026 and grows every minute: check that it is rotated or trimmed (not checked in version 2.4).
## 42.5 How to undo version 2.4

Nothing to undo in Azure or in the lab: version 2.4 changed neither. To present without the new scenes, skip Scenes 13A to 13C; the session is then 124.5 minutes again, or 128.5 with the optional Scene 14. Version 2.3 of this runbook stays unchanged next to this file, and the copy of Figure 19-1 in the build-helpers folder (telemetry-paths-figure-19-1.png) can be deleted at any time.

---

[&larr; 41. Service weather on the SLA board (version 2.3)](41-service-weather-on-the-sla-board-version-2-3.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [43. Look-ahead trail and month view with fast-forward (version 2.5) &rarr;](43-look-ahead-trail-and-month-view-with-fast-forward-version-2.md)
