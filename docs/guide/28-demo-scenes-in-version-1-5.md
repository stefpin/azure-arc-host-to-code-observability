# 28. Demo scenes in version 1.5

<sub>Part F - Priority 1 features (version 1.5) &nbsp;|&nbsp; [Guide index](README.md)</sub>


**Version 1.6:** Chapter 19 now contains these scenes step by step, with a WHERE TO RUN IT box for every command and query (Scenes 2, 3, 4, 5, 6, 7, 7A, 7B and 15), plus the new Scene 0A that tours the technology stack. Use Chapter 19 for rehearsals and for the demo; this chapter stays as the summary of what version 1.5 changed.

## 28.1 Scene list and timings

| Scene | Topic | Minutes | Change in version 1.5 |
|---|---|---|---|
| 0 | The story and MiniBank | 3 | - |
| 1 | OpenShift in Azure Arc (and start adding a node) | 6 | - |
| 2 | How easy it is to onboard each language | 10 | Live zero-code onboarding (3 min) and the collector settings (1 min), Chapter 28.2 |
| 3 | Application Map | 6 | The OpenTelemetry service [minibank]/minibank-rates in the same map (1 min) |
| 4 | One transaction end to end | 6 | The transaction now spans both agents (no extra time) |
| 5 | Latency and a slow Oracle call | 6 | Start with incident.ps1 -Scene 5 (Chapter 28.4) |
| 6 | Failure rate and failure point | 6 | Second phase of the same command, nothing to start |
| 7 | SLA and failure-rate dashboards and alert | 8 | Business impact in IDR and the IDR alert (2 min), Chapter 28.5 |
| 7A | The customer's view: journeys and users | 5 | New, feature C, Chapter 28.6 |
| 7B | Ask the AI to investigate | 6 | New, feature A, Chapter 28.7 |
| 8 to 13 | As in version 1.4 | 38 | - |
| 14 | Optional: governance with Azure Policy | 4 | - |
| 15 | Wrap-up: Cloudera, OpenTelemetry, next steps | 4.5 | 30-second callback to the collector settings, Chapter 28.8 |
| Total |   | 108.5 | 104.5 without Scene 14; drop Scene 14 first when time is short |

## 28.2 Scene 2 - zero-code onboarding on OpenShift (adds 4 minutes)

After the existing part of Scene 2 (the Microsoft agents for .NET, Java and Python), switch to the presenter's PowerShell window on HV-HOST-02 and run onboard-live.ps1 (Chapter 24.4). While the pod restarts, open Application Insights &gt; Application map; after the three test calls, refresh until [minibank]/minibank-rates-copy appears (2 to 4 minutes; if it is slow, continue and come back at the end of Scene 3). Then show the collector settings for one minute: oc get configmap otelcol-config -n minibank-otel -o yaml, pointing at the exporter otlphttp/azuremonitor (the data collection endpoint in Indonesia Central) and the extension azure_auth with workload_identity (no key, no password).

> [!IMPORTANT]
> **Say this**
>
> One annotation, no code, no new image: Red Hat's operator adds the open-source OpenTelemetry agent at start-up. The collector sends the data with the open OTLP protocol to Azure Monitor in Indonesia Central and signs in with a managed identity, so there is no secret to rotate. If the bank already uses OpenTelemetry or Grafana Tempo today, this is the same standard.

## 28.3 Scenes 3 and 4 - one map, one transaction across both agents

In Scene 3 point at [minibank]/minibank-rates under minibank-transfer: the bracket shows the OpenShift namespace of an OpenTelemetry service. In Scene 4 open one transfer in End-to-end transaction details: minibank-api, SQL, minibank-transfer (Microsoft agent), [minibank]/minibank-rates (OpenTelemetry agent), minibank-fraud, PostgreSQL and Oracle in one view.

## 28.4 Scenes 5 and 6 - one incident command

