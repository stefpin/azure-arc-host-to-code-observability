# 33. The fault command fault.ps1 and mystery mode

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


fault.ps1 on HV-HOST-02 injects one realistic fault in one layer for a few minutes and undoes it by itself. Every fault runs with the same extra load, the browser robot at incident pace with the scenario normal and the traffic generator plus 6 calls a minute, so the load gives nothing away. It runs in the presenter's window: Windows PowerShell as administrator in F:\Build\minibank\scripts. Since version 2.0 the Mystery control window runs the mystery draw, the reveal, Status and Stop from buttons; it calls the same commands (Chapter 38.6).

## 33.1 The cards

| Card | Layer | What it does | How it is undone |
|---|---|---|---|
| cpu-win | VM | A scheduled task MiniBank Report Export on APP-WIN starts 16 busy PowerShell runspaces at AboveNormal priority | The task and its processes are stopped |
| oom-ocp | OpenShift | Every 100 seconds the memory of the three minibank-transfer containers is filled until they are OOMKilled (exit 137) | The rounds stop; OpenShift has already restarted the containers |
| net-rhel | Network | tc netem on APP-RHEL eth0: 250 ms delay (plus or minus 30 ms) and 3 % loss, only towards the OpenShift nodes and only for ports 1521, 5432 and 8082 | The root queue of eth0 goes back to mq; a systemd timer on APP-RHEL also removes the delay at the end time |
| nullref-api | Application | Writes the Statement preview switch file on APP-WIN with an end time | The file is removed; the end time also stops it |
| schema-oracle | Database | Renames MINIBANK.LEDGER_ENTRY to LEDGER_ENTRY_BAK | Renamed back; an Oracle scheduler job also renames it back at the end time |
| fail-oracle | Application | The extra load uses the generator scenario fail-oracle (the code queries LEDGER_MISSING); labelled runs only, never in the mystery pool | The extra load stops |
| cpu-host | Host (version 1.9) | Starts the noisy-neighbour VM BATCH-EOD on HV-HOST-02 with the vCPU count in C:\ProgramData\MiniBank\fault\cpu-host.txt (16) and keeps every vCPU busy; labelled runs, and test series only with the switch file series-host.on (Chapter 37) | BATCH-EOD is turned off; the VM also stops itself after 7 minutes, and the guard task turns it off after 540 seconds |
| none | - | Only the extra load: the healthy slot of a test series | - |

## 33.2 Commands

All commands run in the presenter's window. The Mystery control window (Chapter 38.6) runs the draw, the reveal, Status and Stop with buttons; the lines below stay the backup:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

| Command | What it does |
|---|---|
| .\fault.ps1 -Status | Shows the current or last run; during a mystery draw it does not show the card. The window's Status button runs it |
| .\fault.ps1 -Fault net-rhel -Minutes 5 | A labelled run (rehearsal) of the named card for 1 to 30 minutes (5 by default); the scorecard lists it as labelled |
| .\fault.ps1 -Mystery -Pick 3 | A blind draw for the bank's number from 1 to 6 (1 to 5 without the switch file mystery-host.on; without -Pick the number is random); prints the draw ID and the sealed fingerprint; the fault runs 8 minutes. The window's Start the draw button runs it |
| .\fault.ps1 -Reveal | Ends the fault of the draw, shows the card, recomputes the fingerprint, grades the board's answer with the approved grading (Chapter 38.3), prints the lines Customers and Board verdict and records the result. The window's Reveal the answer button runs it |
| .\fault.ps1 -Stop | Ends every fault now with all undo steps; safe at any time, also when nothing runs. The window's Stop every fault button runs it |
| .\fault.ps1 -Series | An unattended blind test series: the pool cards and one healthy slot in a random order, 16-minute slots with a 7-minute fault; 7 slots and 112 minutes while the switch file series-host.on or mystery-host.on adds card 6, otherwise 6 slots and 96 minutes |
| .\fault.ps1 -LeakCheck -Hours 6 | Searches the telemetry of the last hours for giveaway words; the traffic generator's own labels are listed apart |
| .\mystery-window.ps1 | Opens the Mystery control window (version 2.0, Chapter 38.6): The bank's number, Start the draw, the sealed fingerprint with Copy, Reveal the answer, Status and Stop every fault, each with a confirmation. It runs the commands of this table, which stay the backup |

Only one run can be active. A new run is refused while another run or the Scene 5 and 6 incident (incident.ps1) is active: wait, or use .\fault.ps1 -Stop (or incident.ps1 -Stop) first.

## 33.3 A labelled rehearsal

