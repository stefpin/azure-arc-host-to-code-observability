# 30. What version 1.7 adds

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 30.1 The idea in one view

When customers are hurt, the board answers one question: which layer explains it? A KQL function, MiniBankRootCause() in law-appmon, reads the last 6 minutes of telemetry from every layer, checks that customers are impacted, and then applies its rules in a fixed order, from the database schema down to a new exception type in the code. The first rule that matches names the layer, the component and the evidence. An observer task on HV-HOST-02 records the answer twice a minute, and the Grafana board and the workbook show it. fault.ps1 breaks one layer at a time, on purpose and with an automatic undo, so that the board can be tested and shown.

| Layer | Fault card | What breaks | What proves it on the board |
|---|---|---|---|
| VM | cpu-win | A runaway PowerShell job takes all CPU on APP-WIN (16 busy runspaces at AboveNormal priority) | CPU 97 to 100 % on APP-WIN with powershell as the busiest process; most requests slower than usual (P75 at least 2.5 times normal) |
| OpenShift | oom-ocp | Every 100 seconds the three minibank-transfer containers are pushed over their 768Mi memory limit | Container restarts in namespace minibank with the reason OOMKilled (exit 137) |
| Network | net-rhel | 250 ms delay (plus or minus 30 ms) and 3 % loss on APP-RHEL, only towards the OpenShift nodes and only for Oracle 1521, PostgreSQL 5432 and fraud 8082 | The probe pod's TCP connect to oracle (APP-RHEL:1521) is slow (over 50 ms) or lost in 4 or more probes |
| Application | nullref-api | The Statement preview of minibank-api 1.2.1 throws a NullReferenceException (HTTP 500) | A new exception type in minibank-api, System.NullReferenceException, normally 0 |
| Database | schema-oracle | Table MINIBANK.LEDGER_ENTRY is renamed to LEDGER_ENTRY_BAK | The Oracle schema check: LEDGER_ENTRY missing, latest DDL on LEDGER_ENTRY_BAK; transfers fail with ORA-00942 |
| Application (labelled runs only) | fail-oracle | The traffic generator's scenario fail-oracle: the code queries a table that never existed (LEDGER_MISSING) | The same ORA-00942 as schema-oracle, but the schema check is fine, so the new exception type is the cause |
| None | none | Only the extra load (the healthy slot of a test series) | Healthy: no false alarm |

## 30.2 What was changed in the lab (13 November 2026)

Everything is inside rg-appmon-openshift-demo; the managed resource group MA_amw-appmon_indonesiacentral_managed was not changed. The lab owner approved the build at 13:46 WIB and the follow-ups (recovery banner, alert e-mail, closing old alerts, leak check, the pair and series 3, this runbook) at 22:12 WIB.

| Item | Where | What it does |
|---|---|---|
| Data collection rules dcr-minibank-vmperf-win and dcr-minibank-vmperf-linux, associations dcra-minibank-vmperf | APP-WIN and APP-SQL (Windows rule), APP-RHEL (Linux rule) | CPU, memory, swap, processor queue and busy processes every 30 seconds into Perf; APP-SQL now also sends Heartbeat |
| Deployment and ConfigMap minibank-netprobe | OpenShift, namespace minibank (1 pod, the existing image minibank-transfer:1.2.0) | TCP connect time from OpenShift to Oracle, fraud and the API every 15 seconds, as JSON lines in ContainerLogV2 |
| Two schema checks in Route A | APP-RHEL, /opt/minibank/dbsnap (oracle-snap.sql and dbsnap.sh) | Rows of type schema in MiniBankDbSnap_CL every minute: LEDGER_ENTRY present (1 or 0) and the latest DDL |
| minibank-api 1.2.1 | APP-WIN, IIS site minibank-api | The Statement preview switch for the card nullref-api; without the switch it works like 1.2.0 |
| Functions MiniBankRootCause (rules v2.7) and MiniBankRecovering | law-appmon, saved searches minibank-rootcause and minibank-recovering | The verdict, and the display-only recovery banner |
| Tables MiniBankVerdict_CL and MiniBankMystery_CL, data collection rule dcr-minibank-rca (kind Direct) | law-appmon | The observer's readings, and the ledger of draws, series and labelled runs |
| Two role assignments for the managed identity of HV-HOST-02 | Log Analytics Reader on law-appmon; Monitoring Metrics Publisher on dcr-minibank-rca | The observer and fault.ps1 read the verdict and write the ledger without a stored secret |
| Scheduled task minibank-verdict-observer, scripts fault.ps1 and verdict-observer.ps1 | HV-HOST-02, F:\Build\minibank\scripts | Records the verdict twice a minute; runs the faults with automatic undo |
| Dashboard MiniBank - Cross-layer root cause | amg-appmon, folder MiniBank, address /d/minibank-rootcause | The board, 19 panels including the recovery banner |
| Workbook group Root cause across all layers | Workbook MiniBank - SLA and Failure Rate | The same verdict, the recovery banner, the verdict changes and the scorecard in the Azure Portal |
| Action group ag-appmon-email | rg-appmon-openshift-demo (location Global) | E-mail to alerts@example.com for the five log alert rules and Failure Anomalies - appi-minibank (Chapter 34) |
| 25 resolved test alerts closed | Monitor &gt; Alerts | An empty alert list after the test runs (22:34 WIB) |
| Arc agent clusterconnect-agent restarted | OpenShift, namespace azure-arc (11:55 WIB) | Fixed Error (599) on Kubernetes resources &gt; Workloads (Chapter 21) |

