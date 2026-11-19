# 29. Build record and lessons (12 November 2026)

<sub>Part F - Priority 1 features (version 1.5) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 29.1 Build timeline

| Time (WIB) | Step | Result |
|---|---|---|
| 15:06 | Build approved: all four features, changes only in rg-appmon-openshift-demo and MA_amw-appmon_indonesiacentral_managed (plus the agreed subscription setting for feature A) | - |
| 15:14-15:31 | Fresh etcd backup; Arc OIDC issuer and workload identity enabled; OpenShift service account issuer set | OK |
| 15:16 | Managed identity id-otelcol, data collection endpoint dce-otlp and rule for OTLP | OK |
| 15:26 | Images minibank-rates 1.0.0 (no agent) and minibank-transfer 1.2.0 built and pushed | OK |
| 15:44-15:49 | Collector test; gates G1 (OTLP ingestion in Indonesia Central) and G2 (workload identity, no secret) | Passed |
| 15:50-16:00 | Collector (2 replicas), Red Hat operator, instrumentation, minibank-rates deployed; etcd backup | OK |
| 16:10-16:13 | Gates G3 (Application Insights views on OTLP data) and G4 (one transaction across both agents) | Passed |
| 16:05-16:17 | Live onboarding rehearsed twice (28 s act, 20 s reset) | OK |
| 16:20 | Collector filter for health probes | OK |
| 16:24 | Background slow share 6 % to 2 % | OK |
| 16:29 | Subscription linked to amw-appmon for the Observability Agent | OK |
| 16:35-16:48 | Gate G5: first deep investigation on the Indonesia Central resources | Passed |
| 17:16 | Feature D database (tiers, customers, top-up) on APP-SQL; workbook group Business impact (IDR) | OK |
| 17:16-17:24 | API 1.2.0 and web page on APP-WIN: swap failed on a file lock, site down for about 7 minutes, fixed and swapped | OK after fix |
| 17:25 | Traffic generator, probe and incident command on HV-HOST-02 | OK |
| 17:27-17:41 | Robot on APP-WIN: Edge refused to run as SYSTEM; task changed to Administrator with an S4U logon | OK after fix |
| 17:43 | Alerts alr-minibank-failed-value-idr and alr-minibank-journey-success-low | OK |
| 17:43-17:58 | End-to-end rehearsal with incident.ps1 -Scene 5 (Chapter 29.3) | Passed |

## 29.2 What went differently from the plan

**1. API swap and a 7-minute outage (17:17-17:24 WIB).** Stop-WebAppPool reported Stopped while the worker process still held the API files; the copy failed (robocopy exit code 11), the automatic rollback hit the same lock and the pool stayed stopped, so the page returned HTTP 503. Fix: wait until the pool has no worker process (end it after about 100 seconds), then copy. Chapter 25.7 and the source pack now use this safe swap.

**2. Edge does not run as SYSTEM.** Edge 157 exits at once with code 1002 under the SYSTEM account, so the robot task runs as APP-WIN\Administrator with an S4U logon (no stored password, no desktop session needed). The installer in the source pack has the -RunAsUser parameter.

**3. The customer ID column.** enduser.id arrives in AppRequests.UserAuthenticatedId (user_AuthenticatedId in the classic schema), not in UserId. All queries and the workbook use UserAuthenticatedId.

**4. Small portal quirks seen in the investigation.** The investigation text calls the Arc-enabled OpenShift cluster AKS, and a chart axis labelled UTC shows WIB times. Neither changes the conclusion; mention it if the audience asks.

## 29.3 Rehearsal results (17:43-17:58 WIB)

| Check | Expected | Seen |
|---|---|---|
| Robot follows the incident note | Within 30 s | 4 s |
| Slow phase, every 3rd robot payment | About 2 s slower | KEVIN 7.3 s, MELINDA 7.5 s, HARYANTO 7.5 s (normal journeys 4.5-5.3 s) |
| Fail phase, robot failed payments | 6 customers, IDR 240,685,000 | 6 customers, IDR 240,685,000 (KEVIN, MELINDA, HARYANTO, IWAN, FAJAR, ASEP); every other journey succeeded |
| Generator failed payments | About 6 a minute | 6 failed payments a minute, IDR 8,009,000 in the first 7 minutes |
| alr-minibank-failure-rate-high | Fires in the fail phase | Fired 17:50:33 (2 min after the fail phase started) |
| alr-minibank-journey-success-low | Fires after 2 robot failures | Fired 17:53:11 |
| alr-minibank-failed-value-idr | Fires after IDR 100,000,000 failed | Fired 17:54:43, about 2 minutes after HARYANTO.TJAHJADI's IDR 150,000,000 payment failed |
| After the window | Robot back to one journey every 2 minutes, generator ok | Normal pace from 17:58:25; generator stopped; background traffic ok=30 a minute, no failures |

## 29.4 Lessons for the next change

- IIS: never trust Stop-WebAppPool alone. Wait for the WorkerProcesses list to be empty before copying, and treat a robocopy exit code of 8 or more as a failure.
- Browsers for robots: run them as a normal admin user with an S4U logon, not as SYSTEM.
- PowerShell: never use two variable names that differ only by case ($o and $O are the same variable); write "${name}:" before a colon; keep scripts in plain ASCII for Windows PowerShell 5.1.
- Run-command on HV-HOST-02 runs one call at a time and returns at most 4 KB: start long work as a scheduled task and read its log.
- Rename the collector exporter alias otlphttp to otlp_http at the next collector change (it still works but is deprecated).
- Renew the ACR push token before 17 November 2026 20:48 WIB if images must change after that; the pull token is valid until 10 December 2026.

Part G describes what was built and tested on 13 November 2026: one board that names the layer of an incident across the whole stack, a fault command with a blind mystery mode, a recovery banner, and an e-mail for every alert. Scene 7C (Chapter 19.10C) is the demo script; the chapters below are the reference to check, test, explain and remove it.

---

[&larr; 28. Demo scenes in version 1.5](28-demo-scenes-in-version-1-5.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [30. What version 1.7 adds &rarr;](30-what-version-1-7-adds.md)
