# MANIFEST – MiniBank source pack v1.4 (P1 build)

Root folder `minibank/`. Demo only, synthetic data. Machines: APP-WIN 192.168.110.31, APP-RHEL 192.168.110.32,
APP-SQL 192.168.110.33, OpenShift `ocp-minibank` (project `minibank`), HV-HOST-02 (traffic/probe, `az`, `oc`).
Pack unpacked to C:\Build\minibank (APP-WIN, APP-SQL), F:\Build\minibank (HV-HOST-02), ~/minibank (APP-RHEL, Cloud Shell).
Commands for each step are in section 2. `ACR_NAME` = your Azure Container Registry name. Every placeholder outside `*.example`
(`ACR_NAME`, `APPI_ID` and the four collector values of feature B) is listed in section 0b.

## 0. v1.4 (P1 build): new and changed files (features C customer journey + browser robot, D business impact in IDR)

Deploy steps per machine with a rollback note for each step: `P1-DC-DEPLOY.md` (next to this pack folder). Order: APP-SQL
migration + top-up, APP-WIN API + web, APP-WIN robot, HV-HOST-02 scripts + traffic task argument, Azure workbook + alerts.

| File | New / changed | What changed |
|---|---|---|
| db/sqlserver/02-p1-tiers-customers.sql | new | column Customers.Tier, view dbo.DemoBalanceTargets, 30 more customers (33: Reguler 24, Prioritas 7, Solitaire 2), 60 more accounts |
| scripts/topup-demo-balances.sql | changed | all 66 accounts to their tier balance (view dbo.DemoBalanceTargets) instead of 6 listed accounts |
| scripts/topup-demo-balances.ps1 | changed | log line per tier (accounts, total before -> after) + the 6 generator accounts |
| scripts/reset-demo-balances.sql | changed | all accounts to their tier balance (same values as the top-up) |
| scripts/install-topup-task.ps1 | changed | description text only (task action unchanged) |
| api/Program.cs | changed | version 1.2.0; request tags minibank.trafficSource (header X-MiniBank-Source), minibank.userId, minibank.tier, enduser.id; on Transfer/QRIS minibank.channel, minibank.amountIdr, minibank.amountBand, minibank.outcome (set before the call to minibank-transfer); in-memory customer directory from SQL Server |
| api/MiniBank.Api.csproj | changed | version 1.2.0 |
| web/package.json | changed | version 1.2.0 |
| web/src/api.js | changed | header X-MiniBank-Source on every API call (localStorage minibank.trafficSource = robot, else people) |
| web/src/telemetry.js | changed | trafficSource on every browser item, header on GET /api/config, User ID as authenticated user, window.__minibankFlush, journey events minibank.journey |
| web/src/App.jsx | changed | authenticated user set after login and cleared at logout; footer 1.2.0 |
| web/src/screens/Transfer.jsx, Qris.jsx, Statement.jsx | changed | journey start/end events; data-testid attributes for the robot |
| web/src/screens/Login.jsx, Home.jsx, Receipt.jsx | changed | data-testid / data-status attributes for the robot (additive) |
| web/src/components/Header.jsx, DemoBanner.jsx, MenuGrid.jsx, PinPad.jsx, AmountInput.jsx | changed | data-testid attributes for the robot (additive) |
| robot/package.json, robot/package-lock.json | new | minibank-robot, playwright-core 1.64.1 (exact), Node.js 24 |
| robot/robot.js | new | browser robot: Edge headless, one profile per customer, normal pace + incident windows, log C:\BuildLog\robot.log |
| robot/customers.json | new | the 32 robot customers (everyone except ANDI.WIJAYA) with tier, round-robin order |
| robot/install-robot-task.ps1 | new | scheduled task minibank-robot (local Administrator, logon type S4U, not SYSTEM: Edge exits with code 1002 under SYSTEM; boot + watchdog, restart on failure); -Remove |
| robot/incident.example.json | new | example of the incident note format |
| scripts/incident.ps1 | new | HV-HOST-02: -Scene 5 / -Scene 6 / -Stop: incident note into APP-WIN (Copy-VMFile) + generator windows |
| scripts/traffic.ps1 | changed | header X-MiniBank-Source: traffic only |
| scripts/probe.ps1 | changed | header X-MiniBank-Source: probe only |
| monitoring/workbook/minibank-sla-workbook.json | changed | new group "Business impact (IDR)" at the end; existing items unchanged |
| monitoring/alerts/minibank-p1-alerts.json, .parameters.json | new | ARM template + parameter file (APPI_ID) for the two new alert rules |
| monitoring/alerts/create-p1-alerts.ps1 | new | deploys the template (Cloud Shell PowerShell), undo commands |
| monitoring/alerts/alr-minibank-failed-value-idr.kql, alr-minibank-journey-success-low.kql | new | the alert queries (Application Insights and Log Analytics schema) |
| monitoring/kql/minibank-queries.kql | changed | new section E1-E10 (business impact, traffic sources, journeys) |
| README.md, MANIFEST.md | changed | v1.4 notes |

## 0b. v1.4 feature B: new and changed files (zero-code OpenShift onboarding with the Red Hat build of OpenTelemetry)

Built and verified in the lab on 12 Nov 2026 (gates G1-G4). Deploy steps with a check and a rollback for each step: `P1-B-DEPLOY.md`
(next to this pack folder). Order: Arc workload identity + OpenShift service account issuer, Azure identity + DCE/DCR, images
(APP-RHEL, podman), collector, operator + Instrumentation, minibank-rates + copy, minibank-transfer 1.2.0, gates, Scene 2 live act.
New on OpenShift: namespace `minibank-otel` (collector `otelcol`), namespace `openshift-opentelemetry-operator` (operator), and in project
`minibank` the Instrumentation `minibank-java` and the Deployments `minibank-rates` (onboarded) and `minibank-rates-copy` (not onboarded).
In Application Insights the OpenTelemetry role name is `[namespace]/service`, for example `[minibank]/minibank-rates`.