Use a labelled run to rehearse one card and its evidence.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
.\fault.ps1 -Fault net-rhel -Minutes 5
```

> [!TIP]
> **What you should see**
>
> labelled run L&lt;date-time&gt; started: net-rhel for 5 min (start-end WIB), the story of the card and Ends by itself at &lt;time&gt; WIB. On the board: Pending within about a minute, then RootCause Network about 3 minutes after the start. The undo runs by itself at the end time.

## 33.4 A mystery draw

The draw shuffles the pool cards behind the numbers with a cryptographic random generator: since 16 November 2026 the six cards cpu-win, oom-ocp, net-rhel, nullref-api, schema-oracle and cpu-host behind the numbers 1 to 6, because the switch file C:\ProgramData\MiniBank\fault\mystery-host.on exists (without it, the first five behind 1 to 5). It seals the plan, with a random salt, in C:\ProgramData\MiniBank\sealed, which only administrators can read. It prints a fingerprint: the first 16 hexadecimal characters of the SHA-256 hash of the draw ID, the number, the card and the salt. At the reveal the command computes it again from the sealed record; MATCH proves that the answer did not change after the draw. The verdict never reads the sealed folder or the ledger.

Within 90 seconds the command checks that the fault really took effect, for example the CPU of APP-WIN or the delay on APP-RHEL. If it did not, the draw is VOID: everything is reset, the VOID is recorded, and you ask the bank for a new number. The fault runs 8 minutes; the reveal ends it earlier.

The main way since version 2.0 is the Mystery control window (Chapter 38.6): press the bank's number, Start the draw, read the fingerprint, and press Reveal the answer when the board has answered. The lines below are the backup and do exactly the same:

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
.\fault.ps1 -Mystery -Pick 3
# when the board has answered:
.\fault.ps1 -Reveal
```

> [!TIP]
> **What you should see**
>
> At the draw: Draw M20261116-121858: number 3 is sealed. Sealed fingerprint: 32C8 C4EF 74FD 31EB (write it down; -Reveal recomputes it), The fault runs 8 minutes, until 12:27:03 WIB, then Fault is active. Watch the board. At the reveal: Draw M20261116-121858, number 3: Application: minibank-api Statement preview throws NullReferenceException; Expected layer: Application; the fingerprint shown at the draw and the one recomputed now with MATCH (answer unchanged); Customers: affected from 1 min after the start (two impact readings in a row) - the answer was due by 5 min; Board verdict: Application (red) - minibank-api at 12:22:30 WIB (3 min 27 s after the fault started) -&gt; RIGHT LAYER; ledger: 1 row(s) sent. The Mystery control window shows the same lines.

## 33.5 A blind test series

A series runs the five pool cards and one healthy slot in a random order, 16 minutes per slot with a 7-minute fault, 96 minutes in all. It runs by itself on HV-HOST-02 in a hidden runner process, so the window may be closed. The observer records the board, each slot is written to the ledger when it ends, and the scorecard compares the two. Run one series on the demo morning, at least 2 hours before the session, so that the scorecard shows today's results (the morning history).

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
.\fault.ps1 -Series
```

> [!TIP]
> **What you should see**
>
> series S&lt;date-time&gt; started: 6 slots x 16 min, fault 7 min each, and the time it ends. Read the result with the scorecard on the board, or with the query of Chapter 35.1, after the end time.

## 33.6 Same error, two causes: the labelled pair

schema-oracle and fail-oracle both make transfers fail with ORA-00942 (table or view does not exist) in minibank-transfer. In the first, a table was renamed in the database: the schema check proves it, so the board says Database. In the second, the code asks for a table that never existed: the schema is intact, so the new exception type is the cause and the board says Application. Run them as two labelled runs, 16 minutes apart, so that the scorecard shows both for Scene 7C.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
.\fault.ps1 -Fault schema-oracle -Minutes 7
# 16 minutes later:
.\fault.ps1 -Fault fail-oracle -Minutes 7
```

> [!TIP]
> **What you should see**
>
> Two labelled rows in the scorecard: schema-oracle with BoardLayer Database and fail-oracle with BoardLayer Application, both RIGHT LAYER (results of 13 November 2026 in Chapter 35.4).

## 33.7 The leak check

A blind draw is only blind if no telemetry names the card. The leak check searches the application, container, IIS, OpenTelemetry and snapshot tables of the last hours for the five card names and for the words mystery, fault.ps1, netem, report-export and statement-header. Since 13 November 2026 it lists the traffic generator's own random technical failures, labelled fail-oracle, fail-java, fail-python and fail-api (about 0.05 % of its calls), apart: they are expected, they are not cards in the pool, and they are not a leak.

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02 - PowerShell (Admin), the presenter's window: in the Bastion session, after the start block of Chapter 5.5, run Set-Location F:\Build\minibank\scripts so that the prompt is PS F:\Build\minibank\scripts&gt;. Paste the line and press Enter.

```powershell
.\fault.ps1 -LeakCheck -Hours 6
```

> [!TIP]
> **What you should see**
>
> Leak check (6 h): no giveaway word found in the telemetry. Then one line that starts with Background traffic labels (traffic generator, expected; not a giveaway), or says none in this period.

## 33.8 Safety: automatic undo, watchdog and Stop

- Every card ends by itself at its end time; the runner then runs every undo step.
- The scheduled task minibank-fault-watchdog runs fault.ps1 -Stop 2 minutes after the planned end, in case the runner stopped.
- net-rhel and schema-oracle also carry their own undo on APP-RHEL, a systemd timer and an Oracle scheduler job, which work even when HV-HOST-02 cannot reach APP-RHEL.
- .\fault.ps1 -Stop runs every undo step at once and is safe at any time.
- The faults never change Azure resources, alert rules or the verdict function.

---

[&larr; 32. The verdict, the observer, the board and the recovery banner](32-the-verdict-the-observer-the-board-and-the-recovery-banner.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [34. Alert e-mails &rarr;](34-alert-e-mails.md)
