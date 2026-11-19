# MiniBank source pack v1.4 (P1 build)

Source files for **"MiniBank on OpenShift – Application Monitoring Demo Runbook v1.3"**. Version 1.3 adds the continuous traffic task, the balance top-up and the split between technical failures (HTTP 5xx) and business declines (HTTP 409); the Oracle user script creates the USERS tablespace when it is missing.
Version 1.4 (Priority 1 build, features C and D) adds: customer tiers Reguler / Prioritas / Solitaire and 30 more synthetic
customers (33), business tags on the API requests (traffic source, User ID, tier, channel, amount in IDR, amount band, outcome),
the workbook group "Business impact (IDR)", the browser robot (`robot/`, simulated customers in Microsoft Edge on APP-WIN),
customer-journey events, the incident command `scripts/incident.ps1` and two alert rules (`monitoring/alerts/`).
**v1.4 note - the four Priority 1 features:** A = AI investigation with the Azure Copilot Observability Agent (no code: only a
subscription setting that links the Azure Monitor workspace amw-appmon); B = zero-code OpenShift onboarding with the Red Hat build
of OpenTelemetry (new service `rates/` without any agent in its image, `transfer/` 1.2.0 calls it, manifests `openshift/p1/`, Scene 2
scripts `scripts/onboard-*.ps1`, steps in `P1-B-DEPLOY.md`; role name in Application Insights `[minibank]/minibank-rates`); C = customer
journeys + browser robot and D = business impact in IDR (steps in `P1-DC-DEPLOY.md`).
Traffic-source label (header `X-MiniBank-Source`, request tag `minibank.trafficSource`): `people` (real persons on the web page,
default), `robot` (browser robot), `traffic` (traffic.ps1), `probe` (probe.ps1), `unknown` (no or an invalid header).
MiniBank is a DEMO application with synthetic data only; it is not a real bank app.
Exact copy locations and commands for every file: see `MANIFEST.md`.

## Where the pack is unpacked

| Machine | Folder |
|---|---|
| Windows guests APP-WIN and APP-SQL | `C:\Build\minibank` |
| HV-HOST-02 (traffic, probe, `oc`) | `F:\Build\minibank` |
| APP-RHEL | `~/minibank` |
| Azure Cloud Shell (`az acr build`, table creation) | `~/minibank` |

**Logo (optional):** put your own logo as `web\public\brand\logo.svg` or `logo.png` before the build. Without it the header
shows the text wordmark "MiniBank".

## Map: folder -> runbook topic -> machine

| Folder | What it is | Runbook topic | Runs on |
|---|---|---|---|
| `web/` | minibank-web: React 19 + Vite page (EN default, ID toggle) | Build the Windows side (React page) | APP-WIN `C:\Build\minibank\web`, served by IIS from `wwwroot` |
| `api/` | minibank-api: ASP.NET Core minimal API, .NET 10 | Build the Windows side (API + IIS site) | APP-WIN `C:\Build\minibank\api` -> IIS 192.168.110.31:8080 |
| `transfer/` | minibank-transfer: Java 21, Spring Boot 3.5.6, App Insights Java agent 3.7.9 | Build the image with ACR Tasks | built from Cloud Shell `~/minibank/transfer`; runs on OpenShift `ocp-minibank`, project `minibank` |
| `openshift/` | Deployment (3 replicas), Service, Route, PDB | Deploy to OpenShift | `oc apply -f F:\Build\minibank\openshift\` on HV-HOST-02 |
| `fraud/` | minibank-fraud: Python 3.11 FastAPI + uvicorn | Build the Linux side | APP-RHEL `~/minibank/fraud` -> /opt/minibank/fraud, port 8082 |
| `db/sqlserver/` | database MiniBankDemo, seed data, login `APP-SQL\minibank-svc`; v1.4: `02-p1-tiers-customers.sql` (tiers, 33 customers) | Prepare APP-SQL | APP-SQL `C:\Build\minibank\db\sqlserver` (Invoke-SqlFile, Chapter 14.1) |
| `db/oracle/` | users MINIBANK + MINIBANK_MON, table LEDGER_ENTRY + 30 seed rows | Oracle Free on APP-RHEL | container `minibank-oracle`, PDB FREEPDB1 |
| `db/postgres/` | database minibank, roles minibank_app + postgres_exporter, fraud_check | PostgreSQL 16 on APP-RHEL | APP-RHEL 127.0.0.1:5432 |
| `monitoring/route-a/` | DB snapshot every 60 s -> JSON lines -> custom table `MiniBankDbSnap_CL` | Database monitoring, Route A | APP-RHEL (systemd timer) + AMA |
| `monitoring/route-b/` | Oracle (9161) + PostgreSQL (9187) exporters, scrape config | Database monitoring, Route B | APP-RHEL (Podman) + managed Prometheus |
| `monitoring/container-insights/` | Container Insights log filtering ConfigMap | Filtering scene | OpenShift `kube-system` |
| `monitoring/kql/` | every KQL query of the runbook (A1-A18, B1-B5, C1-C8, D1-D4; v1.4: E1-E10) | Dashboards, alert, demo scenes | Azure Portal > Logs |
| `monitoring/alerts/` | v1.4: alert rules alr-minibank-failed-value-idr and alr-minibank-journey-success-low (ARM template, KQL, deploy script) | Alerts | Cloud Shell (PowerShell) |
| `monitoring/workbook/` | Azure Workbook "MiniBank – SLA and Failure Rate" | SLA workbook | Azure Monitor > Workbooks |
| `monitoring/grafana/` | 2 importable Grafana dashboards (Azure Monitor + Prometheus) | Grafana dashboards | Azure Managed Grafana |
| `monitoring/dcr/` | IIS log transformation (drops `/api/health`) | Filtering at ingestion | DCR for APP-WIN IIS logs |
| `scripts/` | continuous traffic + availability probe and their task installer (PowerShell 5.1), balance top-up (SQL + task); v1.4: incident command `incident.ps1` | Traffic, probe, top-up, incident window | HV-HOST-02 `F:\Build\minibank\scripts` (SQL file: APP-SQL `C:\Build\minibank\scripts`) |
| `robot/` | v1.4: browser robot (Node.js 24, playwright-core, Microsoft Edge headless) + task installer | Customer journeys | APP-WIN `C:\Build\minibank\robot` (task minibank-robot) |

## Request flow and scenarios

Browser (minibank-web) -> `POST /api/transfer` or `/api/qris/pay` on minibank-api -> SQL Server row `Transfers` (PENDING)
-> `POST /api/transfers` or `/api/qris/payments` on minibank-transfer (Route) -> `POST /fraud/check` on minibank-fraud
-> PostgreSQL `fraud_check` -> back in Java: Oracle `LEDGER_ENTRY` -> back in the API: balances + `SUCCESS` (or `FAILED` + HTTP 502).
Statement: API -> Java `GET /api/ledger/{accountNo}?days=30` -> Oracle. Every hop carries the same W3C trace ID.

The scenario travels as JSON field `scenario` and header `X-MiniBank-Scenario` (chosen on the presenter page `#/demo`):
`normal`, `slow-sql` (WAITFOR 1.5 s), `slow-oracle` (DBMS_SESSION.SLEEP 2), `slow-python` (sleep 1.5 s), `slow-postgres`
(pg_sleep 1.5 s), `fail-oracle` (table LEDGER_MISSING -> ORA-00942), `fail-java`, `fail-python`, `fail-api` (throws before
any downstream call). Statement calls react only to `fail-api`, `slow-oracle`, `fail-oracle` and `fail-java`.
Every error response carries `traceId`; the receipt shows it large for Application Insights Transaction search.

