# Lab export

A read-only export of the live lab, taken with `az` list/show calls, the Grafana HTTP API (GET only) and a read-only run-command on the Hyper-V host. Names and identifiers were neutralised with the same rules as the rest of the repository; see the placeholder table in the [front page](../README.md#build-it-yourself).

| Folder | What it holds | Count |
|---|---|---|
| [grafana/](grafana/) | Azure Managed Grafana boards (import: Dashboards > New > Import, then pick your Azure Monitor and Prometheus data sources) | 4 |
| [workbooks/](workbooks/) | Azure Monitor workbooks (Workbooks > New > Advanced editor > Gallery template, paste) | 2 |
| [kql-functions/](kql-functions/) | Saved KQL functions of the Log Analytics workspace, including the root-cause rules, topology and look-ahead | 11 |
| [data-collection-rules/](data-collection-rules/) | Data collection rules, with their streams, transformations and destinations | 11 |
| [data-collection-endpoints/](data-collection-endpoints/) | Data collection endpoints | 3 |
| [alerts/](alerts/) | Log alert rules, smart detection and the action group | 7 |
| [custom-tables/](custom-tables/) | Schemas of the custom tables (`*_CL`) | 4 |
| [prometheus-rule-groups/](prometheus-rule-groups/) | Managed Prometheus recording rules created by the cluster onboarding | 3 |
| [inventory.json](inventory.json) | Every resource of the lab resource group and of the managed resource group: name, type, location, SKU | 1 |
| [host/](host/) | Scripts and manifests from the Hyper-V host: fault cards, mystery mode, observer, look-ahead collector, OpenShift extras | 10 |

## Grafana boards

| File | Title | Panels |
|---|---|---|
| [minibank-lookahead.json](grafana/minibank-lookahead.json) | MiniBank - Look-ahead | 30 |
| [minibank-openshift-db.json](grafana/minibank-openshift-db.json) | MiniBank - OpenShift and Databases | 12 |
| [minibank-rootcause.json](grafana/minibank-rootcause.json) | MiniBank - Cross-layer root cause | 23 |
| [minibank-sla.json](grafana/minibank-sla.json) | MiniBank - SLA and Failure Rate | 14 |

## Workbooks

- [minibank-sla-and-failure-rate.workbook](workbooks/minibank-sla-and-failure-rate.workbook): MiniBank - SLA and Failure Rate
- [minibank-look-ahead.workbook](workbooks/minibank-look-ahead.workbook): MiniBank - Look-ahead

## KQL functions

- [MiniBankDrillMinutes.kql](kql-functions/MiniBankDrillMinutes.kql)
- [MiniBankDrills.kql](kql-functions/MiniBankDrills.kql)
- [MiniBankErrorBudget.kql](kql-functions/MiniBankErrorBudget.kql)
- [MiniBankLaDaily.kql](kql-functions/MiniBankLaDaily.kql)
- [MiniBankLaForecast.kql](kql-functions/MiniBankLaForecast.kql)
- [MiniBankLaReadings.kql](kql-functions/MiniBankLaReadings.kql)
- [MiniBankLaScore.kql](kql-functions/MiniBankLaScore.kql)
- [MiniBankLookahead.kql](kql-functions/MiniBankLookahead.kql)
- [MiniBankRecovering.kql](kql-functions/MiniBankRecovering.kql)
- [MiniBankRootCause.kql](kql-functions/MiniBankRootCause.kql)
- [MiniBankTopology.kql](kql-functions/MiniBankTopology.kql)

## Host files

- [minibank/openshift/xlayer/10-netprobe-configmap.yaml](host/minibank/openshift/xlayer/10-netprobe-configmap.yaml)
- [minibank/openshift/xlayer/20-netprobe-deployment.yaml](host/minibank/openshift/xlayer/20-netprobe-deployment.yaml)
- [minibank/openshift/xlayer/netprobe.sh](host/minibank/openshift/xlayer/netprobe.sh)
- [minibank/scripts/batch-guard.ps1](host/minibank/scripts/batch-guard.ps1)
- [minibank/scripts/fault.ps1](host/minibank/scripts/fault.ps1)
- [minibank/scripts/mystery-window.ps1](host/minibank/scripts/mystery-window.ps1)
- [minibank/scripts/verdict-observer.ps1](host/minibank/scripts/verdict-observer.ps1)
- [tools/minibank-lookahead.ps1](host/tools/minibank-lookahead.ps1)
- [tools/mw-stub.ps1](host/tools/mw-stub.ps1)
- [tools/myst17.ps1](host/tools/myst17.ps1)

> [!NOTE]
> Resource IDs inside these files point to the original names with the placeholders `<SUBSCRIPTION_ID>` and friends. Replace them before you deploy anything, and create the custom tables and the data collection endpoint before the rules that use them.