At the start of Scene 5 run, on HV-HOST-02:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\incident.ps1 -Scene 5
```

It replaces the second-window traffic commands of version 1.4. The first 5 minutes are slow-oracle (Scene 5: every slow payment takes about 2 seconds; every 3rd robot payment is slow too), then 10 minutes of fail-oracle (Scene 6). The robot's customers see the same incident in their browsers (Scene 7A). If you skip Scene 5, run -Scene 6 at the start of Scene 6 instead. If the demo must stop early: incident.ps1 -Stop.

## 28.5 Scene 7 - business impact in IDR (adds 2 minutes)

After the SLA tiles and the failure-rate chart, scroll the workbook to Business impact (IDR): failed payment value, customers affected, value by tier and amount band, and the latest failed payments with User ID and trace ID. Open Monitor &gt; Alerts: alr-minibank-failure-rate-high has fired; alr-minibank-failed-value-idr fires once the failed payments pass IDR 100,000,000 in 10 minutes (HARYANTO.TJAHJADI's IDR 150,000,000 transfer, about 4 minutes into the failure phase, plus up to 5 minutes for ingestion and evaluation).

> [!IMPORTANT]
> **Say this**
>
> Ops sees a failure rate. The business sees rupiah: in ten minutes payments worth more than 200 million rupiah failed for six customers, two of them Prioritas and one Solitaire. This alert is about money, not about HTTP codes, and it opens the same trace as the engineer's view.

## 28.6 Scene 7A - the customer's view (new, 5 minutes)

Open Application Insights appi-minibank &gt; Users (left menu, under Usage) and Sessions (filter the custom property trafficSource = robot to show the simulated customers, people for the audience); then run query E7 for the journey success rate and E9 for the failed journeys with User ID, failed step and trace ID in the Azure Portal, law-appmon &gt; Logs (KQL mode; both queries are printed in Chapters 19.10A and 26.6); open one trace. Show the journey alert alr-minibank-journey-success-low in Monitor &gt; Alerts (it fires when fewer than 90 % of journeys succeed with at least 2 failures in 10 minutes). Optional: let one person make a payment in Edge on HV-HOST-02 (http://192.168.110.31:8080 works only inside the lab network) and show that session labelled people. Version 1.6: Chapter 19.10A has this scene step by step.

> [!IMPORTANT]
> **Say this**
>
> These are customers, not servers: each line is a person who tried to pay and saw an error, with the step where it happened and the trace behind it. We can see who was affected and by how much, and filter out test robots and probes.

> [!CAUTION]
> **Be honest**
>
> The customers are simulated by a robot that uses the real page; the label robot keeps them apart from real people. In production the same events come from real browsers or the mobile app.

## 28.7 Scene 7B - ask the AI to investigate (new, 6 minutes)

Open the fired alert alr-minibank-failed-value-idr (or alr-minibank-failure-rate-high) in the Azure Portal, Monitor &gt; Alerts, select Investigate, show the plan, then Start investigation. A deep investigation takes several minutes: keep talking (what the agent looks at: metrics, traces, logs, changes, resource health), and come back to the result. On the demo day, run one investigation in the morning on a short rehearsal incident (incident.ps1 -Scene 6 in the presenter's window on HV-HOST-02, folder F:\Build\minibank\scripts) and keep that tab open (or select Create issue to keep the result) as the backup if the live run is slow. Version 1.6: Chapter 19.10B has this scene step by step.

> [!IMPORTANT]
> **Say this**
>
> The agent read the same telemetry you just saw and wrote what happened, where it failed and what to do next, with the evidence. It found the failing Oracle query behind the 502 errors without being told where to look.

> [!CAUTION]
> **Be honest**
>
> The telemetry stays in Indonesia Central, but the AI analysis runs in the agent's supported regions, which do not include Southeast Asia today. Each deep investigation has a cost (up to about US$5) and is limited in this lab (Chapter 27.4).

## 28.8 Scene 15 - callback (adds 30 seconds)

When you mention OpenTelemetry in the wrap-up, show the collector settings again for 30 seconds: the same open standard that brought minibank-rates in without code can send data from Cloudera, existing tracing back ends or any OpenTelemetry source to the same place.

## 28.9 Reset after a rehearsal (adds to Chapter 20)

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\incident.ps1 -Stop        # only if an incident is still running
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\onboard-reset.ps1           # remove the live onboarding
```

Then close the fired alerts (Chapter 20.3: Monitor &gt; Alerts &gt; select &gt; Change state &gt; Closed; the new alerts resolve by themselves when the data is normal), and top up the balances if a rehearsal ran many payments (Chapter 20.1; the top-up task does it every 6 hours). The robot keeps running; pause it only for maintenance (Chapter 26.3).

---

[&larr; 27. Feature A - AI investigation with the Azure Copilot Observability Agent](27-feature-a-ai-investigation-with-the-azure-copilot-observabil.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [29. Build record and lessons (12 November 2026) &rarr;](29-build-record-and-lessons-12-november-2026.md)
