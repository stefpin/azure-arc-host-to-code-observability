# 38. Version 2.0: the Mystery control window, the approved grading and the readiness tests

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


Version 2.0 finishes the readiness campaign of 15 and 16 November 2026. It adds a Mystery control window on HV-HOST-02 so that the presenter runs the Scene 7C draw with buttons, grades every answer by whether customers were affected, stops the board from waiting for the host data when the host is clearly quiet (rules v2.10), puts card 6 (the busy Hyper-V host) into the mystery draw and moves the two host charts into the section Layer signals. Everything was tested before it was kept: a replay of the stored readings, 10 live tests, a quiet night, two blind series and mystery draws. All lab changes were made in rg-appmon-openshift-demo and on HV-HOST-02; the managed resource group MA_amw-appmon_indonesiacentral_managed was not changed, and the Hyper-V demo in rg-hyperv-arc-monitor-demo was not touched.

## 38.1 Decisions and approvals

| When (WIB) | Decision by the lab owner |
|---|---|
| 15 Nov 15:39 | Error (599): switch the Arc cluster-connect feature off and on, in rg-appmon-openshift-demo and the managed resource group only. |
| 15 Nov 16:35 | Error (599) fix deferred after the off and on did not help. Card 6 into mystery mode with series-host.on kept, and the host wait option B (end the wait early when the host is quiet) only if it passes every test: the replay, live tests, blind series and mystery tests. |
| 15 Nov 16:49 | Go with all recommendations: the test campaign in this order (replay, save rules v2.10, live tests, the Monday blind series, mystery tests), this runbook version 2.0, closing the test alerts afterwards and the pre-approved undo steps; also move the two host charts from the scorecard section into Layer signals and add Host to its title. |
| 15 Nov 22:35 | The grading package, items 1 to 5: grade by whether customers were affected, the time limit, false alarms and after-effects, the quiet-night gate on pairs, and the same wording in the scorecard, the workbook tile and the reveal; with the condition that nothing harms the existing demo setup or the other scenarios. |
| 16 Nov 06:55 | Option A, the Mystery control window on HV-HOST-02: prepared during the Monday series and installed after about 10:50; this runbook describes it as the main way, with the PowerShell lines kept as the backup in Scene 7C and Chapter 33. |

## 38.2 Rules v2.10: the host wait ends early when the host is quiet

Rules v2.9 made the board wait while customers were impacted and the host data had not yet reported past the start of the impact: R2, R3 and R4 showed Pending (Waiting for the HV-HOST-02 host CPU data) so that a host cause would not be missed. The host data arrives every 30 seconds but about a minute late, so this wait cost up to 1.5 minutes. In blind series 5 the VM card took 4.6 minutes instead of about 3.

Since rules v2.10 the wait ends at once when the newest host reading is at most 150 seconds old, was taken no more than 60 seconds before customers were first impacted, and shows a quiet host: a true load under 70 % (the R9 threshold) and fewer than 3 VMs waiting 3 times their normal. A late or missing host reading keeps the wait, and a busy host keeps it as well, so R9 can still name the host. The rule was replayed read-only against every stored reading before it was saved:

| What was replayed | Rules v2.9 | Rules v2.10 |
|---|---|---|
| 15 Nov 07:29:30, blind series 5, network card | Pending (waiting for the host data) | Network, red (R3); quiet host reading of 07:28:30: true load 31 %, no VM waiting |
| 15 Nov 08:27:30, 08:28:01 and 08:28:31, blind series 5, VM card | Pending (waiting for the host data) | VM, red (R4); quiet host readings of 08:26:31 and 08:27:31: 46 and 51 %, no VM waiting |
| The VM slot of blind series 5 | Right after 4.6 minutes | Right after 3.1 minutes |
| The host-card runs | Warning naming the host | The same: the host was busy (72 to 86 %, 3 to 6 VMs waiting), so the wait stayed |
| All 57 stored runs since 13 November | 52 right or no false alarm, 0 wrong, 0 false alarms, 2 late | The same totals; only the four readings above changed, all to an earlier right answer |

