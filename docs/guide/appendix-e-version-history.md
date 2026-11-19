# Appendix E. Version history

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


Version 2.5 (19 November 2026). The lab owner approved the Look-ahead trail with fast-forward and the Outlook-style month view at 19:03 WIB on 18 November 2026 with all the default choices, with no impact on the existing demo and changes only in rg-appmon-openshift-demo and its managed resource group. The trail was saved at 06:42 WIB and the month view at 08:13 WIB on 19 November 2026, each after tests on a temporary copy of the board; the work stopped overnight from 22:10 to 06:10 WIB without any change.

Changes to the lab (in amg-appmon only; the workbooks, the functions, the collector, the managed resource group and the Hyper-V demo were not changed):

- The Grafana board MiniBank - Look-ahead: version 5 with the trail, the board setting Look ahead to and the collapsed row Calendar details with the Expiry dates table; version 6 with the month view under the trail; every panel from Service budget down 36 rows lower (Chapter 43).

Changes to the runbook:

- New Chapter 43 with Figures 43-1 to 43-4; Scene 7D (19.10D) with the trail and the fast-forward in Step 3 and its boxes; the scene list (19.2), Before the session (19.1), the acceptance checklist (18.2) and the time plan (1.5); the Calendar line of Chapter 39.5 and the Scene 7D minutes in the undo of Chapter 39; the open items of Chapters 40.1, 40.4, 40.7 and 41.8; the front pages and Chapter 1.1.

Version 2.4 (18 November 2026). At 09:27 WIB on 18 November 2026 the lab owner asked for new Scenes 13A to 13C after Scene 13 that walk beginners through the existing telemetry setup of the demo (each application, OpenTelemetry and the data collection rules), as full scenes with a telemetry path diagram and screenshots, based on a read-only lab check run the same way as the earlier checks. The check ran from 09:56 to 10:26 WIB and the screenshots were taken from 10:38 to 11:41 WIB.

Changes to the lab: none. Nothing in Azure, in OpenShift or on the virtual machines was created or changed (Chapter 42.2).

Changes to the runbook:

- New Scenes 13A, 13B and 13C (19.16A to 19.16C) with Figure 19-1 and twelve screenshots; new Chapter 42; the scene list (19.2), Before the session (19.1), the acceptance checklist (18.2), the time plan (1.5), the front pages and Chapter 1.1 updated.

Version 2.3 (18 November 2026). The lab owner approved the service weather on the Grafana SLA board at 00:29 WIB on 18 November 2026 with the default choices, except that the error budget bars stay in and are measured against 99.9 %, with no impact on the existing demo and changes only in rg-appmon-openshift-demo and its managed resource group. The strip was built at 07:31 WIB and checked at 07:33 WIB.

Changes to the lab (in amg-appmon only; the Azure workbook, the functions, the managed resource group and the Hyper-V demo were not changed):

- The Grafana board MiniBank - SLA and Failure Rate: version 7 with the service weather strip under the logo header; every other panel 9 rows lower (Chapter 41).

Changes to the runbook:

- New Chapter 41; Scene 6 (19.9) and Scene 7 (19.10), the scene list (19.2), the acceptance checklist (18.2), Chapter 17.4 and Appendix B updated; the open item of Chapter 40.7; the front pages and Chapter 1.1.

Version 2.2 (17 November 2026). The lab owner approved the speed item (limit 1,000 ms, warning 800 ms) at about 17:00 WIB on 17 November 2026, after a read-only check had found the business transactions getting slower every day, and the Look-ahead radar with the default choices at about 20:21 WIB, each with no impact on the existing demo and changes only in rg-appmon-openshift-demo and its managed resource group. The speed item was built at 19:29 WIB and checked at 19:53 WIB; the radar was built at 21:01 WIB and checked at 21:05 WIB.

Changes to the lab (Look-ahead items only, in law-appmon, rg-appmon-openshift-demo and amg-appmon; the managed resource group and the Hyper-V demo were not changed):

- Three functions in law-appmon got a version 1.1 query: MiniBankLaReadings (the hourly P95 reading), MiniBankLookahead (the warning level and the speed row) and MiniBankLaDaily (the sixth daily item) (Chapter 40.2).
- The workbook MiniBank - Look-ahead: three items on the Service budget tab (Chapter 40.2).
- The Grafana board MiniBank - Look-ahead: version 3 with the two speed panels, then version 4 with the Look-ahead radar under the logo header (Chapters 40.2 and 40.3).

