# 37. Host CPU contention on HV-HOST-02 (version 1.9)

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


Version 1.9 takes the cross-layer root-cause board one layer down, to the Hyper-V host HV-HOST-02 that runs every lab VM. A new fault card, cpu-host, starts a noisy-neighbour VM that competes with the lab VMs for the host's processors, and the board shows the host as the place where the trouble starts. The lab owner approved the design on 14 November 2026 at 16:16 WIB (plan A): host data, the noisy VM and the calibration tests on Saturday 14 November, the host rule and two blind test series on Sunday 15 November. Everything was built in rg-appmon-openshift-demo and on HV-HOST-02; the managed resource group MA_amw-appmon_indonesiacentral_managed was not changed.

## 37.1 Why a host problem is hard to see

Every lab VM runs on HV-HOST-02, which has 10 cores and 20 logical processors. When one VM takes more than its share, the other VMs wait for a processor: their requests get slower although their own CPU charts look normal, because a VM only sees the time it actually runs. The host's own Windows does not show it either. Task Manager and the Processor counter on HV-HOST-02 see only the host's own partition: in the tests below Windows on the host showed 3 to 5 % while the host's processors were 84 to 87 % busy. This is the Windows-view trap, and the board shows both numbers side by side so that the audience can see it.

Three measurements show the real picture. The first two come from the hypervisor through the Azure Monitor Agent on HV-HOST-02, the third is the standard Azure metric of the host VM:

| Signal | Counter or metric | Normal | With the 16-vCPU card |
|---|---|---|---|
| True host load | Hyper-V Hypervisor Logical Processor(_Total)\% Total Run Time, every 30 seconds | 27-44 % | 84-87 % |
| What Windows on the host sees | Processor(_Total)\% Processor Time | 2-5 % | 3-5 % |
| Waiting for a processor, per VM | Hyper-V Hypervisor Virtual Processor(\*)\CPU Wait Time Per Dispatch | about 15-30 µs | 100-200 µs, 5 to 11 times normal |
| Azure view of the host VM | Metric Percentage CPU of HV-HOST-02 | follows the true load | follows the true load |

## 37.2 What was added to the lab

| Item | What it is | How to undo |
|---|---|---|
| Host data | Azure Monitor Agent on HV-HOST-02 (extension AzureMonitorWindowsAgent 1.45), data collection rule dcr-minibank-hostperf and its association dcra-minibank-hostperf: five Hyper-V and processor counters every 30 seconds into law-appmon (table Perf, Computer HV-HOST-02). About 83 MB a day, under 1 % of the workspace daily cap of 10 GB. | Delete the association, then the data collection rule, then the extension (Chapter 37.8). |
| Noisy-neighbour VM BATCH-EOD | Windows Server 2022 Core on HV-HOST-02 in F:\VMs\BATCH-EOD: generation 2, 2 GB memory, no network adapter, automatic start Nothing, no checkpoints. A startup task runs C:\batch\eod.ps1, which keeps every vCPU busy for 7 minutes and then shuts the VM down. Version 2 of the load uses one C# spin thread per vCPU; version 1 is kept as eod.ps1.v1. | Stop-VM BATCH-EOD -TurnOff, Remove-VM BATCH-EOD, delete F:\VMs\BATCH-EOD. |
| Card cpu-host in fault.ps1 | The sixth card. It gives BATCH-EOD the number of vCPUs in C:\ProgramData\MiniBank\fault\cpu-host.txt (2 to 16; 16 since 14 November 18:20), starts it, checks within 120 seconds that it is busy and turns it off at the end of the slot. Every reset turns BATCH-EOD off first. The card runs labelled; it joins test series only when the file series-host.on exists and the mystery draw only when mystery-host.on exists (both in the same folder). | Copy F:\Build\minibank\scripts\fault.ps1.bak-20261114-165932 back to fault.ps1. |
| Guard task minibank-batch-guard | Runs every minute and at start-up on HV-HOST-02. It turns BATCH-EOD off after 540 seconds of uptime, or at once when an OpenShift node is not Ready or the OpenShift API does not answer. Log C:\BuildLog\batch-guard.log. | Unregister-ScheduledTask minibank-batch-guard. |
| Host on the board | MiniBankTopology version 2: a live host box, and VM and OpenShift node boxes that turn yellow when they wait for a processor. Two evidence panels at the bottom of MiniBank - Cross-layer root cause (board versions 7 and 8). | Grafana: restore board version 6. Log Analytics: put back MiniBankTopology version 1 (backup F:\Build\tools\topology-fn-before.json). |
| Host rule R9 (rules v2.9) | Written and replay-tested on 14 November; switched on 15 November only after three checks (Chapter 37.6). | Put back rules v2.8 (Chapter 37.6). |

