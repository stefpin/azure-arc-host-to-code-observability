<#
  MiniBank cross-layer lab - Mystery control window (Scene 7C presenter control), version 1.1, 16 Nov 2026.
  HV-HOST-02, Windows PowerShell 5.1 as Administrator.

  One window for the mystery draw of Scene 7C. Its buttons run the same tested commands as the presenter's window:
      number button + Start the draw     ->  fault.ps1 -Mystery -Pick <number>   (computer picks: fault.ps1 -Mystery)
      Reveal the answer                  ->  fault.ps1 -Reveal
      Stop every fault                   ->  fault.ps1 -Stop
      Status (also when the window opens) ->  fault.ps1 -Status
  The shuffle, the sealed fingerprint, the check that the fault took effect, the one-run-at-a-time rule, the watchdog and
  the ledger stay in fault.ps1. The window changes nothing in the app, the telemetry, the rules, the board or Azure.
  Closing the window does not stop a fault: the fault ends by itself after 8 minutes and the watchdog also stops it.

  Open it in the presenter's window (prompt PS F:\Build\minibank\scripts>):   .\mystery-window.ps1
  The prompt returns at once and the window opens (one window at a time).
  Log: C:\BuildLog\mystery-window.log (actions and results; never a card name).
  Backup way (unchanged): the PowerShell lines of Runbook Chapter 33.
  Tests: -Test parse (no window) | -Test stub -FaultScript <stand-in> | -Test real-status | -Test real-draw -TestPick <n>
#>
param(
    [string]$FaultScript = 'F:\Build\minibank\scripts\fault.ps1',
    [string]$StateDir = 'C:\ProgramData\MiniBank\fault',
    [string]$FaultLog = 'C:\BuildLog\fault.log',
    [string]$LogFile = 'C:\BuildLog\mystery-window.log',
    [switch]$Child,
    [switch]$NoRelaunch,
    [ValidateSet('', 'parse', 'stub', 'real-status', 'real-draw')][string]$Test = '',
    [ValidateRange(0, 6)][int]$TestPick = 0,
    [ValidateRange(60, 900)][int]$TestRevealAfterSec = 495,
    [string]$TestLog = 'C:\BuildLog\mystery-window-test.log'
)
$ErrorActionPreference = 'Continue'
$Version = '1.1'
$inv = [Globalization.CultureInfo]::InvariantCulture
$FpPattern = '[0-9A-Fa-f]{4} [0-9A-Fa-f]{4} [0-9A-Fa-f]{4} [0-9A-Fa-f]{4}'
$DrawMinutes = 8

# ================= helpers without a window (checked by -Test parse) =================
function Get-NowWib { return [DateTime]::UtcNow.AddHours(7) }

function Get-PoolCount([string]$Dir) {
    $n = 5
    if ($Dir -and (Test-Path -LiteralPath (Join-Path $Dir 'mystery-host.on'))) { $n = 6 }
    return $n
}

function Get-RunStartWib([string]$RunId) {
    if ($RunId -match '^[MSL](\d{8}-\d{6})$') { return [DateTime]::ParseExact($Matches[1], 'yyyyMMdd-HHmmss', $inv) }
    return $null
}

# end time of a run as a full WIB date-time: the date comes from the run id, the time from the command output
function Get-RunEndWib([string]$RunId, [string]$EndHms) {
    $s = Get-RunStartWib $RunId
    if (-not $s -or $EndHms -notmatch '^\d{2}:\d{2}:\d{2}$') { return $null }
    $t = [DateTime]::ParseExact($s.ToString('yyyy-MM-dd', $inv) + ' ' + $EndHms, 'yyyy-MM-dd HH:mm:ss', $inv)
    if ($t -lt $s) { $t = $t.AddDays(1) }
    return $t
}

function Format-Span([TimeSpan]$Span) {
    if ($Span.TotalSeconds -lt 0) { $Span = $Span.Negate() }
    return ('{0}:{1:00}' -f [int][Math]::Floor($Span.TotalMinutes), $Span.Seconds)
}

function ConvertFrom-DrawText([string]$Text) {
    $r = [ordered]@{ RunId = ''; Number = 0; Fingerprint = ''; EndWib = ''; Active = $false; Void = $false; Checking = $false; NotStarted = '' }
    if ($Text -match 'Not started: ([^\r\n]+)') { $r.NotStarted = $Matches[1].Trim() }
    if ($Text -match 'Draw (M\d{8}-\d{6}): number (\d+) is sealed') { $r.RunId = $Matches[1]; $r.Number = [int]$Matches[2] }
    if ($Text -match ('Sealed fingerprint: (' + $FpPattern + ')')) { $r.Fingerprint = $Matches[1].ToUpperInvariant() }
    if ($Text -match 'until (\d{2}:\d{2}:\d{2}) WIB') { $r.EndWib = $Matches[1] }
    if ($Text -match 'Fault is active') { $r.Active = $true }
    if ($Text -match 'did not take effect|is VOID') { $r.Void = $true }
    if ($Text -match 'Check still running') { $r.Checking = $true }
    return [pscustomobject]$r
}

function ConvertFrom-StatusText([string]$Text) {
    $r = [ordered]@{ None = $false; RunId = ''; Mode = ''; Active = $false; StartWib = ''; EndWib = ''; Number = 0; Fingerprint = ''; Checked = '' }
    if ($Text -match 'No fault run recorded') { $r.None = $true }
    if ($Text -match 'Run (\S+) \((\w+)\) (ACTIVE|ended): start (\d{2}:\d{2}:\d{2}) WIB, end (\d{2}:\d{2}:\d{2}) WIB') {
        $r.RunId = $Matches[1]; $r.Mode = $Matches[2]; $r.Active = ($Matches[3] -eq 'ACTIVE'); $r.StartWib = $Matches[4]; $r.EndWib = $Matches[5]
    }
    if ($Text -match ('Number (\d+), sealed fingerprint (' + $FpPattern + '), fault active check: ?(\w*)')) {
        $r.Number = [int]$Matches[1]; $r.Fingerprint = $Matches[2].ToUpperInvariant(); $r.Checked = $Matches[3]
    }
    return [pscustomobject]$r
}

function ConvertFrom-RevealText([string]$Text) {
    $r = [ordered]@{ NoDraw = $false; RunId = ''; Expected = ''; Match = ''; Line = ''; Outcome = ''; Ledger = '' }
    if ($Text -match 'No mystery draw to reveal') { $r.NoDraw = $true }
    if ($Text -match 'Draw (M\d{8}-\d{6}), number') { $r.RunId = $Matches[1] }
    if ($Text -match 'Expected layer: ([^\r\n]+)') { $r.Expected = $Matches[1].Trim() }
    if ($Text -match '-> (MATCH|DIFFERENT)') { $r.Match = $Matches[1] }
    if ($Text -match '(Board verdict: [^\r\n]+)') { $r.Line = $Matches[1].Trim() }
    if ($r.Line -match '-> (.+)$') { $r.Outcome = $Matches[1].Trim() }
    elseif ($r.Line -match 'none confirmed') { $r.Outcome = 'no confirmed answer yet' }
    if ($Text -cmatch '(?m)^(ledger[^\r\n]*)') { $r.Ledger = $Matches[1].Trim() }
    return [pscustomobject]$r
}

# colour of an output line: bad (red), warn (amber), good (green) or plain
function Get-LineKind([string]$Line) {
    if ($Line -cmatch 'WRONG LAYER|DIFFERENT|VOID|FALSE ALARM|FAILED' -or $Line -match 'did not take effect|Not started|upload failed|Could not start') { return 'bad' }
    if ($Line -match 'RIGHT LAYER \(late\)|NO VERDICT|none confirmed|no confirmed answer|Check still running|No mystery draw') { return 'warn' }
    if ($Line -cmatch 'RIGHT LAYER|MATCH' -or $Line -match 'Fault is active|is sealed|row\(s\) sent') { return 'good' }
    return 'plain'
}

