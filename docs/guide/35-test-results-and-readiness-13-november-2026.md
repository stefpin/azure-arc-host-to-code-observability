# 35. Test results and readiness (13 November 2026)

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 35.1 How to read the score

The scorecard on the board, the scorecard tile of the workbook and this query grade every slot, draw or labelled run with the approved grading of 16 November 2026 (Chapter 38.3), the same rules that grade the test runs. They look at the readings from the start of the fault to 3 minutes after its end (for the healthy slot, from 4 minutes after its start). Customers count as affected when two readings in a row show customer impact. When they were affected, the first confirmed answer (two red readings in a row on one layer, or two readings in a row that name the host) must name the expected layer within 5 minutes of the start, or within 2.5 minutes of customers being first affected if that came later. When they were not affected, that confirmed answer, or else the first layer shown twice in a row in yellow or red, must be the expected layer within 5 minutes. A confirmed answer in the healthy slot is a false alarm. The query below replaced the option-B version of 15 November on 16 November 2026.

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
// Scorecard, approved grading (15 Nov 2026 22:35 WIB) - the same rules as the test grader:
// customers count as affected when two readings in a row show customer impact.
// Affected: the first confirmed answer (two red readings in a row on one layer, or two host warnings in a row) must name the
//   expected layer within 5 min of the start, or within 2.5 min of customers being affected if that came later.
// Not affected: that confirmed answer, or else the first layer shown twice in a row (yellow or red), must be the expected layer
//   within 5 min. Healthy slot: a confirmed answer from minute 4 to 3 min after the end is a false alarm.
let runs = MiniBankMystery_CL
| where TimeGenerated > ago(30d) and Result in ('revealed', 'series', 'labelled', 'void')
| summarize arg_max(TimeGenerated, *) by RunId, Slot
| extend Start = todatetime(StartUtc), End = todatetime(EndUtc);
let rd = MiniBankVerdict_CL | where TimeGenerated > ago(30d)
| project VT = TimeGenerated, VStatus = Status, VLayer = Layer | order by VT asc
| extend PrevLayer = prev(VLayer), PrevStatus = prev(VStatus), PrevT = prev(VT)
| extend Imp = VStatus in ('Pending', 'RootCause', 'Unclassified'), PrevImp = PrevStatus in ('Pending', 'RootCause', 'Unclassified')
| extend RedPair = VStatus in ('RootCause', 'Unclassified') and PrevStatus in ('RootCause', 'Unclassified') and PrevLayer == VLayer,
         HostPair = VLayer == 'Host' and PrevLayer == 'Host' and VStatus in ('Warning', 'RootCause') and PrevStatus in ('Warning', 'RootCause'),
         ShownPair = VStatus in ('Warning', 'RootCause') and PrevStatus in ('Warning', 'RootCause') and PrevLayer == VLayer
                     and VLayer !in ('', 'Healthy', 'Pending', 'No layer at fault', 'Unclassified'),
         ImpPair = Imp and PrevImp
| extend Key = bin(VT, 1m);
let win = runs | where Result != 'void'
| extend WStart = iff(ExpectedLayer == 'Healthy', Start + 4m, Start), WEnd = End + 3m
| mv-expand Key = range(bin(WStart, 1m), bin(WEnd, 1m), 1m) to typeof(datetime)
| project RunId, Slot, Start, WStart, WEnd, Key;
let w = rd | join kind=inner win on Key | where VT between (WStart .. WEnd);
let st = w | summarize AffT = minif(iff(PrevT < Start, Start, PrevT), ImpPair) by RunId, Slot;
let conf = w | where RedPair or HostPair | summarize arg_min(VT, VLayer, VStatus) by RunId, Slot | project RunId, Slot, OT = VT, OLayer = VLayer, OStatus = VStatus;
let shown = w | where ShownPair | summarize arg_min(VT, VLayer, VStatus) by RunId, Slot | project RunId, Slot, YT = VT, YLayer = VLayer, YStatus = VStatus;
runs
| join kind=leftouter st on RunId, Slot | join kind=leftouter conf on RunId, Slot | join kind=leftouter shown on RunId, Slot
| extend Affected = isnotnull(AffT)
| extend UseYel = isnull(OT) and not(Affected) and isnotnull(YT)
| extend AT = iff(isnotnull(OT), OT, iff(UseYel, YT, datetime(null))), ALayer = iff(isnotnull(OT), OLayer, iff(UseYel, YLayer, '')),
         AStatus = iff(isnotnull(OT), OStatus, iff(UseYel, YStatus, ''))