Changes to the runbook:

- New Chapter 40; Scene 7D (19.10D) opens with the radar, with its row in the scene list (19.2) and item 16 of 19.1 updated; notes in Chapters 39.5, 39.6, 39.7 and 39.10; the front pages and Chapter 1.1.

Version 2.1 (17 November 2026). The lab owner approved the card 6 session at 21:11 WIB on 16 November 2026, agreed decisions 3 to 11 of the Look-ahead plan at 21:40 WIB and gave the go at 22:09 WIB: the full plan, built lighter parts first, with no impact on the existing demo and changes only in rg-appmon-openshift-demo and its managed resource group. The card 6 session ran from 08:09 to 08:48 WIB on 17 November 2026; the Look-ahead board was built from 08:55 to 11:05 WIB and checked again at 11:45 WIB.

Changes to the lab (new items only, in rg-appmon-openshift-demo, amg-appmon and on HV-HOST-02; no existing item was changed and the managed resource group was not changed):

- The table MiniBankLookahead_CL, the upload rule dcr-minibank-lookahead with its diagnostic setting la-dcr-errors, and the Monitoring Metrics Publisher role of the host identity on that rule only (Chapter 39.2).
- Eight functions in law-appmon: MiniBankDrills, MiniBankDrillMinutes, MiniBankLaReadings, MiniBankErrorBudget, MiniBankLookahead, MiniBankLaDaily, MiniBankLaForecast and MiniBankLaScore (Chapters 39.4 to 39.6).
- The workbook MiniBank - Look-ahead and the Grafana board MiniBank - Look-ahead (Chapter 39.5).
- The collector F:\Build\tools\minibank-lookahead.ps1 and the scheduled task minibank-lookahead on HV-HOST-02 (Chapters 39.3 and 39.9).
- The card 6 runner F:\Build\tools\myst17.ps1 with the one-time task bg-myst17, no longer running (Chapter 38.7).

Changes to the runbook:

- New Chapter 39 and Scene 7D (19.10D), with a row in the scene list (19.2) and item 16 in 19.1; the card 6 session in Chapter 38.7 and the build record and open items of 38.10; the BE HONEST box of Scene 7C; the front pages and Chapter 1.1.

Version 2.0 (15-16 November 2026). The lab owner approved every recommendation of the follow-up plan at 16:49 WIB on 15 November 2026: rules v2.10 (the host wait ends early when the host is quiet) only if every test passes, card 6 in mystery mode with series-host.on kept, the Monday blind series and mystery tests, this runbook version, closing the test alerts, and the two host charts moved into the section Layer signals. At 22:35 WIB he approved the grading package (customers affected or not), and at 06:55 WIB on 16 November the Mystery control window (option A), which this version describes as the main way, with the PowerShell lines kept as the backup. The cluster-connect off and on for Error (599), approved at 15:39 WIB on 15 November, was done but did not fix the error; the fix was deferred at 16:35 WIB (Chapter 38).

Changes to the lab (all in rg-appmon-openshift-demo and on HV-HOST-02; the managed resource group was not changed):

- Rules v2.10 in MiniBankRootCause, saved at 20:44 WIB on 15 November 2026 after the replay; the rules v2.9 body is kept in F:\Build\tools\rc-fn29-body.json on HV-HOST-02 (Chapter 38.2).
- Grafana board MiniBank - Cross-layer root cause version 11 (the two host charts at the top of the renamed section Layer signals: Host, VM, OpenShift, network, application, database) and version 12 (the scorecard with the approved grading and the column Customers), and the scorecard tile of the workbook with the same query (Chapters 38.3 and 38.8).
- fault.ps1: the reveal grades the answer with the approved grading and prints the line Customers; backup fault.ps1.bak-20261116-115724 (Chapter 38.3).
- The Mystery control window F:\Build\minibank\scripts\mystery-window.ps1 (version 1.1) and its test stand-in F:\Build\tools\mw-stub.ps1 (Chapter 38.6).
- The switch file mystery-host.on, created at 12:18 WIB on 16 November 2026: card 6 is in the mystery draw (Chapter 38.7).
- Test tools on HV-HOST-02: the live tests, the automatic grading, the Monday runner and the mystery-test runners in F:\Build\tools and F:\Build\auto, with one-time scheduled tasks (Chapter 38.10).
- The Arc cluster-connect feature of arc-ocp-minibank switched off and on at 16:00-16:04 WIB on 15 November 2026; it is on, as before (Chapter 38.9).