function Test-Revealed([string]$RunId, [string]$Path) {
    if (-not $RunId -or -not $Path -or -not (Test-Path -LiteralPath $Path)) { return $false }
    return [bool](Select-String -LiteralPath $Path -Pattern ('revealed ' + $RunId) -SimpleMatch -Quiet)
}

function Invoke-ParseTests {
    $script:pp = 0; $script:pf = 0
    function Chk([string]$Name, [bool]$Ok) { if ($Ok) { $script:pp++ } else { $script:pf++; Write-Output ('FAIL ' + $Name) } }
    $nl = "`r`n"
    $sDraw = $nl + 'Draw M20261116-110512: number 3 is sealed.' + $nl + 'Sealed fingerprint: 4745 27d2 19ED 45BC   (write it down; -Reveal recomputes it)' + $nl +
             'The fault runs 8 minutes, until 11:13:17 WIB. Checking that it took effect ...' + $nl + 'Fault is active. Watch the board. When it shows a verdict: .\fault.ps1 -Reveal' + $nl
    $d = ConvertFrom-DrawText $sDraw
    Chk 'draw id' ($d.RunId -eq 'M20261116-110512'); Chk 'draw number' ($d.Number -eq 3); Chk 'draw fingerprint' ($d.Fingerprint -eq '4745 27D2 19ED 45BC')
    Chk 'draw end' ($d.EndWib -eq '11:13:17'); Chk 'draw active' ($d.Active -and -not $d.Void -and -not $d.NotStarted)
    $v = ConvertFrom-DrawText ($sDraw -replace 'Fault is active[^\r\n]+', 'The fault did not take effect: this draw is VOID and everything is reset. Ask the bank for a new number.')
    Chk 'draw void' ($v.Void -and -not $v.Active -and $v.Fingerprint)
    $c = ConvertFrom-DrawText ($sDraw -replace 'Fault is active[^\r\n]+', 'Check still running; see .\fault.ps1 -Status in a minute.')
    Chk 'draw still checking' ($c.Checking -and -not $c.Active -and -not $c.Void)
    $b = ConvertFrom-DrawText 'Not started: the Scene 5/6 incident (incident.ps1) is running; stop it first: incident.ps1 -Stop'
    Chk 'draw not started' ($b.NotStarted -like 'the Scene 5/6 incident*' -and -not $b.RunId)
    Chk 'status none' ((ConvertFrom-StatusText 'No fault run recorded.').None)
    $s = ConvertFrom-StatusText ('Run M20261116-110512 (mystery) ACTIVE: start 11:05:17 WIB, end 11:13:17 WIB' + $nl + 'Number 3, sealed fingerprint 4745 27D2 19ED 45BC, fault active check: True')
    Chk 'status mystery' ($s.RunId -eq 'M20261116-110512' -and $s.Mode -eq 'mystery' -and $s.Active -and $s.Number -eq 3 -and $s.Fingerprint -eq '4745 27D2 19ED 45BC' -and $s.Checked -eq 'True')
    $s2 = ConvertFrom-StatusText ('Run M20261116-110512 (mystery) ended: start 11:05:17 WIB, end 11:13:17 WIB' + $nl + 'Number 3, sealed fingerprint 4745 27D2 19ED 45BC, fault active check: ')
    Chk 'status mystery ended, check blank' (-not $s2.Active -and $s2.Checked -eq '' -and $s2.Number -eq 3)
    $s3 = ConvertFrom-StatusText 'Run S20261116-070003 (series) ACTIVE: start 07:00:08 WIB, end 08:52:08 WIB'
    Chk 'status series' ($s3.Mode -eq 'series' -and $s3.Active -and $s3.EndWib -eq '08:52:08' -and -not $s3.Fingerprint)
    $s4 = ConvertFrom-StatusText ('Run L20261115-231106 (labelled) ended: start 23:11:11 WIB, end 23:18:11 WIB' + $nl + 'Fault: cpu-win = APP-WIN')
    Chk 'status labelled' ($s4.Mode -eq 'labelled' -and -not $s4.Active)
    $rv = $nl + 'Draw M20261113-163615, number 3: Application: minibank-api Statement preview throws NullReferenceException' + $nl + 'Expected layer: Application' + $nl +
          'Fingerprint shown at the draw: 4745 27D2 19ED 45BC  recomputed now: 4745 27D2 19ED 45BC  -> MATCH (answer unchanged)' + $nl +
          'Board verdict: Application - minibank-api at 16:39:30 WIB (3 min 10 s after the fault started) -> RIGHT LAYER' + $nl + 'ledger: 1 row(s) sent' + $nl
    $r = ConvertFrom-RevealText $rv
    Chk 'reveal right' ($r.RunId -eq 'M20261113-163615' -and $r.Expected -eq 'Application' -and $r.Match -eq 'MATCH' -and $r.Outcome -eq 'RIGHT LAYER' -and $r.Ledger -eq 'ledger: 1 row(s) sent')
    $r2 = ConvertFrom-RevealText ($rv -replace '-> RIGHT LAYER', '-> RIGHT LAYER - early warning (yellow: customers not impacted)')
    Chk 'reveal early warning' ($r2.Outcome -eq 'RIGHT LAYER - early warning (yellow: customers not impacted)')
    $r3 = ConvertFrom-RevealText (($rv -replace '-> RIGHT LAYER', '-> WRONG LAYER') -replace 'MATCH \(answer unchanged\)', 'DIFFERENT')
    Chk 'reveal wrong + different' ($r3.Outcome -eq 'WRONG LAYER' -and $r3.Match -eq 'DIFFERENT')
    $r4 = ConvertFrom-RevealText ($rv -replace 'Board verdict: [^\r\n]+', 'Board verdict: none confirmed yet (14 verdict rows recorded since the start)')
    Chk 'reveal none confirmed' ($r4.Outcome -eq 'no confirmed answer yet')
    Chk 'reveal no draw' ((ConvertFrom-RevealText 'No mystery draw to reveal.').NoDraw)
    Chk 'colour right' ((Get-LineKind 'Board verdict: VM - APP-WIN at 11:03:10 WIB (3 min 5 s after the fault started) -> RIGHT LAYER') -eq 'good')
    Chk 'colour early warning' ((Get-LineKind '-> RIGHT LAYER - early warning, customers not affected') -eq 'good')
    Chk 'colour late' ((Get-LineKind '-> RIGHT LAYER (late)') -eq 'warn')
    Chk 'colour wrong' ((Get-LineKind '-> WRONG LAYER') -eq 'bad')
    Chk 'colour void' ((Get-LineKind 'The fault did not take effect: this draw is VOID and everything is reset.') -eq 'bad')
    Chk 'colour not started' ((Get-LineKind 'Not started: another run is active') -eq 'bad')
    Chk 'colour none confirmed' ((Get-LineKind 'Board verdict: none confirmed yet (3 verdict rows recorded since the start)') -eq 'warn')
    Chk 'colour plain (later)' ((Get-LineKind 'Check the board later; translate this') -eq 'plain')
    Chk 'colour ledger failed' ((Get-LineKind 'ledger upload FAILED: timeout') -eq 'bad')
    $e = Get-RunEndWib 'M20261116-235812' '00:06:17'
    Chk 'end over midnight' ($e -eq [DateTime]::ParseExact('2026-11-17 00:06:17', 'yyyy-MM-dd HH:mm:ss', $inv))
    $e2 = Get-RunEndWib 'M20261116-110512' '11:13:17'
    Chk 'end same day' ($e2 -eq [DateTime]::ParseExact('2026-11-16 11:13:17', 'yyyy-MM-dd HH:mm:ss', $inv))
    Chk 'end bad input' ($null -eq (Get-RunEndWib 'X123' '11:13:17'))
    Chk 'span' ((Format-Span ([TimeSpan]::FromSeconds(402))) -eq '6:42')
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('mwp-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Chk 'pool 5' ((Get-PoolCount $tmp) -eq 5)
    Set-Content -LiteralPath (Join-Path $tmp 'mystery-host.on') -Value 'on'
    Chk 'pool 6' ((Get-PoolCount $tmp) -eq 6)
    $lg = Join-Path $tmp 'fault.log'
    Set-Content -LiteralPath $lg -Value @('2026-11-16 11:05:12 mystery draw M20261116-110512 started (number 3, fingerprint 4745 27D2 19ED 45BC)', '2026-11-16 11:13:40 revealed M20261116-110512: x / board X after 190 s')
    Chk 'revealed found' (Test-Revealed 'M20261116-110512' $lg)
    Chk 'revealed not found' (-not (Test-Revealed 'M20261116-120000' $lg))
    Chk 'revealed missing log' (-not (Test-Revealed 'M20261116-110512' (Join-Path $tmp 'none.log')))
    Remove-Item -LiteralPath $tmp -Recurse -Force
    Write-Output ('PARSE TESTS: {0} of {1} passed' -f $script:pp, ($script:pp + $script:pf))
}

if ($Test -eq 'parse') { Invoke-ParseTests; return }

function Test-Admin {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    catch { return $false }
}

# ================= open the window in its own process, so the presenter's window stays free =================
if (-not $Child -and -not $NoRelaunch -and -not $Test) {
    if (-not (Test-Admin)) { Write-Host 'Open the window from the presenter''s window: Windows PowerShell as Administrator.'; return }
    $argList = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $PSCommandPath + '"'), '-Child')
    foreach ($p in @('FaultScript', 'StateDir', 'FaultLog', 'LogFile')) {
        if ($PSBoundParameters.ContainsKey($p)) { $argList += @(('-' + $p), ('"' + $PSBoundParameters[$p] + '"')) }
    }
    Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argList -WindowStyle Hidden | Out-Null
    Write-Host 'The Mystery control window is opening. This prompt stays free; the PowerShell lines of Chapter 33 remain the backup.'
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if ($Test -eq 'stub' -and ([IO.Path]::GetFileName($FaultScript) -notmatch 'stub')) { Write-Output 'TEST stub refused: -FaultScript must be a stand-in whose name contains "stub".'; return }
if (-not $Test -and -not (Test-Admin)) {
    [void][System.Windows.Forms.MessageBox]::Show('Open the Mystery control window from the presenter''s window (Windows PowerShell as Administrator).', 'MiniBank - Mystery draw', 'OK', 'Warning')
    return
}
$script:Mutex = $null
if (-not $Test) {
    $created = $false
    $script:Mutex = [System.Threading.Mutex]::new($true, 'Global\MiniBank-MysteryWindow', [ref]$created)
    if (-not $created) { [void][System.Windows.Forms.MessageBox]::Show('The Mystery control window is already open.', 'MiniBank - Mystery draw', 'OK', 'Information'); return }
}