1,408 moments were replayed with rules v2.9 and 778 with rules v2.10, without errors. Rules v2.10 was saved in MiniBankRootCause at 20:44 WIB on 15 November 2026 and checked at once against three stored moments (Healthy now; the VM answer of 08:27:30; the host Warning of 08:11:31). The rules v2.9 body is kept on HV-HOST-02 in F:\Build\tools\rc-fn29-body.json. To go back, put it back with the az rest command of Chapter 37.6, with rc-fn29-body.json instead of rc-fn28-body.json.

## 38.3 The approved grading: customers affected or not

The first live test of 15 November showed why the old score was too strict: the VM card made APP-WIN's CPU 100 % busy and the board named the VM in yellow for 7 minutes, but customers were never slowed down enough to count as impacted, so the board never turned red and the strict score said NO VERDICT. Over 9 measured VM runs the customers were at most 2.9 to 14.6 times slower, in 5 runs no more than 4 times. The other cards always hurt customers clearly. The lab owner approved a grading that asks first whether customers were affected:

| Term | Rule |
|---|---|
| Customers affected | Two readings in a row show customer impact (Pending, RootCause or Unclassified). Affected from is the first reading of that pair, counted from the start of the fault. |
| Confirmed answer | Two readings in a row name the same layer in red (RootCause), or two readings in a row name the host (yellow or red). |
| When customers were affected | The first confirmed answer must name the expected layer within 5 minutes of the start, or within 2.5 minutes of customers being first affected if that came later. Later still: RIGHT LAYER (late). |
| When customers were not affected | A confirmed answer if there is one, otherwise the first layer shown twice in a row in yellow or red (not Healthy, Pending, No layer at fault or Unclassified), must be the expected layer within 5 minutes: RIGHT LAYER - early warning, customers not affected. |
| The host card | Unchanged: two host readings in a row, yellow or red, are the answer: RIGHT LAYER - early warning. |
| The healthy slot | No confirmed answer from 4 minutes after its start to 3 minutes after its end: OK: no false alarm. |
| Outside every test | A confirmed pair is a false alarm, unless it names the same layer within 10 minutes after the end of a fault of that layer: then it is an after-effect and is only reported. Single readings are only reported. |

The same rules run in five places: the scorecard on the board (version 12, with the new column Customers), the scorecard tile of the workbook, the mystery reveal in fault.ps1 (the lines Customers and Board verdict), the automatic grading of the live tests (F:\Build\tools\sc10.ps1 version 3 with lv11.kql) and the quiet-night gate of the Monday runner (F:\Build\tools\mon10.ps1 version 2). The scorecard query is in Chapter 35.1. Before it was saved, the board's query and the test grader were compared on all 81 runs since 13 November: no difference.

Re-graded with these rules, the 65 runs from 13 to 15 November changed in four places, all as intended: right answers went from 47 to 51, NO VERDICT from 10 to 7 and late answers from 1 to 0. Three VM runs that never affected customers (13 November 15:36 and 15:49, 15 November 20:47) are now RIGHT LAYER - early warning, customers not affected, and the network run of 13 November 14:41 (5.7 minutes) is on time, because customers were affected only from 5.2 minutes. The one wrong answer stays: it came from rules v2.6 on 13 November. The seven host calibration runs of 14 November stay NO VERDICT: they ran before the host rule existed.

## 38.4 Live tests and the quiet night (15-16 November)

Rules v2.10 then met the live tests: 10 labelled cards of 7 minutes, one every 16 minutes from 20:47 WIB on 15 November, run by a one-time task on HV-HOST-02, then 15 quiet minutes. The host graded them by itself at 23:42 with the approved grading: PASS, 10 of 10 right in time, every card type tested with customers affected, no false alarm. That wrote the go file for the Monday series.