Changes to the runbook:

- New Chapter 38. The Mystery control window as the main way in Scene 7C (Steps 2 and 5 and the boxes) and in Chapter 33, with the PowerShell lines kept as the backup; six numbers in the draw (Chapters 19.10C, 33.2 and 33.4); the approved grading and the new scorecard query in Chapter 35.1; the v2.10 host wait in rule R9 (Chapter 32.1); the board layout in Chapters 32.4 and 37.5; Chapter 37.7; the Error (599) row of Chapter 21; and the two tables at the start of the runbook.

Version 1.9 (14-15 November 2026). The lab owner approved plan A for host CPU contention on HV-HOST-02 at 16:16 WIB on 14 November 2026 with every recommended choice: host data, a noisy-neighbour fault card with three safety stops and calibration tests on Saturday, a quiet night as the baseline, an automatic switch-on of the host rule on Sunday morning if three checks pass, and two blind test series that include the new card. All three checks passed and rules v2.9 was switched on at 06:58 WIB on 15 November 2026. Both blind series then scored 7 of 7 when a yellow Warning naming the host counts for card 6; the lab owner chose this scoring (option B) at 11:57 WIB and it was built at 12:18 WIB.

Changes to the lab (all in rg-appmon-openshift-demo and on HV-HOST-02; the managed resource group was not changed):

- Azure Monitor Agent extension on HV-HOST-02, the data collection rule dcr-minibank-hostperf and its association dcra-minibank-hostperf: hypervisor counters every 30 seconds into law-appmon (Chapter 37.2).
- The noisy-neighbour VM BATCH-EOD (16 vCPU, no network) on HV-HOST-02, the fault card cpu-host in fault.ps1, the guard task minibank-batch-guard and the switch files series-host.on and mystery-host.on (Chapters 37.2, 37.3 and 37.7).
- The host on the Live topology map with two evidence panels (board versions 7 and 8, MiniBankTopology version 2) (Chapter 37.5).
- Rules v2.9 with the host rule R9 in MiniBankRootCause, switched on at 06:58 WIB on 15 November 2026; the rules v2.8 body is kept in F:\Build\tools on HV-HOST-02 (Chapter 37.6).
- Scoring option B in the Grafana scorecard (board versions 9 and 10), the scorecard tile of the workbook and the mystery reveal in fault.ps1: a Warning naming the host, seen twice in a row, counts as the answer and shows RIGHT LAYER - early warning; backups in F:\Build\tools and fault.ps1.bak-20261115-121831 on HV-HOST-02 (Chapters 35.1 and 37.8).

Changes to the runbook:

- New Chapter 37 with the calibration tests (37.4) and the blind test results (37.8); card 6 in the cards table of Chapter 33.1, rule R9 in the rules table of Chapter 32.1, and the two tables at the start of the runbook.

Version 1.8 (14 November 2026). The lab owner approved the Live topology map for the cross-layer root-cause board at 10:58 WIB with every recommended choice: Grafana only, placed under the verdict tiles, the detail of the mock-up, yellow boxes for the parts that feel a problem, the map following the verdict switch, and this runbook with figures afterwards.

Changes to the lab (all in rg-appmon-openshift-demo; the managed resource group was not changed):

- The function MiniBankTopology in law-appmon (category MiniBank cross-layer), display only; MiniBankRootCause and its rules v2.8 are unchanged (Chapter 36.3).
- The panel Live topology – where is the problem? on the Grafana board MiniBank - Cross-layer root cause, directly under the verdict tiles (board versions 5 and 6, Chapter 36).
- A temporary helper board, TEMP - MiniBank live topology carrier (delete after build), carried the panel into Grafana; delete it if it is still there (Chapter 36.6).

Changes to the runbook:

- New Chapter 36 with Figures 36-1 to 36-3; the map is also in Chapters 1.1, 19.10C (Scene 7C: steps 1 and 3, and the honesty box with rules v2.8 and the latest score), 32.4, 35.6 and 35.7, and in the two tables at the start of the runbook.