# leftovers of earlier windows (a fault.ps1 run can keep its output file open while its fault runs)
Get-ChildItem -LiteralPath $env:TEMP -Filter 'mw-*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^mw-[0-9a-f]{8}\.(out|err)$' -and $_.LastWriteTime -lt (Get-Date).AddHours(-12) } | Remove-Item -Force -ErrorAction SilentlyContinue

# ================= state =================
$script:Cmd = $FaultScript
$script:Ready = $false
$script:Selected = -1            # -1 none, 0 computer picks, 1..6 the bank's number
$script:Draw = $null             # the current or last mystery draw
$script:OtherRun = $null         # an active series or labelled run (from Status)
$script:Jobs = New-Object System.Collections.ArrayList
$script:PoolCount = Get-PoolCount $StateDir
$script:CopiedUntil = $null
$script:LastError = ''
$script:Ticks = 0
try { $script:OutEnc = [Console]::OutputEncoding } catch { $script:OutEnc = [Text.Encoding]::Default }
if (-not $script:OutEnc) { $script:OutEnc = [Text.Encoding]::Default }
$LogTag = ''; if ($Test) { $LogTag = '[test ' + $Test + '] ' }

function Write-WindowLog([string]$Text) {
    try { Add-Content -LiteralPath $LogFile -Value ((Get-NowWib).ToString('yyyy-MM-dd HH:mm:ss', $inv) + ' ' + $LogTag + $Text) -Encoding ASCII } catch { }
}

function New-DrawState([string]$RunId, [int]$Number, [string]$Fingerprint, $End) {
    return [pscustomobject]@{ RunId = $RunId; Number = $Number; Fingerprint = $Fingerprint; End = $End; Active = $false; Void = $false
                              Stopped = $false; Revealed = $false; RevealedAt = $null; Outcome = '' }
}

