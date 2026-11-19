# Appendix C. Glossary

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


| Term | Meaning |
|---|---|
| Application Insights | The application performance monitoring part of Azure Monitor. It stores requests, dependencies, exceptions, traces and page views. |
| Application Map | A picture of services and back-ends that Application Insights builds automatically from traces. |
| Assisted Installer | Red Hat's web-based installer for OpenShift at console.redhat.com. It creates a discovery ISO, checks the hosts and installs the cluster. |
| Azure Arc-enabled server | A server outside Azure that appears and is managed as an Azure resource, through the Connected Machine agent. |
| Azure Arc-enabled Kubernetes | A Kubernetes or OpenShift cluster outside Azure that appears as an Azure resource and can receive extensions such as monitoring. |
| Azure Managed Grafana | Grafana run by Azure as a managed service. The lab has its own instance, amg-appmon, which reads the lab's workspaces through its managed identity. |
| Azure Monitor Agent (AMA) | The agent that collects logs and performance data from servers according to data collection rules. |
| Azure Monitor workspace | The Azure store for Prometheus metrics (managed service for Prometheus). |
| Business decline | A correct "no" of the bank on the customer's side; in MiniBank the answer Insufficient balance (HTTP 409). It is not a technical failure and does not use the SLA error budget. |
| Compact cluster | An OpenShift cluster of three nodes that are control plane and worker at the same time. |
| Container insights | The Azure Monitor feature that collects Kubernetes inventory, performance and container logs into Log Analytics. |
| Control plane | The OpenShift nodes that run the API server and etcd and manage the cluster. |
| Cordon, drain | Marking a node so that no new pods start on it, and moving its pods away before maintenance. |
| &lt;EXEMPT_TAG&gt; tag | The tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt;, which exempts an Azure item from the cost-control automation of this subscription (Chapter 7.1). |
| CSR | Certificate signing request. A new or restarted node asks the cluster for a certificate; an administrator approves it with oc adm certificate approve. |
| DaemonSet | A Kubernetes object that runs one copy of a pod on every node, used by the monitoring agents. |
| Data collection rule (DCR) | The Azure definition of what the agent collects, how it is transformed and where it is sent. |
| draw.io | A free diagram tool (desktop app or app.diagrams.net). Figure 4-1 is a draw.io file that you can open and edit. |
| Discovery ISO | The boot image from the Assisted Installer. A VM booted from it reports its hardware to the installer. |
| Error budget | The share of requests that may fail without breaking the SLA: 0.1 percent for an SLA of 99.9 percent. |
| etcd | The database inside the OpenShift control plane that stores the state of the cluster. |
| EUS | Extended Update Support. Even-numbered OpenShift releases such as 4.20 that receive a longer support period. |
| Exporter | A small program that reads a product's statistics and offers them as Prometheus metrics. |
| IMDS | Azure Instance Metadata Service at 169.254.169.254, visible only inside Azure VMs. |
| KQL | Kusto Query Language, used in Log Analytics. |
| Log Analytics workspace | The Azure store for logs, including Application Insights and Container insights data. |
| NAT | Network address translation. Lets machines on a private network reach the internet through one address. |
| Nested virtualization | Running Hyper-V virtual machines inside an Azure virtual machine. |
| OpenTelemetry | The open standard for traces, metrics and logs. Azure Monitor's language distros are built on it. |
| P95 | The 95th percentile: 95 percent of requests were faster than this value. |
| Pod disruption budget | A Kubernetes rule that keeps a minimum number of pods running during planned disruptions such as a drain. |
| PowerShell Direct | Running PowerShell inside a Hyper-V guest from the host, without a network connection. |
| PromQL | Prometheus Query Language, used in Grafana with the Azure Monitor workspace. |
| Route (OpenShift) | The OpenShift object that publishes a service under a host name such as minibank-transfer.apps.ocp-minibank.minibank-demo.lab. |
| SAS | Shared access signature. A time-limited link that grants access to one storage item. |
| Scheduled task | A job of the Windows Task Scheduler that starts a program at set times or events, also when nobody is signed in. The lab uses minibank-traffic, minibank-probe and minibank-topup. |
| Security context constraints (SCC) | OpenShift's rules for what a pod is allowed to do. |
| Technical failure | A server error (HTTP 5xx): every fail-\* scenario and every real fault. Only technical failures count against the SLA. |
| Trace ID | The identifier shared by every hop of one transaction (W3C trace context). |
| Transformation | A KQL statement inside a data collection rule that filters or changes data before it is stored. |

---

[&larr; Appendix B. Contents of the source pack](appendix-b-contents-of-the-source-pack.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [Appendix D. References &rarr;](appendix-d-references.md)