| File | New / changed | Purpose |
|---|---|---|
| rates/pom.xml | new | minibank-rates 1.0.0: Java 21, Spring Boot 3.5.6 (web, actuator); NO monitoring library |
| rates/Dockerfile | new | ubi9/openjdk-21 build -> openjdk-21-runtime, USER 185; NO agent in the image (the operator injects it at deploy time); podman build on APP-RHEL |
| rates/src/main/java/id/minibank/rates/RatesApplication.java | new | Spring Boot main class, no monitoring code |
| rates/src/main/java/id/minibank/rates/RatesController.java | new | GET /api/rates/check?channel=TRANSFER or QRIS&amount=..: fee (0 in this demo rule set) and per-transaction limit (TRANSFER IDR 500 million, QRIS IDR 10 million), rule set MINIBANK-2026-11; no account numbers |
| rates/src/main/resources/application.properties | new | port 8080, health probes; no monitoring settings |
| transfer/src/main/java/id/minibank/transfer/RatesClient.java | new | calls minibank-rates (connect 1 s, read 2 s); on any error the fallback rate (rule set FALLBACK), so a rates problem never fails a payment |
| transfer/src/main/java/id/minibank/transfer/TransferController.java | changed | rates check before the fraud check on Transfer and QRIS; the booking log line adds fee and rule set |
| transfer/src/main/resources/application.properties | changed | rates.url = RATES_URL, default http://minibank-rates.minibank.svc.cluster.local:8080 |
| transfer/pom.xml | changed | version 1.2.0 |
| transfer/Dockerfile | changed | comments only: image 1.2.0, built with podman (ACR Tasks are not available in Indonesia Central) |
| openshift/p1/00-otel-operator.yaml | new | Namespace, OperatorGroup and Subscription opentelemetry-product (redhat-operators, channel stable, installPlanApproval Manual) |
| openshift/p1/installplan-approve.json | new | merge patch that approves the operator's InstallPlan |
| openshift/p1/10-otelcol.yaml.tpl | new | collector in namespace minibank-otel: ServiceAccount otelcol (workload identity client ID, pull secret acr-pull), ConfigMap (OTLP receiver, memory_limiter, filter/health, batch, otlphttp exporter with azure_auth workload identity), Deployment otelcol (contrib 0.164.0, 2 replicas), Service 4317/4318, PodDisruptionBudget; 5 placeholders (table below) |
| openshift/p1/20-instrumentation.yaml | new | Instrumentation minibank-java (project minibank): exporter http://otelcol.minibank-otel.svc.cluster.local:4318, tracecontext + baggage, parentbased_always_on, delta temporality; the agent image is set to the ACR mirror in P1-B-DEPLOY.md Step 5 |
| openshift/p1/30-rates.yaml | new | minibank-rates: Deployment (2 replicas, pod annotation instrumentation.opentelemetry.io/inject-java: "true", JAVA_TOOL_OPTIONS -XX:MaxRAMPercentage=50), Service 8080, PodDisruptionBudget |
| openshift/p1/40-rates-copy.yaml | new | minibank-rates-copy: same image, 1 replica, NOT onboarded; Service + Route minibank-rates-copy.apps.ocp-minibank.minibank-demo.lab |
| openshift/p1/onboard-patch.yaml | new | the one-annotation merge patch of the live onboarding |
| openshift/p1/onboard-remove.json | new | JSON patch that removes the annotation again (reset) |
| scripts/onboard-live.ps1 | new | HV-HOST-02, Scene 2 live act (about 28 s): BEFORE, patch, AFTER (same image digest), 3 test calls through the Route |
| scripts/onboard-reset.ps1 | new | HV-HOST-02, reset after a session or rehearsal (about 20 s): annotation removed, new pod without the agent |
| README.md, MANIFEST.md | changed | README: short v1.4 note; MANIFEST: this section, placeholder line, feature B rows in sections 1-4, robot task account (local Administrator, S4U) |

Unchanged in `transfer/` (same as v1.3): applicationinsights.json, FraudClient.java, LedgerRepository.java, ScenarioException.java,
TransferApplication.java. `openshift/10-deployment.yaml` still names minibank-transfer:1.1.0: the lab moved to 1.2.0 with `oc set image`
(P1-B-DEPLOY.md Step 7); change the tag before you apply that file again.