# ================= window =================
$BrandBlue = [System.Drawing.Color]::FromArgb(0, 102, 174)
$Green = [System.Drawing.Color]::FromArgb(16, 124, 16)
$Red = [System.Drawing.Color]::FromArgb(197, 15, 31)
$Amber = [System.Drawing.Color]::FromArgb(157, 93, 0)
$Ink = [System.Drawing.Color]::FromArgb(32, 31, 30)
$Grey = [System.Drawing.Color]::FromArgb(96, 94, 92)
$Soft = [System.Drawing.Color]::FromArgb(243, 242, 241)
$White = [System.Drawing.Color]::White
function New-Font([string]$Name, [single]$Size, [string]$Style = 'Regular') { return (New-Object System.Drawing.Font($Name, $Size, [System.Drawing.FontStyle]$Style)) }
function New-Label([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, $Font, $Color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text; $l.Location = New-Object System.Drawing.Point($X, $Y); $l.Size = New-Object System.Drawing.Size($W, $H)
    $l.Font = $Font; $l.ForeColor = $Color; $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}
function New-Button([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, $Font, $Back, $Fore) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text; $b.Location = New-Object System.Drawing.Point($X, $Y); $b.Size = New-Object System.Drawing.Size($W, $H)
    $b.Font = $Font; $b.FlatStyle = 'Flat'; $b.BackColor = $Back; $b.ForeColor = $Fore; $b.UseVisualStyleBackColor = $false
    $b.FlatAppearance.BorderColor = $Fore; $b.FlatAppearance.BorderSize = 1; $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'MiniBank - Mystery draw (Scene 7C presenter control)'
$form.ClientSize = New-Object System.Drawing.Size(1000, 760)
$form.MinimumSize = New-Object System.Drawing.Size(640, 480)
$form.AutoScroll = $true
$form.AutoScrollMinSize = New-Object System.Drawing.Size(1000, 760)   # small screens (Bastion): scroll bars instead of cut-off buttons
$form.StartPosition = 'CenterScreen'
$form.BackColor = $White
$form.Font = New-Font 'Segoe UI' 11

$hdr = New-Object System.Windows.Forms.Panel
$hdr.Dock = 'Top'; $hdr.Height = 72; $hdr.BackColor = $BrandBlue
$lblTitle = New-Label 'MiniBank  |  Mystery draw' 16 8 640 38 (New-Font 'Segoe UI' 20 'Bold') $White
$lblSub = New-Label ('Scene 7C presenter control - the buttons run the same commands as the presenter''s window  (version ' + $Version + ')') 19 46 780 22 (New-Font 'Segoe UI' 9.5) $White
$lblClock = New-Label '' 740 16 240 40 (New-Font 'Segoe UI' 17 'Bold') $White
$lblClock.TextAlign = 'MiddleRight'; $lblClock.Anchor = 'Top, Right'
$hdr.Controls.Add($lblTitle); $hdr.Controls.Add($lblSub); $hdr.Controls.Add($lblClock)
$form.Controls.Add($hdr)

$lblStep1 = New-Label '1   the bank picks a number' 20 84 600 28 (New-Font 'Segoe UI' 14 'Bold') $Ink
$form.Controls.Add($lblStep1)
$script:NumberButtons = @()
for ($i = 1; $i -le 6; $i++) {
    $b = New-Button ([string]$i) (20 + ($i - 1) * 84) 118 72 72 (New-Font 'Segoe UI' 24 'Bold') $White $BrandBlue
    $b.Tag = $i; $b.FlatAppearance.BorderSize = 2; $b.Visible = ($i -le $script:PoolCount)
    $b.Add_Click({ param($s, $e) Invoke-Safe { Select-Number ([int]$s.Tag) } })
    $form.Controls.Add($b); $script:NumberButtons += $b
}
$px = 20 + $script:PoolCount * 84 + 6
$lblPool = New-Label ('{0} faults in {0} different layers are shuffled behind these numbers when you press Start. Nobody in the room knows which number hides which fault.' -f $script:PoolCount) $px 120 (980 - $px) 70 (New-Font 'Segoe UI' 10.5) $Grey
$form.Controls.Add($lblPool)
$lnkRandom = New-Object System.Windows.Forms.LinkLabel
$lnkRandom.Text = 'or let the computer pick the number'; $lnkRandom.Location = New-Object System.Drawing.Point(20, 196); $lnkRandom.Size = New-Object System.Drawing.Size(360, 26)
$lnkRandom.Font = New-Font 'Segoe UI' 11; $lnkRandom.LinkColor = $BrandBlue
$lnkRandom.Add_LinkClicked({ Invoke-Safe { Select-Number 0 } })
$form.Controls.Add($lnkRandom)

$btnStart = New-Button 'Start the draw' 20 230 300 58 (New-Font 'Segoe UI' 16 'Bold') $BrandBlue $White
$lblChosen = New-Label 'Choose the bank''s number first.' 340 246 640 30 (New-Font 'Segoe UI' 13) $Ink
$form.Controls.Add($btnStart); $form.Controls.Add($lblChosen)

$pnlFp = New-Object System.Windows.Forms.Panel
$pnlFp.Location = New-Object System.Drawing.Point(20, 300); $pnlFp.Size = New-Object System.Drawing.Size(960, 116)
$pnlFp.BackColor = $Soft; $pnlFp.BorderStyle = 'FixedSingle'; $pnlFp.Anchor = 'Top, Left, Right'
$lblFpTitle = New-Label '2   Sealed fingerprint - read it out loud and paste it into the meeting chat' 10 6 900 26 (New-Font 'Segoe UI' 12 'Bold') $Ink
$lblFp = New-Label '---- ---- ---- ----' 8 32 620 58 (New-Font 'Consolas' 34 'Bold') $Ink
$btnCopy = New-Button 'Copy' 650 40 150 46 (New-Font 'Segoe UI' 13 'Bold') $White $BrandBlue
$btnCopy.Enabled = $false
$lblDraw = New-Label '' 10 88 940 24 (New-Font 'Segoe UI' 10.5) $Grey
$pnlFp.Controls.Add($lblFpTitle); $pnlFp.Controls.Add($lblFp); $pnlFp.Controls.Add($btnCopy); $pnlFp.Controls.Add($lblDraw)
$form.Controls.Add($pnlFp)

$lblStatus = New-Label 'Opening ...' 20 426 960 34 (New-Font 'Segoe UI' 15 'Bold') $Ink
$lblStatus.Anchor = 'Top, Left, Right'
$lblCount = New-Label '' 20 462 960 26 (New-Font 'Segoe UI' 12) $Ink
$lblCount.Anchor = 'Top, Left, Right'
$form.Controls.Add($lblStatus); $form.Controls.Add($lblCount)

$btnReveal = New-Button '3   Reveal the answer' 20 498 300 58 (New-Font 'Segoe UI' 16 'Bold') $Green $White
$btnStatus = New-Button 'Status' 340 506 140 44 (New-Font 'Segoe UI' 12) $White $Ink
$btnStop = New-Button 'Stop every fault' 800 506 180 44 (New-Font 'Segoe UI' 12 'Bold') $Red $White
$btnStop.Anchor = 'Top, Right'
$form.Controls.Add($btnReveal); $form.Controls.Add($btnStatus); $form.Controls.Add($btnStop)

$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Location = New-Object System.Drawing.Point(20, 566); $rtb.Size = New-Object System.Drawing.Size(960, 180)
$rtb.Anchor = 'Top, Bottom, Left, Right'; $rtb.ReadOnly = $true; $rtb.BackColor = $White; $rtb.BorderStyle = 'FixedSingle'
$rtb.Font = New-Font 'Consolas' 11; $rtb.DetectUrls = $false; $rtb.TabStop = $false
$form.Controls.Add($rtb)

$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($btnStart, 'fault.ps1 -Mystery -Pick <number>')
$tip.SetToolTip($btnReveal, 'fault.ps1 -Reveal')
$tip.SetToolTip($btnStop, 'fault.ps1 -Stop (safe at any time)')
$tip.SetToolTip($btnStatus, 'fault.ps1 -Status')

# ================= behaviour =================
function Invoke-Safe([scriptblock]$Block) {
    try { & $Block }
    catch {
        $m = $_.Exception.Message
        Write-WindowLog ('window error: ' + $m)
        if ($m -ne $script:LastError) { $script:LastError = $m; try { Add-Output ('Window error: ' + $m) 'bad' } catch { } }
    }
}

function Confirm-Action([string]$Text, [string]$Title) {
    if ($Test) { Write-WindowLog ('auto-yes: ' + $Title); return $true }
    return ([System.Windows.Forms.MessageBox]::Show($form, $Text, $Title, 'YesNo', 'Question') -eq 'Yes')
}

function Get-KindColor([string]$Kind) {
    switch ($Kind) { 'good' { return $Green } 'bad' { return $Red } 'warn' { return $Amber } 'note' { return $Grey } }
    return $Ink
}

function Add-Output([string]$Text, [string]$Kind = '') {
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line.Trim() -eq '') { continue }
        $k = $Kind; if (-not $k) { $k = Get-LineKind $line }
        $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
        $rtb.SelectionColor = Get-KindColor $k
        $rtb.AppendText($line + "`r`n")
    }
    $rtb.SelectionStart = $rtb.TextLength; $rtb.ScrollToCaret()
}

function Set-Status([string]$Text, [string]$Kind) {
    $lblStatus.Text = $Text
    $lblStatus.ForeColor = Get-KindColor $Kind
}

function Select-Number([int]$N) {
    $script:Selected = $N
    if ($N -eq 0) { $lblChosen.Text = 'The computer picks the number at random.' }
    else { $lblChosen.Text = ('Number {0}, chosen by the bank.' -f $N) }
    Update-Buttons
}

function Show-Draw {
    $d = $script:Draw
    if (-not $d) { $lblFp.Text = '---- ---- ---- ----'; $lblDraw.Text = ''; $btnCopy.Enabled = $false; return }
    $lblFp.Text = $d.Fingerprint
    $t = 'Draw ' + $d.RunId + '   |   number ' + $d.Number
    if ($d.End) { $t += '   |   the fault ends by itself at ' + $d.End.ToString('HH:mm:ss', $inv) + ' WIB' }
    if ($d.Revealed -and $d.Outcome) { $t = 'Draw ' + $d.RunId + '   |   number ' + $d.Number + '   |   revealed: ' + $d.Outcome }
    $lblDraw.Text = $t
    $btnCopy.Enabled = [bool]$d.Fingerprint
}

