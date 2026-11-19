# 32. The verdict, the observer, the board and the recovery banner

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 32.1 How the verdict decides

MiniBankRootCause(at, lookback) looks at the 6 minutes before at, which is now when you leave it empty. It first decides whether customers are impacted, judged on the last 3 minutes so that the verdict clears soon after a fault: more than 2 % of the business transactions fail with HTTP 5xx, the 95th percentile of their duration (P95) is above 1,000 ms, P95 is at least 400 ms and 3 times normal, the typical duration (P75) is at least 250 ms and 2.5 times normal, or at least 2 robot journeys failed. Normal is measured over the previous hour. Then the rules run in this order; the first one that matches gives the answer:

| Order | Rule | Matches when | Answer |
|---|---|---|---|
| R0 | Hold | Customers are impacted, the best match so far is R5, R6 or nothing, and a slower source has not yet reported past the start of the impact (VM performance and the probe 60 s, OpenShift pods 30 s, schema check 15 s; at most 3.5 minutes) | Status Pending (checking all layers) |
| R1 | Schema change | The Oracle schema check finds LEDGER_ENTRY missing | Database |
| R9 | Host CPU contention (rules v2.9; the host wait changed in v2.10) | The true load of HV-HOST-02 is 70 % or more in at least 2 readings of the 6-minute look-back and on average from the first such reading, and at least 3 VMs other than the biggest consumer wait 3 times their normal for a processor. When the biggest consumer is APP-WIN, APP-SQL or APP-RHEL and R4 matches, R4 keeps the answer. While customers are impacted and the host data has not yet reported past the start of the impact, R2, R3 and R4 wait (Pending) so that a host cause is not missed. Since rules v2.10 (15 November 2026) this wait ends at once when the newest host reading is at most 150 seconds old, was taken no more than 60 seconds before customers were first impacted and shows a quiet host: a true load under 70 % and fewer than 3 VMs waiting 3 times their normal. Late or missing host data keeps the wait. | Host: red when customers are impacted, otherwise Status Warning (yellow) naming the host |
| R2 | Containers killed | Container restarts or OOMKilled in namespace minibank (it looks back 3 more minutes) | OpenShift |
| R3 | Network path | At least 4 probes to a target and either their median far above its baseline or 4 or more slow (over 50 ms) or lost | Network |
| R4 | VM pressure | CPU 85 % or more in at least 2 samples with an average of 80 % or more since then, or memory 92 % or more in at least 2 samples, on APP-WIN, APP-SQL or APP-RHEL | VM |
| R5 | Database slow | Time spent in database calls far above normal while the probe and the VMs are normal | Database |
| R6 | New exception | An exception type far above its normal count (normal = the 75th percentile of its count per minute over the previous hour, empty minutes included) | Application |
| R8 | A few slow transactions (rules v2.8) | No rule R1 to R6 matches, and customers look impacted only because a few calls are slow: P95 is high, but the typical duration (P75) is normal, at most 2 % of the business transactions fail and fewer than 2 robot journeys failed. R8 is checked before R0, so this pattern is neither held (Pending) nor left Unclassified | Status Warning (yellow): No layer at fault, A few slow transactions, no layer at fault. This Warning never counts as an answer |
| - | Nothing matched | Customers are impacted, the hold is over and no rule matched | Unclassified: open Investigate on the alert (Scene 7B) |

Without impact the status is Healthy, or Warning when a layer signal is present while customers are still fine (for example high CPU). An answer counts when two readings in a row, about 30 seconds apart, name the same layer. The order is what lets the board tell the same symptom from different causes: slow Oracle calls caused by the network are explained by R3 before R5 can blame the database, and ORA-00942 caused by a renamed table is explained by R1 before R6 can blame the code.

## 32.2 Read the verdict yourself

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankRootCause()
| extend OnsetWIB = format_datetime(Onset + 7h, 'HH:mm:ss')
| project Status, Layer, Component, Evidence, OnsetWIB, Impact, Confidence, Rule
```

To see what the board said at an earlier moment, put that moment in UTC (WIB minus 7 hours) into the function:

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankRootCause(datetime(2026-11-13T13:01:30Z))
| project Status, Layer, Component, Evidence, Impact, Rule
```

> [!TIP]
> **What you should see**
>
> Now: Healthy outside tests. For 13 November 2026 at 20:01:30 WIB (13:01:30 UTC, series 2, slot 2): RootCause, OpenShift, Deployment minibank-transfer (namespace minibank, arc-ocp-minibank), 6 container restarts in 3 pods, last termination reason OOMKilled (exit 137: the container reached its memory limit of 768Mi).

> [!TIP]
> **Beginner tip**
>
> Log Analytics can return a cached answer when exactly the same query text runs again within a few minutes. The board and the observer put the time into the query, so they always get a fresh answer. When you run the first query twice by hand, add a space or a comment line the second time.

## 32.3 The observer on HV-HOST-02

