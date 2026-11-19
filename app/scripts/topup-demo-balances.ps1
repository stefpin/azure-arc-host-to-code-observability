<#
  MiniBank v1.4 balance top-up - runs on APP-SQL (scheduled task minibank-topup as SYSTEM, or by hand as Administrator).
  Runs topup-demo-balances.sql against MiniBankDemo with Windows authentication (all 66 accounts of the 33 customers, by tier)
  and appends one line per run to C:\BuildLog\topup.log: per tier the number of accounts and the total balance before -> after,
  then the 6 accounts of the traffic generator customers (ANDI, SITI, BUDI) one by one. Exit code 1 when the top-up failed.
    powershell -ExecutionPolicy Bypass -File C:\Build\minibank\scripts\topup-demo-balances.ps1
#>
param(
    [string]$SqlFile = 'C:\Build\minibank\scripts\topup-demo-balances.sql',
    [string]$LogFile = 'C:\BuildLog\topup.log'
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
try {
    $cn = New-Object System.Data.SqlClient.SqlConnection 'Server=localhost;Database=MiniBankDemo;Integrated Security=True;Connect Timeout=30'
    $cn.Open()
    $before = @{}
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = 'SELECT AccountNo, Balance FROM dbo.Accounts'
    $rd = $cmd.ExecuteReader()
    while ($rd.Read()) { $before[$rd.GetString(0)] = $rd.GetDecimal(1) }
    $rd.Close()
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = Get-Content $SqlFile -Raw
    $cmd.CommandTimeout = 60
    $rd = $cmd.ExecuteReader()
    $tiers = [ordered]@{}
    $generator = @()
    $changed = 0; $total = 0
    while ($rd.Read()) {
        $acct = $rd.GetString(0)
        $after = $rd.GetDecimal(1)
        $tier = '?'
        if ($rd.FieldCount -gt 2 -and -not $rd.IsDBNull(2)) { $tier = $rd.GetString(2) }
        $old = [decimal]0
        if ($before.ContainsKey($acct)) { $old = $before[$acct] }
        if (-not $tiers.Contains($tier)) { $tiers[$tier] = @{ Accounts = 0; Before = [decimal]0; After = [decimal]0 } }
        $tiers[$tier].Accounts++; $tiers[$tier].Before += $old; $tiers[$tier].After += $after
        $total++
        if ($old -ne $after) { $changed++ }
        if ($acct -match '^99010000[123][12]$') { $generator += ('{0} {1:N0} -> {2:N0}' -f $acct, $old, $after) }
    }
    $rd.Close(); $cn.Close()
    $parts = foreach ($t in $tiers.Keys) { '{0} {1} accounts {2:N0} -> {3:N0}' -f $t, $tiers[$t].Accounts, $tiers[$t].Before, $tiers[$t].After }
    $line = "$stamp OK $total accounts, $changed changed | " + ($parts -join ' | ') + ' | generator ' + ($generator -join '; ')
    Add-Content -Path $LogFile -Value $line
    Write-Output $line
} catch {
    $line = "$stamp FAILED " + $_.Exception.Message
    Add-Content -Path $LogFile -Value $line
    Write-Output $line
    exit 1
}