function Start-FaultCommand([string]$Kind, [string]$Title, [string[]]$FaultArgs) {
    $id = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $out = Join-Path $env:TEMP ('mw-' + $id + '.out'); $err = Join-Path $env:TEMP ('mw-' + $id + '.err')
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script:Cmd + '"')) + $FaultArgs
    Add-Output ('--- ' + (Get-NowWib).ToString('HH:mm:ss', $inv) + ' WIB   ' + $Title + '   (fault.ps1 ' + ($FaultArgs -join ' ') + ')') 'note'
    try {
        $p = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err -ErrorAction Stop
    } catch {
        Add-Output ('Could not start the command: ' + $_.Exception.Message) 'bad'
        Write-WindowLog ($Kind + ' could not start: ' + $_.Exception.Message)
        return $null
    }
    $job = [pscustomobject]@{ Kind = $Kind; Title = $Title; Proc = $p; Out = $out; Err = $err; Pos = [long]0; Pending = ''; Text = ''; Started = (Get-NowWib) }
    [void]$script:Jobs.Add($job)
    Write-WindowLog ($Kind + ' started: fault.ps1 ' + ($FaultArgs -join ' '))
    Update-Buttons
    return $job
}

function Read-NewText([string]$Path, [long]$Pos) {
    $res = @{ Text = ''; Pos = $Pos }
    if (-not (Test-Path -LiteralPath $Path)) { return $res }
    $fs = $null
    try {
        $share = [System.IO.FileShare]([int][System.IO.FileShare]::ReadWrite -bor [int][System.IO.FileShare]::Delete)
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
        if ($fs.Length -gt $Pos) {
            [void]$fs.Seek($Pos, [System.IO.SeekOrigin]::Begin)
            $n = [int]($fs.Length - $Pos); $buf = New-Object byte[] $n
            $got = $fs.Read($buf, 0, $n)
            $res.Text = $script:OutEnc.GetString($buf, 0, $got); $res.Pos = $Pos + $got
        }
    } catch { } finally { if ($fs) { $fs.Dispose() } }
    return $res
}

function Add-JobText($Job, [string]$Text, [bool]$Flush) {
    $Job.Text += $Text
    $all = $Job.Pending + $Text
    $parts = $all -split "`n"
    $last = $parts.Count - 1
    for ($i = 0; $i -lt $last; $i++) { Add-Output ($parts[$i].TrimEnd("`r")) }
    if ($Flush) { if ($parts[$last].Trim()) { Add-Output ($parts[$last].TrimEnd("`r")) }; $Job.Pending = '' }
    else { $Job.Pending = $parts[$last] }
}

