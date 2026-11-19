# 26. Feature C - customer journeys and the browser robot

<sub>Part F - Priority 1 features (version 1.5) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 26.1 What the robot does

The browser robot (task minibank-robot on APP-WIN) plays 32 demo customers (24 Reguler, 6 Prioritas, 2 Solitaire; every customer except ANDI.WIJAYA) on the real MiniBank page with Microsoft Edge in headless mode: log in, home, transfer, QRIS or statement, confirm, PIN, receipt, log out. Each customer has its own browser profile, so Application Insights sees real users, sessions, page views and browser timings. The page sends a journey event minibank.journey at the start and at the end of each transfer, QRIS payment or statement (success, failed step, amount, trace ID).

| Mode | Pace | Content |
|---|---|---|
| Normal | 1 journey every 2 minutes | Transfer, QRIS and statement in turn (40/40/20 %), amounts by tier, 2 % of journeys with scenario slow-oracle, no failures |
| Incident window | 1 payment journey every 30 seconds, at most 2 browsers | Every 3rd journey carries the phase scenario; a fixed amount cycle that restarts with every phase |

## 26.2 Traffic-source labels

| Label | Who | How it is set |
|---|---|---|
| people | Real persons on the page (you, the audience) | Default of the web page |
| robot | The browser robot | The robot sets localStorage minibank.trafficSource = robot in its profiles and checks it before each journey |
| traffic | traffic.ps1 (continuous load and incident generator) | Header X-MiniBank-Source: traffic |
| probe | probe.ps1 (availability probe) | Header X-MiniBank-Source: probe |
| unknown | Anything without a valid label | API default; should stay near 0 |

## 26.3 The robot task on APP-WIN

| Item | Value |
|---|---|
| Task | minibank-robot: at startup (3-minute delay) and a watchdog every 15 minutes, restart after failure, no run-time limit |
| Runs as | APP-WIN\Administrator, logon type S4U (Run whether user is logged on or not, no password stored), highest privileges |
| Program | C:\tools\node-v24.22.2-win-x64\node.exe C:\Build\minibank\robot\robot.js (playwright-core, installed Microsoft Edge 157) |
| Log | C:\BuildLog\robot.log (one line per journey) |
| Profiles | C:\ProgramData\MiniBank\robot\profiles&lt;User ID&gt; |
| Incident note | C:\ProgramData\MiniBank\robot\incident.json, read every 30 seconds |

The robot does not run as SYSTEM: Microsoft Edge exits at once (exit code 1002) under the SYSTEM account, which the build found on 12 November 2026.

> [!NOTE]
> **Where to run it**
>
> APP-WIN - PowerShell Direct: in HV-HOST-02 - PowerShell (Admin) run Enter-PSSession -VMName APP-WIN -Credential (Get-Credential Administrator) (Chapter 5.6). The prompt starts with [APP-WIN]: PS. Type exit to return to the host.

```powershell
Disable-ScheduledTask minibank-robot; Stop-ScheduledTask minibank-robot      # pause
Enable-ScheduledTask minibank-robot; Start-ScheduledTask minibank-robot      # resume
Get-Content C:\BuildLog\robot.log -Tail 8                                  # last journeys
```

## 26.4 One incident command for Scenes 5 and 6

> [!NOTE]
> **Where to run it**
>
> HV-HOST-02, PowerShell as Administrator, folder F:\Build\minibank\scripts

```powershell
powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Scene 5    # slow-oracle 5 min, then fail-oracle 10 min
powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Scene 6    # fail-oracle 10 min
powershell -ExecutionPolicy Bypass -File .\incident.ps1 -Stop       # end early (robot back to normal within 30 s)
```

The command returns at once. It writes the incident note into APP-WIN (Hyper-V Copy-VMFile, so Guest Service Interface must stay enabled), and starts the traffic generator window(s) of the former Scene 6 command minimized (6 calls per minute with the scenario). Log: C:\BuildLog\incident.log and incident-traffic.log on the host, robot.log on APP-WIN.

In every fail-oracle phase the robot's 3rd, 6th, 9th, 12th, 15th and 18th journeys fail:

| Journey | Customer | Tier | Payment | Amount (IDR) |
|---|---|---|---|---|
| 3 | KEVIN.HALIM | Prioritas | Transfer | 25,000,000 |
| 6 | MELINDA.KUSNADI | Prioritas | Transfer | 60,000,000 |
| 9 | HARYANTO.TJAHJADI | Solitaire | Transfer | 150,000,000 |
| 12 | IWAN.KURNIAWAN | Reguler | QRIS | 85,000 |
| 15 | FAJAR.NUGROHO | Reguler | Transfer | 600,000 |
| 18 | ASEP.SURYANA | Reguler | Transfer | 5,000,000 |
| Total | 6 customers |   |   | 240,685,000 |