Version 1.7 (13 November 2026). The lab owner approved the cross-layer root-cause build with mystery mode at 13:46 WIB and the follow-ups at 22:12 WIB: option A for the after-fault flicker (a display-only recovery banner), an e-mail for every alert, closing the old test alerts, a leak check that ignores the traffic generator's own labels, the labelled pair and a third test series, and this runbook.

Changes to the lab (all in rg-appmon-openshift-demo; the managed resource group was not changed):

- Telemetry for the verdict: VM performance rules for the three Arc-enabled servers (30 seconds), the network probe minibank-netprobe in OpenShift, two Oracle schema checks in Route A, and minibank-api 1.2.1 with the Statement preview switch (Chapter 31).
- The verdict function MiniBankRootCause (rules v2.7), the observer task on HV-HOST-02 with the tables MiniBankVerdict_CL and MiniBankMystery_CL, the Grafana board MiniBank - Cross-layer root cause and the workbook group Root cause across all layers (Chapter 32).
- The fault command fault.ps1 with six cards, mystery draws, test series and a leak check (Chapter 33).
- The recovery banner, function MiniBankRecovering, on the board and in the workbook (Chapter 32.5).
- The action group ag-appmon-email on every alert rule, and 25 resolved test alerts closed (Chapter 34).
- The Arc cluster-connect agent restarted to fix Error (599) on Kubernetes resources &gt; Workloads (Chapter 21).
- On 14 November 2026 (approved at 07:23 WIB): the 9 alerts of the night closed, rules v2.8 saved with rule R8 (Chapter 32.1), test series 4, and logo header on the three Grafana boards and the workbook (Chapters 35.4 to 35.7).

Changes to the runbook:

- New Part G (Chapters 30 to 35) and the new Scene 7C (Chapter 19.10C); the scene list is now 124.5 minutes, or 120.5 without Scene 14.
- Chapter 19.1 has the cross-layer board, the morning history, the fault and alert checks and the Error 599 pre-flight; Chapters 18.2, 20.3, 21 and 22.2 have the matching checks and fixes.
- APP-RHEL - Bash opens with the lab SSH key (ssh -i F:\Build\ocp\id_ed25519), so nobody types or pastes the labadmin password through Bastion (Chapters 1.3, 5.6, 11.3, 11.4 and every APP-RHEL box).
- On 14 November 2026: Chapter 35.4 has the results of the pair, series 3, the quiet night, rules v2.8 and series 4; Chapter 32.1 has rule R8; Chapters 35.5 to 35.7 and the two tables at the start of the runbook were brought up to date.

**Version 1.6 (12 November 2026).** Version 1.6 changes only the runbook; nothing was changed in the lab. The lab owner asked for the Priority 1 scenes inside Chapter 19, a scene that shows the technology stack, and the exact place to run every command and query.

Changes to the runbook:

- Chapter 19 is the complete demo script: the Priority 1 features are part of Scenes 2 (live zero-code onboarding), 3, 4, 5 (the incident command), 6, 7 (business impact in IDR) and 15 (the collector callback); new Scenes 7A (the customer's view) and 7B (the AI investigation); new Scene 0A (a tour of Hyper-V, the OpenShift web console, Oracle, PostgreSQL, SQL Server and the application servers); preparation (19.1) and the scene list (19.2) are updated. The session takes 114.5 minutes, or 110.5 without the optional Scene 14.
- Where to run: every command and query block has a WHERE TO RUN IT box with the window and machine, or the Azure Portal page, menu and field. Boxes that pointed to the wrong place were corrected: queries that use the workspace tables (AppRequests, AppEvents, OTelSpans and others) run in law-appmon &gt; Logs. The tips, the acceptance checklist, the daily checks, the troubleshooting table and the rollback tables now name the window for each command. Chapter 1.3 lists three more working places.
- Chapter 18.2 has three Priority 1 checks; Chapter 20 ends a running incident and undoes the live onboarding after a rehearsal and closes the two new alert rules; Chapter 28 points to Chapter 19.

Still open on 12 November 2026:

- The bank demo date is not set. Rehearse with Chapter 19 and run the morning backup investigation on the demo day (Scene 7B).
- Renew the container registry push token before 17 November 2026 20:48 WIB if an image must change after that; the pull token runs until 10 December 2026 (Chapter 22.2).
- Rename the collector exporter alias otlphttp to otlp_http at the next collector change (Chapter 29.4).
- Close the alerts fired during the build and the rehearsal on 12 November 2026 before the demo (Chapter 20.3).

**Version 1.5 (12 November 2026).** Version 1.5 adds the four Priority 1 features. The lab owner approved the build at 15:06 WIB on 12 November 2026, with changes only in rg-appmon-openshift-demo and MA_amw-appmon_indonesiacentral_managed, plus the agreed subscription setting for feature A. The features were built, checked at gates G1 to G5 and rehearsed end to end the same day.

Changes made in the lab:

- Feature B: Arc OIDC issuer and workload identity, managed identity id-otelcol, data collection endpoint dce-otlp and rule dcr-otlp, the Red Hat build of OpenTelemetry operator, the collector otelcol, the new Java service minibank-rates (onboarded with one annotation) and minibank-transfer 1.2.0 (Chapter 24).
- Feature D: customer tiers and 30 more customers on APP-SQL, payment tags in API 1.2.0, the workbook group Business impact (IDR) and the alert alr-minibank-failed-value-idr (Chapter 25).
- Feature C: journey events and traffic-source labels in the web page and the API, the browser robot (task minibank-robot on APP-WIN), incident.ps1 on HV-HOST-02 and the alert alr-minibank-journey-success-low (Chapter 26).
- Feature A: the subscription setting that links amw-appmon for the Azure Copilot Observability Agent (Chapter 27).
- The background slow share of the traffic generator went from 6 % to 2 %, so the 95th percentile of transfers and QRIS stays under the 1-second SLA outside the incident scenes.

Changes to the runbook:

- New Part F (Chapters 23 to 29) at the end of the runbook, after the appendices: the features, as-built settings, checks, rollback, the demo scenes of version 1.5 with times, and the build record with lessons.
- The front page, What changed in version 1.5, Chapter 1.1, Chapter 4.2, Chapter 19 and Appendix B point to Part F and to the new companion files.

Still open on 12 November 2026:

- The bank demo date is not set. Rehearse with Chapter 28 and run the morning backup investigation on the demo day (Chapter 28.7).
- Renew the container registry push token before 17 November 2026 20:48 WIB if an image must change after that; the pull token runs until 10 December 2026 (Chapter 22.2).
- Rename the collector exporter alias otlphttp to otlp_http at the next collector change (Chapter 29.4).
- Close the alerts fired during the build and the rehearsal on 12 November 2026, and the three open alerts of alr-minibank-failure-rate-high from 10 November 2026, before the demo (Chapter 20.3).
## E.1 Version 1.4 (11 November 2026)

Version 1.4 follows the lab as it runs on the evening of 11 November 2026. Nothing was built for this version; the changes made in the lab after version 1.3 were each approved by the lab owner on 11 November 2026.

Changes made in the lab after version 1.3:

- Kubernetes resources view: the Portal signs in with the presenter's Microsoft Entra account and no longer offers a token field. The OpenShift binding arc-portal-entra-reader (cluster-reader, for the presenter's sign-in name and object ID) and the Azure role Azure Arc Kubernetes Viewer on arc-ocp-minibank fixed Error (599) on 11 November 2026 at 17:21 WIB (Chapters 13.4, 19.4 and 21).
- Oracle dependency type: the ConfigMap minibank-transfer-ai-config with applicationinsights-oracle.json and the setting APPLICATIONINSIGHTS_CONFIGURATION_FILE on minibank-transfer name the Oracle calls oracle.db since 11 November 2026, 21:20 WIB. No image was rebuilt and nothing changed in Azure (Chapters 15.2, 17.6 and 19).

Changes to the runbook:

- Every query that a step uses is printed in that step, with its Appendix A number (Chapters 16 to 22). New query A.23 checks the dependency types of the transfer service.
- Query A.5 grouped by the table name instead of the dependency type; corrected. Query A.16 now finds the Oracle calls by the type oracle.db or the target freepdb1.
- New Portal paths: Extensions under Settings, and the Insights page titled Monitor (Chapters 13.5, 13.8, 18.2, 19.4 and 19.11).
- The automatic smart detection rule Failure Anomalies - appi-minibank is described, with its shared action group in rg-ut-monitor-demo (Chapters 4.7, 17.5, 19.10, 20.3 and 21).
- Two transfer pods on one node: delete the newer pod instead of a rolling restart (Chapters 15.2, 18.2, 20.2, 21 and 22.2).
- The OpenShift route keeps each client on one transfer pod for a while, so per-pod counts are uneven in short time windows (Chapter 17.6, Appendix A.8).
- Figure 4-1 and its draw.io file redrawn as version 1.4: the lab's own Grafana amg-appmon, three alert rules, the storage account shown as optional (Chapter 4.2).
- New rows in the worksheet, the list of Azure items, the acceptance checklist, the daily checks and the troubleshooting table (Chapters 4.7, 5.1, 18.2, 21 and 22.2).

