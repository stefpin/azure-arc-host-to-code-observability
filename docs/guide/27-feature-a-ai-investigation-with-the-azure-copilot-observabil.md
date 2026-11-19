# 27. Feature A - AI investigation with the Azure Copilot Observability Agent

<sub>Part F - Priority 1 features (version 1.5) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 27.1 Prerequisite: link the Azure Monitor workspace (done on 12 November 2026)

The Observability Agent reads the subscription setting that names its Azure Monitor workspace. This is a subscription-level setting, agreed as the only exception to the resource-group rule of this lab. No Observability Agent resource is created.

> [!NOTE]
> **Where to run it**
>
> Cloud Shell - Bash, as built on 12 November 2026 (settings.json was created in the Bash home folder). In Cloud Shell - PowerShell the same lines work only if the body file is quoted, --body '@settings.json', because @ is a special character in PowerShell. The setting is already in place: run these lines only to repeat or undo it.

```bash
az rest --method put --url "https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/providers/Microsoft.Monitor/settings/default?api-version=2025-06-03-preview" --body @settings.json
az rest --method delete --url "https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/providers/Microsoft.Monitor/settings/default?api-version=2025-06-03-preview"   # undo
```

settings.json holds {"properties":{"defaultAzureMonitorWorkspace":"&lt;resource ID of amw-appmon&gt;"}}. Check afterwards in Cloud Shell that no Observability Agent resource exists: az resource list --resource-type Microsoft.Monitor/observabilityAgents --query "length(@)" returns 0.

## 27.2 Start an investigation from an alert

> [!NOTE]
> **Where to run it**
>
> Azure Portal &gt; Monitor &gt; Alerts (the existing rules are scoped to law-appmon, the two new ones to appi-minibank; open the fired alert from Monitor &gt; Alerts, not from the Application Insights Alerts blade)

- Open the fired alert (for example alr-minibank-failure-rate-high or alr-minibank-failed-value-idr).
- Select Investigate. A temporary chat opens with the investigation plan (time window, the alert, the workspace and the related resources).
- Select Start investigation. The deep investigation runs for several minutes and ends with a summary, the supporting data and next steps.
- Do not select Create agent or Set up automatic investigation: they create a resource or run investigations without you, outside the plan and the budget.
## 27.3 What the first investigation found (gate G5, 12 November 2026)

The test incident was fail-oracle for 10 minutes. Without any hint, the agent named the root cause and the failure point: "minibank-transfer SQL failure caused minibank-api 502s". Its summary: 182 requests with 24 failures (13.19 %) on POST /api/\* between 09:29 and 09:39 UTC; a representative transaction showed minibank-api POST /api/transfer, the dependency call to minibank-transfer, SELECT COUNT(\*) FROM LEDGER_MISSING failing with BadSqlGrammarException, minibank-transfer returning 500 and minibank-api returning 502; the Oracle call failed 60 of 60 times while SQL Server (0 of 1,875) and the minibank-rates and minibank-fraud dependencies were healthy; the cluster arc-ocp-minibank showed no platform problem. Its next steps: correct the query, re-run the payments, review whether the fail-oracle path is intentionally exposed, keep an alert on SQL exceptions.

> [!CAUTION]
> **Be honest**
>
> The chart in the result is labelled UTC time but shows local times; the summary text uses UTC. The agent may call the Arc-enabled OpenShift cluster an AKS cluster in its wording. It also noticed the demo's scenario switch (fail-oracle): say that the fault was injected on purpose.

## 27.4 Budget and rules

| Item | Rule |
|---|---|
| Deep investigations | At most 5 in total: build test (used 12 November), rehearsal, morning backup run on the demo day, live, spare |
| Automatic investigation, Create agent | Not used |
| Region | AI processing runs in the agent's regions (not Southeast Asia); the telemetry stays in Indonesia Central |

---

[&larr; 26. Feature C - customer journeys and the browser robot](26-feature-c-customer-journeys-and-the-browser-robot.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [28. Demo scenes in version 1.5 &rarr;](28-demo-scenes-in-version-1-5.md)