| extend MinutesToVerdict = iff(isnull(AT), real(null), round((AT - Start) / 1m, 1)), ImpMin = iff(Affected, round((AffT - Start) / 1m, 1), real(null))
| extend DueMin = iff(Affected, max_of(5.0, ImpMin + 2.5), 5.0)
| extend AnswerType = case(isnull(AT), '', AStatus == 'Warning', 'Warning (yellow)', AStatus == 'RootCause', 'Root cause (red)', AStatus)
| extend Customers = case(Result == 'void' or ExpectedLayer == 'Healthy', '', Affected, strcat('affected from ', tostring(ImpMin), ' min'), 'not affected')
| extend Verdict = case(Result == 'void', 'VOID (fault did not start)',
                        ExpectedLayer == 'Healthy' and isnull(OT), 'OK: no false alarm',
                        ExpectedLayer == 'Healthy', strcat('FALSE ALARM: ', OLayer),
                        isnull(AT) and Affected, 'NO VERDICT - customers affected, no confirmed answer',
                        isnull(AT), 'NO VERDICT - no layer shown twice in a row',
                        ALayer != ExpectedLayer, strcat('WRONG LAYER: ', ALayer),
                        MinutesToVerdict > DueMin, 'RIGHT LAYER (late)',
                        UseYel, 'RIGHT LAYER - early warning, customers not affected',
                        AStatus == 'Warning', 'RIGHT LAYER - early warning',
                        'RIGHT LAYER')
