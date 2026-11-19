# MiniBank lab safety guard for the noisy-neighbour VM BATCH-EOD (task minibank-batch-guard, every minute, SYSTEM).
# Independent of fault.ps1: turns BATCH-EOD off when it has run longer than 9 min, when an OpenShift node is not
# Ready, or when the OpenShift API does not answer while BATCH-EOD runs. Log C:\BuildLog\batch-guard.log
$ErrorActionPreference = 'SilentlyContinue'
$vm = Get-VM -Name 'BATCH-EOD'
if (-not $vm -or $vm.State -eq 'Off') { return }
function L([string]$t) { Add-Content -Path 'C:\BuildLog\batch-guard.log' -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' ' + $t) }
$why = ''
if ($vm.Uptime.TotalSeconds -gt 540) { $why = 'running ' + [int]$vm.Uptime.TotalSeconds + ' s (limit 540 s)' }
else {
    $env:KUBECONFIG = 'F:\Build\ocp\kubeconfig'
    $out = @(& 'C:\Tools\oc\oc.exe' get nodes --no-headers --request-timeout=15s 2>&1 | ForEach-Object { "$_" })
    $rows = @($out | Where-Object { $_ -match '^ocp-node-[123]\s+\S+' })
    $bad = @($rows | Where-Object { ($_ -split '\s+')[1] -notmatch '^Ready' } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($rows.Count -eq 0) { $why = 'OpenShift API not answering' } elseif ($bad.Count -gt 0) { $why = 'node not Ready: ' + ($bad -join ',') }
}
if ($why) { Stop-VM -Name 'BATCH-EOD' -TurnOff -Force; L ("GUARD STOP BATCH-EOD: $why -> " + (Get-VM -Name 'BATCH-EOD').State) }