Decisions deferred on 11 November 2026 (the lab stays as it is until the lab owner decides):

- Failure Anomalies rule: keep it as it is, remove its link to the shared action group, or switch it off (Chapter 17.5).
- Transfer pod placement: keep the manual fix of Chapter 20.2, or change the rollout of minibank-transfer to stop an old pod before it starts a new one, so that restarts end with one pod per node by themselves.
- Route minibank-transfer: keep the sticky cookie, or turn it off and balance round robin so that every pod gets an even share of the requests.
- Oracle rule for a fresh build: keep it in a ConfigMap as the lab runs now, or build it into the image with the next image build.

Still open in the lab on 11 November 2026:

- etcd backup: due since 20:21 WIB on 11 November 2026, 24 hours after the installation (Chapter 12.7).
- Save the kubeadmin password and the kubeconfig in ENVIRONMENT.txt (Chapter 12.6), register APP-RHEL with Red Hat (Chapter 11.3) and prepare OCP-NODE-4 (Chapter 12.8, gate G8).
- Three alerts of alr-minibank-failure-rate-high from 10 November 2026 are resolved but still open; close them (Chapter 20.3).
- Renew the container registry pull token before 10 December 2026. The push token expires on 17 November 2026 and is needed only for a new image (Chapter 22.2).
- Check the &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; tags every day (Chapter 22.2).
- The download link of the storage account stays blocked by the subscription policy; its steps are kept as an option (Chapter 10.5).
## E.2 Version 1.3 (11 November 2026)

Version 1.3 describes the lab as it was built in rg-appmon-openshift-demo on 10 and 11 November 2026, and adds the changes approved on 11 November 2026.

Changes from building the lab:

- Grafana: the lab has its own Azure Managed Grafana, amg-appmon (Standard, Grafana 12, Indonesia Central), in rg-appmon-openshift-demo, instead of adding content to amg-ops in the Hyper-V demo resource group as planned in version 1.2. Its managed identity reads only the lab (Monitoring Reader on the resource group, Monitoring Data Reader on amw-appmon), and the presenter has Grafana Admin. The Hyper-V demo is not touched at all (Chapters 1.1, 2.1, 2.2, 4.2, 4.7, 4.8, 10.7, 17.4 and 22.4).
- Cost-control tags: &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; is merged onto both resource groups and every resource in them, and checked every day (Chapters 6.5, 7.1 and 22.2).
- Source pack: a governance policy blocks the download link of the storage account, so the pack is copied from OneDrive; the storage steps are optional (Chapters 10.5 and 10.6).
- Windows guests from the WIM image: the boot files are written with the image's own bcdboot (Chapter 11.2).
- Defender for Servers: the extensions MDE.Windows and MDE.Linux appear on the Arc machines through a subscription policy; leave them (Chapter 11.7).
- OpenShift: the as-built installation time, 20:21 WIB on 10 November 2026, as an example for the 24-hour rule and the etcd backup (Chapters 12.6 and 12.7).
- Container registry: ACR Tasks is not available in Indonesia Central, so the image is built with podman on APP-RHEL and pushed with a push token. The pull token runs for 30 days, the push token for 7 days (Chapters 10.4 and 15.2).
- SQL Server 2022 Developer: direct ISO download with curl.exe; the downloader (SSEI) is the fallback with a time limit (Chapter 14.1).
- APP-WIN: Node.js 24 and the ASP.NET Core Hosting Bundle are downloaded with curl.exe from the official release lists (Chapters 15.3 and 15.4).
- Oracle on APP-RHEL: the USERS tablespace in FREEPDB1, checks of the sqlplus exit code and of dba_users, firewall ports opened before the containers start, netavark-firewalld-reload.service and podman network reload (Chapters 14.2, 16.2 and 21).
- Oracle exporter 2.5.x: its configuration file (Chapter 16.2).
- Monitoring volume and cost, measured: about 5.3 GB per day and about US$14 per day instead of the estimate of 1 to 3 GB per day (Chapters 17.8 and 22.1, Appendix A.18).