Demo values (documented, synthetic): users `ANDI.WIJAYA`, `SITI.RAHAYU`, `BUDI.SANTOSO`, password `Demo123!`, PIN `123456`,
accounts 9901000011/12, 9901000021/22, 9901000031/32. Amount >= IDR 50,000,000 gives fraud decision REVIEW.
v1.4: 33 customers (the 3 above are Prioritas; list in `db/sqlserver/02-p1-tiers-customers.sql`), same password and PIN,
accounts 990100 + 3-digit customer number + 1 (Tabungan) or 2 (Giro), for example 9901000331/32. ANDI.WIJAYA is reserved for
the presenter; the robot plays the other 32 (`robot/customers.json`); traffic.ps1 keeps using the original 3 users.

## Ports

| Port | Where | Used by |
|---|---|---|
| 8080 | APP-WIN IIS site `minibank-api` (API + web page) | browser, traffic, probe |
| 80 | Route `minibank-transfer.apps.ocp-minibank.minibank-demo.lab` (Ingress VIP 192.168.110.11) | minibank-api |
| 8080 | minibank-transfer container port / Service | Route |
| 1433 | APP-SQL SQL Server | minibank-api (from APP-WIN only) |
| 1521 | APP-RHEL Oracle Free (container `minibank-oracle`) | minibank-transfer pods, Oracle exporter |
| 5432 | APP-RHEL PostgreSQL 16 (local only) | minibank-fraud, postgres_exporter, dbsnap |
| 8082 | APP-RHEL minibank-fraud | minibank-transfer pods |
| 9161 / 9187 | APP-RHEL Oracle / PostgreSQL exporters | managed Prometheus (ama-metrics) in the cluster |
| 6443 | `api.ocp-minibank.minibank-demo.lab` (API VIP 192.168.110.10) | `oc` |

APP-RHEL firewall: allow 1521, 8082, 9161, 9187 from the OpenShift nodes 192.168.110.21-24.

## How to build each part (details and paths in MANIFEST.md)

- **web** (APP-WIN, `C:\Build\minibank\web`): `npm.cmd install` then `npm.cmd run build`; copy `dist\*` to
  `C:\inetpub\minibank-api\wwwroot`. Add your own logo first if you want one (see above and `PUT-LOGO-HERE.txt`).
- **api** (APP-WIN, `C:\Build\minibank\api`): `dotnet publish MiniBank.Api.csproj -c Release -r win-x64 --self-contained true -o C:\inetpub\minibank-api`.
- **transfer** (Cloud Shell, `~/minibank/transfer`): `az acr build --registry ACR_NAME --image minibank-transfer:1.1.0 .` (Maven runs inside the build).
- **fraud** (APP-RHEL, `~/minibank/fraud`): `python3.11 -m venv .venv` and `.venv/bin/pip install -r requirements.txt`, then the systemd unit.
- **openshift** (HV-HOST-02, `F:\Build\minibank\openshift`): replace `ACR_NAME` in `10-deployment.yaml`, create the two secrets, `oc apply -f openshift/`.

## Rules used in this pack

- No secrets in files. Passwords and the Application Insights connection string come from environment variables,
  root-only env files (`*.example` show the names) or OpenShift Secrets. Placeholders appear only in `*.example`
  files and as `ACR_NAME`, `APPI_ID` and the four collector values in `openshift/p1/10-otelcol.yaml.tpl` (MANIFEST.md section 0b).
- Account numbers are never logged in full: the API logs `******1234`; the Java agent masks `url.path` and
  `minibank.account`; the browser SDK masks every 10-digit number.
- Telemetry: Application Insights `appi-minibank` (workspace `law-appmon`); cloud role names
  minibank-web, minibank-api, minibank-transfer, minibank-fraud (plus minibank-probe for availability results).
