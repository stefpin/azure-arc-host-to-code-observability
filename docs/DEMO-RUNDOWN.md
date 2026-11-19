# Demo rundown

The full demo is a 24-scene script of about two and a half hours, with a talk track (**Say this**), what you should see, and what to do if something goes wrong for every scene. It lives in [Chapter 19 of the guide](guide/19-demo-scenes-and-talk-track.md); this page is the map.

> [!TIP]
> Before the session, work through [19.1 Before the session](guide/19-demo-scenes-and-talk-track.md#191-before-the-session) and the acceptance checklist of [Chapter 18](guide/18-rehearsal.md). After it, reset with [Chapter 20](guide/20-reset-between-rehearsals-and-after-the-demo.md).

## Scenes

| Scene | Topic | Minutes | Requirement |
|---|---|---|---|
| [0](guide/19-demo-scenes-and-talk-track.md#193-scene-0---the-story-and-minibank) | The story and MiniBank | 3 | Context |
| [0A](guide/19-demo-scenes-and-talk-track.md#193a-scene-0a---the-technology-stack-tour-new-in-version-16-6-minutes) | The technology stack: Hyper-V, OpenShift web console, Oracle, PostgreSQL, SQL Server (new) | 6 | R7, R9 |
| [1](guide/19-demo-scenes-and-talk-track.md#194-scene-1---openshift-in-azure-arc) | OpenShift in Azure Arc (and start adding a node) | 6 | R9, R10 |
| [2](guide/19-demo-scenes-and-talk-track.md#195-scene-2---how-easy-it-is-to-onboard) | How easy it is to onboard each language, with live zero-code onboarding on OpenShift | 10 | R5, R7, R8 |
| [3](guide/19-demo-scenes-and-talk-track.md#196-scene-3---application-map) | Application Map | 6 | R3 |
| [4](guide/19-demo-scenes-and-talk-track.md#197-scene-4---one-transaction-end-to-end) | One transaction end to end | 6 | R1 |
| [5](guide/19-demo-scenes-and-talk-track.md#198-scene-5---latency-and-a-slow-oracle-call) | Latency and a slow Oracle call (starts the incident command) | 6 | R1 |
| [6](guide/19-demo-scenes-and-talk-track.md#199-scene-6---failure-rate-and-failure-point) | Failure rate and failure point | 6 | R2 |
| [7](guide/19-demo-scenes-and-talk-track.md#1910-scene-7---sla-and-failure-rate-dashboards-and-alert) | SLA and failure-rate dashboards with the service weather (new), alert and business impact in IDR | 8 | R4, R8 |
| [7A](guide/19-demo-scenes-and-talk-track.md#1910a-scene-7a---the-customers-view-journeys-and-users-feature-c-new-in-version-16-5-minutes) | The customer's view: journeys and users (new) | 5 | R1, R4 |
| [7B](guide/19-demo-scenes-and-talk-track.md#1910b-scene-7b---ask-the-ai-to-investigate-feature-a-new-in-version-16-6-minutes) | Ask the AI to investigate (new) | 6 | R2 |
| [7C](guide/19-demo-scenes-and-talk-track.md#1910c-scene-7c---mystery-fault-one-board-names-the-layer-new-in-version-17-10-minutes) | Mystery fault: one board names the layer across VM, OpenShift, network, application and database (new) | 10 | R2, R9, R11 |
| [7D](guide/19-demo-scenes-and-talk-track.md#1910d-scene-7d---look-ahead-what-will-need-attention-next-new-in-version-21-radar-in-version-22-trail-and-fast-forward-in-version-25-5-minutes) | Look-ahead: what will need attention next - the radar, capacity, expiry dates on the trail and the month view with fast-forward, known weaknesses, speed and the error budget (new) | 5 | R4, R9, R11 |
| [8](guide/19-demo-scenes-and-talk-track.md#1911-scene-8---inside-openshift-container-insights-and-prometheus) | Inside OpenShift: Container insights and Prometheus | 6 | R9 |
| [9](guide/19-demo-scenes-and-talk-track.md#1912-scene-9---lose-a-node) | Lose a node | 8 | R10 |
| [10](guide/19-demo-scenes-and-talk-track.md#1913-scene-10---planned-maintenance-drain) | Planned maintenance (drain) | 5 | R10 |
| [11](guide/19-demo-scenes-and-talk-track.md#1914-scene-11---the-new-node-is-already-monitored) | The new node is already monitored | 5 | R10 |
| [12](guide/19-demo-scenes-and-talk-track.md#1915-scene-12---oracle-and-postgresql-internals) | Oracle and PostgreSQL internals | 8 | R11 |
| [13](guide/19-demo-scenes-and-talk-track.md#1916-scene-13---filtering-telemetry) | Filtering telemetry | 6 | R6 |
| [13A](guide/19-demo-scenes-and-talk-track.md#1916a-scene-13a---how-each-application-sends-telemetry-new-in-version-24-9-minutes) | How each application sends telemetry: the Java agent, the .NET, Python and browser packages, the probe and their connection strings (new) | 9 | R5, R7 |
| [13B](guide/19-demo-scenes-and-talk-track.md#1916b-scene-13b---the-opentelemetry-path-new-in-version-24-8-minutes) | The OpenTelemetry path: operator, injected agent, collector, endpoint, rule and workload identity (new) | 8 | R5, R8 |
| [13C](guide/19-demo-scenes-and-talk-track.md#1916c-scene-13c---data-collection-rules-new-in-version-24-9-minutes) | Data collection rules: what is collected, from where, what is dropped and where it is stored (new) | 9 | R6, R9, R11 |
| [14](guide/19-demo-scenes-and-talk-track.md#1917-scene-14---optional-governance-with-azure-policy) | Optional: governance with Azure Policy | 4 | R9 |
| [15](guide/19-demo-scenes-and-talk-track.md#1918-scene-15---wrap-up) | Wrap-up: Cloudera, OpenTelemetry with the collector callback, next steps | 4.5 | R7, R8 |

**Total:** 151.5 minutes without the optional Scene 14. If time is short, move Scenes 13A to 13C (26 minutes) to a separate session for the bank's engineers first, then drop Scene 14, then show only the radar and the risk register of Scene 7D (2 minutes), then shorten Scene 0A to the OpenShift web console (2 minutes), then show Scene 7C from the morning history only (4 minutes).

## Requirements the scenes answer

| ID | Requirement | How the lab answers it | Where |
|---|---|---|---|
| R1 | Distributed traces: performance and latency of each request across services | Application Insights end-to-end transaction view and Performance view (P50, P95, P99), with OpenTelemetry-based instrumentation in every service | Chapter 15; Scenes 4, 5 and 7A |
| R2 | Failure rate and failure point | Application Insights Failures view: failed requests, exceptions with stack traces, failed dependencies (SQL Server, Oracle, PostgreSQL, HTTP) | Chapter 15; Scenes 6 and 7B |
| R3 | Application flow: which service calls which back-end or endpoint | Application Map built automatically from W3C trace context: React, .NET, Java on OpenShift, Python, three databases | Chapter 15; Scene 3 |
| R4 | Dashboards for SLA and failure rate | Azure Workbook, Grafana dashboards, availability probe and log alerts; business declines are shown apart from technical failures | Chapters 17 and 25; Scenes 7 and 7A |
| R5 | How easy it is to adjust existing applications | Java: one agent file and no code change, also inside a container image. .NET: one package and one line. Python: one package and two lines. React: one package and one small file | Chapters 15 and 24; Scene 2 (Parts 1 and 2) |
| R6 | Filter the metrics and telemetry sent to Azure Monitor | At the source: sampling and masking rules in the Java agent. At collection: Container insights namespace filter and Prometheus scrape list. At ingestion: data collection rule transformation for IIS logs | Chapter 17; Scene 13 |
| R7 | Cover Java, Python, .NET, React and Oracle, SQL Server, PostgreSQL, Cloudera | All four languages and three databases are built for real. Cloudera is a talk track | Chapters 14, 15; Scenes 0A and 15 |
| R8 | Keep using what the bank already has (Grafana, OpenTelemetry knowledge) | Azure Managed Grafana (the lab's own amg-appmon), Prometheus data and an optional OTLP module | Chapters 17 and 24; Scenes 2, 7, 8 and 15 |
| R9 | Manage and monitor Red Hat OpenShift with Azure Arc | Arc-enabled Kubernetes inventory and Kubernetes resources view, Container insights, managed Prometheus, optional Azure Policy | Chapters 12, 13; Scenes 0A, 1, 8, 14 |
| R10 | Behaviour of a multi-node cluster when nodes fail, are maintained or are added | Three OpenShift nodes with three copies of the transfer service; node power-off, drain and a fourth worker added live | Chapters 12, 15; Scenes 9, 10, 11 |
| R11 | Database-internal monitoring of Oracle and PostgreSQL | Route A: snapshots of sessions, waits, top SQL and locks collected by the Azure Monitor Agent. Route B: Oracle and PostgreSQL exporters scraped by managed Prometheus | Chapter 16; Scene 12 |

Back to the [guide index](guide/README.md) or the [repository front page](../README.md).