Changes approved on 11 November 2026:

- traffic.ps1 version 1.3 runs all the time as the scheduled task minibank-traffic; the probe task minibank-probe has no run-time limit; the 25-hour run before the demo is gone (Chapters 17.1, 18.1, 19.1 and 22.3).
- Balance top-up every 6 hours on APP-SQL in the new Chapter 17.10 (also Chapters 18.1 and 20.1).
- Technical failures (HTTP 5xx) and business declines (HTTP 409 Insufficient balance) are separated everywhere; the background traffic has 0.05 percent technical failures and about 4 declines per hour (Chapters 3.3, 4.4, 17.1 to 17.5, 19.9 and 19.10).
- Grafana SLA dashboard and workbook version 1.3, with colour thresholds on the Grafana tiles (Chapters 17.3 and 17.4).
- The alert alr-minibank-failure-rate-high counts only technical failures, and the new informational alert alr-minibank-decline-spike watches the declines (Chapters 17.5, 19.10 and 20.3).
- Queries A.2 and A.19 changed, A.21 and A.22 added (Appendix A).
- Source pack MiniBank-source-pack-v1.3.zip with the new scripts and the updated dashboards (Appendix B).
- New rows in the rehearsal timeline, the acceptance checklist, the daily checks and the troubleshooting table (Chapters 18.1, 18.2, 22.2 and 21).

Still open:

- Figure 4-1 and its draw.io file still show the version 1.2 design for Grafana; see the note under the figure (Chapter 4.2).
- Renew the container registry pull token before 10 December 2026. The push token expires on 17 November 2026 and is needed only for a new image (Chapter 22.2).
- Check the &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; tags every day (Chapter 22.2).
- The download link of the storage account stays blocked by the subscription policy; its steps are kept as an option (Chapter 10.5).
## E.3 Version 1.2 (10 November 2026)

| Area | Change |
|---|---|
| Architecture diagram | New Figure 4-1 in Chapter 4.2: the whole lab in one picture, drawn in draw.io with the Azure icons of the draw.io Azure library, numbered request path and lettered data flows |
| Chapter 4.2 | The text sketch is replaced by Figure 4-1, a reading guide and a table that links every data flow to the chapter that builds it |
| Companion files | New editable diagram MiniBank-OpenShift-Demo-Architecture-v1.2.drawio. The source pack stays MiniBank-source-pack-v1.1.zip, unchanged |
| Build steps | No change |

## E.4 Changes from version 1.0 to version 1.1

| Area | Version 1.0 (31 October 2026) | Version 1.1 (10 November 2026) |
|---|---|---|
| Application | MiniBank, simple test page | MiniBank screens, English by default with an Indonesian toggle |
| Location | Existing guests of HV-HOST-01 in rg-hyperv-arc-monitor-demo | New HV-HOST-02 and new resource group rg-appmon-openshift-demo; the Hyper-V demo is untouched |
| Java service | systemd service on RHEL94-GUEST | Three containers on Red Hat OpenShift 4.20, image in Azure Container Registry |
| Kubernetes | Not covered | Arc-enabled OpenShift, Container insights, managed Prometheus, node scenes |
| Databases | Application view only; internals a talk track | Oracle and PostgreSQL internals through Route A and Route B |
| SQL Server | Existing SQL2019-GUEST | New APP-SQL with SQL Server 2022 Developer |
| Workspace | law-arc-monitor-poc (shared) | law-appmon and amw-appmon (own) |
| Network | Existing lab network | Own virtual network, NAT gateway and Bastion |
| Scenes | 10 scenes | 16 scenes, including OpenShift, node loss, drain, add node and database internals |
| Approval gates | G1 to G8 | G0 to G10 |

Version 1.5 adds the four Priority 1 features that close the gaps found when it was compared with a commercial APM suite. They were built in the lab on 12 November 2026 in rg-appmon-openshift-demo, with one agreed subscription-level setting for feature A. Every chapter below names what was built, how to check it, how to undo it, and what to say in the demo. Chapters 1 to 22 are unchanged unless Chapter 28 says otherwise.

---

[&larr; Appendix D. References](appendix-d-references.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [23. What version 1.5 adds &rarr;](23-what-version-1-5-adds.md)