## 37.3 Safety: three independent stops

The noisy VM is the only part of version 1.9 that can hurt the lab, because it competes with the OpenShift nodes for the same processors. It has no network adapter and never starts by itself, and three stops end it independently of each other:

- The guest: eod.ps1 stops the load after 7 minutes and shuts the VM down.
- The guard task on the host: after 540 seconds of uptime, or at the first OpenShift node that is not Ready, or when the OpenShift API stops answering, it turns the VM off.
- fault.ps1: during a slot it checks the nodes and the API every 15 seconds; two failed checks in a row end the card with SAFETY STOP. A labelled run is limited to 7 minutes, and .\fault.ps1 -Stop turns BATCH-EOD off at any time.

Both outer stops were proven before the first test. On 14 November at 17:00 the VM switched itself off after about 7 minutes without help, and at 17:08 a copy of the guard with a 60-second test limit turned it off after 76 seconds. In the seven tests that followed, the VM always stopped by itself, the guard never had to act and the three OpenShift nodes stayed Ready.

Hyper-V also protects OpenShift: the three OpenShift nodes have processor weight 200 and every other VM, BATCH-EOD included, has weight 100, so OpenShift is served first when processors are short.

## 37.4 Calibration tests (14 November 2026)

Seven labelled runs of 7 minutes found the strongest contention the host can show without putting OpenShift at risk. Customers' typical response (P75) is shown with its ratio to normal (131-146 ms that evening):

| Test (WIB) | Noisy VM | True load | Windows view | VMs waiting at least 3x | Customers (P75) | Live verdict (v2.8) |
|---|---|---|---|---|---|---|
| T1 17:13-17:20 | 8 vCPU, load v1 | 63-65 % | 3 % | 0 (max 2.1x) | 149-172 ms (1.1-1.3x) | Healthy |
| T2 17:23-17:30 | 12 vCPU, v1 | 72-73 % | 3-4 % | 1-3 (max 3.6x) | 178-194 ms (1.3-1.4x) | Healthy |
| T3 17:33-17:40 | 16 vCPU, v1 | 74-76 % | 3 % | 5-6 (max 5.8x) | 209-231 ms (1.5-1.7x) | Healthy |
| T4 17:46-17:53 | 12 vCPU, v2 | 77-79 % | not recorded | 0-2 (max 3.5x) | 181-200 ms (1.3-1.5x) | Healthy |
| T5 17:54-18:01 | 16 vCPU, v2 | 84-85 % | 3-5 % | all 6 (max 7.6x) | 239-253 ms (1.8x) | Healthy; Warning R8 at the start |
| T6 18:03-18:10 | 16 vCPU, v2, weight 200 | 86-87 % | 4 % | all 6 (max 7.1x) | 248-276 ms (1.8-2.0x) | Healthy |
| T7 18:28-18:35 | 16 vCPU, v2 (card setting) | 84-86 % | 3-4 % | all 6 (max 10.8x) | 233-269 ms (1.7-2.0x) | Healthy |

What the tests showed:

- This nested host never goes past about 87 % true load. Hyper-V's core scheduler gives a whole core to one VM at a time, so a second thread of a core can stay idle while other VMs wait.
- Load version 1, a PowerShell loop, kept only about 8 threads busy whatever the number of vCPUs. Version 2, C# spin threads, uses every vCPU it gets; it was copied into the VM's disk at 17:41 while the VM was off.
- Pure CPU contention made customers at most about 2 times slower. That is below the impact bar of the verdict (Chapter 32.1: typical response at least 2.5 times normal and 250 ms, slow tail at least 3 times normal and 400 ms, or more than 2 % failures). The honest answer for this card is therefore a yellow Warning that names the host, not a red root cause. A red Host answer appears only when one of the traffic generator's occasional slow minutes falls inside the slot.
- Raising BATCH-EOD to weight 200 (T6) added only about 5 % true load, and the next step would slow the OpenShift nodes first, so the calibration stopped there. The card uses 16 vCPU, load version 2 and weight 100; T7 repeated T5 with that setting and gave the same picture.
## 37.5 What the board shows

The Live topology map (Chapter 36) now has a live host box. Green reads, for example, OK · true load 29 % (Windows on the host shows 2 %) · 0 VMs waiting ≥ 3x. During the card it turns yellow: SIGNAL – host CPU busy · true load 85 % (Windows on the host shows 3-4 %) · 6 VMs waiting ≥ 3x · biggest: BATCH-EOD 11.0 of 20 logical processors. The VM and OpenShift node boxes turn yellow with WAITING FOR CPU and their ratio to normal, for example 3.7x. The host box turns red only when the verdict names the host.

Normal waiting is the quieter quarter (25th percentile) of the previous hour for each VM, so earlier contention in that hour does not raise the bar. The first version used the median and missed the waiting VMs after several tests in a row; it was corrected at 18:36 on 14 November and checked by replaying T7 (4 VMs waiting at 18:31, all 6 at 18:33).

Two panels give the evidence. Since board version 11 (15 November 2026) they sit at the top of the section Layer signals: Host, VM, OpenShift, network, application, database, above the VM, OpenShift and network charts; before that they were in the scorecard section at the bottom of the board. Host HV-HOST-02: true CPU load vs what Windows on the host shows draws the true load, the Windows view, BATCH-EOD's share of the 20 logical processors and the Azure metric Percentage CPU of HV-HOST-02. Host HV-HOST-02: CPU wait per dispatch by VM (µs) - how long each VM waits for a processor draws each VM's wait in microseconds. The host box opens the first panel. To read the same numbers yourself:

```kusto
MiniBankTopology(now(), 'show')
| project TimeGenerated, t_host
 
Perf
| where TimeGenerated > ago(30m) and Computer startswith 'HV-HOST-02'
| where ObjectName == 'Hyper-V Hypervisor Logical Processor' and CounterName == '% Total Run Time' and InstanceName == '_Total'
| summarize TrueLoad = round(avg(CounterValue), 0) by bin(TimeGenerated, 1m)
| order by TimeGenerated desc
```

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run. Run the two queries one at a time.

## 37.6 The host rule R9 (rules v2.9)

R9 names the host when the host's processors are really busy and the other VMs feel it. In the 6-minute look-back it needs at least two readings of the true load at 70 % or more, an average of 70 % or more from the first such reading, and at least 3 VMs other than the biggest consumer waiting at least 3 times their normal. It runs right after the database rule R1, so a database fault keeps its answer, and when the biggest consumer is APP-WIN, APP-SQL or APP-RHEL and the VM rule R4 already answers, R4 keeps the answer. The evidence line gives the true load, the Windows view, the waiting VMs and the biggest consumer. When customers are impacted and the host data of the last minutes has not arrived yet, the OpenShift, network and VM rules wait (Pending) instead of answering too early.

Before anything was saved, R9 was replayed read-only against the evening's tests and stored answers:

| What was replayed | Rules v2.8 (live) | Rules v2.9 (draft) |
|---|---|---|
| T2 and T7: the host was quiet before the test | Healthy | Warning naming the host from about 1.5 minutes after the start (T2 17:25, T7 18:30) until 1 to 2 minutes after the end |
| T3, T5 and T6: started 2 to 3 minutes after the previous test | Healthy (T5: Warning R8 twice) | Warning naming the host after 4 to 5 minutes; the previous test was still inside the 6-minute look-back |
| T4: only 0 to 2 VMs waiting | Healthy | Healthy: below the bar, as designed |
| Quiet windows 16:40-17:12, 18:12-18:27 and 18:39-18:48 | Healthy, Warning R8 | The same, except one reading at 18:12, one minute after T6 ended |
| The six stored answers of series 4 (network, VM, OpenShift, healthy, application, database) | As stored | Identical |

