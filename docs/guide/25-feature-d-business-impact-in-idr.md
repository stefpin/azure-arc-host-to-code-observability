# 25. Feature D - business impact in IDR

<sub>Part F - Priority 1 features (version 1.5) &nbsp;|&nbsp; [Guide index](README.md)</sub>


## 25.1 What changed

The API (minibank-api 1.2.0) tags every payment with the customer, the tier, the channel, the amount in rupiah, an amount band and the outcome. The database gives every customer a tier and holds 30 more customers, so a failure has a realistic spread of customers and amounts. A new workbook group counts failed payments in IDR, and the alert alr-minibank-failed-value-idr fires when failed payments are worth IDR 100,000,000 or more in 10 minutes. Technical failures (HTTP 5xx) count; business declines such as Insufficient balance (HTTP 409) do not.

## 25.2 Customers and tiers

| Tier | Customers | Accounts | Tabungan balance (top-up target) |
|---|---|---|---|
| Reguler | 24 (all new) | 48 | IDR 35-75 million (Giro 25-46 million) |
| Prioritas | 7 (ANDI.WIJAYA, SITI.RAHAYU, BUDI.SANTOSO and 4 new) | 14 | IDR 0.9-1.2 billion (Giro 15-46 million) |
| Solitaire | 2 (new) | 4 | IDR 9-12.2 billion (Giro 50-101 million) |

ANDI, SITI and BUDI are Prioritas because the continuous traffic generator logs them in and pays about IDR 100 million per customer per hour to the other 63 accounts; a Prioritas balance lasts about 10 hours between the 6-hourly top-ups (00:00, 06:00, 12:00, 18:00 WIB). The top-up now sets all 66 accounts to their tier balance (view dbo.DemoBalanceTargets). After the build: ANDI Tabungan IDR 974,625,000, SITI 1,049,250,000, BUDI 1,111,375,000. ANDI.WIJAYA is the presenter's customer: the robot never uses it.

## 25.3 Telemetry tags

| Tag (Application Insights) | Meaning |
|---|---|
| minibank.trafficSource | people, robot, traffic, probe or unknown (Chapter 26.2) |
| user_AuthenticatedId (AppRequests.UserAuthenticatedId) | User ID of the logged-in customer (set as enduser.id; it lands in the authenticated-user column, not in user_Id) |
| minibank.userId, minibank.tier | User ID and tier (also on a failed login) |
| minibank.channel | transfer or qris |
| minibank.amountIdr, minibank.amountBand | Amount in rupiah and its band (for example &lt;1M, 1-10M, 10-100M, &gt;=100M) |
| minibank.outcome | success, declined or failed |

Account numbers stay masked; no password or PIN is ever tagged.

## 25.4 Workbook group Business impact (IDR)

Workbook MiniBank - SLA and Failure Rate (Application Insights appi-minibank &gt; Workbooks) has a new group at the end: four tiles (failed value in the time range, failed value in the last 10 minutes with the alert threshold, customers affected, failed payments), tables by tier, by amount band and by traffic source, a 5-minute chart by tier, and the latest failed payments with User ID, tier, channel, amount and trace ID. The 11 items above it are unchanged. With no incident the IDR tiles show 0.

## 25.5 Alert alr-minibank-failed-value-idr

| Setting | Value |
|---|---|
| Scope | Application Insights appi-minibank (region indonesiacentral) |
| Query | requests of minibank-api, Transfer and QRIS, resultCode 500 or above, measure = amountIdr x itemCount, aggregation Total |
| Threshold | Greater than or equal to IDR 100,000,000 |
| Evaluation | Every 5 minutes over 10 minutes, severity 2, auto-resolve, no action group |
| Tags | demo=minibank, owner=labadmin, purpose=appmon-openshift-demo, &lt;EXEMPT_TAG&gt;=&lt;EXEMPT_VALUE&gt; |

In an incident the robot's failed payments alone are worth IDR 240,685,000 (Chapter 26.4); the threshold is crossed when HARYANTO.TJAHJADI's IDR 150,000,000 transfer fails, about 4 minutes into the failure phase. The generator's own failures add only about IDR 11 million per 10 minutes, so without the robot this alert would not fire.

