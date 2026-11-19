# 34. Alert e-mails

<sub>Part G - Cross-layer root cause and mystery mode (version 1.7) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 34.1 What was set up

On 13 November 2026 at 22:32 WIB the action group ag-appmon-email (short name appmon, location Global, in rg-appmon-openshift-demo) was created with one e-mail receiver, alerts@example.com, using the common alert schema. It is attached to every alert rule of the lab:

| Alert rule | Type | Severity | Fires when (Chapter 17 has the details) |
|---|---|---|---|
| alr-minibank-failure-rate-high | Log search alert | 2 | Technical failures (HTTP 5xx) of the business transactions are too high |
| alr-minibank-journey-success-low | Log search alert | 2 | Fewer than 90 % of the robot journeys succeed, with at least 2 failures in 10 minutes |
| alr-minibank-failed-value-idr | Log search alert | 2 | Failed payments are worth more than IDR 100,000,000 |
| alr-minibank-decline-spike | Log search alert | 3 | More than 10 business declines (HTTP 409) |
| alr-ocp-node-not-ready | Log search alert | 1 | An OpenShift node is not Ready (Scene 9) |
| Failure Anomalies - appi-minibank | Smart detection | - | An unusual failure rate in Application Insights; it keeps its Application Insights Smart Detection action group as well |

The three Prometheus rule groups of the cluster hold recording rules only and send no alerts, so they need no action group. The five log alerts resolve by themselves, so each alert sends two e-mails: one when it fires and one when it resolves. Closing an alert sends none.

## 34.2 What the e-mail looks like and how many to expect

The sender is Microsoft Azure (azure-noreply@microsoft.com). The subject names the state, the severity, the rule, the resource and the time in UTC, for example: Fired:Sev2 Azure Monitor Alert alr-minibank-failure-rate-high on law-appmon ( microsoft.operationalinsights/workspaces ) at 11/13/2026 3:40:37 PM. The first real alert e-mails arrived 10 to 17 seconds after the alerts fired, at 22:40, 22:43 and 22:44 WIB on 13 November 2026, during the labelled schema-oracle run. Expect a few alerts, and twice as many e-mails, for each fault that hurts customers: a rehearsal day or a test series sends dozens of e-mails.

## 34.3 Test, mute and undo

Test: Azure Portal &gt; search box: Monitor &gt; Alerts &gt; Action groups (top menu) &gt; ag-appmon-email &gt; Test action group. Choose a sample type, for example Log search alerts V2, tick the e-mail action and select Test. A Delivery Confirmation e-mail arrives within a minute; the first test arrived on 13 November 2026 at 22:37 WIB.

Mute during a rehearsal (optional, not set up): Azure Portal &gt; Monitor &gt; Alerts &gt; Alert processing rules &gt; Create, scope rg-appmon-openshift-demo, rule type Suppress notifications, with a schedule for the rehearsal. The alerts still fire and show in the Portal; only the e-mails stop.

Undo: Azure Portal &gt; Monitor &gt; Alerts &gt; Alert rules, open each rule of the table above &gt; Edit &gt; Actions, remove ag-appmon-email and select Save (for Failure Anomalies - appi-minibank keep the Application Insights Smart Detection group). Then Monitor &gt; Alerts &gt; Action groups &gt; ag-appmon-email &gt; Delete.

---

[&larr; 33. The fault command fault.ps1 and mystery mode](33-the-fault-command-fault-ps1-and-mystery-mode.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [35. Test results and readiness (13 November 2026) &rarr;](35-test-results-and-readiness-13-november-2026.md)