A blind test series keeps at least 9 quiet minutes between two faults (16-minute slots with 7-minute faults), so the slower naming after back-to-back tests does not occur there.

Rules v2.9 is switched on only when three checks pass: (1) the quiet night has no moment where R9 could fire, (2) the replays show no host answer outside a test except a short tail, and (3) the stored answers are unchanged. Checks 2 and 3 passed on Saturday evening and check 1 at 06:55 WIB on Sunday 15 November, so rules v2.9 was switched on at 06:58 WIB (Chapter 37.8). The switch backed up rules v2.8 first, in Cloud Shell and on HV-HOST-02 as F:\Build\tools\rc-fn28-body.json and as plain text F:\Build\tools\rc-fn28.kql, and then saved v2.9 in the function MiniBankRootCause in law-appmon.

To go back to rules v2.8, put the saved body back with one command. Copy F:\Build\tools\rc-fn28-body.json from HV-HOST-02 to your Cloud Shell home folder first (Manage files &gt; Upload); the body keeps the function's name, category and parameters:

```bash
az rest --method put --body @rc-fn28-body.json --url "https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-appmon-openshift-demo/providers/Microsoft.OperationalInsights/workspaces/law-appmon/savedSearches/minibank-rootcause?api-version=2020-08-01"
```

> [!NOTE]
> **Where to run it**
>
> Cloud Shell (Bash) in the Azure Portal, signed in to the lab subscription &lt;YOUR_SUBSCRIPTION_NAME&gt;, in the folder where you uploaded rc-fn28-body.json. Then run MiniBankRootCause() in law-appmon &gt; Logs once and check that it answers.

## 37.7 Card 6 in rehearsals and in the demo

Rehearse the card labelled. It needs no network change and undoes itself. Allow 10 minutes: the VM boots, loads the host for 7 minutes and shuts down by itself, and the verdict and the map show the host after about 2 minutes:

```powershell
.\fault.ps1 -Fault cpu-host -Minutes 7
```

> [!NOTE]
> **Where to run it**
>
> The presenter's window: Windows PowerShell as administrator on HV-HOST-02 in F:\Build\minibank\scripts.

Talk track: nothing is wrong inside any VM, and each VM's own CPU looks normal. The host is busy with an end-of-day batch VM. Windows on the host says 3 %, the hypervisor says 85 % and the Azure metric agrees with the hypervisor; every other VM waits 5 to 10 times longer for a processor. Customers are about two times slower but still inside the service level, so the board says Warning: Host in yellow instead of a red root cause. This is the early warning a capacity owner wants before an end-of-day batch hurts customers.

Card 6 joins the mystery draw only after two clean blind series that include it and a decision on how its yellow answer is scored. Both were in place on 15 November (Chapter 37.8), and the lab owner approved card 6 in mystery mode at 16:49 WIB that day, with series-host.on kept. The switch file mystery-host.on was created at 12:18 WIB on 16 November 2026, so the draw now has six numbers (Chapter 38.7); to take card 6 out of the draw again, delete C:\ProgramData\MiniBank\fault\mystery-host.on. Because series-host.on also stays, every blind series includes card 6 (7 slots, 112 minutes). If neither switch file exists, create series-host.on before a series that should include the card and delete it afterwards:

```powershell
New-Item C:\ProgramData\MiniBank\fault\series-host.on -ItemType File -Force
.\fault.ps1 -Series
# after the series:
Remove-Item C:\ProgramData\MiniBank\fault\series-host.on
```

> [!NOTE]
> **Where to run it**
>
> The presenter's window: Windows PowerShell as administrator on HV-HOST-02 in F:\Build\minibank\scripts. With the switch file a series has 7 slots of 16 minutes, 112 minutes in all.

