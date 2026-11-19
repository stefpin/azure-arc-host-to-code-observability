# 1. How to use this runbook

<sub>Part A - Understand and prepare &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 1.1 What this runbook is

A bank's IT team asked to see how Azure Arc and Azure Monitor can monitor applications that run in the bank's own data centres: distributed traces and latency, failure rate and failure point, the flow between services and back-ends, SLA dashboards, how much work it takes to onboard existing applications, and how to filter the telemetry that is sent to Azure. The estate in scope is typical for a bank: Java, Python, .NET and React applications, Oracle, SQL Server, PostgreSQL and Cloudera data platforms, and containers on Red Hat OpenShift.

This runbook builds a complete, separate lab that answers those questions with a small banking application called **MiniBank**. MiniBank is a synthetic internet-banking app written only for this lab. Its transfer service runs as containers on a three-node Red Hat OpenShift 4.20 cluster, and its other parts run on Windows and Linux virtual machines, exactly like a typical on-premises bank estate. Everything runs inside one Azure virtual machine that plays the role of an on-premises Hyper-V server.

Version 2.5 completes the redesign of the Look-ahead board (Chapter 43). Under the heading Calendar of the Grafana board MiniBank - Look-ahead, a trail shows every dated risk on a road from today into the next two years, and an Outlook-style month view shows the same dates as a calendar. Both can fast-forward: one click on a stop, or a date in the board setting Look ahead to, shows the lab as it would look on that day if nobody acts. Scene 7D now shows that jump. Only this one board changed; the rest of the demo is unchanged.

Version 2.4 adds Scenes 13A to 13C, a walkthrough of the telemetry setup for engineers (Chapter 19.16A to 19.16C): how each application sends telemetry, the OpenTelemetry path through the collector and the data collection rules, with a telemetry path diagram and screenshots, in simple steps that say exactly where to run each one. The scenes walk through the setup that is already in the lab; nothing was changed (Chapter 42).

Version 2.3 adds the service weather to the Grafana board MiniBank - SLA and Failure Rate (Chapter 41). A strip under the logo header shows the weather now, over the last 7 days and for the next 7 days with the same colour rules as the five tiles, and measures the error budget against the board's own SLA of 99.9 %. Nothing else in the demo was changed.

Version 2.2 adds the Look-ahead radar and the speed item (Chapter 40). The radar sits at the top of the Grafana board MiniBank - Look-ahead and shows every risk of the register as a contact closing in on today: the distance is the time left, the sector the kind of risk and the colour the status. The speed item tracks how fast the business transactions are, after a read-only check on 17 November 2026 found them about 23 ms slower every day; at that pace they reach the 800 ms warning about 12 December 2026. Both read the same risk register, and nothing else in the demo was changed.

Version 2.1 looks ahead (Chapter 39). A new Look-ahead board, in Grafana and as a separate workbook, shows what will need attention next: capacity trends towards their limits, dates that expire, known weaknesses and the error budget of the business transactions, in one risk register with the days left, the impact, the action and the owner, and a forecast for the next 24 hours that the board checks the day after. New Scene 7D shows it right after the mystery fault. Version 2.1 also records the card 6 session of 17 November 2026: card 6 came up once in 3 draws and the board named it right, so all 18 mystery draws so far named the right layer (Chapter 38.7).

Version 2.0 makes the mystery fault easier to run and fairer to score (Chapter 38). A Mystery control window on HV-HOST-02 runs the draw, the reveal, the status and the stop with buttons, and the PowerShell lines stay as the backup. The scorecard, the workbook tile, the reveal and the test runs now grade an answer by whether customers were affected; rules v2.10 stop waiting for the host data when the host is clearly quiet; and card 6, the busy Hyper-V host, is in the mystery draw, so the bank picks a number from 1 to 6. It was built and tested on 15 and 16 November 2026 with a replay, 10 live tests, a quiet night, two blind series and 15 mystery draws, all of them right.

Version 1.9 adds the Hyper-V host to the cross-layer root-cause board (Chapter 37): host data from HV-HOST-02, a noisy-neighbour fault card with three safety stops, the host on the Live topology map and the host rule R9. It was built and calibrated on 14 November 2026; the host rule was switched on and tested in two blind series on 15 November 2026, and the scorecard now counts a yellow Warning naming the host, seen twice in a row, as the answer (option B, Chapter 37.8).