| # | Start (WIB) | Card | Board answer | Min. | Customers | Verdict |
|---|---|---|---|---|---|---|
| 1 | 20:47 | cpu-win | VM, yellow (R4) | 2.3 | not affected | RIGHT LAYER - early warning, customers not affected |
| 2 | 21:03 | cpu-host | Host, yellow (R9) | 2.3 | - | RIGHT LAYER - early warning |
| 3 | 21:19 | oom-ocp | OpenShift, red (R2) | 2.3 | affected | RIGHT LAYER |
| 4 | 21:35 | cpu-win | VM, red (R4) | 4.3 | affected from 3.8 min (due 6.3) | RIGHT LAYER |
| 5 | 21:51 | net-rhel | Network, red (R3) | 2.8 | affected | RIGHT LAYER |
| 6 | 22:07 | schema-oracle | Database, red (R1) | 2.3 | affected | RIGHT LAYER |
| 7 | 22:23 | fail-oracle | Application, red (R6) | 3.3 | affected | RIGHT LAYER |
| 8 | 22:39 | cpu-host | Host, yellow (R9) | 2.3 | - | RIGHT LAYER - early warning |
| 9 | 22:55 | nullref-api | Application, red (R6) | 3.3 | affected from 0.3 min | RIGHT LAYER |
| 10 | 23:11 | cpu-win | VM, red (R4) | 2.8 | affected from 2.3 min | RIGHT LAYER |

Outside the tests there was no false alarm; one single Database reading at 22:19:31, five minutes after the schema card, was an after-effect. The night from 23:45 to 06:45 was the false-alarm test: 836 readings, 827 Healthy and 9 yellow (among them R8, a few slow transactions, at 02:42 to 02:44), no red answer and no pair, so the Monday runner's night gate passed at 06:45 and its last-16-minute gate at 07:00.

## 38.5 The two Monday blind series (16 November)

The Monday runner started blind series 1 at 07:00:04 and series 2 at 08:54:55, each with 7 slots (series-host.on adds card 6). The observer did not know the order. Graded with the approved grading, both series scored 7 of 7:

| Slot | Start (WIB) | Card | Board answer | Min. | Customers | Verdict |
|---|---|---|---|---|---|---|
| 1-1 | 07:00 | cpu-host | Host, yellow (R9) | 2.4 | not affected | RIGHT LAYER - early warning |
| 1-2 | 07:16 | nullref-api | Application, red | 3.4 | affected from 0.4 min | RIGHT LAYER |
| 1-3 | 07:32 | cpu-win | VM, red | 2.4 | affected from 1.4 min | RIGHT LAYER |
| 1-4 | 07:48 | net-rhel | Network, red | 2.9 | affected from 0.9 min | RIGHT LAYER |
| 1-5 | 08:04 | oom-ocp | OpenShift, red | 2.4 | affected from 0.4 min | RIGHT LAYER |
| 1-6 | 08:20 | none | no confirmed answer | - | - | OK: no false alarm |
| 1-7 | 08:36 | schema-oracle | Database, red | 2.4 | affected from 0.4 min | RIGHT LAYER |
| 2-1 | 08:55 | cpu-host | Host, yellow (R9) | 2.5 | not affected | RIGHT LAYER - early warning |
| 2-2 | 09:11 | oom-ocp | OpenShift, red | 2.5 | affected from 0.5 min | RIGHT LAYER |
| 2-3 | 09:27 | schema-oracle | Database, red | 2.5 | affected from 0.5 min | RIGHT LAYER |
| 2-4 | 09:43 | net-rhel | Network, red | 3.0 | affected from 1.0 min | RIGHT LAYER |
| 2-5 | 09:59 | nullref-api | Application, red | 3.5 | affected from 0.5 min | RIGHT LAYER |
| 2-6 | 10:15 | none | no confirmed answer | - | - | OK: no false alarm |
| 2-7 | 10:31 | cpu-win | VM, red | 7.5 | affected from 7.0 min (due 9.5) | RIGHT LAYER |