Since 15 November 2026 (option B, Chapter 37.8) two readings in a row that name the Host, in yellow or red, count as the board's answer, and the approved grading of 16 November 2026 (Chapter 38.3) keeps this rule. A card 6 slot or draw that ends with a yellow Warning naming the host therefore shows RIGHT LAYER - early warning, and the column AnswerType says Warning (yellow).

## 37.8 Blind test results (15 November 2026)

Check 1 used the quiet night from 19:00 on 14 November to 06:50 on 15 November as the baseline. The true load of HV-HOST-02 never went above 51 % (95th percentile 33 %) and never reached 60 %, so there was no moment where R9 could fire. With rules v2.8 the board said Healthy 1,387 times and showed the yellow warning A few slow transactions (R8) 34 times, with no red, orange or Pending answer. All three checks had passed, so rules v2.9 was switched on at 06:58 WIB, after rules v2.8 had been backed up in Cloud Shell and on HV-HOST-02 and both copies had been checked. The first answers of v2.9 were as expected: the R8 warning that was showing at the moment of the switch, a Warning naming the host for test T7 and the VM answer for a stored VM case.

Two blind series of 7 slots then ran with the switch file series-host.on, so card 6 was in the draw: series 5 (S20261115-070448, 07:04 to 08:56 WIB) and series 6 (S20261115-085950, 08:59 to 10:51 WIB). Each series draws the cards in an order the observer does not know. Minutes are counted from the start of the slot to the second of two readings that agree, as in Chapter 35.1.

| Slot | Start (WIB) | Card | Expected | Board answer | Min. | Score: strict / option B |
|---|---|---|---|---|---|---|
| 5-1 | 07:04 | schema-oracle | Database | Database, red (R1) | 2.6 | Right / Right |
| 5-2 | 07:20 | net-rhel | Network | Network, red (R3) | 3.1 | Right / Right |
| 5-3 | 07:36 | nullref-api | Application | Application, red (R6) | 3.6 | Right / Right |
| 5-4 | 07:52 | oom-ocp | OpenShift | OpenShift, red (R2) | 2.6 | Right / Right |
| 5-5 | 08:08 | cpu-host | Host | Warning naming the host, yellow (R9) | 2.6 | No verdict / Right |
| 5-6 | 08:24 | cpu-win | VM | VM, red (R4) | 4.6 | Right / Right |
| 5-7 | 08:40 | none | Healthy | Healthy in every reading | - | No false alarm / No false alarm |
| 6-1 | 08:59 | cpu-win | VM | VM, red (R4) | 2.6 | Right / Right |
| 6-2 | 09:15 | none | Healthy | Healthy in every reading | - | No false alarm / No false alarm |
| 6-3 | 09:31 | cpu-host | Host | Warning naming the host, yellow (R9) | 2.6 | No verdict / Right |
| 6-4 | 09:47 | nullref-api | Application | Application, red (R6) | 3.6 | Right / Right |
| 6-5 | 10:03 | net-rhel | Network | Network, red (R3) | 2.6 | Right / Right |
| 6-6 | 10:19 | schema-oracle | Database | Database, red (R1) | 2.6 | Right / Right |
| 6-7 | 10:35 | oom-ocp | OpenShift | OpenShift, red (R2) | 2.6 | Right / Right |

Series 5 and series 6 each scored 6 of 7 on the strict score and 7 of 7 with option B. The only strict miss in each series is the card 6 slot, which by design ends with a yellow Warning naming the host (2.6 minutes in both series). No slot named a wrong layer, the host was never named outside the card 6 slots, and both Healthy slots stayed Healthy in every reading. Series 6 ended on schedule and its clean-up at 10:54 WIB ran every undo step; its score was read from the scorecard when the browser connection was back. Re-scored with option B, all 57 runs recorded since 13 November keep their result except these two card 6 slots.

Time to the answer in minutes, compared with series 4 of 14 November (rules v2.8):