Version 1.8 adds the Live topology map (Chapter 36): one picture of the whole monitored stack, from the virtual machines through the network, OpenShift and IIS to the applications and databases, coloured live from the same verdict as the rest of the board. Version 1.7 added Part G (Chapters 30 to 35): the cross-layer root-cause board, mystery mode and their test results.

**Version 1.6** makes Chapter 19 the complete demo script. The Priority 1 scenes of Chapter 28 are now written into Scenes 2 to 7 and 15 and into the new Scenes 7A and 7B, and the new Scene 0A tours the technology stack (Hyper-V, the OpenShift web console, Oracle, PostgreSQL and SQL Server) before Azure is shown. Every command and query says exactly where to run it: the window and the machine, or the Azure Portal page, menu and field. Nothing was changed in the lab for version 1.6.

**Version 1.5** adds the four Priority 1 features, built and rehearsed in the lab on 12 November 2026: AI investigation with the Azure Copilot Observability Agent (A), zero-code onboarding on OpenShift with the Red Hat build of OpenTelemetry (B), customer journeys with a browser robot (C) and business impact in rupiah (D). Part F (Chapters 23 to 29) at the end of this runbook describes them; Chapter 28 gives the demo scenes and times of version 1.5.

**Version 1.4** brings the runbook in line with the lab as it runs on 11 November 2026. The Portal's Kubernetes resources view now signs in with your own Microsoft Entra account (Chapter 13.4), Oracle calls are named oracle.db in Application Insights (Chapter 15.2), and the new Portal paths are used. It also corrects query A.5, documents the automatic Failure Anomalies alert rule and a reliable way to keep one transfer pod per node, and prints every query in the step that uses it, so you no longer have to switch to Appendix A. The table "What changed in version 1.4" at the start of this runbook and Appendix E.1 list every change.

Version 1.3 described the lab as it was built in rg-appmon-openshift-demo on 10 and 11 November 2026. It added the fixes found during the build, a separate Azure Managed Grafana (amg-appmon) in the lab resource group, cost-control tags, continuous traffic with a balance top-up, and business declines that are shown apart from technical failures. The companion Hyper-V monitoring demo in rg-hyperv-arc-monitor-demo is not touched at all (Appendix E.2).

Version 1.2 added Figure 4-1, an architecture diagram of the whole lab drawn in draw.io with the Azure icons from the draw.io Azure library (Chapter 4.2), and the editable diagram file.

Version 1.1 replaced the MiniBank design of version 1.0. The main changes were:

- A new, separate lab: its own resource group (rg-appmon-openshift-demo) and its own Hyper-V host (HV-HOST-02). The companion Hyper-V monitoring demo in rg-hyperv-arc-monitor-demo is not touched (since version 1.3 not even its Grafana: the lab has its own, Chapter 10.7).
- Red Hat OpenShift 4.20 with three control-plane nodes that also run applications, plus a fourth worker node that you add live during the demo.
- The OpenShift cluster is connected to Azure Arc and monitored by Container insights and Azure Monitor managed service for Prometheus.
- Database-internal monitoring of Oracle and PostgreSQL through two routes: Route A (database snapshots collected by the Azure Monitor Agent into Log Analytics) and Route B (Prometheus exporters scraped into an Azure Monitor workspace).
- The application is called MiniBank and shows English by default with an Indonesian toggle.
- New demo scenes: OpenShift in Azure, losing a node, planned node maintenance, adding a node and database internals.

The runbook has five parts. Part A (Chapters 1 to 6) explains the goal, the safety rules, the design and the values you need. Part B (Chapters 7 to 10) builds the Azure foundation and the Hyper-V host. Part C (Chapters 11 to 13) builds the application virtual machines, the OpenShift cluster and the Azure Arc connection. Part D (Chapters 14 to 17) builds MiniBank, the database monitoring, the dashboards, the alerts and the filtering. Part E (Chapters 18 to 22) rehearses, presents, resets, troubleshoots and finally removes the lab. The appendices hold every query, the content of the source pack, a glossary and the references.

## 1.2 How each step is written

Every step tells you three things: where to type, what to type or click, and what you should see. Read the **WHERE TO RUN IT** box before you start a step so that you never type into the wrong window. Then do the numbered actions in order and run any command block that follows them. Finally compare your screen with the **WHAT YOU SHOULD SEE** box. If it does not match, read the **IF SOMETHING GOES WRONG** box or Chapter 21 before you try anything else.

These boxes are used throughout the runbook:

| Box | What it means |
|---|---|
| WHERE TO RUN IT | The exact machine, window and account to use for the step. |
| WHAT YOU SHOULD SEE | The result that tells you the step worked. |
| IF SOMETHING GOES WRONG | The first thing to check. Do not improvise fixes. |
| APPROVAL GATE | Stop. This step creates or changes something. Continue only after the lab owner (The lab owner) has approved the gate named in the box (Chapter 2.2). |
| BEGINNER TIP | A short explanation of a term, or a trick that saves time. |
| SAY THIS | Words you can use with the bank during the demo. |
| BE HONEST | A limitation you must state clearly, before the customer finds it. |

When a step uses a query, the query is printed in the step itself, with its number from Appendix A (for example Query A.14), so you can copy it without leaving the step. Run KQL queries in law-appmon, **Logs**, in KQL mode, with the time range set to **Set in query**; result times are UTC (WIB minus 7 hours). PromQL queries run in amw-appmon, **Prometheus explorer**, or in Grafana. Appendix A keeps the full collection.

Most build steps offer two ways to do the same thing: the **Portal path** (clicks in the Azure Portal) and the **CLI path** (commands in Azure Cloud Shell). Pick one of them for each step. Never do both, or you may create the same thing twice. Steps inside a virtual machine, such as installing SQL Server, have only one path, and the box tells you which window to use.

## 1.3 The windows you will use

Beginners most often go wrong by typing the right command into the wrong window. This lab has sixteen places where you work. The label in the first column is the one used in every WHERE TO RUN IT box.

| Label used in this runbook | How to open it | What runs there |
|---|---|---|
| Azure Portal | Browser on your own computer: https://portal.azure.com, signed in as &lt;LAB_ADMIN_UPN&gt; (tenant Contoso, &lt;GUID&gt;) | Clicks in menus, fields and buttons |
| Cloud Shell - PowerShell | In the Azure Portal, click the Cloud Shell icon (a small box with &gt;_) at the top right. If it opens in Bash, click Switch to PowerShell. | az commands that read or create Azure resources |
| Red Hat Hybrid Cloud Console | Microsoft Edge on HV-HOST-02 (recommended, because the discovery ISO must be saved on HV-HOST-02): https://console.redhat.com, signed in with your Red Hat account | The Assisted Installer that installs OpenShift |
| HV-HOST-02 - PowerShell (Admin) | Azure Portal, open the virtual machine HV-HOST-02, click Connect, then Connect via Bastion, sign in as labadmin. On the host: Start, type PowerShell, right-click Windows PowerShell, Run as administrator. | Hyper-V commands, PowerShell Direct, SSH to Linux, oc and az commands for the cluster, the traffic and probe tasks |
| Hyper-V Manager | On HV-HOST-02: Start, type Hyper-V Manager, open it | Creating, starting and stopping the lab virtual machines |
| VM console | In Hyper-V Manager, double-click a virtual machine | The screen of a virtual machine during operating-system installation |
| APP-WIN - PowerShell Direct | In HV-HOST-02 PowerShell (Admin), run the Enter-PSSession line in Chapter 5.6 | IIS, .NET, Node.js and the MiniBank web files |
| APP-SQL - PowerShell Direct | In HV-HOST-02 PowerShell (Admin), run the Enter-PSSession line in Chapter 5.6 | SQL Server installation, firewall, sqlcmd and the balance top-up task |
| APP-RHEL - Bash | In HV-HOST-02 PowerShell (Admin), type ssh -i F:\Build\ocp\id_ed25519 labadmin@192.168.110.32 (the lab SSH key: no password; Chapter 5.6) | Linux commands: dnf, systemctl, podman (also the build of the transfer image), psql, curl |
| OpenShift CLI (oc) | In HV-HOST-02 PowerShell (Admin), after the start block in Chapter 5.5 | oc commands against the OpenShift cluster |
| OpenShift web console | Microsoft Edge on HV-HOST-02: https://console-openshift-console.apps.ocp-minibank.minibank-demo.lab | OpenShift screens: nodes, pods, projects |
| MiniBank app | Microsoft Edge on HV-HOST-02: http://192.168.110.31:8080 (presenter panel: http://192.168.110.31:8080/#/demo) | The demo banking application |
| Grafana | Browser on your own computer: the endpoint of the lab's own Grafana amg-appmon (worksheet, Chapter 5.1), signed in with your lab account | Grafana dashboards |
| Presenter's window | In HV-HOST-02, a PowerShell (Admin) window with the start block of Chapter 5.5, then Set-Location F:\Build\minibank\scripts; use a large font (Ctrl and the mouse wheel) | incident.ps1, onboard-live.ps1, onboard-reset.ps1 and the oc commands that the audience sees (Chapter 19) |
| Log Analytics Logs (law-appmon &gt; Logs) | Azure Portal &gt; search box: law-appmon &gt; Logs (left menu); switch from Simple mode to KQL mode at the top right; paste into the query editor; Time range Set in query; Run | Every KQL query of this runbook: Appendix A, query B.1 and queries E1 to E10 |
| Prometheus explorer | Azure Portal &gt; search box: amw-appmon &gt; Prometheus explorer (left menu); paste one PromQL line into the PromQL box; Run query | PromQL queries (Chapter 16.2 and Appendix A.20); the same queries work in Grafana &gt; Explore |