Slot 2-7 shows why the grading asks about customers. The board named the VM in yellow from 2.0 minutes, but customers were affected only from 7.0 minutes; the red answer came at 7.5 minutes, well within the 9.5 minutes allowed, and no other layer was ever named. Outside the slots there were only three Database readings at 08:47 to 08:48, within 10 minutes after the schema card of series 1 had ended: after-effects, not false alarms. Every undo step ran and BATCH-EOD was off after each host slot.

## 38.6 The Mystery control window

The Mystery control window is a small Windows window on HV-HOST-02 that runs the Scene 7C commands with buttons, so the presenter does not type during the demo. It runs exactly the same fault.ps1 commands as the presenter's window: the draw, the reveal, Status and Stop. It changes nothing else: not the application, the telemetry, the rules, the board or Azure. Its own log, C:\BuildLog\mystery-window.log, never names the card before the reveal.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02, in the Bastion session: the presenter's window (Windows PowerShell as administrator, after the start block of Chapter 5.5, prompt PS F:\Build\minibank\scripts&gt;). Open the window before the session; it opens on its own and leaves the prompt free. Only one window can be open at a time.

```powershell
.\mystery-window.ps1
```

| Part of the window | What you do | What you see |
|---|---|---|
| 1  the bank picks a number | Press the bank's number (the buttons follow the pool: 1 to 6 now), or let the computer pick the number. Then Start the draw and confirm. | Number &lt;n&gt;, chosen by the bank; Starting the draw; Number sealed. Checking that the fault took effect (up to 90 seconds). |
| 2  Sealed fingerprint | Read it out loud; Copy puts it on the clipboard for the meeting chat. | Four groups of four characters in large letters, the line Draw M&lt;date-time&gt; \| number &lt;n&gt;, then Fault is active - watch the board, and the time since the start and until the fault ends by itself. |
| 3  Reveal the answer | When the board has answered, press it and confirm. | The card, Expected layer, the fingerprint MATCH, the line Customers and the line Board verdict, coloured green when right, amber when late or without a verdict, red when wrong. |
| Status | Any time. | The current or last run, without the card during a draw. |
| Stop every fault | Only when something looks stuck; confirm. | Every fault, also a blind series, is ended and undone at once. |

Safety: Start, Reveal and Stop ask for a confirmation. While another run is active the window refuses a new draw and shows when that run ends. Closing the window during a draw asks first and does not stop the fault: it ends by itself after 8 minutes, and the watchdog of fault.ps1 also stops it. If the window ever fails, the PowerShell lines of Scene 7C and Chapter 33 do exactly the same.

Tests before it was used: the PowerShell parser on HV-HOST-02 (Windows PowerShell 5.1) found no error and the 36 parse tests passed; a stand-in for fault.ps1 (F:\Build\tools\mw-stub.ps1, which changes nothing) drove every button and message, and the status test read the real fault.ps1. The stand-in test found one bug in version 1.0: a variable inside one function had the same name as the window's own draw record, apart from upper and lower case, and PowerShell treats such names as the same. The draw result was therefore overwritten: 7 of 31 tests failed (for example a VOID draw was not recognised and Start stayed locked). Version 1.1 renamed the variable at 11:49 WIB on 16 November; all 31 tests passed, and a scan of the whole window found no other such name. The window was then used for the real mystery draws of Chapter 38.7.

## 38.7 Card 6 in mystery mode and the mystery tests

The switch file C:\ProgramData\MiniBank\fault\mystery-host.on was created at 12:18:57 WIB on 16 November 2026. Since then the draw shuffles six cards behind the numbers 1 to 6, and the bank can draw the busy host. series-host.on stays, so the blind series keep card 6 as well. To take card 6 out of the draw, delete mystery-host.on; the draw goes back to 1 to 5.

