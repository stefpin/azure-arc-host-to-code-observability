# Build helpers

Stand-alone copies of the panels and queries added last to the Grafana boards, so you can study or reuse one feature without importing a whole board. The complete boards, functions and rules are in [lab-export](../lab-export/).

| File | What it is |
|---|---|
| [lookahead-functions.kql](lookahead-functions.kql) | The eight saved KQL functions behind the look-ahead register, forecast and score (Chapter 39). |
| [lookahead-trail-query.kql](lookahead-trail-query.kql) | Query of the look-ahead trail panel, with the fast-forward date (Chapter 43). |
| [lookahead-trail-panel.json](lookahead-trail-panel.json) | Grafana Canvas panel of the trail (Chapter 43). |
| [lookahead-month-query.kql](lookahead-month-query.kql) | Query of the Outlook-style month view (Chapter 43). |
| [lookahead-month-panel.json](lookahead-month-panel.json) | Grafana Canvas panel of the month view (Chapter 43). |
| [lookahead-setting-fast-forward.json](lookahead-setting-fast-forward.json) | The board variable "Look ahead to" that drives fast-forward (Chapter 43). |
| [sla-service-weather-query.kql](sla-service-weather-query.kql) | Query of the service weather strip on the SLA board (Chapter 41). |
| [sla-service-weather-panel.json](sla-service-weather-panel.json) | Grafana Canvas panel of the service weather (Chapter 41). |
| [topology-function.kql](topology-function.kql) | The function behind the live topology map on the root-cause board (Chapter 36). |

To add a panel to a board: open the board in Grafana, **Edit** > **Add** > **Visualization**, then the panel menu > **Inspect** > **Panel JSON**, paste the JSON and **Apply**. Replace the data source and the workspace placeholders with your own.
