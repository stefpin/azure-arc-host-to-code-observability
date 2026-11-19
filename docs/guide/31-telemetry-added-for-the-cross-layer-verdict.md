# 31. Telemetry added for the cross-layer verdict

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


Before version 1.7 the lab had application, OpenShift and database data, but no performance data from the three Arc-enabled servers, no measurement of the network path and no schema check. Chapters 31.1 to 31.4 describe what was added; Chapter 31.5 checks all sources at once.

## 31.1 VM performance from the three Arc-enabled servers

Two data collection rules send performance counters every 30 seconds to the Perf table of law-appmon. dcr-minibank-vmperf-win covers APP-WIN and APP-SQL: Processor(_Total) % Processor Time, Memory Available MBytes and % Committed Bytes In Use, System Processor Queue Length, and Process(\*) % Processor Time with a transformation that keeps only processes at 20 % or more. dcr-minibank-vmperf-linux covers APP-RHEL: Processor, Memory % Used Memory, Available MBytes and % Used Swap. The association on each server is named dcra-minibank-vmperf. As a side effect, APP-SQL now also sends Heartbeat rows.

## 31.2 Network probe from OpenShift

The deployment minibank-netprobe (namespace minibank, one pod) reuses the image minibank-transfer:1.2.0, so no new image was pushed. Every 15 seconds its script, from the ConfigMap minibank-netprobe, opens a TCP connection with a 3-second timeout to oracle 192.168.110.32:1521, fraud 192.168.110.32:8082 and api 192.168.110.31:8080, and writes one JSON line per target. It sends no application data and uses no password. Container insights carries the lines to ContainerLogV2. Normal connect times are about 2 ms; the verdict counts a probe as slow above 50 ms and as lost when no connection is made in 3 seconds.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin) in the Bastion session (Run as administrator), after the start block of Chapter 5.5, which sets KUBECONFIG and the path of oc. Paste the block at the PS F:\Build&gt; prompt and press Enter.

```bash
oc get deployment minibank-netprobe -n minibank
oc logs deployment/minibank-netprobe -n minibank --tail=3
```

> [!TIP]
> **What you should see**
>
> READY 1/1, then three lines such as {"probe":"minibank-netprobe","target":"oracle","host":"192.168.110.32","port":1521,"ok":1,"connectMs":2.315,"node":"ocp-node-1"}.

## 31.3 Oracle schema checks

Route A on APP-RHEL (Chapter 16) has two more queries in oracle-snap.sql, and dbsnap.sh sends their rows with the type schema. Every minute MiniBankDbSnap_CL receives Name LEDGER_ENTRY with Value 1 when the table MINIBANK.LEDGER_ENTRY exists (0 when it does not), and the latest DDL in the schema with the object name and how many minutes ago it happened. The original files are kept on APP-RHEL as /opt/minibank/dbsnap/\*.bak-20261113-140633.

## 31.4 minibank-api 1.2.1 and the Statement preview switch

minibank-api 1.2.1 on APP-WIN is version 1.2.0 plus a Statement header preview. While the switch file C:\ProgramData\MiniBank\api\statement-header.json holds an end time in the future, the preview looks up the branch label in a table that knows only branch 0001, so statements of other branches throw System.NullReferenceException in StatementHeaderPreview.BranchLabel and answer HTTP 500. After the end time, or without the file, statements work as before. Only fault.ps1 writes and removes the file. Backups: C:\Build\minibank-api-src-1.2.0 (source) and C:\inetpub\minibank-api-1.2.0-backup (site).

> [!CAUTION]
> **Be honest**
>
> The update to 1.2.1 caused an unplanned API outage of about 3 minutes on 13 November 2026 (14:10:30 to 14:13:45 WIB), because an IIS worker process still held the files. The copy step now waits until the worker process is gone (Chapter 35.6).

## 31.5 Check every source at once

Run this query before a test series, or when the board stays Pending. Every source should have rows from the last 1 to 2 minutes.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
let t0 = ago(15m);
union
    (Perf | where TimeGenerated > t0 and ObjectName in ('Processor', 'Memory') | summarize Rows = count(), Last = max(TimeGenerated) by Source = strcat('VM performance: ', Computer)),
    (ContainerLogV2 | where TimeGenerated > t0 and PodNamespace == 'minibank' and ContainerName == 'netprobe' | summarize Rows = count(), Last = max(TimeGenerated) by Source = 'Network probe (minibank-netprobe)'),
    (KubePodInventory | where TimeGenerated > t0 and Namespace == 'minibank' | summarize Rows = count(), Last = max(TimeGenerated) by Source = 'OpenShift pods (namespace minibank)'),
    (MiniBankDbSnap_CL | where TimeGenerated > t0 and SnapshotType == 'schema' | summarize Rows = count(), Last = max(TimeGenerated) by Source = 'Oracle schema check'),
    (MiniBankVerdict_CL | where TimeGenerated > t0 | summarize Rows = count(), Last = max(TimeGenerated) by Source = 'Verdict observer')
| project Source, Rows, LastWIB = format_datetime(Last + 7h, 'HH:mm:ss')
| order by Source asc
```

> [!TIP]
> **What you should see**
>
> Seven rows: Network probe (about 160 rows in 15 minutes), OpenShift pods, Oracle schema check, VM performance for APP-SQL, APP-WIN and app-rhel.minibank-demo.lab, and Verdict observer (about 30 rows), each with LastWIB in the last 2 minutes. A missing row or an old time names the source to repair (Chapter 21).

---

[&larr; 30. What version 1.7 adds](30-what-version-1-7-adds.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [32. The verdict, the observer, the board and the recovery banner &rarr;](32-the-verdict-the-observer-the-board-and-the-recovery-banner.md)