The scheduled task minibank-verdict-observer runs as SYSTEM every minute and at start-up. Each run reads the verdict twice, about 30 seconds apart, with the current time in the query; it writes each reading to C:\ProgramData\MiniBank\verdict\verdict-&lt;date&gt;.jsonl and sends it through the data collection rule dcr-minibank-rca to the table MiniBankVerdict_CL. The managed identity of HV-HOST-02 reads law-appmon (Log Analytics Reader) and writes to the rule (Monitoring Metrics Publisher); no secret is stored. The verdict history on the board, the scorecard and the recovery banner all read this table.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin): Azure Portal &gt; virtual machine HV-HOST-02 &gt; Connect &gt; Connect via Bastion, sign in as labadmin. On HV-HOST-02 click Start, type PowerShell, right-click Windows PowerShell &gt; Run as administrator (the window title starts with Administrator). Paste the block at the prompt and press Enter.

```powershell
Get-ScheduledTask minibank-verdict-observer | Select-Object TaskName, State
Get-ChildItem C:\ProgramData\MiniBank\verdict\verdict-*.jsonl | Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content -Tail 2
```

> [!TIP]
> **What you should see**
>
> State Ready (the task starts every minute and ends after its two readings), then two JSON readings from the last minute; outside tests their Status is Healthy.

The same readings in the workspace, newest first:

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankVerdict_CL
| where TimeGenerated > ago(30m)
| project TimeWIB = format_datetime(TimeGenerated + 7h, 'HH:mm:ss'), Status, Layer, Component, Evidence
| order by TimeWIB desc
```

## 32.4 The Grafana board and the workbook group

The board MiniBank - Cross-layer root cause shows, from top to bottom: The bank and Microsoft logo header; the Recovery banner; Root cause: layer, Status and Verdict details (the function at the end of the time range, so moving the time range back shows what the board said then); the Live topology map (version 1.8, Chapter 36), which draws the whole stack and colours it from the same verdict; the Verdict history, one coloured band per reading; the user rows (failed business transactions, P95 and robot journeys); the section Layer signals: Host, VM, OpenShift, network, application, database, which since board version 11 (15 November 2026) starts with the two host charts of Chapter 37.5, followed by VM CPU, OpenShift container restarts, TCP connect time from OpenShift, exceptions per minute, the Oracle schema check and the time spent in database calls; and the scorecard, which since board version 12 (16 November 2026) grades with the approved grading of Chapter 38.3 and shows the column Customers. The variable verdict = hide hides the verdict, the banner and the history and takes the red out of the map, for a workshop in which people guess first.

> [!NOTE]
> **Where to run it**
>
> Microsoft Edge on your own computer: Grafana amg-appmon (https://&lt;GRAFANA_HOST&gt;) &gt; Dashboards &gt; folder MiniBank &gt; MiniBank - Cross-layer root cause (address /d/minibank-rootcause). Time range Last 1 hour, refresh 30s, variable verdict = show.

The workbook MiniBank - SLA and Failure Rate shows the same verdict in its group Root cause across all layers (cross-layer lab): an explanation, the recovery banner (only during a recovery), Verdict now, Verdict changes in the time range, and the scorecard.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; appi-minibank &gt; Workbooks (left menu, under Monitoring) &gt; MiniBank - SLA and Failure Rate, scroll to the group Root cause across all layers (cross-layer lab).

## 32.5 The recovery banner (option A, display only)

After a fault ends, the 6-minute window still holds leftover errors or slow calls for a few minutes. Test series 2 showed what that looks like: after the OOM fault the live reading named OpenShift again at 20:12:30 and 20:13:00 WIB, 6.7 minutes after the fault had ended, then showed Pending and Unclassified for one reading each, and then Healthy. Nothing was wrong, but an audience would see the board change its mind.

The lab owner chose option A on 13 November 2026: for 10 minutes after the last confirmed answer, a purple banner reads Recovering - last cause: &lt;layer&gt; (&lt;component&gt;), with the time of the answer, the time it cleared and the time until which late readings may flicker. It appears as soon as the newest reading is no longer that confirmed answer, and disappears after 10 minutes or as soon as a new answer is confirmed. It is display only: the function MiniBankRecovering() reads the observer's history and never feeds the verdict or the scoring; rules v2.7 did not change.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankRecovering()
| project Banner
```

The same banner as it looked on 13 November 2026 at 20:10 WIB (13:10 UTC), after the OOM fault of series 2:

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
MiniBankRecovering(datetime(2026-11-13T13:10:00Z))
| project Banner
```

> [!TIP]
> **What you should see**
>
> Banner none when no answer was given in the last 10 minutes. For 20:10 WIB: Recovering - last cause: OpenShift (Deployment minibank-transfer (namespace minibank, arc-ocp-minibank)) - answered 20:01, cleared 20:08 WIB - late readings may flicker until 20:18 WIB.

> [!IMPORTANT]
> **Say this**
>
> "The board gave its answer a few minutes ago and the fault is gone. For a short while the window still contains leftover errors, so the live reading can flicker. The banner tells you the board is recovering from that cause, not finding a new one."

---

[&larr; 31. Telemetry added for the cross-layer verdict](31-telemetry-added-for-the-cross-layer-verdict.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [33. The fault command fault.ps1 and mystery mode &rarr;](33-the-fault-command-fault-ps1-and-mystery-mode.md)
