# 2. Safety rules and approval gates

<sub>Part A - Understand and prepare &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 2.1 Rules that apply to every chapter

- **Stay inside the approved boundary.** Use subscription &lt;YOUR_SUBSCRIPTION_NAME&gt; (&lt;SUBSCRIPTION_ID&gt;) in tenant &lt;TENANT_ID&gt;. Create every new Azure item in the new resource group rg-appmon-openshift-demo, in region Indonesia Central unless a step names another region. Do not create, change or delete anything in any other resource group. The only other resource group you touch is MA_amw-appmon_indonesiacentral_managed, which Azure creates for amw-appmon: you only merge the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; onto it and its resources (Chapter 7.1).
- **Leave the Hyper-V demo alone.** Do not touch rg-hyperv-arc-monitor-demo, HV-HOST-01, its guests, its workspace law-arc-monitor-poc, its data collection rules, alert rules, action group, workbook, Grafana, maintenance configuration or shift-report applications. There is no exception: since version 1.3 the lab has its own Azure Managed Grafana, amg-appmon, inside rg-appmon-openshift-demo (gate G6, Chapter 10.7).
- **Never expose secrets.** Keep passwords, the kubeadmin password, the Red Hat pull secret, the registry token and storage links in the approved ENVIRONMENT.txt file only (Chapter 5.2). The Application Insights connection string is not a password, but treat it as internal information.
- **No new notifications.** Alert rules in this runbook are created without an action group, so nobody receives email or Teams messages.
- **Keep the lab running while it is in use.** From the OpenShift installation (Chapter 12) until the demo is over, do not stop or deallocate HV-HOST-02, do not turn on auto-shutdown and do not let a cost-control tool stop it: keep the tag &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; on every lab item (Chapter 7.1). A cluster that is stopped within 24 hours of installation may not start again.
- **Preview features need explicit approval.** The optional OpenTelemetry (OTLP) module in Chapter 17.9 uses preview features and needs gate G10.
- **If you are unsure, stop.** Write down what you saw and ask. Never delete, recreate or restart something just to make an error disappear.
## 2.2 Approval gates

Each gate appears again in an APPROVAL GATE box at the step where it applies. Record each approval (who approved, when and what) in the pre-check record (Chapter 6.6) before you start that step.

| Gate | What it allows | Where |
|---|---|---|
| G0 | Start the build and accept the running cost (Chapter 22.1), and ask for the governance cost-control exception for the new resource group | Chapter 7 |
| G1 | Register missing resource providers; create the resource group, virtual network, NAT gateway, network security group and Bastion | Chapters 6.3, 7 |
| G2 | Create HV-HOST-02 and its five data disks | Chapter 8 |
| G3 | Create the Log Analytics workspace, Application Insights, Azure Monitor workspace, container registry, registry tokens, and the optional storage account and download link | Chapter 10 |
| G4 | Connect APP-WIN, APP-RHEL and APP-SQL to Azure Arc, install the Azure Monitor Agent, create data collection rules and the custom table | Chapters 11, 14, 16 |
| G5 | Create the OpenShift trial cluster, connect it to Azure Arc, install the Container insights and Prometheus extensions, deploy MiniBank to OpenShift | Chapters 12, 13, 15, 16 |
| G6 | Create amg-appmon in the lab resource group, give it read access, add the Prometheus data source and import two dashboards | Chapters 10.7, 17.4 |
| G7 | Create alert rules without notifications | Chapter 17.5 |
| G8 | Run the disruptive scenes: power off a node, drain a node, add the fourth worker | Chapters 18, 19 |
| G9 | Remove the lab: delete the resource group (this removes Grafana too; there is nothing to clean in the Hyper-V demo) and the Red Hat cluster record | Chapter 22.4 |
| G10 | Optional preview: OpenTelemetry (OTLP) ingestion | Chapter 17.9 |

---

[&larr; 1. How to use this runbook](01-how-to-use-this-runbook.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [3. What the bank asked for and how this demo answers it &rarr;](03-what-the-bank-asked-for-and-how-this-demo-answers-it.md)