From 12:18 WIB one-time tasks on HV-HOST-02 drew one card about every 15 minutes, each time only after at least 6 minutes since the last reveal, 4 Healthy readings in a row and no run active. Draw 1 used the PowerShell line as the baseline; every later draw went through the Mystery control window, with the number pressed by the test as the bank would (twice the computer picked it). Nobody saw the card before the reveal. The reveal graded each draw with the approved grading, and the scorecard on the board shows the same verdicts (Board answer: the layer and colour of the first confirmed answer and the time after the start of the fault; Customers: from the scorecard):

| # | Start (WIB) | Number | Card | Board answer | Customers | Verdict |
|---|---|---|---|---|---|---|
| 1 | 12:19 | 3 (PowerShell) | nullref-api | Application, red, 3 min 27 s | affected from 1.0 min | RIGHT LAYER |
| 2 | 13:43 | 6 | nullref-api | Application, red, 3 min 25 s | affected from 0.4 min | RIGHT LAYER |
| 3 | 13:58 | 1 | nullref-api | Application, red, 3 min 22 s | affected from 0.9 min | RIGHT LAYER |
| 4 | 14:13 | 4 (computer) | schema-oracle | Database, red, 2 min 50 s | affected from 0.3 min | RIGHT LAYER |
| 5 | 14:30 | 5 | net-rhel | Network, red, 2 min 49 s | affected from 0.8 min | RIGHT LAYER |
| 6 | 14:45 | 2 | cpu-win | VM, yellow, 2 min 47 s | not affected | RIGHT LAYER - early warning, customers not affected |
| 7 | 15:00 | 4 | nullref-api | Application, red, 3 min 16 s | affected from 0.3 min | RIGHT LAYER |
| 8 | 15:17 | 6 | schema-oracle | Database, red, 2 min 16 s | affected from 0.3 min | RIGHT LAYER |
| 9 | 15:33 | 2 | net-rhel | Network, red, 2 min 15 s | affected from 0.8 min | RIGHT LAYER |
| 10 | 15:59 | 3 | schema-oracle | Database, red, 2 min 18 s | affected from 0.3 min | RIGHT LAYER |
| 11 | 16:15 | 5 (computer) | nullref-api | Application, red, 3 min 17 s | affected from 0.3 min | RIGHT LAYER |
| 12 | 16:31 | 5 | cpu-win | VM, red, 2 min 18 s | affected from 1.3 min | RIGHT LAYER |
| 13 | 16:45 | 1 | oom-ocp | OpenShift, red, 3 min 47 s | affected from 0.3 min | RIGHT LAYER |
| 14 | 17:05 | 4 | schema-oracle | Database, red, 3 min 15 s | affected from 0.3 min | RIGHT LAYER |
| 15 | 17:21 | 2 | nullref-api | Application, red, 3 min 44 s | affected from 0.2 min | RIGHT LAYER |

Result: 15 of 15 draws named the right layer, 14 of them through the Mystery control window, with the first confirmed answer after 2 min 15 s to 3 min 47 s. No window test reported a failure and no draw was void. The cards that came up: Application (nullref-api) 6, Database (schema-oracle) 4, Network (net-rhel) 2, VM (cpu-win) 2, OpenShift (oom-ocp) 1. Card 6, the busy host, did not come up in these 15 draws. The draw is fair: a read-only check of fault.ps1 shows six different cards and a shuffle with a cryptographic random generator, and the chance of missing one given card in 15 draws is about 6.5 %. Card 6 is covered by its six runs in the blind series and the live tests (all RIGHT LAYER - early warning after 2.3 to 2.6 minutes) and by the stand-in test of the window, which covers its slower start check.