| Card (expected answer) | Series 4 (v2.8) | Series 5 (v2.9) | Series 6 (v2.9) |
|---|---|---|---|
| schema-oracle (Database) | 2.1 | 2.6 | 2.6 |
| net-rhel (Network) | 3.1 | 3.1 | 2.6 |
| nullref-api (Application) | 3.1 | 3.6 | 3.6 |
| oom-ocp (OpenShift) | 3.1 | 2.6 | 2.6 |
| cpu-win (VM) | 2.2 | 4.6 | 2.6 |
| cpu-host (Host, yellow) | not in the draw | 2.6 | 2.6 |
| Average of the red answers | 2.7 | 3.3 | 2.8 |

Card 6 behaved as calibrated. About 2 minutes after BATCH-EOD started, the board named the host in yellow: Host CPU 82.0 % busy (true load; Windows on the host shows 4.0 %); 6 VMs wait for a processor. Customers were at most about two times slower, so the answer stayed a Warning and never turned red. It cleared about 2 minutes after the VM had stopped itself.

The host rule did not change any other answer: every other card got the same layer as in series 4. The VM card in series 5 was slower, 4.6 instead of 2.2 minutes, because the board waited about 1.5 minutes for the host data (Pending: Waiting for the HV-HOST-02 host CPU data to report past that time, so a host cause is not missed). The host data reaches law-appmon about a minute after it is measured, and the wait shows only when the VM signal comes before customers feel the slowdown; in the first slot of series 6 the same card was answered in under 3 minutes, without a wait. A refinement that stops waiting as soon as the latest host reading is clearly quiet would remove most of this delay. It is not built and needs approval.

A fault can still leave a short tail after it ends: in slot 5-2 the board showed one more red Network answer at 07:30, two minutes after the network fault had ended, from probe readings that arrived late. This is the after-fault effect that the recovery banner of Chapter 32.5 was added for.

> [!NOTE]
> **Decision: How Card 6 Is Scored (Option B, 15 November 2026)**
>
> the lab owner chose option B at 11:57 WIB on 15 November 2026: a yellow Warning naming the host, seen twice in a row, counts as the board's answer. It was built at 12:18 WIB in all three places that score an answer: the scorecard on the Grafana board (versions 9 and 10, with the new column AnswerType), the scorecard tile of the workbook and the mystery reveal in fault.ps1 on HV-HOST-02. Such a slot shows RIGHT LAYER - early warning. Every other yellow answer (a few slow transactions, a layer signal while customers are fine, the recovery tail) still never counts, and a host warning in another card's slot counts against the board as a wrong layer or a false alarm. Re-scored with the new rule, all 57 runs recorded since 13 November keep their result except the two card 6 slots. Card 6 joins the mystery draw only when the switch file C:\ProgramData\MiniBank\fault\mystery-host.on is created on HV-HOST-02; that needs a separate go, and the file has not been created.

## 37.9 Build record, lessons and undo

Version 1.9 adds two Azure items, the data collection rule and its association, plus the agent extension on HV-HOST-02. None of them has a charge of its own; the host data adds about 83 MB a day to law-appmon. BATCH-EOD uses host capacity only during a slot. The build on 14 and 15 November 2026 (15 November rows marked Sun):

