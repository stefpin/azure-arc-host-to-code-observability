# 3. What the bank asked for and how this demo answers it

<sub>Part A - Understand and prepare &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 3.1 The requirements

| ID | The bank requirement | Azure answer used in this demo | Built in / shown in |
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

## 3.2 Decisions taken since version 1.0

| Topic | Decision | Agreed |
|---|---|---|
| Lab boundary | New resource group rg-appmon-openshift-demo with its own network, Bastion, host, workspaces and registry. The Hyper-V demo is not touched | 10 Nov 2026 |
| Host | HV-HOST-02, Standard_E20s_v5 (20 vCPU, 160 GiB), Windows Server 2025 with Hyper-V | 10 Nov 2026 |
| Quota | Checked read-only on 10 Nov 2026 in Indonesia Central: Standard ESv5 family 16 of 100 vCPU used, total regional 32 of 100. After HV-HOST-02: 36 and 52. E20s_v5 is offered without restriction in zones 1, 2 and 3 | 10 Nov 2026 |
| OpenShift | Version 4.20 (an Extended Update Support release on Kubernetes 1.33; maintenance support until 21 April 2027). Three control-plane nodes that also run applications (6 vCPU, 24 GB each) plus a fourth worker (4 vCPU, 16 GB) for the add-a-node scene | 10 Nov 2026 |
| Workload placement | The Java transfer service runs as three containers on OpenShift. The React web app and .NET API run on Windows with IIS, the Python fraud service, Oracle and PostgreSQL on RHEL, SQL Server on its own Windows VM | 10 Nov 2026 |
| Database internals | Route A (Azure Monitor Agent and Log Analytics) and Route B (exporters and managed Prometheus). Route C (OpenTelemetry Collector receivers) is not built | 10 Nov 2026 |
| Application name | MiniBank, a synthetic banking application written for this lab; no customer code, data or branding | 10 Nov 2026 |
| D1 Network and access | Own virtual network, NAT gateway for outbound internet, Azure Bastion Basic | 10 Nov 2026 |
| D2 Image registry | Azure Container Registry, Basic tier, with a pull-only token for OpenShift | 10 Nov 2026 |
| D3 Add-a-node scene | The fourth VM is created and discovered before the session; the presenter starts its installation during the demo | 10 Nov 2026 |
| D4 Language | English by default, Indonesian through a toggle | 10 Nov 2026 |
| D5 Getting the code into the lab | The source pack is uploaded to a private storage account and downloaded on HV-HOST-02 with a time-limited link. As built, a governance policy blocked the link, so the pack was copied from OneDrive instead (Chapter 10.6) | 10 Nov 2026 |
| D6 Running schedule | HV-HOST-02 stays running from the OpenShift installation until after the demo | 10 Nov 2026 |
| Grafana (until version 1.2) | Reuse the Grafana of the Hyper-V demo (content only). Replaced on 11 Nov 2026 by the next row | 10 Nov 2026 |
| Grafana | Own Azure Managed Grafana amg-appmon (Standard, Grafana 12) in rg-appmon-openshift-demo; the Hyper-V demo is not touched at all | 11 Nov 2026 |
| Cost-control tags | &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; merged onto rg-appmon-openshift-demo, MA_amw-appmon_indonesiacentral_managed and every resource in them | 11 Nov 2026 |
| Continuous traffic | The load generator runs all the time (scheduled task minibank-traffic, 30 operations per minute), with a balance top-up every 6 hours on APP-SQL (Tabungan accounts set to IDR 250 million) | 11 Nov 2026 |
| Background failures | 0.05 percent technical failures in the continuous traffic (about one per hour) instead of 1 percent | 11 Nov 2026 |
| Business declines | About 4 per hour, shown separately from technical failures (HTTP 5xx); they do not use the SLA error budget | 11 Nov 2026 |
| Decline alert | Informational log search alert alr-minibank-decline-spike, without notifications | 11 Nov 2026 |

## 3.3 Assumptions used until the bank answers the open questions

Open questions were sent to the bank's IT team on 31 October 2026. Until they are answered, this runbook uses the common assumptions below. When answers arrive, review this table first. Most changes affect only the talk track, not the build.

| Q | Topic | Assumption used in this runbook |
|---|---|---|
| Q1 | Java services | Spring Boot on Java 17 or 21. The demo uses Spring Boot on Java 21, built into a Red Hat UBI container image. |
| Q2 | .NET services | ASP.NET Core (.NET 8 or later) in IIS on Windows Server. The demo uses .NET 10 in IIS on Windows Server 2022. Older .NET Framework applications are a talk track. |
| Q3 | Data rules for telemetry | Assume private connectivity (for example ExpressRoute) and strict data rules: telemetry may be stored in-country, account numbers must be masked and request or response bodies must never be collected. The demo stores data in Indonesia Central, masks account numbers and collects no bodies. Production would add Azure Monitor Private Link Scope over ExpressRoute. |
| Q4 | Pilot size | Three to five services with up to 50 transactions per second each. The demo keeps 100 percent of requests and shows how sampling reduces volume. |
| Q5 | Oracle | Oracle 19c or later. The demo uses Oracle AI Database 26ai Free in a container and reads the same dynamic performance views (V$ views) that Oracle Enterprise Edition offers. |
| Q6 | Cloudera | Cloudera Private Cloud Base 7.x managed by Cloudera Manager. Talk track only. |
| Q7 | SLA definition | Availability 99.9 percent per month, P95 latency below 1,000 ms for business transactions, alert when the failure rate is above 2 percent for 5 minutes. From version 1.3 the demo counts only technical failures (HTTP 5xx) against the SLA; business declines such as Insufficient balance (HTTP 409) are shown separately (Chapter 4.4). |
| Q8 | Current tools | An existing APM product may stay in production during an evaluation, and OpenTelemetry-based tracing may already have been tried. |
| Q9 | OpenShift | Production clusters typically run an OpenShift 4.x Extended Update Support release with three control-plane nodes and separate worker nodes, often behind a proxy. The demo uses 4.20 and a compact cluster without a proxy. |

## 3.4 What this demo does not cover

- A real Cloudera cluster. It is a talk track.
- Private Link and ExpressRoute. The lab sends telemetry over the internet to public Azure endpoints.
- Real high availability. All OpenShift nodes share one Azure virtual machine, so the node scenes show Kubernetes behaviour, not hardware resilience.
- Production sizing and production cost.
- Azure role-based access control for OpenShift: Azure RBAC on Arc-enabled Kubernetes is not supported for OpenShift, so OpenShift keeps its own role-based access control.
- Real application code of the bank. MiniBank is a small sample written only for this demo.

> [!CAUTION]
> **Be honest**
>
> Say clearly that application onboarding is per runtime: one agent or package per service, unlike a single host agent that instruments everything on a server. Say that Oracle Free is a developer edition with limits on CPU, memory and data size, and that the Oracle views used here exist in every edition. Say that the optional OTLP ingestion path is a preview, and that Microsoft Defender for Containers on Arc-enabled clusters is a preview and only a talk track in this demo.

---

[&larr; 2. Safety rules and approval gates](02-safety-rules-and-approval-gates.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [4. Demo design &rarr;](04-demo-design.md)