Card 6 session (17 November 2026). The lab owner approved it at 21:11 WIB on 16 November: up to 10 more draws, stopping at the first card 6. The one-time task bg-myst17 (runner F:\Build\tools\myst17.ps1, made from the runner of 16 November with the same gate: at least 6 minutes after the last reveal, 4 Healthy readings in a row and no run active) started at 08:09:56 WIB. Every draw went through the Mystery control window with the number pressed as the bank would; in draw 18 the computer picked it. Nobody saw the card before the reveal.

| # | Start (WIB) | Number | Card | Board answer | Customers | Verdict |
|---|---|---|---|---|---|---|
| 16 | 08:10 | 2 | cpu-win | VM, red, 3 min 43 s | affected from 3.2 min | RIGHT LAYER |
| 17 | 08:24 | 5 | net-rhel | Network, red, 2 min 13 s | affected from 1.2 min | RIGHT LAYER |
| 18 | 08:40 | 4 (computer) | cpu-host (card 6) | Host, yellow, 2 min 12 s | not affected | RIGHT LAYER - early warning, customers not affected |

Result: 3 of 3 right. Card 6 came up in draw 18: the noisy-neighbour VM BATCH-EOD ran only from 08:40:18 to 08:48:18 WIB, the board named Host in yellow after 2 min 12 s and customers were not affected, so the answer counts as an early warning (Chapter 38.3). The runner stopped after card 6 at 08:48:36 WIB, as planned. All 18 mystery draws so far named the right layer: Application 6, Database 4, VM 3, Network 3, OpenShift 1 and Host 1. These three draws fired no alert: the VM, network and host cards mostly slow customers down, and none of them crossed the failure thresholds of the alert rules, so there was nothing to close.

## 38.8 The board and the workbook (versions 11 and 12)

Board version 11 (17:16 WIB, 15 November 2026) moved the two host charts, Host HV-HOST-02: true CPU load vs what Windows on the host shows and Host HV-HOST-02: CPU wait per dispatch by VM (µs) - how long each VM waits for a processor, from the scorecard section to the top of the section that is now called Layer signals: Host, VM, OpenShift, network, application, database. The VM, OpenShift and network charts follow, then the application and database charts; the scorecard section now holds only the scorecard. Board version 12 (16 November 2026, before 12:14 WIB) put the approved grading into the scorecard and added the column Customers; the scorecard tile of the workbook got the same query. The colours did not change: RIGHT LAYER and OK are green, WRONG LAYER, FALSE ALARM, NO VERDICT and VOID are red.

Backups on HV-HOST-02: F:\Build\tools\rc-board-v10-before-gp24.json.gz (version 10), rc-board-v11-before-item5.json.gz (version 11) and workbook-before-grading11-20261116-050329-before-item5.json.gz (the workbook). In Grafana every version can also be restored from Dashboard settings &gt; Versions.

## 38.9 Error (599) on Kubernetes resources: still open

Azure Portal &gt; arc-ocp-minibank &gt; Kubernetes resources &gt; Workloads shows Error (599) Failed to load all namespaces. On 13 November a restart of the clusterconnect-agent fixed it; the error came back on 14 November and a restart at 18:52 did not help. On 15 November, approved at 15:39, a read-only check passed first (cluster Connected, agent 1.39.3, 9 of 9 Arc pods running, backups of the Arc release in F:\Build\backup\cc), and the cluster-connect feature was switched off and on at 16:00 to 16:04 WIB. It was clean: the Arc agents were back 9 of 9, the board stayed Healthy and no data was lost. The Portal still showed Error (599): the Portal's requests never reach the agent in the cluster, which waits and receives nothing. A test from Cloud Shell was not possible (its sign-in cannot open this kind of connection), and the host's managed identity lacks the Cluster User role. At 16:35 WIB the lab owner deferred the fix.