## 26.5 Alert alr-minibank-journey-success-low

Scope Application Insights appi-minibank; query on customEvents minibank.journey with stage end; fires when the journey success rate in 10 minutes is below 90 % and at least 2 journeys failed; every 5 minutes, severity 2, no action group. In a fail-oracle window 14 of 20 robot journeys succeed (70 %), so it fires after the 6th journey, about 3 minutes into the phase plus ingestion and evaluation time.

## 26.6 Checks

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; search box at the top: law-appmon &gt; open the Log Analytics workspace law-appmon &gt; Logs (left menu). Close the Queries hub if it opens. At the top right of the query window switch from Simple mode to KQL mode, paste the whole query into the query editor, leave Time range on Set in query and click Run.

```kusto
// E1 Traffic sources on minibank-api (last hour)
AppRequests
| where TimeGenerated > ago(1h) and AppRoleName == "minibank-api" and Name has "/api/"
| summarize Requests = sum(ItemCount), TechnicalFailures = sumif(ItemCount, toint(ResultCode) >= 500)
            by TrafficSource = tostring(Properties["minibank.trafficSource"])
| order by Requests desc
// E7 Customer journeys: success rate per 10 minutes by journey type and traffic source
AppEvents
| where TimeGenerated > ago(6h) and Name == "minibank.journey" and tostring(Properties["stage"]) == "end"
| summarize Journeys = sum(ItemCount), Failed = sumif(ItemCount, tostring(Properties["success"]) != "true")
            by bin(TimeGenerated, 10m), JourneyType = tostring(Properties["journeyType"]), TrafficSource = tostring(Properties["trafficSource"])
| extend SuccessPct = round(100.0 * (Journeys - Failed) / Journeys, 1)
| order by TimeGenerated desc
// E9 Failed journeys with the customer and the API trace ID
AppEvents
| where TimeGenerated > ago(24h) and Name == "minibank.journey" and tostring(Properties["stage"]) == "end"
      and tostring(Properties["success"]) != "true"
| project TimeGenerated, UserId = UserAuthenticatedId, JourneyType = tostring(Properties["journeyType"]),
          FailedStep = tostring(Properties["failedStep"]), AmountIdr = todouble(Properties["amountIdr"]),
          ErrorCode = tostring(Properties["errorCode"]), TraceId = tostring(Properties["traceId"])
| top 20 by TimeGenerated desc
```

The source pack v1.4 (monitoring/kql/minibank-queries.kql, section E) holds all ten queries E1-E10.

## 26.7 Rollback

| Change | Undo |
|---|---|
| Robot | APP-WIN - PowerShell Direct (Chapter 5.6): powershell -ExecutionPolicy Bypass -File C:\Build\minibank\robot\install-robot-task.ps1 -Remove (task removed, node and Edge stopped); optionally delete C:\ProgramData\MiniBank\robot |
| Journey alert | Cloud Shell - PowerShell, after the start block of Chapter 5.4: az monitor scheduled-query delete -g rg-appmon-openshift-demo -n alr-minibank-journey-success-low --yes |
| Host scripts | HV-HOST-02 - PowerShell (Admin) in F:\Build\minibank\scripts: Copy-Item traffic-v1.3.ps1 traffic.ps1 -Force; Copy-Item probe-v1.3.ps1 probe.ps1 -Force (the header is harmless, so this is optional); then restart both tasks with Stop-ScheduledTask and Start-ScheduledTask for minibank-traffic and minibank-probe |
| Slow share | HV-HOST-02 - PowerShell (Admin) in F:\Build\minibank\scripts: powershell -ExecutionPolicy Bypass -File .\install-traffic-tasks.ps1 -SlowPercent 6 restores the v1.3 value (not recommended: Transfer and QRIS P95 then stay above 1,000 ms) |

> [!WARNING]
> **If something goes wrong**
>
> robot.log shows result=error with step launch: check that the task runs as Administrator (S4U), not SYSTEM. robot.log shows self-check failed: the page label is not robot; delete that customer's profile folder and let the robot recreate it. The robot does not follow an incident: incident.log says note NOT copied; check that APP-WIN is running and Guest Service Interface is enabled (Get-VMIntegrationService -VMName APP-WIN).

---

[&larr; 25. Feature D - business impact in IDR](25-feature-d-business-impact-in-idr.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [27. Feature A - AI investigation with the Azure Copilot Observability Agent &rarr;](27-feature-a-ai-investigation-with-the-azure-copilot-observabil.md)