function Update-Jobs {
    foreach ($job in @($script:Jobs)) {
        $r = Read-NewText $job.Out $job.Pos; $job.Pos = $r.Pos
        if ($r.Text) { Add-JobText $job $r.Text $false; if ($job.Kind -eq 'draw') { Update-DrawProgress $job } }
        $exited = $false
        try { $exited = $job.Proc.HasExited } catch { $exited = $true }
        if ($exited) {
            Start-Sleep -Milliseconds 150
            $r = Read-NewText $job.Out $job.Pos; $job.Pos = $r.Pos
            Add-JobText $job $r.Text $true
            $e = Read-NewText $job.Err 0
            if ($e.Text.Trim()) { Add-Output ('Messages from the command: ' + $e.Text.Trim()) 'warn'; Write-WindowLog ($job.Kind + ' stderr: ' + ($e.Text.Trim() -replace '\s+', ' ')) }
            $script:Jobs.Remove($job)
            foreach ($f in @($job.Out, $job.Err)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
            Complete-Job $job
        }
    }
}

function Update-DrawProgress($Job) {
    $d = ConvertFrom-DrawText $Job.Text
    if ($d.RunId -and $d.Fingerprint -and (-not $script:Draw -or $script:Draw.RunId -ne $d.RunId)) {
        $script:Draw = New-DrawState $d.RunId $d.Number $d.Fingerprint (Get-RunEndWib $d.RunId $d.EndWib)
        Show-Draw
        Set-Status 'Number sealed. Checking that the fault took effect (up to 90 seconds) ...' 'warn'
        if ($Test) { Add-TestLine ('INFO fingerprint on screen {0:0.0} s after Start (command still running)' -f ((Get-NowWib) - $Job.Started).TotalSeconds) }
    }
}

function Complete-Job($Job) {
    switch ($Job.Kind) {
        'status' { Use-StatusResult (ConvertFrom-StatusText $Job.Text) }
        'draw' { Use-DrawResult (ConvertFrom-DrawText $Job.Text) }
        'reveal' { Use-RevealResult (ConvertFrom-RevealText $Job.Text) }
        'stop' { Use-StopResult $Job.Text }
    }
    Update-Buttons
}

function Get-ModeName([string]$Mode) {
    switch ($Mode) { 'series' { return 'blind test series' } 'labelled' { return 'labelled fault run' } }
    return ($Mode + ' run')
}

function Use-StatusResult($S) {
    if ($S.None) { $script:OtherRun = $null; if (-not $script:Draw) { Set-Status 'No fault is running. Ready for a draw.' 'plain' }; Write-WindowLog 'status: no run recorded'; return }
    if (-not $S.RunId) { Set-Status 'The status could not be read - see the lines below.' 'warn'; Write-WindowLog 'status: not readable'; return }
    $end = Get-RunEndWib $S.RunId $S.EndWib
    Write-WindowLog ('status: ' + $S.RunId + ' ' + $S.Mode + ' active=' + $S.Active)
    if ($S.Mode -eq 'mystery') {
        $script:OtherRun = $null
        if (-not $script:Draw -or $script:Draw.RunId -ne $S.RunId) { $script:Draw = New-DrawState $S.RunId $S.Number $S.Fingerprint $end }
        $d = $script:Draw
        if (Test-Revealed $S.RunId $FaultLog) { $d.Revealed = $true }
        if ($S.Checked -eq 'True') { $d.Active = $true }
        if ($S.Checked -eq 'False') { $d.Void = $true }
        $stale = $end -and (((Get-NowWib) - $end).TotalMinutes -gt 60)
        Show-Draw
        if ($d.Revealed) { Set-Status ('Draw ' + $S.RunId + ' has been revealed. Ready for a new draw.') 'plain' }
        elseif ($d.Void) { Set-Status 'The last draw was VOID (the fault did not take effect). Ask the bank for a new number.' 'warn' }
        elseif ($S.Active -and -not $d.Stopped) { if ($d.Active) { Set-Status 'Fault is active - watch the board. Reveal when it shows a verdict.' 'good' } else { Set-Status 'Number sealed. The check that the fault took effect is still running.' 'warn' } }
        elseif ($stale) { $d.Revealed = $true; Set-Status ('The last draw (' + $S.RunId + ') ended more than an hour ago. Ready for a new draw.') 'plain' }
        else { Set-Status ('The fault of draw ' + $S.RunId + ' has ended. Reveal to show and record the answer.') 'warn' }
    } else {
        if ($S.Active) {
            $script:OtherRun = [pscustomobject]@{ Mode = $S.Mode; RunId = $S.RunId; End = $end }
            Set-Status ('A ' + (Get-ModeName $S.Mode) + ' runs until ' + $S.EndWib + ' WIB. Start a draw after it ends.') 'warn'
        } else {
            $script:OtherRun = $null
            if (-not $script:Draw) { Set-Status 'No fault is running. Ready for a draw.' 'plain' }
        }
    }
}

# $Res = what the draw command printed; $ds = the window's draw state (PowerShell names ignore case, so they must differ)
function Use-DrawResult($Res) {
    if ($Res.NotStarted) { Set-Status ('Not started: ' + $Res.NotStarted) 'bad'; Write-WindowLog ('draw not started: ' + $Res.NotStarted); return }
    if (-not $Res.RunId -or -not $Res.Fingerprint) { Set-Status 'The draw did not report a fingerprint - see the lines below, then press Status.' 'bad'; Write-WindowLog 'draw: no fingerprint in the output'; return }
    if (-not $script:Draw -or $script:Draw.RunId -ne $Res.RunId) { $script:Draw = New-DrawState $Res.RunId $Res.Number $Res.Fingerprint (Get-RunEndWib $Res.RunId $Res.EndWib) }
    $ds = $script:Draw
    if ($Res.Void) { $ds.Void = $true; Set-Status 'VOID - the fault did not take effect and everything is reset. Ask the bank for a new number.' 'bad' }
    elseif ($Res.Active) { $ds.Active = $true; Set-Status 'Fault is active - watch the board. Reveal when it shows a verdict.' 'good' }
    elseif ($Res.Checking) { Set-Status 'The check is still running - press Status in a minute.' 'warn' }
    else { Set-Status 'The draw ended without a clear message - press Status.' 'warn' }
    Show-Draw
    Write-WindowLog ('draw ' + $Res.RunId + ' number ' + $Res.Number + ' fingerprint ' + $Res.Fingerprint + ' active=' + $Res.Active + ' void=' + $Res.Void + ' checking=' + $Res.Checking)
}

function Use-RevealResult($R) {
    if ($R.NoDraw) { Set-Status 'There is no mystery draw to reveal.' 'warn'; Write-WindowLog 'reveal: no draw'; return }
    if ($script:Draw -and (-not $R.RunId -or $R.RunId -eq $script:Draw.RunId)) {
        $script:Draw.Revealed = $true; $script:Draw.RevealedAt = Get-NowWib; $script:Draw.Outcome = $R.Outcome
    }
    $kind = 'warn'; if ($R.Line) { $kind = Get-LineKind $R.Line }
    $text = 'Expected layer: ' + $R.Expected + '   |   board: ' + $R.Outcome
    if (-not $R.Outcome) { $text = 'Revealed - see the lines below.' }
    if ($R.Match -eq 'DIFFERENT') { $text = 'Fingerprint DIFFERENT - ' + $text; $kind = 'bad' }
    Set-Status $text $kind
    Show-Draw
    Write-WindowLog ('reveal ' + $R.RunId + ': ' + $R.Outcome + ' | fingerprint ' + $R.Match + ' | ' + $R.Ledger)
}

function Use-StopResult([string]$Text) {
    $script:OtherRun = $null
    $d = $script:Draw
    if ($d -and -not $d.Revealed -and -not $d.Void) { $d.Stopped = $true; Set-Status 'Every fault is stopped and undone. Reveal to show and record the answer.' 'warn' }
    else { Set-Status 'Every fault is stopped and all undo steps ran.' 'plain' }
    Write-WindowLog ('stop: ' + (($Text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)))
}

function Update-Buttons {
    $main = @($script:Jobs | Where-Object { $_.Kind -ne 'stop' }).Count -gt 0
    $stopping = @($script:Jobs | Where-Object { $_.Kind -eq 'stop' }).Count -gt 0
    $now = Get-NowWib
    $d = $script:Draw
    $drawRunning = [bool]($d -and -not $d.Revealed -and -not $d.Void -and -not $d.Stopped -and $d.End -and $now -lt $d.End)
    $other = [bool]($script:OtherRun -and $script:OtherRun.End -and $now -lt $script:OtherRun.End)
    $canReveal = [bool]($d -and -not $d.Revealed -and -not $d.Void -and (-not $d.End -or ($now - $d.End).TotalMinutes -lt 60))
    $pickOk = $script:Ready -and -not $main -and -not $drawRunning
    foreach ($b in $script:NumberButtons) {
        $b.Enabled = $pickOk
        if ([int]$b.Tag -eq $script:Selected) { $b.BackColor = $BrandBlue; $b.ForeColor = $White } else { $b.BackColor = $White; $b.ForeColor = $BrandBlue }
    }
    $lnkRandom.Enabled = $pickOk
    $btnStart.Enabled = $pickOk -and -not $stopping -and -not $other -and ($script:Selected -ge 0)
    $btnReveal.Enabled = $script:Ready -and -not $main -and -not $stopping -and $canReveal
    $btnStatus.Enabled = $script:Ready -and -not $main
    $btnStop.Enabled = $script:Ready -and -not $stopping
}

function Update-Clock {
    $now = Get-NowWib
    $lblClock.Text = $now.ToString('HH:mm:ss', $inv) + ' WIB'
    $d = $script:Draw
    if ($d -and $d.End) {
        $start = $d.End.AddMinutes(-$DrawMinutes)
        if ($d.Revealed) { if ($d.RevealedAt) { $lblCount.Text = 'Revealed at ' + $d.RevealedAt.ToString('HH:mm:ss', $inv) + ' WIB, ' + (Format-Span ($d.RevealedAt - $start)) + ' after the fault started.' } else { $lblCount.Text = '' } }
        elseif ($d.Void) { $lblCount.Text = '' }
        elseif ($d.Stopped) { $lblCount.Text = 'The fault was stopped. Reveal to show and record the answer.' }
        elseif ($now -lt $d.End) { $lblCount.Text = 'Fault started at ' + $start.ToString('HH:mm:ss', $inv) + ' WIB (' + (Format-Span ($now - $start)) + ' ago)   |   it ends by itself in ' + (Format-Span ($d.End - $now)) }
        else { $lblCount.Text = 'The fault ended by itself at ' + $d.End.ToString('HH:mm:ss', $inv) + ' WIB. Reveal to show and record the answer.' }
    } elseif ($script:OtherRun -and $script:OtherRun.End) {
        if ($now -lt $script:OtherRun.End) { $lblCount.Text = 'The ' + (Get-ModeName $script:OtherRun.Mode) + ' ends at ' + $script:OtherRun.End.ToString('HH:mm:ss', $inv) + ' WIB (in ' + (Format-Span ($script:OtherRun.End - $now)) + '). Press Status after that.' }
        else { $lblCount.Text = 'The ' + (Get-ModeName $script:OtherRun.Mode) + ' should have ended. Press Status.' }
    } else { $lblCount.Text = '' }
    if ($script:CopiedUntil -and $now -gt $script:CopiedUntil) { $btnCopy.Text = 'Copy'; $script:CopiedUntil = $null }
}

$btnStart.Add_Click({ Invoke-Safe {
    if ($script:Selected -lt 0) { return }
    $d = $script:Draw
    if ($d -and -not $d.Revealed -and -not $d.Void) {
        if (-not (Confirm-Action ("Draw " + $d.RunId + " has not been revealed. Its result is only recorded by a reveal.`n`nStart a new draw anyway?") 'Last draw not revealed')) { return }
    }
    $what = 'number ' + $script:Selected; if ($script:Selected -eq 0) { $what = 'a number the computer picks' }
    if (-not (Confirm-Action ("Start the mystery draw for " + $what + "?`n`nThe fault runs 8 minutes. Reveal ends it earlier.") 'Start the draw')) { return }
    $fa = @('-Mystery'); if ($script:Selected -gt 0) { $fa += @('-Pick', [string]$script:Selected) }
    $script:Draw = $null; Show-Draw
    Set-Status 'Starting the draw ...' 'warn'
    [void](Start-FaultCommand 'draw' ('Start the draw (' + $what + ')') $fa)
} })
$btnReveal.Add_Click({ Invoke-Safe {
    if (-not (Confirm-Action "Reveal the answer now?`n`nThis ends the fault at once if it still runs, shows the card, checks the fingerprint and records the result." 'Reveal the answer')) { return }
    Set-Status 'Revealing ...' 'warn'
    [void](Start-FaultCommand 'reveal' 'Reveal the answer' @('-Reveal'))
} })
$btnStatus.Add_Click({ Invoke-Safe { [void](Start-FaultCommand 'status' 'Status' @('-Status')) } })
$btnStop.Add_Click({ Invoke-Safe {
    if (-not (Confirm-Action "Stop every fault now?`n`nThis ends every fault at once, also a blind test series, and runs all undo steps. It is safe at any time." 'Stop every fault')) { return }
    Set-Status 'Stopping every fault ...' 'warn'
    [void](Start-FaultCommand 'stop' 'Stop every fault' @('-Stop'))
} })
$btnCopy.Add_Click({ Invoke-Safe {
    if (-not $script:Draw -or -not $script:Draw.Fingerprint) { return }
    try { [System.Windows.Forms.Clipboard]::SetText($script:Draw.Fingerprint); $btnCopy.Text = 'Copied' }
    catch { $btnCopy.Text = 'Not copied' }
    $script:CopiedUntil = (Get-NowWib).AddSeconds(3)
    Write-WindowLog ('copy: ' + $btnCopy.Text)
} })

$form.Add_FormClosing({ param($s, $e) Invoke-Safe {
    $d = $script:Draw
    if (-not $Test -and $d -and -not $d.Revealed -and -not $d.Void -and -not $d.Stopped -and $d.End -and (Get-NowWib) -lt $d.End) {
        if (-not (Confirm-Action ("A draw is running. Closing this window does NOT stop the fault: it ends by itself at " + $d.End.ToString('HH:mm:ss', $inv) + " WIB and the watchdog also stops it.`n`nClose the window?") 'Close the window')) { $e.Cancel = $true }
    }
} })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({ Invoke-Safe { $script:Ticks++; Update-Jobs; Update-Clock; Update-Buttons } })

# ================= scripted tests (the same buttons, clicked by script; confirmations answered Yes) =================
$script:T = [pscustomobject]@{ Index = 0; Started = $null; Acted = $false; Pass = 0; Fail = 0; Begin = (Get-NowWib); Steps = @(); Done = $false }
function Add-TestLine([string]$Text) {
    try { Add-Content -LiteralPath $TestLog -Value ((Get-NowWib).ToString('yyyy-MM-dd HH:mm:ss', $inv) + ' [' + $Test + '] ' + $Text) -Encoding ASCII } catch { }
}
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { $script:T.Pass++; Add-TestLine ('PASS ' + $Name) } else { $script:T.Fail++; Add-TestLine ('FAIL ' + $Name + ' ' + $Detail) }
}
function Test-Idle { return (@($script:Jobs).Count -eq 0 -and $script:Ticks -gt 2) }
function New-Step([string]$Name, [scriptblock]$Act, [scriptblock]$Until, [scriptblock]$Check, [int]$Timeout = 60) {
    return [pscustomobject]@{ Name = $Name; Act = $Act; Until = $Until; Check = $Check; Timeout = $Timeout }
}
$idle = { Test-Idle }

