# Appendix B. Contents of the source pack

<sub>Part E - Rehearse, present, reset and remove &nbsp;|&nbsp; [Guide index](README.md)</sub>


The source pack MiniBank-source-pack-v1.3.zip unpacks into one folder, minibank. It goes to C:\Build\minibank on APP-WIN and APP-SQL, to F:\Build\minibank on HV-HOST-02, and to ~/minibank on APP-RHEL and in Cloud Shell. README.md and MANIFEST.md inside the pack describe every file.

| Folder | What it contains | Where it is used | Chapter |
|---|---|---|---|
| web | MiniBank screens (React 19 and Vite): login, home, transfer, QRIS payment, statement, receipt and the presenter page #/demo. English by default with an Indonesian switch, and the DEMO banner on every screen | APP-WIN | 15.4 |
| api | minibank-api (.NET 10): login, accounts, statement, transfer and QRIS endpoints, with the Azure Monitor OpenTelemetry Distro | APP-WIN | 15.3 |
| transfer | minibank-transfer (Java 21, Spring Boot), its Dockerfile and the Application Insights Java agent configuration | APP-RHEL (image build with podman) | 15.2 |
| openshift | Deployment with three copies, Service, Route and pod disruption budget | HV-HOST-02 | 15.2 |
| fraud | minibank-fraud (Python 3.11, FastAPI), its service file and a settings example | APP-RHEL | 15.1 |
| db\sqlserver | Database MiniBankDemo with three demo customers and six accounts | APP-SQL | 14.1 |
| db\oracle | Users MINIBANK and MINIBANK_MON, the ledger table and 30 demo rows. From version 1.3, 01-minibank-user.sql first creates the USERS tablespace when it is missing | APP-RHEL (Oracle container) | 14.2 |
| db\postgres | Roles minibank_app and postgres_exporter, database minibank and table fraud_check | APP-RHEL | 14.3 |
| monitoring\route-a | Snapshot script, the two snapshot SQL files, service and timer, settings example and the custom table definition | APP-RHEL, Cloud Shell | 16.1 |
| monitoring\route-b | Exporter start script, settings example and the Prometheus scrape configuration | APP-RHEL, HV-HOST-02 | 16.2 |
| monitoring\container-insights | Log collection settings that skip the OpenShift system namespaces | HV-HOST-02 | 13.5 |
| monitoring\workbook | SLA and failure-rate workbook, version 1.3: technical failures and business declines shown separately | Azure Portal | 17.3 |
| monitoring\grafana | Dashboards MiniBank - SLA and Failure Rate, and MiniBank - OpenShift and Databases, version 1.3: Business declines tile and panels, colour thresholds (version 2.3 adds the service weather panel to the SLA board in Grafana; a copy is in the build-helpers folder, Chapter 41.7) | Grafana amg-appmon | 17.4 |
| monitoring\dcr | IIS transformation that drops /api/health lines | Cloud Shell | 17.7 |
| monitoring\kql | Query library (the queries of Appendix A up to A.22, and more) | Log Analytics | 17 to 19 |
| scripts (for HV-HOST-02) | traffic.ps1 version 1.3 (continuous load generator with business declines), install-traffic-tasks.ps1 (scheduled tasks minibank-traffic and minibank-probe) and probe.ps1 | HV-HOST-02 | 17.1 |
| scripts (for APP-SQL) | topup-demo-balances.ps1 and topup-demo-balances.sql (balance top-up), install-topup-task.ps1 (scheduled task minibank-topup), and reset-demo-balances.sql (seed balances of version 1.2, no longer used) | APP-SQL | 17.10, 20.1 |

No logo is part of the pack. You can add your own in Chapter 15.4.

Version 1.4 of this runbook uses the same pack, MiniBank-source-pack-v1.3.zip. The only new file, transfer\applicationinsights-oracle.json, is written on HV-HOST-02 in Chapter 15.2 Step 3 and loaded into the cluster as the ConfigMap minibank-transfer-ai-config; the file transfer\applicationinsights.json inside the pack and the image stays unchanged.

**Version 1.5 uses MiniBank-source-pack-v1.4.zip** (104 files): the version 1.3 pack plus the code, scripts and configuration of the Priority 1 features - the new service in rates, transfer 1.2.0, the OpenShift files in openshift\p1 (operator, collector template, instrumentation, minibank-rates and the copy for the live act), onboard-live.ps1 and onboard-reset.ps1, the robot folder, incident.ps1, the alert templates in monitoring\alerts, the database script db\sqlserver\02-p1-tiers-customers.sql, API and web 1.2.0 and the workbook with the group Business impact (IDR). P1-B-DEPLOY.md and P1-DC-DEPLOY.md at the top of the zip give the deployment steps, and MANIFEST.md section 0b lists every new and changed file. The collector template holds placeholders (OTELCOL_CLIENT_ID, DCE_LOGS_ENDPOINT, DCE_METRICS_ENDPOINT, DCR_IMMUTABLE_ID, ACR_NAME) instead of lab values. openshift\10-deployment.yaml still names transfer 1.1.0: do not apply it again as it is (the lab runs 1.2.0).

Demo data (all synthetic):

| User ID | Name | Accounts |
|---|---|---|
| ANDI.WIJAYA | Andi Wijaya | 9901000011, 9901000012 |
| SITI.RAHAYU | Siti Rahayu | 9901000021, 9901000022 |
| BUDI.SANTOSO | Budi Santoso | 9901000031, 9901000032 (also used by the probe) |

Password for all three users: Demo123!. Transaction PIN: 123456. A transfer of IDR 50,000,000 or more gets the fraud decision REVIEW.

---

[&larr; Appendix A. Queries](appendix-a-queries.md) &nbsp;|&nbsp; [Guide index](README.md) &nbsp;|&nbsp; [Appendix C. Glossary &rarr;](appendix-c-glossary.md)