## 30.3 Files on HV-HOST-02

| File or folder | What it is |
|---|---|
| F:\Build\minibank\scripts\fault.ps1 | The fault command (Chapter 33); earlier versions are kept next to it as fault.ps1.bak-&lt;date-time&gt; |
| F:\Build\minibank\scripts\verdict-observer.ps1 | The observer, run every minute by the task minibank-verdict-observer |
| C:\ProgramData\MiniBank\verdict\verdict-&lt;date&gt;.jsonl | The observer's local copy of every reading |
| C:\ProgramData\MiniBank\sealed | Sealed draws and series plans with their salt; readable by administrators only |
| C:\ProgramData\MiniBank\fault\state.json | The current or last run; fault.ps1 -Status reads it |
| C:\BuildLog\fault.log | What fault.ps1 did; during a mystery draw it holds no card name |
| F:\Build\minibank\openshift\xlayer | The manifests of minibank-netprobe |
| F:\Build\tools\rc-fn-before-x19.json | The verdict function before rules v2.7 (rules v2.6), for a rollback |
| F:\Build\tools\grafana-rootcause-before-banner-20261113-153534.json and workbook-before-banner-20261113-153542.json | The board and the workbook before the recovery banner, for a rollback |

## 30.4 Cost

The extra telemetry adds about 28 MB a day to law-appmon, about 0.5 % of the 5.5 GB ingested each day; the daily cap stays at 10 GB. The functions, the observer, the board and the workbook add no Azure resource with a price. E-mail notifications cost almost nothing at this volume. A blind test series adds load inside the lab for 96 minutes, not cost.

## 30.5 Honest notes for the presenter

- The verdict is a set of rules written for this lab in open KQL, not a product feature. It was tested on the five fault cards and the healthy slot; another kind of fault shows Unclassified, and then the AI investigation of Scene 7B is the next step.
- It needs about 3 minutes, and most of that is waiting: the VM, OpenShift, network and schema data arrive 60 to 100 seconds after the application data, and the board waits for them (Pending) so that an application symptom is never blamed for a lower-layer cause.
- Commercial APM suites find root causes with closed engines built on their own agents. Here every rule can be read and changed by your own engineers; say so if asked.
- Results on 13 November 2026: the right layer in 10 of 11 blind draws. The one miss came from rules v2.6 and was fixed in rules v2.7; series 2 under rules v2.7 was 5 of 5 with no false alarm (Chapter 35).
- The test bar for the demo: the right layer every time, within 5 minutes, with no false alarm, in two series before the demo day and one on the demo morning. Only cards that pass stay in the mystery pool.

---

[&larr; 29. Build record and lessons (12 November 2026)](29-build-record-and-lessons-12-november-2026.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [31. Telemetry added for the cross-layer verdict &rarr;](31-telemetry-added-for-the-cross-layer-verdict.md)
