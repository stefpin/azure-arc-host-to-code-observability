<#
  MiniBank v1.4 (P1) - create or update the two new log search alerts. Azure Cloud Shell - PowerShell (pack in ~/minibank),
  or any PowerShell with az signed in to the lab subscription.
    alr-minibank-failed-value-idr     (feature D) failed Transfer + QRIS payments (HTTP 5xx) worth IDR 100,000,000 or more
                                     in the last 10 minutes (measure FailedValueIdr, aggregation Total)
    alr-minibank-journey-success-low  (feature C) customer-journey success rate below 90 % AND at least 2 failed journeys
                                     in the last 10 minutes (table rows > 0)
  Both: severity 2, evaluated every 5 minutes over 10 minutes, scope = Application Insights appi-minibank (APPI_ID),
  no action group (alerts are only visible in the Portal), auto-resolve, tags demo=minibank owner=labadmin
  purpose=appmon-openshift-demo. The rules are one ARM deployment of minibank-p1-alerts.json in
  resource group rg-appmon-openshift-demo (queries = the two .kql files of this folder); a second run updates them.
    ./create-p1-alerts.ps1                                     # finds appi-minibank by name
    ./create-p1-alerts.ps1 -AppiId '<resource ID of appi-minibank>'
  Same with the parameter file: replace APPI_ID in minibank-p1-alerts.parameters.json, then
    az deployment group create -g rg-appmon-openshift-demo -n p1-minibank-alerts --template-file minibank-p1-alerts.json --parameters '@minibank-p1-alerts.parameters.json'
  Undo (rollback):
    az monitor scheduled-query delete -g rg-appmon-openshift-demo -n alr-minibank-failed-value-idr --yes
    az monitor scheduled-query delete -g rg-appmon-openshift-demo -n alr-minibank-journey-success-low --yes
#>
param(
    [string]$ResourceGroup = 'rg-appmon-openshift-demo',
    [string]$AppiId = 'APPI_ID',
    [string]$AppiName = 'appi-minibank',
    [string]$Location = ''      # empty = the region of appi-minibank (indonesiacentral in the lab)
)
$ErrorActionPreference = 'Stop'
if ($AppiId -eq 'APPI_ID') {
    $AppiId = az resource list --name $AppiName --resource-type 'microsoft.insights/components' --query '[0].id' -o tsv
    if (-not $AppiId) { throw "Application Insights $AppiName not found: pass -AppiId <resource ID>." }
}
if (-not $Location) { $Location = az resource show --ids $AppiId --query location -o tsv }
"Scope (APPI_ID): $AppiId   region: $Location"
$template = Join-Path $PSScriptRoot 'minibank-p1-alerts.json'
az deployment group create -g $ResourceGroup -n 'p1-minibank-alerts' --template-file $template `
    --parameters "appiId=$AppiId" "location=$Location" --query 'properties.provisioningState' -o tsv
if ($LASTEXITCODE -ne 0) { throw 'The deployment failed: see the az message above.' }
az monitor scheduled-query list -g $ResourceGroup `
    --query "[?starts_with(name, 'alr-minibank-')].{name:name, enabled:enabled, severity:severity, every:evaluationFrequency, window:windowSize}" -o table