Next options, each needing a go: open the Workloads page from another network or device; give the host's managed identity the Azure Arc Enabled Kubernetes Cluster User Role on arc-ocp-minibank for one test and remove it afterwards; or open a support case with the evidence. During the demo show the workloads in Insights, tab Controllers (Scene 1), or in the OpenShift web console (Scene 0A). Nothing needs to be undone: the feature is on, as before.

## 38.10 Build record, open items and undo

| Time (WIB) | What happened |
|---|---|
| 15 Nov 15:39 | Error (599) fix approved: switch the cluster-connect feature off and on. |
| 15 Nov 15:50 | Read-only pre-check passed: cluster Connected, agent 1.39.3, 9 of 9 Arc pods running; backups of the Arc release in F:\Build\backup\cc. |
| 15 Nov 16:00-16:04 | Cluster-connect switched off and on: clean (Arc agents 9 of 9, board Healthy, no data gap), but the Portal still showed Error (599) (Chapter 38.9). |
| 15 Nov 16:35 | Error (599) fix deferred; card 6 in mystery mode and the host wait option B approved, subject to every test. |
| 15 Nov 16:49 | Go with all recommendations, plus the move of the host charts. |
| 15 Nov 17:16 | Board version 11: the host charts at the top of Layer signals: Host, VM, OpenShift, network, application, database; version 10 backed up on HV-HOST-02. |
| 15 Nov 17:17-19:30 | Replay of the stored readings with rules v2.9 and v2.10 (Chapter 38.2); one restart after a sign-in token expired during the run. |
| 15 Nov 20:44 | Rules v2.10 saved; the v2.9 body kept in F:\Build\tools\rc-fn29-body.json. |
| 15 Nov 20:46-23:42 | 10 live tests and 15 quiet minutes; the host graded them at 23:42: PASS, 10 of 10 (Chapter 38.4). |
| 15 Nov 22:35-22:58 | Grading package approved and installed on HV-HOST-02: live-test grader version 3 and Monday runner version 2, with backups of the earlier versions. |
| 15 Nov 23:45 - 16 Nov 06:45 | Quiet night: 836 readings, no red answer, no pair. |
| 16 Nov 06:45-07:00 | Monday runner: the go file, the night gate and the last-16-minute gate passed. |
| 16 Nov 06:55 | Mystery control window (option A) approved. |
| 16 Nov 07:00-08:52 | Blind series 1: 7 of 7 right (Chapter 38.5). |
| 16 Nov 08:55-10:47 | Blind series 2: 7 of 7 right. |
| 16 Nov 11:27-11:51 | Mystery control window installed (version 1.0) and tested; the stand-in test found a variable-name bug, fixed in version 1.1 at 11:49; 31 of 31 tests passed (Chapter 38.6). |
| 16 Nov 11:57 | Reveal grading added to fault.ps1 (backup fault.ps1.bak-20261116-115724). |
| 16 Nov 12:05-12:14 | Board version 12 and the workbook tile with the approved grading, after backups of board version 11 and the workbook to HV-HOST-02; checked on the board. |
| 16 Nov 12:18 | Switch file mystery-host.on created; mystery tests started; draw 1 with the PowerShell line. |
| 16 Nov 12:57-13:43 | The test runner stopped after draw 1: its own wait check read the status line 'fault active check: True' as a running fault. The check was corrected and the runner restarted at 13:42; nothing in the lab was affected. |
| 16 Nov 13:43-15:42 | Mystery draws 2 to 9 through the Mystery control window: 8 of 8 right; card 6 did not come up. |
| 16 Nov 15:49 | The lab owner approved up to six more draws, so that card 6 had more chances to come up. |
| 16 Nov 15:59-17:30 | Draws 10 to 15 (one-time task bg-myst16c, set to stop as soon as card 6 came up or after draw 15): 6 of 6 right; card 6 did not come up, so the runner stopped after draw 15 as approved. |
| 16 Nov 19:45-20:15 | Test alerts reviewed in the Portal (rg-appmon-openshift-demo, past 7 days): the 36 resolved alerts of 15 and 16 November with user response New were set to Closed, with a note. No alert was active; no alert rule or action group was changed. |
| 16 Nov 20:20 | Runbook v2.0 completed: Chapter 38.6 to 38.10, the status and readiness tables, the BE HONEST box of Scene 7C and the introduction now give the 15 mystery draws. |
| 16 Nov 21:11 | Card 6 session approved for 17 November from 07:00 WIB: up to 10 draws, stopping at the first card 6. |
| 17 Nov 08:09-08:48 | Card 6 session (one-time task bg-myst17): 3 draws, 3 of 3 right; card 6 came up in draw 18 and was named right as an early warning (Chapter 38.7). The runner stopped after card 6. |
| 17 Nov 11:45 | Alerts checked in rg-appmon-openshift-demo: the three draws fired no alert, so none had to be closed. The Look-ahead board of version 2.1 was checked the same morning (Chapter 39). |

