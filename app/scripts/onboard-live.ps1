# MiniBank Scene 2 - LIVE zero-code onboarding of minibank-rates-copy with the Red Hat build of OpenTelemetry.
# Where: HV-HOST-02, second PowerShell window:   cd F:\Build\minibank\scripts ; .\onboard-live.ps1
# Reset after the session or a rehearsal:        .\onboard-reset.ps1
# What it does: shows the pod BEFORE, applies ONE annotation (patch file), waits for the new pod,
# shows the pod AFTER (agent injected, same image), then makes 3 test calls through the OpenShift Route.
param([int]$Calls = 3)
$ErrorActionPreference = 'Continue'
$env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
$oc = 'C:\Tools\oc\oc.exe'
$ns = 'minibank'; $app = 'minibank-rates-copy'
$patch = 'F:\Build\minibank\openshift\p1\onboard-patch.yaml'
$route = 'http://minibank-rates-copy.apps.ocp-minibank.minibank-demo.lab'

function Title([string]$t) { Write-Host ''; Write-Host (' ' + $t + ' ').PadRight(78, '=') -ForegroundColor Cyan }
function Show([string]$c) { Write-Host "PS> $c" -ForegroundColor Yellow }
function PodFacts {
    $all = (& $oc get pods -n $ns -l app=$app -o json | Out-String | ConvertFrom-Json).items
    $p = $all | Where-Object { -not $_.metadata.deletionTimestamp -and $_.status.phase -eq 'Running' } |
        Sort-Object { [datetime]$_.metadata.creationTimestamp } | Select-Object -Last 1
    $c = $p.spec.containers[0]
    $envs = @{}; foreach ($e in $c.env) { $envs[$e.name] = $e.value }
    $digest = (($p.status.containerStatuses | Where-Object { $_.name -eq $c.name }).imageID -split '@')[-1]
    [ordered]@{
        'Pod'                         = $p.metadata.name
        'Image'                       = $c.image
        'Image digest'                = $digest
        'Init containers'             = $(if ($p.spec.initContainers) { ($p.spec.initContainers | ForEach-Object { $_.name }) -join ', ' } else { '(none)' })
        'JAVA_TOOL_OPTIONS'           = $(if ($envs['JAVA_TOOL_OPTIONS']) { $envs['JAVA_TOOL_OPTIONS'] } else { '(not set)' })
        'OTEL_SERVICE_NAME'           = $(if ($envs['OTEL_SERVICE_NAME']) { $envs['OTEL_SERVICE_NAME'] } else { '(not set)' })
        'OTEL_EXPORTER_OTLP_ENDPOINT' = $(if ($envs['OTEL_EXPORTER_OTLP_ENDPOINT']) { $envs['OTEL_EXPORTER_OTLP_ENDPOINT'] } else { '(not set)' })
    }
}
function PrintFacts($f) { foreach ($k in $f.Keys) { Write-Host ('  {0,-28} {1}' -f $k, $f[$k]) } }

Title 'BEFORE: minibank-rates-copy runs WITHOUT any monitoring'
$before = PodFacts; PrintFacts $before

Title 'The only change: one annotation on the Deployment (patch file)'
Show "Get-Content $patch"
Get-Content $patch | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
Show "oc patch deployment/$app -n $ns --type merge --patch-file $patch"
& $oc patch deployment/$app -n $ns --type merge --patch-file $patch
Show "oc rollout status deployment/$app -n $ns"
& $oc rollout status deployment/$app -n $ns --timeout=180s
Start-Sleep -Seconds 2

Title 'AFTER: the operator injected the OpenTelemetry Java agent'
$after = PodFacts; PrintFacts $after
$same = ($before['Image digest'] -eq $after['Image digest'])
Write-Host ''
Write-Host ('  Same image, no rebuild, no code change: {0}' -f $same) -ForegroundColor $(if ($same) { 'Green' } else { 'Red' })

Title "$Calls test calls through the OpenShift Route"
$tests = @(@{ch = 'TRANSFER'; amt = 2500000 }, @{ch = 'QRIS'; amt = 85000 }, @{ch = 'TRANSFER'; amt = 25000000 })
for ($i = 0; $i -lt $Calls; $i++) {
    $t = $tests[$i % $tests.Count]
    $u = "$route/api/rates/check?channel=$($t.ch)&amount=$($t.amt)"
    Show "Invoke-RestMethod $u"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-RestMethod -Uri $u -TimeoutSec 20
        Write-Host ('  -> {0} IDR {1:N0}: fee {2}, within limit {3}, rule set {4} ({5} ms)' -f $r.channel, [decimal]$r.amount, $r.fee, $r.withinLimit, $r.ruleSet, $sw.ElapsedMilliseconds)
    } catch { Write-Host "  -> call failed: $($_.Exception.Message)" -ForegroundColor Red }
}
Write-Host ''
Write-Host '  Next: Application Insights (appi-minibank) > Logs, query B.1 - minibank-rates-copy appears within 1 to 2 minutes.' -ForegroundColor Cyan