if ($Test -eq 'stub') {
    $env:MW_STUB_MODE = 'ok'
    Remove-Item -LiteralPath (Join-Path $env:TEMP 'mw-stub-state.json') -Force -ErrorAction SilentlyContinue
    $script:T.Steps = @(
        (New-Step 'open' {} $idle { Test-That 'opening status read' ($rtb.Text -match 'No fault run recorded') ($lblStatus.Text)
                                     Test-That 'start disabled before a number' (-not $btnStart.Enabled)
                                     Test-That 'reveal disabled at open' (-not $btnReveal.Enabled)
                                     Test-That ('number buttons shown = pool ' + $script:PoolCount) (@($script:NumberButtons | Where-Object { $_.Visible }).Count -eq $script:PoolCount) }),
        (New-Step 'pick 3' { $script:NumberButtons[2].PerformClick() } { $true } { Test-That 'number 3 selected' ($script:Selected -eq 3 -and $lblChosen.Text -match '3') ($lblChosen.Text)
                                                                                 Test-That 'start enabled after a number' $btnStart.Enabled }),
        (New-Step 'draw' { $btnStart.PerformClick() } $idle { Test-That 'fingerprint shown' ($lblFp.Text -eq '4745 27D2 19ED 45BC') ($lblFp.Text)
                                                               Test-That 'status active (green)' ($lblStatus.Text -match 'active' -and $lblStatus.ForeColor.ToArgb() -eq $Green.ToArgb()) ($lblStatus.Text)
                                                               Test-That 'draw line has id and number' ($lblDraw.Text -match 'Draw M\d{8}-\d{6}' -and $lblDraw.Text -match 'number 3') ($lblDraw.Text)
                                                               Test-That 'countdown running' ($lblCount.Text -match 'ends by itself in') ($lblCount.Text)
                                                               Test-That 'reveal enabled while the fault runs' $btnReveal.Enabled
                                                               Test-That 'start and numbers locked while the fault runs' (-not $btnStart.Enabled -and -not $script:NumberButtons[0].Enabled) } 60),
        (New-Step 'copy' { $btnCopy.PerformClick() } { $true } { Test-That 'copy button answered' ($btnCopy.Text -in 'Copied', 'Not copied') ($btnCopy.Text); Add-TestLine ('INFO copy result in this session: ' + $btnCopy.Text) }),
        (New-Step 'status during draw' { $btnStatus.PerformClick() } $idle { Test-That 'status keeps the draw' ($lblFp.Text -eq '4745 27D2 19ED 45BC' -and $lblStatus.Text -match 'active' -and $btnReveal.Enabled) ($lblStatus.Text) }),
        (New-Step 'reveal' { $btnReveal.PerformClick() } $idle { Test-That 'reveal shows right layer (green)' ($lblStatus.Text -match 'RIGHT LAYER' -and $lblStatus.ForeColor.ToArgb() -eq $Green.ToArgb()) ($lblStatus.Text)
                                                                 Test-That 'output shows MATCH' ($rtb.Text -match 'MATCH')
                                                                 Test-That 'reveal locked after the reveal' (-not $btnReveal.Enabled)
                                                                 Test-That 'start open again after the reveal' $btnStart.Enabled
                                                                 Test-That 'countdown says revealed' ($lblCount.Text -match '^Revealed at') ($lblCount.Text) }),
        (New-Step 'busy refusal' { $env:MW_STUB_MODE = 'busy'; $script:NumberButtons[0].PerformClick(); $btnStart.PerformClick() } $idle {
                                                                 Test-That 'not started shown in red' ($lblStatus.Text -match '^Not started' -and $lblStatus.ForeColor.ToArgb() -eq $Red.ToArgb()) ($lblStatus.Text)
                                                                 Test-That 'no reveal after a refusal' (-not $btnReveal.Enabled)
                                                                 Test-That 'start open after a refusal' $btnStart.Enabled }),
        (New-Step 'void draw' { $env:MW_STUB_MODE = 'void'; $btnStart.PerformClick() } $idle {
                                                                 Test-That 'VOID shown in red' ($lblStatus.Text -match 'VOID' -and $lblStatus.ForeColor.ToArgb() -eq $Red.ToArgb()) ($lblStatus.Text)
                                                                 Test-That 'no reveal after VOID' (-not $btnReveal.Enabled)
                                                                 Test-That 'start open after VOID' $btnStart.Enabled }),
        (New-Step 'random draw' { $env:MW_STUB_MODE = 'ok'; Select-Number 0; $btnStart.PerformClick() } $idle {
                                                                 Test-That 'random number read from the output' ($script:Draw -and $script:Draw.Number -eq 4 -and $lblDraw.Text -match 'number 4') ($lblDraw.Text)
                                                                 Test-That 'random draw active' ($lblStatus.Text -match 'active') ($lblStatus.Text) }),
        (New-Step 'stop during draw' { $btnStop.PerformClick() } $idle {
                                                                 Test-That 'stop leaves the reveal open' ($btnReveal.Enabled -and $lblStatus.Text -match 'Reveal') ($lblStatus.Text)
                                                                 Test-That 'stop output shown' ($rtb.Text -match 'stopped run') }),
        (New-Step 'reveal after stop' { $btnReveal.PerformClick() } $idle { Test-That 'revealed after stop' ($script:Draw.Revealed -and -not $btnReveal.Enabled) ($lblStatus.Text) }),
        (New-Step 'log written' {} { $true } { Test-That 'window log has entries' ((Test-Path -LiteralPath $LogFile) -and (Select-String -LiteralPath $LogFile -Pattern '[test stub] reveal' -SimpleMatch -Quiet)) })
    )
}
elseif ($Test -eq 'real-status') {
    $script:T.Steps = @(
        (New-Step 'open' {} $idle { Test-That 'status read from fault.ps1' ($rtb.Text -match 'No fault run recorded|Run [MSL]\d{8}-\d{6}') ($rtb.Text -replace '\s+', ' ')
                                     Test-That 'no window error' ($rtb.Text -notmatch 'Window error|Could not start') ($rtb.Text -replace '\s+', ' ')
                                     Add-TestLine ('INFO status line: ' + $lblStatus.Text)
                                     Add-TestLine ('INFO pool buttons: ' + @($script:NumberButtons | Where-Object { $_.Visible }).Count) } 60)
    )
}
elseif ($Test -eq 'real-draw') {
    $script:T.Steps = @(
        (New-Step 'open' {} $idle { Test-That 'status read' ($rtb.Text -match 'No fault run recorded|Run [MSL]\d{8}-\d{6}')
                                     Test-That 'no other run active' (-not $script:OtherRun) ($lblStatus.Text)
                                     if ($script:OtherRun) { $script:T.Index = 98 } } 60),
        (New-Step 'pick' { if ($TestPick -gt 0) { $script:NumberButtons[$TestPick - 1].PerformClick() } else { Select-Number 0 } } { $true } {
                                     Test-That ('picked ' + $TestPick) ($script:Selected -eq $TestPick -and $btnStart.Enabled) ($lblChosen.Text) }),
        (New-Step 'draw' { $btnStart.PerformClick() } $idle {
                                     Test-That 'fingerprint shown' ($lblFp.Text -match ('^' + $FpPattern + '$')) ($lblFp.Text)
                                     Add-TestLine ('INFO draw ' + $lblDraw.Text + ' | status: ' + $lblStatus.Text)
                                     Test-That 'fault active or VOID reported' ($lblStatus.Text -match 'active|VOID') ($lblStatus.Text)
                                     if ($script:Draw -and $script:Draw.Void) { $script:T.Index = 98 } } 180),
        (New-Step 'wait for the board' {} { $script:Draw -and $script:Draw.End -and (Get-NowWib) -ge $script:Draw.End.AddMinutes(-$DrawMinutes).AddSeconds($TestRevealAfterSec) } {
                                     Add-TestLine ('INFO countdown at reveal time: ' + $lblCount.Text) } ($TestRevealAfterSec + 120)),
        (New-Step 'reveal' { $btnReveal.PerformClick() } $idle {
                                     Test-That 'revealed' ($script:Draw.Revealed -and -not $btnReveal.Enabled) ($lblStatus.Text)
                                     Test-That 'fingerprint MATCH' ($rtb.Text -match 'MATCH \(answer unchanged\)')
                                     Add-TestLine ('RESULT ' + $script:Draw.RunId + ' number ' + $script:Draw.Number + ' | ' + $lblStatus.Text)
                                     foreach ($l in ($rtb.Text -split "`r?`n" | Where-Object { $_ -match '^(Draw M|Expected layer|Fingerprint shown|Board verdict|ledger)' })) { Add-TestLine ('REVEAL ' + $l) } } 240)
    )
}