| Time (WIB) | What happened |
|---|---|
| 16:16 | Plan A approved. |
| 16:36-16:43 | Azure Monitor Agent, data collection rule and association on HV-HOST-02; host data in law-appmon from 16:38:52. |
| 16:40-16:55 | BATCH-EOD built from the Windows Server 2022 media; the boot files were written with the image's own bcdboot after the host's version failed. |
| 16:59 | Card cpu-host added to fault.ps1 (backup fault.ps1.bak-20261114-165932) and the guard task registered. |
| 17:00-17:09 | Both outer stops proven. |
| 17:13-18:10 | Tests T1 to T6; load version 2 installed at 17:41. |
| 18:20 | Calibration stopped: weight back to 100, card setting 16 vCPU. |
| 18:21-18:36 | Host box and evidence panels on the board (board versions 7 and 8, MiniBankTopology version 2); normal waiting changed to the quieter quarter of the hour. |
| 18:28-18:35 | T7 at the card setting. |
| 18:44-18:56 | R9 replayed read-only against the tests, quiet windows and stored answers. |
| 18:52 | Pre-approved recovery for Error (599) on Kubernetes resources &gt; Workloads: the Arc cluster-connect agent was restarted; the page still showed the error afterwards (Chapter 21). |
| 19:17 | Health check passed: verdict Healthy since the last test, nodes Ready, BATCH-EOD off. Quiet night as the baseline. |
| Sun 06:55 | Check 1 passed: during the quiet night (19:00-06:50) the host never reached 60 %, and the board gave no red, orange or Pending answer. |
| Sun 06:58 | Rules v2.9 switched on in MiniBankRootCause; rules v2.8 backed up in Cloud Shell and on HV-HOST-02, both copies checked. |
| Sun 07:04-08:56 | Blind series 5 with card 6 in the draw (7 slots): 6 of 7 right on the strict score, 7 of 7 with option B. |
| Sun 08:59 | Blind series 6 started with card 6 in the draw (7 slots). The lab could not be reached from the browser after 09:35; the series ran on by itself. |
| Sun 10:51-10:54 | Series 6 finished: 6 of 7 right on the strict score, 7 of 7 with option B; the clean-up ran every undo step, BATCH-EOD off, bg-fault Ready. |
| Sun 11:57 | The lab owner chose option B for card 6: a yellow Warning naming the host, seen twice in a row, counts as the answer. |
| Sun 12:18-12:27 | Option B built after read-only checks and backups: Grafana board version 9 (scorecard query, column AnswerType, scoring note) and version 10 (column widths), the scorecard tile of the workbook, and the mystery reveal in fault.ps1 (backup fault.ps1.bak-20261115-121831). Board and workbook backups copied to F:\Build\tools on HV-HOST-02. |

Lessons for the next change:

- Do not trust the host's Task Manager for a Hyper-V host; read the hypervisor counters.
- Apply a Windows Server image with that image's own bcdboot.
- A PowerShell busy loop cannot keep many threads busy; use compiled spin threads for a CPU load.
- Compare waits with the quieter part of the previous hour, and leave at least 6 quiet minutes between two host tests.
- Azure run-command returns only the last 4 KB of output; filter long logs on the host before reading them.

How to undo version 1.9, in this order:

| Step | What to do |
|---|---|
| 1 | Scoring option B: restore version 8 of MiniBank - Cross-layer root cause in Grafana (versions 9 and 10 hold option B); put the workbook back with az rest --method put from F:\Build\tools\workbook-before-optionB-20261115-051819.json.gz (unzip it first); copy F:\Build\minibank\scripts\fault.ps1.bak-20261115-121831 back to fault.ps1. |
| 2 | Rules: if v2.9 was switched on, put rules v2.8 back (Chapter 37.6). |
| 3 | Delete the switch files series-host.on and mystery-host.on in C:\ProgramData\MiniBank\fault if they exist. |
| 4 | Run .\fault.ps1 -Stop, copy fault.ps1.bak-20261114-165932 back to fault.ps1 and run Unregister-ScheduledTask minibank-batch-guard -Confirm:$false. |
| 5 | Stop-VM BATCH-EOD -TurnOff -Force; Remove-VM BATCH-EOD -Force; Remove-Item F:\VMs\BATCH-EOD -Recurse. |
| 6 | Grafana: restore version 6 of MiniBank - Cross-layer root cause. Log Analytics: save MiniBankTopology version 1 from F:\Build\tools\topology-fn-before.json. |
| 7 | Azure: delete the association dcra-minibank-hostperf, the data collection rule dcr-minibank-hostperf and the extension AzureMonitorWindowsAgent of HV-HOST-02 (all in rg-appmon-openshift-demo). |

---

[&larr; 36. Live topology map (version 1.8)](36-live-topology-map-version-1-8.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [38. Version 2.0: the Mystery control window, the approved grading and the readiness tests &rarr;](38-version-2-0-the-mystery-control-window-the-approved-grading.md)