Open items:

- Closed on 17 November 2026: card 6 came up in the card 6 session (draw 18) and the board named the host right, as an early warning (Chapter 38.7). All 18 mystery draws so far named the right layer.
- Error (599) on Kubernetes resources &gt; Workloads: fix deferred (Chapter 38.9); use Insights or the OpenShift web console in the demo.
- Update the table of contents in desktop Word: References &gt; Update Table &gt; Update entire table.
- The source pack v1.4 does not contain the version 1.7 to 2.1 scripts; they are on HV-HOST-02 in F:\Build\minibank\scripts and F:\Build\tools.
- Optional, later: a stronger VM fault card and a steadier impact line, so that the VM card affects customers in every run.
- The one-time tasks bg-live10, bg-mon10, bg-myst16, bg-myst16b, bg-myst16c and bg-myst17 are still registered on HV-HOST-02 but not running; remove them with step 5 of the undo table when they are no longer needed.

How to undo version 2.0, in this order (each step only if you want that part back):

| Step | What to do |
|---|---|
| 1 | Card 6 out of the mystery draw: delete C:\ProgramData\MiniBank\fault\mystery-host.on (the draw goes back to 1 to 5; series-host.on keeps card 6 in the blind series). |
| 2 | Mystery control window: delete F:\Build\minibank\scripts\mystery-window.ps1 and F:\Build\tools\mw-stub.ps1. The PowerShell lines need nothing else. |
| 3 | Reveal grading: copy F:\Build\minibank\scripts\fault.ps1.bak-20261116-115724 back to fault.ps1 (the option-B reveal of 15 November). |
| 4 | Board and workbook grading: restore version 11 of MiniBank - Cross-layer root cause in Grafana (version 10 also puts the host charts back into the scorecard section); put the workbook back with az rest --method put from F:\Build\tools\workbook-before-grading11-20261116-050329-before-item5.json.gz (unzip it first). |
| 5 | Test grading on the host: copy F:\Build\tools\sc10.ps1.bak-v2-20261115-225317 to sc10.ps1 and F:\Build\tools\mon10.ps1.bak-v1-20261115-225317 to mon10.ps1; remove the one-time tasks bg-live10, bg-mon10, bg-myst16, bg-myst16b, bg-myst16c and bg-myst17 if they are still there (Unregister-ScheduledTask &lt;name&gt; -Confirm:$false), and the card 6 runner F:\Build\tools\myst17.ps1 of 17 November. |
| 6 | Rules: put rules v2.9 back from F:\Build\tools\rc-fn29-body.json with the az rest command of Chapter 37.6. |
| 7 | Error (599): nothing to undo; the cluster-connect feature is on, as before. |

---

[&larr; 37. Host CPU contention on HV-HOST-02 (version 1.9)](37-host-cpu-contention-on-hv-host-02-version-1-9.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [39. Look-ahead: what will need attention next (version 2.1) &rarr;](39-look-ahead-what-will-need-attention-next-version-2-1.md)
