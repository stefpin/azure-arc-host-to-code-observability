# The build and demo guide

This is the complete guide behind the lab, written for beginners: every step says where to run it (the Azure Portal page and field, Cloud Shell, the Hyper-V host or a guest), what you should see, and what to do if it goes wrong. It was written while the lab was built and kept in step with it, so the "as built" notes and test records are real.

> [!NOTE]
> Names and identifiers were neutralised for publication. Values such as `<SUBSCRIPTION_ID>`, `<GRAFANA_HOST>`, `<ACR_NAME>` or `<EXEMPT_TAG>` are placeholders: replace them with your own. Dates, timings and measurements are as recorded in the lab in November 2026.
>
> Where the guide mentions the *source pack*, use the [app](../../app/) folder of this repository; the live boards, workbooks, functions and rules are in [lab-export](../../lab-export/).

**Start here:** [How to use this guide](01-how-to-use-this-runbook.md) &nbsp;·&nbsp; **Present it:** [Demo scenes and talk track](19-demo-scenes-and-talk-track.md) &nbsp;·&nbsp; **Understand the telemetry:** [Telemetry walkthrough](19-demo-scenes-and-talk-track.md#1916a-scene-13a---how-each-application-sends-telemetry-new-in-version-24-9-minutes)


## Part A - Understand and prepare

_What the lab answers, its design, the safety rules and the read-only pre-checks._

- [1. How to use this runbook](01-how-to-use-this-runbook.md)
- [2. Safety rules and approval gates](02-safety-rules-and-approval-gates.md)
- [3. What the bank asked for and how this demo answers it](03-what-the-bank-asked-for-and-how-this-demo-answers-it.md)
- [4. Demo design](04-demo-design.md)
- [5. Values, tools and the start of every session](05-values-tools-and-the-start-of-every-session.md)
- [6. Read-only pre-checks](06-read-only-pre-checks.md)

## Part B - Build the Azure foundation and the host

_Azure foundation: resource group, network, NAT gateway, Bastion, the nested Hyper-V host and the monitoring back end._

- [7. Resource group, network, NAT gateway and Bastion](07-resource-group-network-nat-gateway-and-bastion.md)
- [8. Create the Hyper-V host HV-HOST-02](08-create-the-hyper-v-host-hv-host-02.md)
- [9. Prepare HV-HOST-02](09-prepare-hv-host-02.md)
- [10. Monitoring and supporting Azure items](10-monitoring-and-supporting-azure-items.md)

## Part C - Build the virtual machines, OpenShift and the Azure Arc connection

_Guest VMs on Azure Arc with the Azure Monitor Agent, a three-node Red Hat OpenShift 4.20 cluster, Container insights and managed Prometheus._

- [11. Application VMs, Azure Arc and the Azure Monitor Agent](11-application-vms-azure-arc-and-the-azure-monitor-agent.md)
- [12. Red Hat OpenShift 4.20 cluster](12-red-hat-openshift-4-20-cluster.md)
- [13. OpenShift in Azure Arc, Container insights and managed Prometheus](13-openshift-in-azure-arc-container-insights-and-managed-promet.md)

## Part D - Build MiniBank, database monitoring, dashboards and alerts

_The MiniBank application, its three databases, database-internal monitoring, traffic, dashboards, alerts and telemetry filtering._

- [14. Databases](14-databases.md)
- [15. MiniBank services and screens](15-minibank-services-and-screens.md)
- [16. Database-internal monitoring of Oracle and PostgreSQL](16-database-internal-monitoring-of-oracle-and-postgresql.md)
- [17. Traffic, dashboards, alerts and telemetry filtering](17-traffic-dashboards-alerts-and-telemetry-filtering.md)

## Part E - Rehearse, present, reset and remove

_Rehearsal, the full demo rundown and talk track, reset, troubleshooting, daily operations, removal and the appendices._

- [18. Rehearsal](18-rehearsal.md)
- [19. Demo scenes and talk track](19-demo-scenes-and-talk-track.md)
- [20. Reset between rehearsals and after the demo](20-reset-between-rehearsals-and-after-the-demo.md)
- [21. Troubleshooting](21-troubleshooting.md)
- [22. Daily operations, cost and removal](22-daily-operations-cost-and-removal.md)
- [Appendix A. Queries](appendix-a-queries.md)
- [Appendix B. Contents of the source pack](appendix-b-contents-of-the-source-pack.md)
- [Appendix C. Glossary](appendix-c-glossary.md)
- [Appendix D. References](appendix-d-references.md)
- [Appendix E. Version history](appendix-e-version-history.md)

## Part F - Priority 1 features (version 1.5)

_Zero-code OpenTelemetry onboarding on OpenShift, business impact in currency, synthetic customer journeys and AI investigation._

- [23. What version 1.5 adds](23-what-version-1-5-adds.md)
- [24. Feature B - onboard a service with no code change](24-feature-b-onboard-a-service-with-no-code-change.md)
- [25. Feature D - business impact in IDR](25-feature-d-business-impact-in-idr.md)
- [26. Feature C - customer journeys and the browser robot](26-feature-c-customer-journeys-and-the-browser-robot.md)
- [27. Feature A - AI investigation with the Azure Copilot Observability Agent](27-feature-a-ai-investigation-with-the-azure-copilot-observabil.md)
- [28. Demo scenes in version 1.5](28-demo-scenes-in-version-1-5.md)
- [29. Build record and lessons (12 November 2026)](29-build-record-and-lessons-12-november-2026.md)

## Part G - Cross-layer root cause and mystery mode (version 1.7)

_Cross-layer root cause, mystery mode, live topology, host contention, look-ahead radar, trail and calendar, SLA service weather and the telemetry walkthrough._

- [30. What version 1.7 adds](30-what-version-1-7-adds.md)
- [31. Telemetry added for the cross-layer verdict](31-telemetry-added-for-the-cross-layer-verdict.md)
- [32. The verdict, the observer, the board and the recovery banner](32-the-verdict-the-observer-the-board-and-the-recovery-banner.md)
- [33. The fault command fault.ps1 and mystery mode](33-the-fault-command-fault-ps1-and-mystery-mode.md)
- [34. Alert e-mails](34-alert-e-mails.md)
- [35. Test results and readiness (13 November 2026)](35-test-results-and-readiness-13-november-2026.md)
- [36. Live topology map (version 1.8)](36-live-topology-map-version-1-8.md)
- [37. Host CPU contention on HV-HOST-02 (version 1.9)](37-host-cpu-contention-on-hv-host-02-version-1-9.md)
- [38. Version 2.0: the Mystery control window, the approved grading and the readiness tests](38-version-2-0-the-mystery-control-window-the-approved-grading.md)
- [39. Look-ahead: what will need attention next (version 2.1)](39-look-ahead-what-will-need-attention-next-version-2-1.md)
- [40. Look-ahead radar and the speed item (version 2.2)](40-look-ahead-radar-and-the-speed-item-version-2-2.md)
- [41. Service weather on the SLA board (version 2.3)](41-service-weather-on-the-sla-board-version-2-3.md)
- [42. Telemetry walkthrough scenes (version 2.4)](42-telemetry-walkthrough-scenes-version-2-4.md)
- [43. Look-ahead trail and month view with fast-forward (version 2.5)](43-look-ahead-trail-and-month-view-with-fast-forward-version-2.md)