| project StartWIB = format_datetime(Start + 7h, 'yyyy-MM-dd HH:mm'), RunId, Mode, Slot, Number, Card, ExpectedLayer, BoardLayer = ALayer, AnswerType, MinutesToVerdict, Customers, Verdict
| order by StartWIB desc, Slot asc
```

> [!TIP]
> **What you should see**
>
> One row per slot, draw or labelled run, newest first, with Card, ExpectedLayer, BoardLayer, AnswerType, MinutesToVerdict, Customers and Verdict. Customers says affected from &lt;n&gt; min or not affected (empty for a healthy slot or a VOID). Verdict is RIGHT LAYER, RIGHT LAYER - early warning (the host named twice in a row in yellow), RIGHT LAYER - early warning, customers not affected, RIGHT LAYER (late), WRONG LAYER: &lt;layer&gt;, NO VERDICT - customers affected, no confirmed answer, NO VERDICT - no layer shown twice in a row, OK: no false alarm, FALSE ALARM: &lt;layer&gt; or VOID (fault did not start). AnswerType is Root cause (red) or Warning (yellow), and it is empty when the board gave no answer. The host calibration runs of 14 November show NO VERDICT: they ran before the host rule existed.

## 35.2 Rehearsals and the first mystery draw

| Start (WIB) | Card | Board answer | What changed after it |
|---|---|---|---|
| 14:41 | net-rhel (120 ms) | Network after 5.2 minutes | The impact was borderline: the card now uses 250 ms |
| 14:52 | schema-oracle | Application for one minute, then Database after 3.2 minutes | Rule R0 (hold) added |
| 15:10 | nullref-api | Application after 4.2 minutes | The hold waits per source |
| 15:24 | oom-ocp | OpenShift after 2.9 minutes | - |
| 15:36 | cpu-win (normal priority) | Warning only, no customer impact | The card runs at AboveNormal priority |
| 15:49 | cpu-win (AboveNormal) | Warning only | Impact also when P95 is clearly slower than normal |
| 16:03 | net-rhel (250 ms) | Network after 3.4 minutes | The hold stopped a wrong Database answer |
| 16:15 | cpu-win (16 runspaces) | VM after 3.8 minutes | - |
| 16:24 | schema-oracle | Database after 3.0 minutes | Impact judged on the last 3 minutes (rules v2.6) |
| 16:36 | Mystery draw M20261113-163615, number 3 = nullref-api | Application after 3.2 minutes, fingerprint MATCH | - |

## 35.3 Blind series 1 and 2

| Series | Slot | Card | Board answer | Minutes | Result |
|---|---|---|---|---|---|
| 1 (S20261113-164602, 16:46-18:22 WIB, rules v2.6) | 1 | nullref-api | Unclassified | 3.4 | WRONG LAYER (the earlier draw made this exception look normal; fixed in rules v2.7) |
| 1 | 2 | none | - | - | OK: no false alarm |
| 1 | 3 | net-rhel | Network | 3.4 | RIGHT LAYER |
| 1 | 4 | schema-oracle | Database | 2.9 | RIGHT LAYER |
| 1 | 5 | oom-ocp | OpenShift | 2.4 | RIGHT LAYER |
| 1 | 6 | cpu-win | VM | 2.9 | RIGHT LAYER |
| 2 (S20261113-194242, 19:42-21:18 WIB, rules v2.7) | 1 | nullref-api | Application | 3.7 | RIGHT LAYER |
| 2 | 2 | oom-ocp | OpenShift | 2.7 | RIGHT LAYER |
| 2 | 3 | none | - | - | OK: no false alarm (32 of 32 readings Healthy) |
| 2 | 4 | net-rhel | Network | 2.7 | RIGHT LAYER |
| 2 | 5 | cpu-win | VM | 2.7 | RIGHT LAYER |
| 2 | 6 | schema-oracle | Database | 2.7 | RIGHT LAYER |

Series 2 met the bar: the right layer every time, 2.7 to 3.7 minutes (2.9 on average), no false alarm, every undo step ran and the leak check was clean. After some faults the live reading flickered for a reading or two (Chapter 32.5); the recovery banner now explains those minutes.

## 35.4 The pair and series 3 (night of 13 November 2026)

A one-time task on HV-HOST-02 (bg-chain17, log C:\BuildLog\chain-20261113.log) ran them with rules v2.7 unchanged: the labelled pair, schema-oracle at 22:38 WIB and fail-oracle at 22:54 WIB, then blind series 3 from 23:10 WIB to 00:46 WIB on 14 November 2026. They were read with the query of Chapter 35.1 on 14 November 2026:

| Run (start WIB) | Card | Expected | Board answer | Minutes | Result |
|---|---|---|---|---|---|
| L20261113-223805 (22:38) | schema-oracle | Database | Database | 2.3 | RIGHT LAYER |
| L20261113-225405 (22:54) | fail-oracle | Application | Application (BadSqlGrammarException on LEDGER_MISSING) | 3.3 | RIGHT LAYER |
| Series 3 S20261113-231006, slot 1 (23:10) | nullref-api | Application | Application | 3.3 | RIGHT LAYER |
| Series 3, slot 2 (23:26) | none (healthy slot) | Healthy | - (one single Unclassified reading at 23:33:01, not confirmed) | - | OK: no false alarm |
| Series 3, slot 3 (23:42) | net-rhel | Network | Network | 3.3 | RIGHT LAYER |
| Series 3, slot 4 (23:58) | schema-oracle | Database | Database | 2.3 | RIGHT LAYER |
| Series 3, slot 5 (00:14) | cpu-win | VM | VM | 2.3 | RIGHT LAYER |
| Series 3, slot 6 (00:30) | oom-ocp | OpenShift | OpenShift | 2.3 | RIGHT LAYER |

Series 3 met the bar as well: the right layer in all five fault slots in 2.3 to 3.3 minutes (2.7 on average), no false alarm in the healthy slot, every undo step ran (00:48 WIB) and the leak check over the 7 hours found no giveaway word. Under rules v2.7, series 2 and 3 together gave 10 right layers out of 10 in 2.3 to 3.7 minutes (2.8 on average). All blind fault draws of 13 November 2026 gave 15 right layers out of 16; the one miss was series 1, slot 1, under rules v2.6.

### The quiet night after series 3

From 00:51 to 05:29 WIB, with no fault running, the observer took 557 readings: 542 were Healthy and 15 were not, in seven short episodes. Only one of them became an answer on the board: from 01:39:31 to 01:42:01 WIB it read Unclassified for about 2.5 minutes. The cause was the traffic generator itself. Its background slow-scenario calls to the fraud check take about 1.6 seconds and all succeed; from 01:37 to 01:40 WIB, 11 of 126 business transactions (8.7 %) took longer than 1 second, which lifted the 3-minute P95 to 1.6 seconds, 12 times the normal 134 ms, and passed the impact gate (P95 above 1,000 ms).

Everything else was normal: P75 117 to 150 ms, no HTTP 5xx, no failed robot journey, CPU at most 15 % and no exception. No layer rule could match, so when the hold ended the board said Unclassified. The other six episodes were short Pending stretches of one to three readings; one of them also had a single Unclassified reading that was never confirmed.

The night's tests also raised 9 alerts: alr-minibank-failure-rate-high, alr-minibank-journey-success-low and alr-minibank-failed-value-idr, 3 each, fired between 22:40 and 00:40 WIB and resolved by 01:01 WIB. The lab owner approved closing them, and they were closed on 14 November 2026 at 07:38 WIB; after that, all 34 alerts of the previous 7 days in rg-appmon-openshift-demo were Closed.

### Rules v2.8: a few slow transactions, no layer at fault

The lab owner chose option B on 14 November 2026 at 07:23 WIB. Rules v2.8 add rule R8 (Chapter 32.1): when customers look impacted only because a few calls are slow (P95 is high, but P75 is normal, at most 2 % of the business transactions fail and fewer than 2 robot journeys failed) and no layer rule matches, the status is Warning, and the board shows in yellow No layer at fault: A few slow transactions, no layer at fault. The evidence says how many calls were slow, for example 9 of 94 business transactions in the last 3 minutes at 01:40 WIB.

A Warning never counts as an answer, so the scorecard, the recovery banner and the alert rules did not change. Rules v2.8 were saved as the function minibank-rootcause in law-appmon on 14 November 2026 at 08:09 WIB; the rules v2.7 text is kept in F:\Build\tools\rc-fn-before-v28.json on HV-HOST-02 (undo: Chapter 35.7). Since 15 November 2026 there is one exception (option B, Chapter 37.8): a Warning naming the host, seen twice in a row, counts as the answer.

Before the save, a read-only replay recalculated both versions at 327 moments: every reading that was not Healthy from 13 November 19:40 WIB to 14 November 07:30 WIB (series 2, the pair, series 3 and the night), the slow-oracle and fail-oracle runs of 12 November 2026 and three quiet moments. No layer answer changed or was lost: all 222 RootCause readings, all 56 Warning readings with a layer and all 7 Healthy readings stayed the same. 29 readings changed to the yellow No layer at fault (17 Pending and 12 Unclassified), among them the whole 01:39 to 01:42 episode and the single Unclassified reading of series 3's healthy slot; 13 readings inside fault windows stayed Pending (11) or Unclassified (2).

What the presenter sees: in a quiet stretch the board now shows the yellow Warning instead of Pending or Unclassified for these minutes. At the start of a fault, when only P95 has risen and the layer data has not arrived yet, the first reading can also be the yellow Warning instead of Pending; the layer answer follows as before. A suitable line: the board sees a few slow calls and is still checking the layers.

### Series 4 with rules v2.8 (14 November 2026)

Blind series S20261114-081121 ran from 08:11:26 to 09:47:26 WIB with rules v2.8: the five cards and one healthy slot in a random order, 16 minutes per slot with a 7-minute fault. It met the bar: the right layer in all five fault slots in 2.1 to 3.1 minutes (2.7 on average), and no false alarm in the healthy slot (32 of 32 readings Healthy). Rule R8 showed the yellow No layer at fault only three times, each in the first minute of a fault (08:12:00 in slot 1, 08:28:00 and 08:28:30 in slot 2), before the board named the layer. Every undo step ran (09:49 WIB) and the leak check over 2 hours found no giveaway word. Series 2, 3 and 4 together: 15 right layers out of 15 in 2.1 to 3.7 minutes (2.8 on average) and no false alarm.

| Run (start WIB) | Card | Expected | Board answer | Minutes | Result |
|---|---|---|---|---|---|
| Series 4 S20261114-081121, slot 1 (08:11) | net-rhel | Network | Network | 3.1 | RIGHT LAYER |
| Series 4, slot 2 (08:27) | cpu-win | VM | VM | 2.2 | RIGHT LAYER |
| Series 4, slot 3 (08:43) | oom-ocp | OpenShift | OpenShift | 3.1 | RIGHT LAYER |
| Series 4, slot 4 (08:59) | none (healthy slot) | Healthy | - (32 of 32 readings Healthy) | - | OK: no false alarm |
| Series 4, slot 5 (09:15) | nullref-api | Application | Application | 3.1 | RIGHT LAYER |
| Series 4, slot 6 (09:31) | schema-oracle | Database | Database | 2.1 | RIGHT LAYER |

## 35.5 The test bar and what is still open

- The bar: the right layer every time, within 5 minutes, with no false alarm, in two series before the demo day and in one series on the demo morning. Series 2 and 3 passed under rules v2.7 (10 of 10), and series 4 passed under rules v2.8 on 14 November 2026 (5 of 5, no false alarm); the demo-morning series is still to run.
- The demo date is not fixed yet. Plan the morning series and the pair at least 2 hours before the session (Chapter 19.1).
- Option B for the after-fault flicker (the layer evidence must be recent compared with the impact, and the relative P95 trigger is dropped) was not built; the recovery banner of option A explains the flicker. Rules v2.8 is a different, smaller change: rule R8 for a few slow transactions (Chapters 32.1 and 35.4).
- The memory-pressure card for APP-RHEL was not built; the mystery pool stays at five cards.
- The version 1.7 scripts, functions and dashboards are on HV-HOST-02 and in the lab (Chapter 30.3), not yet in a new source pack or architecture diagram.
- The ACR push token expires on 17 November 2026 at 20:48 WIB; renew it only if images must change. The pull token is valid until 10 December 2026.
- Close the alerts of every test run before the demo (Chapter 20.3); each of them also sent e-mails. The 9 alerts of the night of 13 November 2026 were closed on 14 November 2026 at 07:38 WIB. Series 4 raised 7 new alerts between 08:45 and 09:43 WIB (one of them Failure Anomalies - appi-minibank); they are still open.
- Check Kubernetes resources &gt; Workloads on the demo morning (Chapter 19.1): the cause of the Error (599) of 13 November 2026 is not known.
- Deferred: Priority 2 (health model, bad release and rollback, closed-loop fix, SQL Server internals) and the forward-looking Outlook board.
## 35.6 Build record and lessons

| Time (WIB) | What happened |
|---|---|
| 11:55 | Error (599) on Kubernetes resources &gt; Workloads fixed by restarting only the cluster-connect agent (approved) |
| 13:46 | Build approved: the cross-layer board and mystery mode |
| 14:00-14:13 | VM performance rules, network probe, schema checks and minibank-api 1.2.1; an unplanned API outage from 14:10:30 to 14:13:45 |
| 14:32-14:40 | Verdict function, observer, fault.ps1, Grafana board and workbook group |
| 14:41-16:30 | Nine rehearsals; the rules went from v2 to v2.6 |
| 16:36-16:43 | First mystery draw: right layer after 3.2 minutes, fingerprint MATCH |
| 16:46-18:22 | Series 1 (rules v2.6): 4 of 5 and no false alarm |
| 19:33 | Rules v2.7 saved |
| 19:42-21:18 | Series 2 (rules v2.7): 5 of 5 and no false alarm |
| 22:12 | Follow-ups approved: recovery banner, alert e-mail, closing old alerts, leak check, the pair and series 3, Runbook 1.7 |
| 22:32-22:38 | Action group and e-mails, 25 alerts closed, banner on the board and in the workbook, leak check changed, the pair and series 3 started |
| 22:38-00:48 | The pair (both on the right layer) and series 3 (rules v2.7): 5 of 5 and no false alarm; all undo steps ran |
| 00:51-05:29 | Quiet night: Unclassified for about 2.5 minutes at 01:39-01:42 with no fault running, caused by the generator's own slow calls |
| 14 Nov 07:23 | Approved: close the 9 alerts of the night, Chapter 35.4, rules v2.8 (option B) and the logo header on every board and workbook |
| 07:38 | 9 alerts of the night closed |
| 07:52-08:17 | Logo header on the three Grafana boards (07:52, with the yellow No layer at fault on the cross-layer board) and on the workbook (08:17) |
| 08:09 | Rules v2.8 saved after the replay of 327 readings (no layer answer changed) |
| 08:11-09:47 | Series 4 (rules v2.8): 5 of 5 and no false alarm; all undo steps ran (09:49) |
| 10:58-13:10 | Live topology map (version 1.8): approved at 10:58, the function tested at 17 moments at 12:20 (all as expected), the panel saved on the board at 12:57 and 12:59, then checked live, in a replay and in mystery mode (Chapter 36) |

- Data arrives at different speeds: application data in about 10 seconds; VM, OpenShift, network and schema data in 60 to 100 seconds. A verdict must wait for the slow layers before it blames the fast one (rule R0).
- Log Analytics can return a cached result for the same query text: put the time into the query, as the observer and the board do.
- A CPU hog at normal priority does not slow IIS enough for customers to notice; the card runs at AboveNormal priority.
- A baseline must not learn from a test: a 10-minute burst of the same exception looked normal 10 minutes later (series 1, slot 1). Rules v2.7 use the 75th percentile of the counts per minute, so a short burst never becomes normal.
- IIS: wait until the worker process has released the files before copying a new version (the outage at 14:10).
- Get-VM CPUUsage is a share of the whole host: scale it by the host's logical processors and the VM's virtual processors before comparing it with 70 %.
- A quiet lab is not silent: the traffic generator's own slow calls lifted the 3-minute P95 above 1 second for a few minutes during the night. A rule that sees only a high P95 must neither blame a layer nor give up; rule R8 (rules v2.8) shows that pattern as a yellow Warning.
## 35.7 Rollback of version 1.7

| Item | Where | How to undo |
|---|---|---|
| Recovery banner | Grafana amg-appmon; Azure Portal (workbook); law-appmon | Import F:\Build\tools\grafana-rootcause-before-banner-20261113-153534.json (Dashboards &gt; New &gt; Import), or delete the panel Recovery banner. In the workbook remove the items recovering-param and recovering-banner (Edit &gt; Advanced Editor), or put back workbook-before-banner-20261113-153542.json. Then delete the saved search minibank-recovering (law-appmon &gt; Logs &gt; Functions) |
| Alert e-mails | Azure Portal, Monitor &gt; Alerts | Chapter 34.3 |
| Leak-check change | HV-HOST-02 - PowerShell (Admin) | Copy-Item F:\Build\minibank\scripts\fault.ps1.bak-20261113-223703 F:\Build\minibank\scripts\fault.ps1 -Force |
| Rules v2.7 | Cloud Shell or law-appmon &gt; Logs &gt; Functions | Save the query text of F:\Build\tools\rc-fn-before-x19.json (rules v2.6) as the function minibank-rootcause again |
| Board and workbook group | Grafana; Azure Portal (workbook) | Delete the dashboard minibank-rootcause; remove the group cross-layer-root-cause from the workbook |
| Observer and ledger | HV-HOST-02 - PowerShell (Admin); Azure Portal | Unregister-ScheduledTask minibank-verdict-observer -Confirm:$false; delete the tables MiniBankVerdict_CL and MiniBankMystery_CL, the rule dcr-minibank-rca and the two role assignments of the HV-HOST-02 identity |
| Network probe | HV-HOST-02 - PowerShell (Admin), after the start block of Chapter 5.5 | oc delete deployment/minibank-netprobe configmap/minibank-netprobe -n minibank |
| VM performance rules | Azure Portal &gt; Monitor &gt; Data collection rules | Delete the three associations dcra-minibank-vmperf, then dcr-minibank-vmperf-win and dcr-minibank-vmperf-linux |
| Schema checks | APP-RHEL - Bash | Put back the two files /opt/minibank/dbsnap/\*.bak-20261113-140633 |
| minibank-api 1.2.1 | APP-WIN - PowerShell Direct | Stop-WebAppPool minibank, wait until no worker process is left, robocopy C:\inetpub\minibank-api-1.2.0-backup C:\inetpub\minibank-api /E, Start-WebAppPool minibank |
| Rules v2.8 (14 November 2026) | Cloud Shell or law-appmon &gt; Logs &gt; Functions | Save the query text of F:\Build\tools\rc-fn-before-v28.json (rules v2.7) as the function minibank-rootcause again |
| Logo header (14 November 2026) | Grafana amg-appmon; Azure Portal (workbook) | Grafana: on each of the three boards select Edit &gt; Settings &gt; Versions and restore the version before the header (MiniBank - OpenShift and Databases version 3, MiniBank - SLA and Failure Rate version 5, MiniBank - Cross-layer root cause version 3, which also removes the yellow colour of No layer at fault), or import the copies in F:\Build\tools\brand-bak-20261114-0052.tgz (Dashboards &gt; New &gt; Import). Workbook: Edit &gt; Advanced Editor, delete the item brand-header, then Apply, Done Editing and Save |
| Live topology map (14 November 2026) | Grafana amg-appmon; law-appmon &gt; Logs &gt; Functions | Restore version 4 of MiniBank - Cross-layer root cause (Edit &gt; Settings &gt; Versions), then delete the function MiniBankTopology; details in Chapter 36.6 |

---

[&larr; 34. Alert e-mails](34-alert-e-mails.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [36. Live topology map (version 1.8) &rarr;](36-live-topology-map-version-1-8.md)