## 25.6 Checks

> [!NOTE]
> **Where to run it**
>
> Log Analytics workspace law-appmon &gt; Logs (time range set in the query)

```kusto
// E2 Failed payment value in IDR (5xx of Transfer and QRIS), last 10 minutes and last hour
AppRequests
| where TimeGenerated > ago(1h) and AppRoleName == "minibank-api" and (Name endswith "/api/transfer" or Name endswith "/api/qris/pay")
| where toint(ResultCode) >= 500
| extend AmountIdr = todouble(Properties["minibank.amountIdr"]), UserId = tostring(Properties["minibank.userId"])
| summarize FailedValueIdr1h = sum(AmountIdr * ItemCount), FailedValueIdr10m = sumif(AmountIdr * ItemCount, TimeGenerated > ago(10m)),
            FailedPayments1h = sum(ItemCount), CustomersAffected1h = dcountif(UserId, isnotempty(UserId))
// E4 Latest failed payments with User ID, tier, channel, amount and trace ID
AppRequests
| where TimeGenerated > ago(24h) and AppRoleName == "minibank-api" and (Name endswith "/api/transfer" or Name endswith "/api/qris/pay")
| where toint(ResultCode) >= 500
| project TimeGenerated, UserId = tostring(Properties["minibank.userId"]), Tier = tostring(Properties["minibank.tier"]),
          Channel = tostring(Properties["minibank.channel"]), AmountIdr = todouble(Properties["minibank.amountIdr"]),
          TrafficSource = tostring(Properties["minibank.trafficSource"]), ResultCode, TraceId = OperationId
| top 20 by TimeGenerated desc
// E6 Payment outcomes by tier (last hour): success, declined (409), failed (5xx)
AppRequests
| where TimeGenerated > ago(1h) and AppRoleName == "minibank-api" and isnotempty(tostring(Properties["minibank.channel"]))
| summarize Payments = sum(ItemCount), ValueIdr = sum(todouble(Properties["minibank.amountIdr"]) * ItemCount)
            by Tier = tostring(Properties["minibank.tier"]), Outcome = tostring(Properties["minibank.outcome"])
| order by Tier asc, Outcome asc
```

## 25.7 Rollback

| Change | Undo |
|---|---|
| Alert | Cloud Shell - PowerShell, after the start block of Chapter 5.4: az monitor scheduled-query delete -g rg-appmon-openshift-demo -n alr-minibank-failed-value-idr --yes |
| Workbook group | Azure Portal &gt; appi-minibank &gt; Workbooks (left menu, under Monitoring) &gt; MiniBank - SLA and Failure Rate &gt; Edit &gt; Advanced Editor (&lt;/&gt;): paste the saved workbook-before-p1 JSON, or remove the item business-impact-idr; then Apply, Done Editing and Save |
| API and web 1.2.0 | APP-WIN - PowerShell Direct (Chapter 5.6): Stop-WebAppPool minibank, wait until IIS:\AppPools\minibank\WorkerProcesses is empty, robocopy C:\inetpub\minibank-api-v1.3 C:\inetpub\minibank-api /E, Start-WebAppPool minibank (health shows 1.1.0) |
| Tiers and customers | Remove the robot first (Chapter 26.7). Then, in APP-SQL - PowerShell Direct, run the undo SQL of P1-DC-DEPLOY.md (source pack v1.4) with the helper Invoke-SqlFile of Chapter 14.1, or restore MiniBankDemo-before-p1.bak |

> [!WARNING]
> **If something goes wrong**
>
> IIS answers 503 Service Unavailable after an API update: the application pool is stopped. Run Start-WebAppPool minibank in APP-WIN - PowerShell Direct (Chapter 5.6). Never copy files into C:\inetpub\minibank-api right after Stop-WebAppPool: the pool reports Stopped at once while its worker process still holds the files for up to 90 seconds. In the build this left the API down for about 8 minutes (12 November 2026, 17:17-17:24 WIB).

---

[&larr; 24. Feature B - onboard a service with no code change](24-feature-b-onboard-a-service-with-no-code-change.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [26. Feature C - customer journeys and the browser robot &rarr;](26-feature-c-customer-journeys-and-the-browser-robot.md)
