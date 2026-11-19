# Reset the Scene 2 live onboarding: remove the annotation again -> new minibank-rates-copy pod WITHOUT the agent.
# Where: HV-HOST-02:   cd F:\Build\minibank\scripts ; .\onboard-reset.ps1
$ErrorActionPreference = 'Continue'
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
$oc = 'C:\Tools\oc\oc.exe'
$ns = 'minibank'; $app = 'minibank-rates-copy'
$val = & $oc get deployment/$app -n $ns -o "jsonpath={.spec.template.metadata.annotations['instrumentation\.opentelemetry\.io/inject-java']}"
if ($val) {
    & $oc patch deployment/$app -n $ns --type json --patch-file F:\Build\minibank\openshift\p1\onboard-remove.json
    & $oc rollout status deployment/$app -n $ns --timeout=180s
} else { Write-Host 'minibank-rates-copy is not onboarded - nothing to reset.' }
$p = (& $oc get pods -n $ns -l app=$app -o json | Out-String | ConvertFrom-Json).items | Where-Object { -not $_.metadata.deletionTimestamp } | Select-Object -Last 1
$ic = if ($p.spec.initContainers) { ($p.spec.initContainers | ForEach-Object { $_.name }) -join ', ' } else { '(none)' }
Write-Host ("Pod {0}: init containers {1} - ready for the next live onboarding." -f $p.metadata.name, $ic)