Placeholders (none of them is a secret; the filled-in copies stay on the lab hosts, for example `F:\Build\minibank\openshift\p1\rendered\`):

| Placeholder | In file | Value | Where to get it |
|---|---|---|---|
| ACR_NAME | openshift/10-deployment.yaml, openshift/p1/10-otelcol.yaml.tpl, openshift/p1/30-rates.yaml, openshift/p1/40-rates-copy.yaml (in comments: transfer/Dockerfile, rates/Dockerfile) | registry name without .azurecr.io | your ACR |
| APPI_ID | monitoring/alerts/minibank-p1-alerts.parameters.json (named in the other files of monitoring/alerts) | resource ID of appi-minibank | create-p1-alerts.ps1 finds it by name (section 0) |
| OTELCOL_CLIENT_ID | openshift/p1/10-otelcol.yaml.tpl (ServiceAccount annotation azure.workload.identity/client-id) | client ID of the managed identity id-otelcol | P1-B-DEPLOY.md Step 2 (2d) |
| DCE_LOGS_ENDPOINT | openshift/p1/10-otelcol.yaml.tpl (traces_endpoint, logs_endpoint) | logs ingestion endpoint of dce-otlp (https://..., no trailing slash) | P1-B-DEPLOY.md Step 2 (2d) |
| DCE_METRICS_ENDPOINT | openshift/p1/10-otelcol.yaml.tpl (metrics_endpoint) | metrics ingestion endpoint of dce-otlp (https://..., no trailing slash) | P1-B-DEPLOY.md Step 2 (2d) |
| DCR_IMMUTABLE_ID | openshift/p1/10-otelcol.yaml.tpl (all three endpoints) | immutable ID of dcr-otlp (dcr-...) | P1-B-DEPLOY.md Step 2 (2d) |

No placeholder is needed for the tenant ID (the Arc workload identity webhook puts AZURE_TENANT_ID into the collector pod), the Arc OIDC
issuer URL (P1-B-DEPLOY.md reads it with `az`) or the subscription ID.

## 1. Files

| File | What it is | Lab location | Build / run |
|---|---|---|---|
| README.md | folder map, flow, ports | – | read first |
| MANIFEST.md | this list | – | – |
| web/package.json | minibank-web npm project (react 19, @microsoft/applicationinsights-web ^3.4.2, vite 6); v1.4: version 1.2.0 | APP-WIN C:\Build\minibank\web | 2.1 |
| web/vite.config.js | Vite config, base '/', dev proxy /api -> :8080 | C:\Build\minibank\web | 2.1 |
| web/index.html | page shell, title MiniBank | C:\Build\minibank\web | 2.1 |
| web/public/brand/PUT-LOGO-HERE.txt | where to download/save logo.svg or .png | C:\Build\minibank\web\public\brand (logo placed by the presenter, never in the pack) | 2.1 |
| web/src/main.jsx | entry: starts telemetry, renders App | C:\Build\minibank\web\src | 2.1 |
| web/src/App.jsx | hand-written hash router (#/login #/home #/transfer #/qris #/statement #/receipt #/demo); v1.4: User ID = authenticated user after login, cleared at logout | C:\Build\minibank\web\src | 2.1 |
| web/src/api.js | fetch wrapper, X-MiniBank-Scenario header, {error, traceId}; v1.4: X-MiniBank-Source header (robot / people) | C:\Build\minibank\web\src | 2.1 |
| web/src/telemetry.js | App Insights JS SDK: config from /api/config, W3C, role minibank-web, masking; v1.4: trafficSource dimension, authenticated user, window.__minibankFlush, journey events minibank.journey | C:\Build\minibank\web\src | 2.1 |
| web/src/i18n.js | English (default) + Indonesian texts, localStorage minibank.lang, IDR/WIB format | C:\Build\minibank\web\src | 2.1 |
| web/src/theme.css | brand blue #0066AE, white 16px cards, #F2F5F8, pills, Calibri/Arial | C:\Build\minibank\web\src | 2.1 |
| web/src/components/Header.jsx | white bar: logo svg->png->wordmark, EN/ID, scenario badge; v1.4: data-testid logout | src\components | 2.1 |
| web/src/components/DemoBanner.jsx | yellow demo bar on every screen + ErrorNote; v1.4: data-testid error-note | src\components | 2.1 |
| web/src/components/AccountCard.jsx | masked account, balance eye toggle, Statement/Other accounts | src\components | 2.1 |
| web/src/components/MenuGrid.jsx | round blue SVG icons; 3 active, 3 "coming soon"; Icon set; v1.4: data-testid menu-<icon> | src\components | 2.1 |
| web/src/components/PinPad.jsx | 6-digit PIN pad (demo PIN 123456); v1.4: data-testid pinpad, pin-key-<digit> | src\components | 2.1 |
| web/src/components/AmountInput.jsx | number pad with 000 key, IDR 1.250.000; v1.4: data-testid amount-display, amount-key-<key> | src\components | 2.1 |
| web/src/screens/Login.jsx | "Hello, Welcome!", User ID + password, Instant Access; v1.4: data-testid login-* | src\screens | 2.1 |
| web/src/screens/Home.jsx | greeting band, AccountCard, MenuGrid, last 3 transactions; v1.4: data-testid home-greeting, home-recent (data-status) | src\screens | 2.1 |
| web/src/screens/Transfer.jsx | details -> confirm -> PIN; v1.4: journey start/end (transfer), data-testid transfer-* | src\screens | 2.1 |
| web/src/screens/Qris.jsx | simulated scan: merchant -> amount -> confirm -> PIN; v1.4: journey start/end (qris), data-testid qris-* | src\screens | 2.1 |
| web/src/screens/Statement.jsx | last 30 days from API; v1.4: journey start/end (statement), data-testid statement-* | src\screens | 2.1 |
| web/src/screens/Receipt.jsx | success details / failure with big Trace ID + copy; v1.4: data-testid receipt (data-status, data-trace-id) | src\screens | 2.1 |
| web/src/screens/DemoPanel.jsx | presenter page: 9 scenarios, Apply/Reset (sessionStorage minibank.scenario) | src\screens | 2.1 |
| api/MiniBank.Api.csproj | net10.0; Azure.Monitor.OpenTelemetry.AspNetCore 1.6.0, Microsoft.Data.SqlClient 5.2.2; v1.4: version 1.2.0 | APP-WIN C:\Build\minibank\api | 2.1 |
| api/Program.cs | minimal API, SPA hosting, SQL, calls Java, traceId on errors; v1.4: request tags (traffic source, User ID, tier, channel, amount, band, outcome), enduser.id | C:\Build\minibank\api | 2.1 |
| api/appsettings.json | ConnectionStrings:MiniBank, TransferService:BaseUrl, Demo:Password/Pin | C:\Build\minibank\api -> C:\inetpub\minibank-api | 2.1 |
| transfer/pom.xml | Spring Boot 3.5.6, web/jdbc/actuator/ojdbc11, finalName minibank-transfer; v1.4 B: version 1.2.0 (podman build on APP-RHEL, P1-B-DEPLOY.md Step 3) | Cloud Shell ~/minibank/transfer | 2.4 |
| transfer/Dockerfile | ubi9/openjdk-21 build -> openjdk-21-runtime + agent 3.7.9, USER 185; v1.4 B: comments for the podman build of 1.2.0 | Cloud Shell ~/minibank/transfer | 2.4 |
| transfer/applicationinsights.json | role, console self-diagnostics, health sampling 0 %, masking processor | image /opt/appinsights | 2.4 |
| transfer/src/main/java/id/minibank/transfer/TransferApplication.java | Spring Boot main class | image | 2.4 |
| transfer/src/main/java/id/minibank/transfer/TransferController.java | /api/transfers, /api/qris/payments, /api/ledger/{accountNo}; errors -> JSON + traceId; v1.4 B: fee and limit check (minibank-rates) before the fraud check | image | 2.4 |
| transfer/src/main/java/id/minibank/transfer/LedgerRepository.java | JdbcTemplate, LEDGER_ENTRY, slow-oracle / fail-oracle | image | 2.4 |
| transfer/src/main/java/id/minibank/transfer/FraudClient.java | RestClient POST {FRAUD_URL}/fraud/check + scenario header | image | 2.4 |
| transfer/src/main/java/id/minibank/transfer/RatesClient.java | v1.4 B: RestClient GET {RATES_URL}/api/rates/check (connect 1 s, read 2 s), fallback rate FALLBACK on any error | image | 2.4 |
| transfer/src/main/java/id/minibank/transfer/ScenarioException.java | fail-java exception -> HTTP 500 | image | 2.4 |
| transfer/src/main/resources/application.properties | port 8080, ORACLE_*/FRAUD_URL env, health probes; v1.4 B: rates.url (RATES_URL) | image | 2.4 |
| rates/pom.xml | v1.4 B: minibank-rates 1.0.0, Spring Boot 3.5.6 (web, actuator), no monitoring library, finalName minibank-rates | APP-RHEL ~/p14/minibank/rates | P1-B-DEPLOY 3 |
| rates/Dockerfile | v1.4 B: ubi9/openjdk-21 build -> openjdk-21-runtime, USER 185, NO agent (injected by the operator) | APP-RHEL ~/p14/minibank/rates | P1-B-DEPLOY 3 |
| rates/src/main/java/id/minibank/rates/RatesApplication.java | v1.4 B: Spring Boot main class | image | P1-B-DEPLOY 3 |
| rates/src/main/java/id/minibank/rates/RatesController.java | v1.4 B: GET /api/rates/check (fee, per-transaction limit, rule set MINIBANK-2026-11) | image | P1-B-DEPLOY 3 |
| rates/src/main/resources/application.properties | v1.4 B: port 8080, health probes | image | P1-B-DEPLOY 3 |
| openshift/10-deployment.yaml | Deployment, 3 replicas, probes, spread, tolerations 60 s | HV-HOST-02 F:\Build\minibank (oc) | 2.4 |
| openshift/20-service.yaml | ClusterIP 8080 | HV-HOST-02 F:\Build\minibank (oc) | 2.4 |
| openshift/30-route.yaml | HTTP route minibank-transfer.apps.ocp-minibank.minibank-demo.lab | HV-HOST-02 F:\Build\minibank (oc) | 2.4 |
| openshift/40-pdb.yaml | PodDisruptionBudget minAvailable 2 | HV-HOST-02 F:\Build\minibank (oc) | 2.4 |
| openshift/p1/00-otel-operator.yaml | v1.4 B: Red Hat build of OpenTelemetry operator (Subscription opentelemetry-product, Manual approval) | HV-HOST-02 F:\Build\minibank\openshift\p1 (oc) | P1-B-DEPLOY 5 |
| openshift/p1/installplan-approve.json | v1.4 B: approves the operator's InstallPlan | HV-HOST-02 F:\Build\minibank\openshift\p1 (oc) | P1-B-DEPLOY 5 |
| openshift/p1/10-otelcol.yaml.tpl | v1.4 B: collector otelcol in namespace minibank-otel (template, placeholders of section 0b) | HV-HOST-02 F:\Build\minibank\openshift\p1 -> rendered\ (oc) | P1-B-DEPLOY 4 |
| openshift/p1/20-instrumentation.yaml | v1.4 B: Instrumentation minibank-java (project minibank) | HV-HOST-02 F:\Build\minibank\openshift\p1 (oc) | P1-B-DEPLOY 5 |
| openshift/p1/30-rates.yaml | v1.4 B: minibank-rates (2 replicas, onboarded), Service, PDB | HV-HOST-02 F:\Build\minibank\openshift\p1 -> rendered\ (oc) | P1-B-DEPLOY 6 |
| openshift/p1/40-rates-copy.yaml | v1.4 B: minibank-rates-copy (1 replica, not onboarded), Service, Route | HV-HOST-02 F:\Build\minibank\openshift\p1 -> rendered\ (oc) | P1-B-DEPLOY 6 |
| openshift/p1/onboard-patch.yaml, onboard-remove.json | v1.4 B: add / remove the inject-java annotation (used by scripts/onboard-*.ps1) | HV-HOST-02 F:\Build\minibank\openshift\p1 | 2.7 |
| fraud/app.py | minibank-fraud FastAPI (POST /fraud/check, GET /health) | APP-RHEL /opt/minibank/fraud | 2.2 |
| fraud/requirements.txt | fastapi, uvicorn, psycopg2-binary, azure-monitor-opentelemetry==1.8.12 | /opt/minibank/fraud | 2.2 |
| fraud/minibank-fraud.service | systemd unit, user minibank, port 8082 | /etc/systemd/system | 2.2 |
| fraud/fraud.env.example | PG_DSN, APPLICATIONINSIGHTS_CONNECTION_STRING, OTEL_SERVICE_NAME | /etc/minibank/fraud.env (600) | 2.2 |
| db/sqlserver/01-minibank-db.sql | MiniBankDemo, 3 customers x 2 accounts, login APP-SQL\minibank-svc | APP-SQL C:\Build\minibank\db\sqlserver | 2.3 |
| db/sqlserver/02-p1-tiers-customers.sql | v1.4: column Tier, view dbo.DemoBalanceTargets, 30 more customers (33 = Reguler 24, Prioritas 7, Solitaire 2), 66 accounts; safe to run again | APP-SQL C:\Build\minibank\db\sqlserver | 2.3 |
| db/oracle/01-minibank-user.sql | MINIBANK + MINIBANK_MON (&1, &2), run as SYSTEM in FREEPDB1 (v1.3: creates the USERS tablespace when missing) | ~/minibank/db/oracle -> container /tmp | 2.2 |
| db/oracle/02-minibank-tables.sql | LEDGER_ENTRY + index + 30 seed rows | ~/minibank/db/oracle -> container /tmp | 2.2 |
| db/postgres/01-minibank-db.sql | roles minibank_app/postgres_exporter (-v app_pw/exp_pw), db minibank, fraud_check | APP-RHEL ~/minibank/db/postgres | 2.2 |
| monitoring/route-a/minibank-dbsnap.sh | snapshot -> /var/log/minibank/dbsnap.json (JSON lines, no Computer field) | /opt/minibank/dbsnap | 2.5 |
| monitoring/route-a/oracle-snap.sql | Oracle sessions/waits/topsql/locks (mounted as /snap) | /opt/minibank/dbsnap | 2.5 |
| monitoring/route-a/pg-snap.sql | PostgreSQL sessions/waits/topsql/locks | /opt/minibank/dbsnap | 2.5 |
| monitoring/route-a/minibank-dbsnap.service | oneshot unit (root) | /etc/systemd/system | 2.5 |
| monitoring/route-a/minibank-dbsnap.timer | every 60 s | /etc/systemd/system | 2.5 |
| monitoring/route-a/dbsnap.env.example | MINIBANK_MON / postgres_exporter credentials, alert log path | /etc/minibank/dbsnap.env (600) | 2.5 |
| monitoring/route-a/MiniBankDbSnap_CL.columns.txt | table + DCR stream columns (Computer/FilePath from AMA) | Cloud Shell ~/minibank | 2.6 |
| monitoring/route-a/MiniBankDbSnap_CL.table.json | Log Analytics table schema body | Cloud Shell ~/minibank | 2.6 |
| monitoring/route-b/run-exporters.sh | Podman: Oracle exporter 2.5.1 (9161, v1.3: writes /etc/minibank/oracle-exporter.yaml and sets CONFIG_FILE), postgres-exporter v0.20.1 (9187) | /opt/minibank/exporters | 2.5 |
| monitoring/route-b/exporters.env.example | DB_USERNAME, DB_PASSWORD, DB_CONNECT_STRING, DATA_SOURCE_NAME | /etc/minibank/exporters.env (600) | 2.5 |
| monitoring/route-b/ama-metrics-prometheus-config.yaml | scrape jobs minibank-oracle / minibank-postgres, 30 s | HV-HOST-02 F:\Build\minibank (oc) | 2.4 |
| monitoring/container-insights/container-azm-ms-agentconfig.yaml | stdout/stderr on, 58 namespaces excluded, ContainerLogV2 | HV-HOST-02 F:\Build\minibank (oc) | 2.4 |
| monitoring/kql/minibank-queries.kql | all runbook queries A1-A18, B1-B5, C1-C8, D1-D4 (v1.3: technical failures = 5xx, business declines = 409); v1.4: E1-E10 business impact, traffic sources, journeys | Portal > Logs | copy/paste |
| monitoring/workbook/minibank-sla-workbook.json | Workbook gallery template (appi-minibank); v1.3 tiles, technical failures vs business declines; v1.4: group Business impact (IDR) | Portal | 2.6 |
| monitoring/alerts/minibank-p1-alerts.json | v1.4: ARM template, alr-minibank-failed-value-idr + alr-minibank-journey-success-low (sev 2, 5 min / 10 min, no action group, scope APPI_ID) | Cloud Shell ~/minibank | 2.6 |
| monitoring/alerts/minibank-p1-alerts.parameters.json | v1.4: parameter file (appiId = APPI_ID placeholder, location, tags) | Cloud Shell ~/minibank | 2.6 |
| monitoring/alerts/create-p1-alerts.ps1 | v1.4: deploys the template (finds appi-minibank by name), lists the rules; undo commands | Cloud Shell ~/minibank (PowerShell) | 2.6 |
| monitoring/alerts/alr-minibank-failed-value-idr.kql | v1.4: IDR alert query (requests/customDimensions) + Log Analytics variant + count-based fallback | Portal | 2.6 |
| monitoring/alerts/alr-minibank-journey-success-low.kql | v1.4: journey alert query (customEvents) + Log Analytics variant (AppEvents) | Portal | 2.6 |
| monitoring/grafana/minibank-sla-dashboard.json | Grafana, Azure Monitor data source, law-appmon; v1.3: 5 tiles incl. Business declines, colour thresholds, declines panels | Managed Grafana amg-appmon | 2.6 |
| monitoring/grafana/minibank-openshift-db-dashboard.json | Grafana, Prometheus data source: nodes, pods, Oracle, PostgreSQL; v1.3 colour thresholds | Managed Grafana amg-appmon | 2.6 |
| monitoring/dcr/iis-transform.kql | transformKql: drop /api/health IIS lines | DCR for APP-WIN IIS logs | 2.6 |
| scripts/traffic.ps1 | v1.3 traffic: -Minutes (0 = until stopped) -PerMinute -Scenario -FailPercent 0.05 -SlowPercent 6 -DeclinesPerHour -LogFile; v1.4: header X-MiniBank-Source: traffic | HV-HOST-02 F:\Build\minibank\scripts | 2.7 |
| scripts/install-traffic-tasks.ps1 | v1.3: task minibank-traffic (continuous, 4 declines/hour, watchdog, no time limit) + probe task without time limit | HV-HOST-02 F:\Build\minibank\scripts | 2.7 |
| scripts/probe.ps1 | availability probe every 60 s -> /v2.1/track; v1.4: header X-MiniBank-Source: probe | HV-HOST-02 F:\Build\minibank\scripts | 2.7 |
| scripts/reset-demo-balances.sql | v1.4: all accounts to their tier balance (view dbo.DemoBalanceTargets; same values as the top-up) | APP-SQL C:\Build\minibank\scripts | 2.3 |
| scripts/topup-demo-balances.sql | v1.4: set all 66 balances to their tier targets (view dbo.DemoBalanceTargets) | APP-SQL C:\Build\minibank\scripts | 2.3 |
| scripts/topup-demo-balances.ps1 | v1.3: runs the top-up SQL, log C:\BuildLog\topup.log; v1.4: one line per run with totals per tier + the 6 generator accounts | APP-SQL C:\Build\minibank\scripts | 2.3 |
| scripts/install-topup-task.ps1 | v1.3: task minibank-topup at 00:00, 06:00, 12:00, 18:00 WIB (v1.4: description text only) | APP-SQL C:\Build\minibank\scripts | 2.3 |
| scripts/incident.ps1 | v1.4: incident command -Scene 5 / -Scene 6 / -Stop: note into APP-WIN (Copy-VMFile) for the robot + generator windows in the background | HV-HOST-02 F:\Build\minibank\scripts | 2.7 |
| scripts/onboard-live.ps1 | v1.4 B: Scene 2 live zero-code onboarding of minibank-rates-copy (about 28 s) | HV-HOST-02 F:\Build\minibank\scripts | 2.7 |
| scripts/onboard-reset.ps1 | v1.4 B: reset of the live onboarding (about 20 s) | HV-HOST-02 F:\Build\minibank\scripts | 2.7 |
| robot/package.json | v1.4: minibank-robot, playwright-core 1.64.1 (exact), Node.js 24 | APP-WIN C:\Build\minibank\robot | 2.1 |
| robot/package-lock.json | v1.4: lock file for npm.cmd ci | APP-WIN C:\Build\minibank\robot | 2.1 |
| robot/robot.js | v1.4: browser robot (Edge headless, profiles C:\ProgramData\MiniBank\robot\profiles\<User ID>, note incident.json, log C:\BuildLog\robot.log); --once, --plan | APP-WIN C:\Build\minibank\robot | 2.1 |
| robot/customers.json | v1.4: 32 robot customers with tier (ANDI.WIJAYA reserved for the presenter) | APP-WIN C:\Build\minibank\robot | 2.1 |
| robot/install-robot-task.ps1 | v1.4: task minibank-robot (local Administrator, logon type S4U, not SYSTEM; boot + 15-minute watchdog, restart on failure, no time limit); -Remove | APP-WIN C:\Build\minibank\robot | 2.1 |
| robot/incident.example.json | v1.4: example incident note (Scene 5 phases) | – | – |

## 2. Exact commands

### 2.1 APP-WIN – Windows PowerShell (Admin); .NET 10 SDK, Node.js 22, IIS + ASP.NET Core Hosting Bundle installed
```powershell
# optional first: the presenter places logo.svg or logo.png in C:\Build\minibank\web\public\brand
Set-Location C:\Build\minibank\api
dotnet publish MiniBank.Api.csproj -c Release -r win-x64 --self-contained true -o C:\inetpub\minibank-api
New-Item -ItemType Directory -Path C:\inetpub\minibank-api\wwwroot -Force | Out-Null
Set-Location C:\Build\minibank\web
npm.cmd install
npm.cmd run build
Copy-Item C:\Build\minibank\web\dist\* C:\inetpub\minibank-api\wwwroot -Recurse -Force
# IIS: site minibank-api, port 8080, path C:\inetpub\minibank-api, app pool minibank (No Managed Code) running as APP-WIN\minibank-svc
$cs = Read-Host 'Application Insights connection string'
[Environment]::SetEnvironmentVariable('APPLICATIONINSIGHTS_CONNECTION_STRING', $cs, 'Machine'); iisreset
Invoke-RestMethod http://localhost:8080/api/health
# v1.4 browser robot (Node.js 24 on the PATH of this window, Microsoft Edge installed); details in P1-DC-DEPLOY.md
Set-Location C:\Build\minibank\robot
npm.cmd ci
node robot.js --once --type statement --customer SITI.RAHAYU
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\robot\install-robot-task.ps1
```

### 2.2 APP-RHEL – bash (RHEL 9.6), pack in ~/minibank
```bash
cd ~/minibank
sudo useradd --system --home-dir /opt/minibank --shell /sbin/nologin minibank
sudo mkdir -p /opt/minibank/fraud /opt/minibank/dbsnap /opt/minibank/exporters /etc/minibank
sudo cp monitoring/route-a/{minibank-dbsnap.sh,oracle-snap.sql,pg-snap.sql} /opt/minibank/dbsnap/   # before Oracle starts (/snap mount)
# Oracle Free container (name, port and /snap mount used by this pack; podman secret oracle_pwd = SYSTEM password)
sudo podman run -d --name minibank-oracle --restart=always -p 1521:1521 --secret=oracle_pwd \
  -v minibank-oracle-data:/opt/oracle/oradata -v /opt/minibank/dbsnap:/snap:ro,z container-registry.oracle.com/database/free:latest-lite
# Oracle users and table: run the commented lines at the top of db/oracle/01-minibank-user.sql, then of db/oracle/02-minibank-tables.sql
# PostgreSQL 16 (shared_preload_libraries = 'pg_stat_statements'): run the commented lines at the top of db/postgres/01-minibank-db.sql
# minibank-fraud
sudo cp fraud/app.py fraud/requirements.txt /opt/minibank/fraud/
sudo python3.11 -m venv /opt/minibank/fraud/.venv
sudo /opt/minibank/fraud/.venv/bin/pip install -r /opt/minibank/fraud/requirements.txt
sudo install -m 600 -o root -g root fraud/fraud.env.example /etc/minibank/fraud.env && sudo vi /etc/minibank/fraud.env
sudo cp fraud/minibank-fraud.service /etc/systemd/system/ && sudo chown -R minibank:minibank /opt/minibank/fraud
sudo systemctl daemon-reload && sudo systemctl enable --now minibank-fraud && curl -s http://127.0.0.1:8082/health
# firewall: Oracle, fraud and exporters reachable from the OpenShift nodes only
for ip in 21 22 23 24; do for p in 1521 8082 9161 9187; do sudo firewall-cmd --permanent \
  --add-rich-rule="rule family=ipv4 source address=192.168.110.$ip port port=$p protocol=tcp accept"; done; done; sudo firewall-cmd --reload
```

### 2.3 APP-SQL – Windows PowerShell (Admin) with the Invoke-SqlFile helper from runbook Chapter 14.1
```powershell
New-LocalUser -Name minibank-svc -Password (Read-Host 'Same password as on APP-WIN' -AsSecureString) -PasswordNeverExpires
Invoke-SqlFile C:\Build\minibank\db\sqlserver\01-minibank-db.sql
#   or, if sqlcmd is installed: sqlcmd -S localhost -E -b -i C:\Build\minibank\db\sqlserver\01-minibank-db.sql
Invoke-SqlFile C:\Build\minibank\db\sqlserver\02-p1-tiers-customers.sql                             # v1.4: tiers + 30 customers (the v1.4 top-up needs it)
powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\install-topup-task.ps1        # v1.3: top-up task every 6 hours (runs once now)
#   lab upgraded from v1.3 (task already installed): run the v1.4 top-up once instead of the line above:
#   powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\topup-demo-balances.ps1
```

### 2.4 Image: Azure Cloud Shell (bash, ~/minibank). OpenShift: HV-HOST-02 (PowerShell + `oc`, api.ocp-minibank.minibank-demo.lab:6443)
```bash
cd ~/minibank/transfer
read -rp 'ACR name (without .azurecr.io): ' ACR
az acr build --registry "$ACR" --image minibank-transfer:1.1.0 .
# v1.4 B: ACR Tasks are not available in Indonesia Central; minibank-transfer:1.2.0 and minibank-rates:1.0.0 are built with podman on
# APP-RHEL (P1-B-DEPLOY.md Step 3)
```
```powershell
Set-Location F:\Build\minibank
$ACR = Read-Host 'ACR name (without .azurecr.io)'
oc new-project minibank
$u = Read-Host 'ACR pull token name'; $p = Read-Host 'ACR pull token password'
oc -n minibank create secret docker-registry acr-pull --docker-server="$ACR.azurecr.io" --docker-username=$u --docker-password=$p
$ora = Read-Host 'Oracle MINIBANK password'; $cs = Read-Host 'Application Insights connection string'
oc -n minibank create secret generic minibank-transfer-secrets --from-literal=ORACLE_PASSWORD=$ora --from-literal=APPLICATIONINSIGHTS_CONNECTION_STRING=$cs
(Get-Content openshift\10-deployment.yaml) -replace 'ACR_NAME', $ACR | Set-Content openshift\10-deployment.yaml
oc apply -f openshift\
oc -n minibank rollout status deployment/minibank-transfer
Invoke-RestMethod http://minibank-transfer.apps.ocp-minibank.minibank-demo.lab/actuator/health
oc apply -f monitoring\route-b\ama-metrics-prometheus-config.yaml
oc apply -f monitoring\container-insights\container-azm-ms-agentconfig.yaml
# v1.4 B: collector, operator, Instrumentation, minibank-rates (+ copy) and minibank-transfer 1.2.0: P1-B-DEPLOY.md Steps 4-7
```

### 2.5 Route A and Route B on APP-RHEL – bash, pack in ~/minibank
```bash
cd ~/minibank
sudo chmod 755 /opt/minibank/dbsnap/minibank-dbsnap.sh
sudo install -m 600 -o root -g root monitoring/route-a/dbsnap.env.example /etc/minibank/dbsnap.env && sudo vi /etc/minibank/dbsnap.env
sudo cp monitoring/route-a/minibank-dbsnap.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now minibank-dbsnap.timer
sudo /opt/minibank/dbsnap/minibank-dbsnap.sh; sudo tail -n 3 /var/log/minibank/dbsnap.json
sudo install -m 755 monitoring/route-b/run-exporters.sh /opt/minibank/exporters/
sudo install -m 600 -o root -g root monitoring/route-b/exporters.env.example /etc/minibank/exporters.env && sudo vi /etc/minibank/exporters.env
sudo /opt/minibank/exporters/run-exporters.sh && sudo systemctl enable --now podman-restart.service
```

### 2.6 Azure – Cloud Shell (bash), pack in ~/minibank
```bash
cd ~/minibank
read -rp 'Resource group of law-appmon: ' RG
LAW=$(az monitor log-analytics workspace show -g "$RG" -n law-appmon --query id -o tsv)
az rest --method put --url "https://management.azure.com$LAW/tables/MiniBankDbSnap_CL?api-version=2022-10-01" --body @monitoring/route-a/MiniBankDbSnap_CL.table.json
```
- DCR (custom JSON logs, file `/var/log/minibank/dbsnap.json`, columns from MiniBankDbSnap_CL.columns.txt) -> associate with APP-RHEL.
- IIS DCR for APP-WIN: `transformKql` = content of monitoring/dcr/iis-transform.kql.
- Workbook: Monitor > Workbooks > + New > Advanced Editor > Gallery Template > paste minibank-sla-workbook.json > Apply > Save.
- v1.4 alerts (Cloud Shell - PowerShell): `./monitoring/alerts/create-p1-alerts.ps1` (scope appi-minibank = APPI_ID, found by name).
- Grafana: Dashboards > New > Import > upload each JSON > pick the Azure Monitor / Prometheus data source > Import.

### 2.7 HV-HOST-02 – Windows PowerShell 5.1
```powershell
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\traffic.ps1 -BaseUrl http://192.168.110.31:8080 -Minutes 30 -PerMinute 30 -Scenario mix
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\traffic.ps1 -Minutes 10 -PerMinute 6 -Scenario fail-oracle   # incident window
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\traffic.ps1 -Minutes 5 -PerMinute 0 -DeclinesPerHour 240  # decline burst (about 20)
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\install-traffic-tasks.ps1  # v1.3: continuous traffic task + probe without time limit
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\probe.ps1        # asks for the connection string if not set
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\install-traffic-tasks.ps1 -SlowPercent 2  # v1.4: background slow share 6 -> 2 %
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\incident.ps1 -Scene 6   # v1.4: incident window for generator + robot (-Scene 5, -Stop)
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\onboard-live.ps1    # v1.4 B: Scene 2 live onboarding of minibank-rates-copy (about 28 s)
powershell -ExecutionPolicy Bypass -File F:\Build\minibank\scripts\onboard-reset.ps1   # v1.4 B: reset after the session or rehearsal (about 20 s)
```

## 3. Environment variables

| Name | Where set | Used by |
|---|---|---|
| APPLICATIONINSIGHTS_CONNECTION_STRING | APP-WIN machine variable; /etc/minibank/fraud.env; Secret minibank-transfer-secrets; optional on HV-HOST-02 | minibank-api (+ /api/config for minibank-web), minibank-fraud, minibank-transfer agent, probe.ps1 |
| OTEL_SERVICE_NAME=minibank-fraud | /etc/minibank/fraud.env | Python role name |
| PG_DSN | /etc/minibank/fraud.env | minibank-fraud -> PostgreSQL |
| ORACLE_URL, ORACLE_USER | 10-deployment.yaml | minibank-transfer (defaults in application.properties) |
| ORACLE_PASSWORD | Secret minibank-transfer-secrets | minibank-transfer |
| FRAUD_URL | 10-deployment.yaml (http://192.168.110.32:8082) | minibank-transfer |
| APPLICATIONINSIGHTS_ROLE_NAME=minibank-transfer | 10-deployment.yaml | Java agent |
| JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=50 | Dockerfile | JVM heap |
| RATES_URL | not set (default http://minibank-rates.minibank.svc.cluster.local:8080 in application.properties) | v1.4 B: minibank-transfer 1.2.0 -> minibank-rates |
| JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=50 | openshift/p1/30-rates.yaml, 40-rates-copy.yaml (Deployment env, not the image) | v1.4 B: minibank-rates heap; the operator appends -javaagent on injected pods |
| OTEL_SERVICE_NAME, OTEL_EXPORTER_OTLP_ENDPOINT and other OTEL_* | the operator, on injected pods (Instrumentation minibank-java) | v1.4 B: OpenTelemetry Java agent in minibank-rates |
| AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE, AZURE_AUTHORITY_HOST | the Arc workload identity webhook, on the collector pods | v1.4 B: azure_auth extension of the collector (no secret) |
| ORACLE_CONTAINER, ORACLE_MON_USER, ORACLE_MON_PASSWORD, ORACLE_ALERT_LOG, PG_HOST, PG_PORT, PG_DB, PG_MON_USER, PG_MON_PASSWORD, DBSNAP_FILE | /etc/minibank/dbsnap.env | minibank-dbsnap.sh |
| DB_USERNAME, DB_PASSWORD, DB_CONNECT_STRING | /etc/minibank/exporters.env | Oracle exporter |
| DATA_SOURCE_NAME | /etc/minibank/exporters.env | postgres_exporter |

## 4. Ports

| Port | Host | Service |
|---|---|---|
| 8080 | APP-WIN 192.168.110.31 | IIS site: minibank-api + minibank-web |
| 80 | 192.168.110.11 (*.apps.ocp-minibank.minibank-demo.lab) | Route minibank-transfer (HTTP) |
| 6443 | 192.168.110.10 (api.ocp-minibank.minibank-demo.lab) | OpenShift API |
| 8080 | pods / Service minibank-transfer | Spring Boot |
| 1433 | APP-SQL 192.168.110.33 | SQL Server 2022, MiniBankDemo |
| 1521 | APP-RHEL 192.168.110.32 | Oracle Free, FREEPDB1 |
| 5432 | APP-RHEL (local only) | PostgreSQL 16, minibank |
| 8082 | APP-RHEL | minibank-fraud |
| 9161 / 9187 | APP-RHEL | Oracle exporter / postgres_exporter |
| 8080 | pods / Service minibank-rates (project minibank) | v1.4 B: fee and limit check, called by minibank-transfer |
| 80 | Route minibank-rates-copy.apps.ocp-minibank.minibank-demo.lab | v1.4 B: test calls of onboard-live.ps1 |
| 4317 / 4318 | Service otelcol (namespace minibank-otel) | v1.4 B: OTLP gRPC / HTTP from the injected agents |
| 443 (outbound) | data collection endpoint dce-otlp (Indonesia Central) | v1.4 B: collector -> Azure Monitor (OTLP over HTTPS, Microsoft Entra token) |