> [!TIP]
> **Beginner tip**
>
> You can always tell where you are from the prompt. Cloud Shell shows PS /home/labadmin&gt;. HV-HOST-02 PowerShell shows PS C:\Windows\system32&gt; and the window title starts with Administrator. A PowerShell Direct session shows the guest name in square brackets, for example [APP-WIN]: PS C:\&gt;. The Linux guest shows [labadmin@app-rhel ~]$. Type exit to leave a guest session.

## 1.4 Rules for copying commands

- PowerShell blocks are written for Windows PowerShell 5.1 on HV-HOST-02 and for PowerShell 7 in Cloud Shell. Both accept the same commands in this runbook. A backtick (`) at the end of a line means the command continues on the next line. Copy all lines of a block together.
- Bash blocks run only in the APP-RHEL SSH session. A backslash (\) at the end of a line means the command continues on the next line.
- Text in angle brackets, such as &lt;ACR-NAME&gt;, is a value you must replace. Chapter 5.1 lists every value and where to find it. All IP addresses and names in this runbook are the real lab values and need no change.
- A block that starts with @' or with cat &gt; ... &lt;&lt; 'EOF' creates a file. Copy it from the first line down to and including the closing line ('@ or EOF).
- Never paste a password into this document, a chat, a ticket or a shared screen. Type passwords only into the sign-in prompt that asks for them.
- Times are Jakarta time (WIB, UTC+7) unless a step says UTC. Log Analytics results are in UTC.
## 1.5 Time plan

| Chapter | Time needed | Gates |
|---|---|---|
| 6. Read-only pre-checks | 30 minutes | None |
| 7. Resource group, network, NAT gateway, Bastion | 45 minutes (Bastion takes 10 to 20 minutes to deploy) | G0, G1 |
| 8. Create HV-HOST-02 | 30 minutes | G2 |
| 9. Prepare HV-HOST-02 (disks, Hyper-V, switch, DNS, tools, downloads) | 2 to 3 hours, mostly downloads | G3 |
| 10. Monitoring and supporting Azure items | 45 minutes | G3, G6 |
| 11. Application VMs, Azure Arc and the agent | 3 to 4 hours | G4 |
| 12. OpenShift 4.20 cluster | 3 hours (the installation itself runs about 60 to 90 minutes) | G5 |
| 13. OpenShift in Azure Arc, Container insights, Prometheus | 1 hour | G5 |
| 14. Databases | 2 hours | G4 |
| 15. MiniBank services and screens | 3 hours | G3, G5 |
| 16. Oracle and PostgreSQL internals (Routes A and B) | 90 minutes | G4, G5 |
| 17. Traffic, dashboards, alerts and filtering | 2 hours, plus up to 30 minutes of waiting for the first data | G6, G7 |
| 18. Rehearsal | 3 hours, the day before the demo | G8 |
| 19. Live demo | About 156 minutes (155.5 with the optional Scene 14, 151.5 without it, Chapter 19.2) | G8 |
| Part G. Cross-layer root cause and mystery mode (version 1.7) | About one working day to build and tune; each blind test series then runs 96 minutes by itself | Approval, Chapter 2.2 (given on 13 November 2026) |

Plan three working days for the build and one day for the rehearsal. Do not start Chapter 12 less than two days before the demo: a new OpenShift cluster must run for at least 24 hours before it may be shut down, and the 60-day OpenShift trial starts when you create the cluster.

---

[Guide index](README.md) &nbsp;|&nbsp; [2. Safety rules and approval gates &rarr;](02-safety-rules-and-approval-gates.md)