if ($Test) {
    $script:TestTimer = New-Object System.Windows.Forms.Timer
    $script:TestTimer.Interval = 1000
    $script:TestTimer.Add_Tick({ Invoke-Safe {
        $T = $script:T
        if ($T.Done) { return }
        $limit = 1200; if ($Test -eq 'real-draw') { $limit = $TestRevealAfterSec + 600 }
        if (((Get-NowWib) - $T.Begin).TotalSeconds -gt $limit) { Test-That 'whole test within its time limit' $false; $T.Index = 99 }
        if ($T.Index -ge @($T.Steps).Count) {
            $T.Done = $true
            Add-TestLine ('SUMMARY ' + $Test + ': ' + $T.Pass + ' passed, ' + $T.Fail + ' failed')
            $script:TestTimer.Stop(); $form.Close(); return
        }
        $st = $T.Steps[$T.Index]
        if (-not $T.Acted) { $T.Acted = $true; $T.Started = Get-NowWib; Add-TestLine ('STEP ' + $st.Name); & $st.Act; return }
        $ok = $false; try { $ok = [bool](& $st.Until) } catch { $ok = $false }
        if ($ok) { & $st.Check; $T.Index++; $T.Acted = $false; return }
        if (((Get-NowWib) - $T.Started).TotalSeconds -gt $st.Timeout) { Test-That ($st.Name + ' finished in time') $false ('after ' + $st.Timeout + ' s'); $T.Index++; $T.Acted = $false }
    } })
    if (Test-Path -LiteralPath $TestLog) { Add-TestLine '----' }
    Add-TestLine ('BEGIN ' + $Test + ' window ' + $Version + ' command ' + $script:Cmd)
}

$form.Add_Shown({ Invoke-Safe {
    if (-not (Test-Path -LiteralPath $script:Cmd)) {
        Set-Status ('Command not found: ' + $script:Cmd) 'bad'; Write-WindowLog ('command not found: ' + $script:Cmd)
    } else {
        $script:Ready = $true
        Add-Output ('Mystery control window ' + $Version + '  |  runs ' + $script:Cmd + '  |  pool ' + $script:PoolCount + ' faults') 'note'
        Write-WindowLog ('window opened, version ' + $Version + ', pool ' + $script:PoolCount)
        [void](Start-FaultCommand 'status' 'Status when the window opened' @('-Status'))
    }
    Update-Buttons
    $timer.Start()
    if ($Test) { $script:TestTimer.Start() }
} })

# fit the window to a small screen (for example a Bastion session); the layout keeps its size and scroll bars appear
$scr = [System.Windows.Forms.Screen]::PrimaryScreen
if ($scr) {
    $wa = $scr.WorkingArea
    $fitW = [Math]::Min(1000, $wa.Width - 24); $fitH = [Math]::Min(760, $wa.Height - 48)
    if ($fitW -lt 1000 -or $fitH -lt 760) { $form.ClientSize = New-Object System.Drawing.Size([Math]::Max(600, $fitW), [Math]::Max(440, $fitH)) }
}
# Application.Run instead of ShowDialog: it also works where Windows shows no desktop (the scripted tests run as SYSTEM)
[System.Windows.Forms.Application]::Run($form)
$timer.Stop()
Write-WindowLog 'window closed'
if ($script:Mutex) { try { $script:Mutex.ReleaseMutex() } catch { }; $script:Mutex.Dispose() }
if ($Test) {
    Write-Output ('TEST ' + $Test + ': ' + $script:T.Pass + ' passed, ' + $script:T.Fail + ' failed (details: ' + $TestLog + ')')
    if (Test-Path -LiteralPath $TestLog) { Get-Content -LiteralPath $TestLog -Tail 40 | Where-Object { $_ -match 'FAIL|RESULT|REVEAL|SUMMARY|INFO' } | ForEach-Object { Write-Output $_ } }
}
