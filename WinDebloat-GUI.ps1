param([switch]$SelfTest, [string]$SelfTestPage = 'dashboard')

$script:GuiRoot = $PSScriptRoot
if (-not $script:GuiRoot) { $script:GuiRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$script:LogDir = Join-Path $script:GuiRoot 'logs'
$script:StartupLogPath = Join-Path $script:LogDir 'gui-startup.log'

function Write-StartupLog {
    param([string]$Message)
    try {
        if (-not (Test-Path -LiteralPath $script:LogDir)) {
            New-Item -ItemType Directory -Path $script:LogDir -Force -ErrorAction Stop | Out-Null
        }
        $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $Message
        Add-Content -LiteralPath $script:StartupLogPath -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {
        try {
            $fallbackDir = Join-Path $env:LOCALAPPDATA 'WinDebloat\logs'
            if (-not (Test-Path -LiteralPath $fallbackDir)) {
                New-Item -ItemType Directory -Path $fallbackDir -Force -ErrorAction SilentlyContinue | Out-Null
            }
            $script:StartupLogPath = Join-Path $fallbackDir 'gui-startup.log'
            Add-Content -LiteralPath $script:StartupLogPath -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $Message) -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
        }
    }
}

trap {
    Write-StartupLog ('FATAL: ' + $_.Exception.ToString())
    if ($splash) {
        try { $splash.Close() } catch {
        }
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("WinDebloat GUI could not start.`r`n`r`n" + $_.Exception.Message + "`r`n`r`nLog: " + $script:StartupLogPath, 'WinDebloat startup error', 'OK', 'Error') | Out-Null
    } catch {
    }
    exit 1
}

Write-StartupLog '--- GUI launch ---'
Write-StartupLog ("User=" + $env:USERNAME + " PS=" + $PSVersionTable.PSVersion.ToString() + " CLR=" + [System.Environment]::Version.ToString() + " OS=" + [System.Environment]::OSVersion.VersionString)
Write-StartupLog ("Path=" + $script:GuiRoot)

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-StartupLog ("Admin=" + $isAdmin)
if (-not $isAdmin -and -not $SelfTest) {
    $elevatePath = $PSCommandPath
    if (-not $elevatePath) { $elevatePath = $MyInvocation.MyCommand.Path }
    Write-StartupLog 'Requesting elevation via UAC.'
    try {
        $elevateArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $elevatePath + '"'
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $elevateArgs -ErrorAction Stop
        Write-StartupLog 'Elevation request sent; exiting launcher.'
    } catch {
        Write-StartupLog ('Elevation failed: ' + $_.Exception.ToString())
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            [System.Windows.Forms.MessageBox]::Show("Administrator permission is required to open WinDebloat.`r`n`r`nApprove the UAC prompt when starting Debloat-GUI.bat, or run it from an administrator account.`r`n`r`nDetails: " + $_.Exception.Message + "`r`n`r`nLog: " + $script:StartupLogPath, 'Administrator required', 'OK', 'Warning') | Out-Null
        } catch {
        }
    }
    exit
}
Write-StartupLog 'Running elevated.'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Write-StartupLog 'WinForms assemblies loaded.'

try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $eventArgs)
        Write-StartupLog ('UI exception: ' + $eventArgs.Exception.ToString())
        try {
            [System.Windows.Forms.MessageBox]::Show("An unexpected error occurred.`r`n`r`n" + $eventArgs.Exception.Message + "`r`n`r`nLog: " + $script:StartupLogPath, 'WinDebloat error', 'OK', 'Error') | Out-Null
        } catch {
        }
    })
    [System.AppDomain]::CurrentDomain.add_UnhandledException({
        param($sender, $eventArgs)
        Write-StartupLog ('Unhandled exception: ' + $eventArgs.ExceptionObject.ToString())
    })
    Write-StartupLog 'Exception handlers attached.'
} catch {
    Write-StartupLog ('Exception handler setup failed: ' + $_.Exception.Message)
}

$script:UiSource = Join-Path $script:GuiRoot 'ui\WinDebloatUi.cs'

try {
    if (-not ('ToggleSwitch' -as [type])) {
        if (-not (Test-Path -LiteralPath $script:UiSource)) {
            throw 'WinDebloatUi.cs was not found in the ui folder next to WinDebloat-GUI.ps1.'
        }
        $runtimeDirectory = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $wpfDirectory = Join-Path $runtimeDirectory 'WPF'
        $uiReferences = @(
            'System.dll'
            'System.Core.dll'
            'System.Drawing.dll'
            'System.Windows.Forms.dll'
            (Join-Path $wpfDirectory 'PresentationCore.dll')
            (Join-Path $wpfDirectory 'WindowsBase.dll')
        )
        Add-Type -Path $script:UiSource -ReferencedAssemblies $uiReferences -ErrorAction Stop
    }
    Write-StartupLog 'UI classes compiled.'
} catch {
    Write-StartupLog ('UI compile failed: ' + $_.Exception.ToString())
    [System.Windows.Forms.MessageBox]::Show("Could not initialize the interface.`r`n`r`nThe UI source is ui\WinDebloatUi.cs and it needs .NET Framework 4.8. Try OneClick-Debloat.bat (CLI) on this PC.`r`n`r`n$($_.Exception.Message)`r`n`r`nLog: $script:StartupLogPath", 'Initialization error', 'OK', 'Error') | Out-Null
    exit 1
}

$script:ScriptRoot = $script:GuiRoot
$script:EnginePath = Join-Path $script:ScriptRoot 'WinDebloat.ps1'
Write-StartupLog ('Engine=' + $script:EnginePath)

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
Write-StartupLog 'Visual styles enabled.'

if (-not (Test-Path -LiteralPath $script:EnginePath)) {
    Write-StartupLog 'Engine file missing.'
    [System.Windows.Forms.MessageBox]::Show('WinDebloat.ps1 was not found next to this GUI.', 'Missing engine', 'OK', 'Error') | Out-Null
    exit 1
}

$script:ColorBg = [System.Drawing.Color]::FromArgb(246, 247, 249)
$script:ColorSidebar = [System.Drawing.Color]::FromArgb(255, 255, 255)
$script:ColorNavActive = [System.Drawing.Color]::FromArgb(239, 246, 255)
$script:ColorCard = [System.Drawing.Color]::FromArgb(255, 255, 255)
$script:ColorCardSoft = [System.Drawing.Color]::FromArgb(248, 250, 252)
$script:ColorBorder = [System.Drawing.Color]::FromArgb(229, 231, 235)
$script:ColorBorderSoft = [System.Drawing.Color]::FromArgb(238, 242, 247)
$script:ColorBorderStrong = [System.Drawing.Color]::FromArgb(209, 213, 219)
$script:ColorText = [System.Drawing.Color]::FromArgb(17, 24, 39)
$script:ColorTextStrong = [System.Drawing.Color]::FromArgb(15, 23, 42)
$script:ColorMuted = [System.Drawing.Color]::FromArgb(107, 114, 128)
$script:ColorDim = [System.Drawing.Color]::FromArgb(156, 163, 175)
$script:ColorAccent = [System.Drawing.Color]::FromArgb(37, 99, 235)
$script:ColorAccentHover = [System.Drawing.Color]::FromArgb(29, 78, 216)
$script:ColorAccentPressed = [System.Drawing.Color]::FromArgb(30, 64, 175)
$script:ColorAccentSoft = [System.Drawing.Color]::FromArgb(239, 246, 255)
$script:ColorGreen = [System.Drawing.Color]::FromArgb(21, 128, 61)
$script:ColorGreenSoft = [System.Drawing.Color]::FromArgb(236, 253, 245)
$script:ColorGreenDot = [System.Drawing.Color]::FromArgb(16, 185, 129)
$script:ColorOrange = [System.Drawing.Color]::FromArgb(180, 83, 9)
$script:ColorOrangeSoft = [System.Drawing.Color]::FromArgb(255, 247, 237)
$script:ColorOrangeBorder = [System.Drawing.Color]::FromArgb(254, 215, 170)
$script:ColorRed = [System.Drawing.Color]::FromArgb(220, 38, 38)
$script:ColorHover = [System.Drawing.Color]::FromArgb(243, 244, 246)
$script:ColorChip = [System.Drawing.Color]::FromArgb(248, 250, 252)
$script:ColorLogText = [System.Drawing.Color]::FromArgb(51, 65, 85)

$script:IconDirectory = Join-Path $script:GuiRoot 'assets\icons'
$script:Icons = @{}

function Import-UiIcons {
    if (-not (Test-Path -LiteralPath $script:IconDirectory)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $script:IconDirectory -Filter '*.svg' -File -ErrorAction SilentlyContinue) {
        try {
            $svg = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $paths = [regex]::Matches($svg, '\sd="([^"]+)"')
            if ($paths.Count -gt 0) {
                $script:Icons[$file.BaseName] = (($paths | ForEach-Object { $_.Groups[1].Value.Trim() }) -join ' ')
            }
        } catch {
            Write-StartupLog ('Icon load failed: ' + $file.Name + ' - ' + $_.Exception.Message)
        }
    }
    Write-StartupLog ('Icons loaded: ' + $script:Icons.Count)
}

function Get-IconData {
    param([string]$Name)
    if ($script:Icons.ContainsKey($Name)) { return $script:Icons[$Name] }
    return ''
}

Import-UiIcons

$script:Pages = @{}
$script:PageMeta = @{
    dashboard   = @{ Title = 'Dashboard'; Subtitle = 'Overview, system status and quick presets' }
    apps        = @{ Title = 'App Cleanup'; Subtitle = 'Choose which preinstalled apps to remove' }
    performance = @{ Title = 'Performance'; Subtitle = 'Background services, indexing and responsiveness' }
    privacy     = @{ Title = 'Privacy'; Subtitle = 'Telemetry, ads, search and background activity' }
    advanced    = @{ Title = 'Advanced'; Subtitle = 'Risky tweaks, cleanup and network settings' }
    log         = @{ Title = 'Activity Log'; Subtitle = 'Live output from the debloat engine' }
}
$script:Nav = @{}
$script:Toggles = @{}
$script:ToggleOrder = New-Object System.Collections.Generic.List[string]
$script:RiskyKeys = @{}
$script:PresetButtons = @()
$script:DnsButtons = @{}
$script:DnsValue = 'None'
$script:Running = $false
$script:Runner = $null
$script:RunStart = $null
$script:DryRunActive = $false
$script:PresetOrder = @(
    'apps', 'aggressive', 'xbox', 'onedrive',
    'privacy', 'background', 'copilot', 'services', 'tasks',
    'visuals', 'mouse', 'startdelay', 'gamedvr', 'sysmain', 'searchidx', 'wer',
    'recall', 'location', 'llmnr', 'drivers',
    'temp', 'updatecache', 'docache', 'thumbs', 'recycle',
    'hibernate', 'ultimate', 'restore'
)
$script:Presets = @{
    Safe = @{
        apps = $true; aggressive = $false; xbox = $false; onedrive = $false
        privacy = $true; background = $true; copilot = $true; services = $true; tasks = $true
        visuals = $false; mouse = $false; startdelay = $false; gamedvr = $false
        sysmain = $false; searchidx = $false; wer = $false
        recall = $false; location = $false; llmnr = $false; drivers = $false
        temp = $false; updatecache = $false; docache = $false; thumbs = $false; recycle = $false
        hibernate = $false; ultimate = $false; restore = $true
        Dns = 'None'
    }
    Balanced = @{
        apps = $true; aggressive = $false; xbox = $false; onedrive = $false
        privacy = $true; background = $true; copilot = $true; services = $true; tasks = $true
        visuals = $true; mouse = $true; startdelay = $true; gamedvr = $true
        sysmain = $false; searchidx = $false; wer = $false
        recall = $true; location = $true; llmnr = $false; drivers = $false
        temp = $true; updatecache = $true; docache = $true; thumbs = $true; recycle = $true
        hibernate = $false; ultimate = $false; restore = $true
        Dns = 'None'
    }
    Aggressive = @{
        apps = $true; aggressive = $true; xbox = $false; onedrive = $false
        privacy = $true; background = $true; copilot = $true; services = $true; tasks = $true
        visuals = $true; mouse = $true; startdelay = $true; gamedvr = $true
        sysmain = $true; searchidx = $true; wer = $true
        recall = $true; location = $true; llmnr = $true; drivers = $true
        temp = $true; updatecache = $true; docache = $true; thumbs = $true; recycle = $true
        hibernate = $true; ultimate = $true; restore = $true
        Dns = 'Cloudflare'
    }
}

function Add-BodyControl {
    param($Body, $Control)
    $row = $Body.RowCount
    $Body.RowCount = $row + 1
    $Body.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
    $Body.Controls.Add($Control, 0, $row)
}

function Add-StackCard {
    param($Stack, $Card)
    $row = $Stack.RowCount
    $Stack.RowCount = $row + 1
    $Stack.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
    $Stack.Controls.Add($Card, 0, $row)
}

function New-Separator {
    $line = New-Object System.Windows.Forms.Panel
    $line.Height = 1
    $line.Dock = [System.Windows.Forms.DockStyle]::Top
    $line.BackColor = $script:ColorBorder
    $line.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
    return $line
}

function New-Card {
    param([string]$Title, [string]$Subtitle, [string]$Icon = '')
    $card = New-Object CardPanel
    $card.FillColor = $script:ColorCard
    $card.BorderColor = $script:ColorBorder
    $card.CornerRadius = 14
    $card.Dock = [System.Windows.Forms.DockStyle]::Top
    $card.AutoSize = $true
    $card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $card.Padding = [System.Windows.Forms.Padding]::new(22, 18, 22, 20)
    $card.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 14)

    $body = New-Object System.Windows.Forms.TableLayoutPanel
    $body.Dock = [System.Windows.Forms.DockStyle]::Top
    $body.AutoSize = $true
    $body.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $body.BackColor = $script:ColorCard
    $body.ColumnCount = 1
    $body.RowCount = 0
    $body.ColumnStyles.Clear()
    $body.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $body.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
    $card.Controls.Add($body)

    if ($Title) {
        $header = New-Object System.Windows.Forms.TableLayoutPanel
        $header.Dock = [System.Windows.Forms.DockStyle]::Top
        $header.AutoSize = $true
        $header.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $header.BackColor = $script:ColorCard
        $header.ColumnCount = 2
        $header.RowCount = 1
        $header.ColumnStyles.Clear()
        $iconWidth = 0
        if ($Icon) { $iconWidth = 42 }
        $header.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, $iconWidth)) | Out-Null
        $header.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
        $header.RowStyles.Clear()
        $header.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
        $header.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 9)

        $textFlow = New-Object System.Windows.Forms.FlowLayoutPanel
        $textFlow.Dock = [System.Windows.Forms.DockStyle]::Fill
        $textFlow.AutoSize = $true
        $textFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $textFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
        $textFlow.WrapContents = $false
        $textFlow.BackColor = $script:ColorCard
        $textFlow.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
        $textFlow.Padding = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)

        if ($Icon) {
            $iconBox = New-Object IconBox
            $iconBox.Size = [System.Drawing.Size]::new(36, 36)
            $iconBox.GlyphData = Get-IconData $Icon
            $iconBox.BoxColor = $script:ColorAccentSoft
            $iconBox.IconColor = $script:ColorAccent
            $iconBox.CornerRadius = 10
            $iconBox.IconInset = 9
            $iconBox.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 0)
            $header.Controls.Add($iconBox, 0, 0)
        }

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = $Title
        $titleLabel.AutoSize = $true
        $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 11.25, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = $script:ColorTextStrong
        $titleLabel.BackColor = $script:ColorCard
        $titleLabel.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
        $textFlow.Controls.Add($titleLabel)

        if ($Subtitle) {
            $subLabel = New-Object System.Windows.Forms.Label
            $subLabel.Text = $Subtitle
            $subLabel.AutoSize = $true
            $subLabel.MaximumSize = [System.Drawing.Size]::new(700, 0)
            $subLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.75)
            $subLabel.ForeColor = $script:ColorMuted
            $subLabel.BackColor = $script:ColorCard
            $subLabel.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 0)
            $textFlow.Controls.Add($subLabel)
        }

        $header.Controls.Add($textFlow, 1, 0)
        Add-BodyControl -Body $body -Control $header
    }
    return [pscustomobject]@{ Card = $card; Body = $body }
}

function New-ToggleRow {
    param(
        [string]$Key,
        [string]$Title,
        [string]$Description,
        [bool]$Checked,
        [bool]$Risky
    )
    $row = New-Object System.Windows.Forms.TableLayoutPanel
    $row.Dock = [System.Windows.Forms.DockStyle]::Top
    $row.AutoSize = $true
    $row.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $row.BackColor = $script:ColorCard
    $row.ColumnCount = 2
    $row.RowCount = 1
    $row.ColumnStyles.Clear()
    $row.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $row.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 64)) | Out-Null
    $row.RowStyles.Clear()
    $row.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
    $row.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
    $row.Padding = [System.Windows.Forms.Padding]::new(0, 12, 0, 12)

    $text = New-Object System.Windows.Forms.FlowLayoutPanel
    $text.Dock = [System.Windows.Forms.DockStyle]::Fill
    $text.AutoSize = $true
    $text.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $text.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $text.WrapContents = $false
    $text.BackColor = $script:ColorCard
    $text.Margin = [System.Windows.Forms.Padding]::new(0, 0, 12, 0)

    $titleFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $titleFlow.AutoSize = $true
    $titleFlow.WrapContents = $false
    $titleFlow.BackColor = $script:ColorCard
    $titleFlow.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.AutoSize = $true
    $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 9.75)
    $titleLabel.ForeColor = $script:ColorText
    $titleLabel.BackColor = $script:ColorCard
    $titleLabel.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
    $titleFlow.Controls.Add($titleLabel)

    if ($Risky) {
        $badge = New-Object Pill
        $badge.Text = 'RISKY'
        $badge.GlyphData = Get-IconData 'alert-triangle'
        $badge.GlyphColor = $script:ColorOrange
        $badge.FillColor = $script:ColorOrangeSoft
        $badge.TextColor = $script:ColorOrange
        $badge.Margin = [System.Windows.Forms.Padding]::new(8, 1, 0, 0)
        $badge.Size = $badge.GetPreferredSize([System.Drawing.Size]::Empty)
        $titleFlow.Controls.Add($badge)
        $script:RiskyKeys[$Key] = $true
    }

    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = $Description
    $descLabel.AutoSize = $true
    $descLabel.MaximumSize = [System.Drawing.Size]::new(640, 0)
    $descLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
    $descLabel.ForeColor = $script:ColorMuted
    $descLabel.BackColor = $script:ColorCard
    $descLabel.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 0)

    $text.Controls.Add($titleFlow)
    $text.Controls.Add($descLabel)

    $toggle = New-Object ToggleSwitch
    $toggle.Checked = $Checked
    $toggle.OnColor = $script:ColorAccent
    $toggle.OnHoverColor = $script:ColorAccentHover
    $toggle.OffColor = $script:ColorBorderStrong
    $toggle.OffHoverColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
    $toggle.KnobColor = [System.Drawing.Color]::White
    $toggle.Anchor = [System.Windows.Forms.AnchorStyles]::Right
    $toggle.Margin = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
    $toggle.add_CheckedChanged({
        Update-Dashboard
    })

    $row.Controls.Add($text, 0, 0)
    $row.Controls.Add($toggle, 1, 0)

    $script:Toggles[$Key] = $toggle
    $script:ToggleOrder.Add($Key)
    return $row
}

function Add-ToggleRow {
    param($Body, [string]$Key, [string]$Title, [string]$Description, [bool]$Checked, [bool]$Risky = $false)
    Add-BodyControl -Body $Body -Control (New-Separator)
    $row = New-ToggleRow -Key $Key -Title $Title -Description $Description -Checked $Checked -Risky $Risky
    Add-BodyControl -Body $Body -Control $row
}

function New-StatBlock {
    param([string]$Value, [string]$Label, [int]$Width = 184)
    $panel = New-Object CardPanel
    $panel.Width = $Width
    $panel.Height = 66
    $panel.FillColor = $script:ColorCardSoft
    $panel.BorderColor = $script:ColorBorderSoft
    $panel.CornerRadius = 10
    $panel.Margin = [System.Windows.Forms.Padding]::new(0, 0, 10, 10)

    $valueLabel = New-Object System.Windows.Forms.Label
    $valueLabel.Text = $Value
    $valueLabel.AutoSize = $false
    $valueLabel.AutoEllipsis = $true
    $valueLabel.Size = [System.Drawing.Size]::new(($Width - 24), 24)
    $valueLabel.Location = [System.Drawing.Point]::new(13, 9)
    $valueLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $valueLabel.Font = [System.Drawing.Font]::new('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
    $valueLabel.ForeColor = $script:ColorTextStrong
    $valueLabel.BackColor = $script:ColorCardSoft

    $captionLabel = New-Object System.Windows.Forms.Label
    $captionLabel.Text = $Label
    $captionLabel.AutoSize = $true
    $captionLabel.Location = [System.Drawing.Point]::new(13, 38)
    $captionLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8)
    $captionLabel.ForeColor = $script:ColorMuted
    $captionLabel.BackColor = $script:ColorCardSoft

    $panel.Controls.Add($valueLabel)
    $panel.Controls.Add($captionLabel)
    return [pscustomobject]@{ Panel = $panel; Value = $valueLabel; Caption = $captionLabel }
}

function New-NavItem {
    param([string]$Key, [string]$Text, [string]$Icon)
    $button = New-Object NavButton
    $button.Text = $Text
    $button.GlyphData = Get-IconData $Icon
    $button.Width = 212
    $button.Height = 40
    $button.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 4)
    $button.ActiveBackColor = $script:ColorNavActive
    $button.HoverBackColor = $script:ColorHover
    $button.ActiveForeColor = $script:ColorAccentHover
    $button.NormalForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
    $button.ActiveIconColor = $script:ColorAccent
    $button.NormalIconColor = $script:ColorMuted
    $button.Tag = $Key
    $button.add_Click({
        Show-Page ([string]$this.Tag)
    })
    $script:Nav[$Key] = [pscustomobject]@{ Button = $button }
    return $button
}

function Add-ComboRow {
    param($Body, $Title, $Description, [string[]]$Items, [int]$SelectedIndex)
    Add-BodyControl -Body $Body -Control (New-Separator)

    $row = New-Object System.Windows.Forms.TableLayoutPanel
    $row.Dock = [System.Windows.Forms.DockStyle]::Top
    $row.AutoSize = $true
    $row.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $row.BackColor = $script:ColorCard
    $row.ColumnCount = 2
    $row.RowCount = 1
    $row.ColumnStyles.Clear()
    $row.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $row.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 200)) | Out-Null
    $row.RowStyles.Clear()
    $row.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
    $row.Padding = [System.Windows.Forms.Padding]::new(0, 12, 0, 12)

    $text = New-Object System.Windows.Forms.FlowLayoutPanel
    $text.Dock = [System.Windows.Forms.DockStyle]::Fill
    $text.AutoSize = $true
    $text.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $text.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $text.WrapContents = $false
    $text.BackColor = $script:ColorCard
    $text.Margin = [System.Windows.Forms.Padding]::new(0, 0, 12, 0)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.AutoSize = $true
    $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 9.75)
    $titleLabel.ForeColor = $script:ColorText
    $titleLabel.BackColor = $script:ColorCard
    $titleLabel.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)

    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = $Description
    $descLabel.AutoSize = $true
    $descLabel.MaximumSize = [System.Drawing.Size]::new(560, 0)
    $descLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
    $descLabel.ForeColor = $script:ColorMuted
    $descLabel.BackColor = $script:ColorCard
    $descLabel.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 0)

    $text.Controls.Add($titleLabel)
    $text.Controls.Add($descLabel)

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $combo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $combo.BackColor = [System.Drawing.Color]::White
    $combo.ForeColor = $script:ColorText
    $combo.Font = [System.Drawing.Font]::new('Segoe UI', 9)
    $combo.Width = 180
    $combo.Anchor = [System.Windows.Forms.AnchorStyles]::Right
    foreach ($item in $Items) { [void]$combo.Items.Add($item) }
    $combo.SelectedIndex = $SelectedIndex
    $combo.add_SelectedIndexChanged({
        Update-Dashboard
    })

    $row.Controls.Add($text, 0, 0)
    $row.Controls.Add($combo, 1, 0)
    Add-BodyControl -Body $Body -Control $row
    return $combo
}

function New-Page {
    param([string]$Key)
    $page = New-Object System.Windows.Forms.Panel
    $page.Dock = [System.Windows.Forms.DockStyle]::Fill
    $page.AutoScroll = $true
    $page.BackColor = $script:ColorBg
    $page.Visible = $false
    $page.Padding = [System.Windows.Forms.Padding]::new(28, 8, 28, 24)

    $stack = New-Object System.Windows.Forms.TableLayoutPanel
    $stack.Dock = [System.Windows.Forms.DockStyle]::Top
    $stack.AutoSize = $true
    $stack.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $stack.BackColor = $script:ColorBg
    $stack.ColumnCount = 1
    $stack.RowCount = 0
    $stack.ColumnStyles.Clear()
    $stack.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
    $stack.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
    $page.Controls.Add($stack)

    $script:Pages[$Key] = $page
    $script:PageHost.Controls.Add($page)
    return $stack
}

function Get-SelectedCount {
    if (-not $script:Toggles.ContainsKey('apps')) { return 0 }
    $count = 0
    foreach ($key in $script:ToggleOrder) {
        if ($key -eq 'riskack') { continue }
        if ($script:Toggles.ContainsKey($key) -and $script:Toggles[$key].Checked) { $count++ }
    }
    if ($script:DnsValue -ne 'None') { $count++ }
    return $count
}

function Get-RiskyCount {
    if (-not $script:Toggles.ContainsKey('apps')) { return 0 }
    $count = 0
    foreach ($key in $script:RiskyKeys.Keys) {
        if ($script:Toggles.ContainsKey($key) -and $script:Toggles[$key].Checked) { $count++ }
    }
    if ($script:DnsValue -ne 'None') { $count++ }
    return $count
}

function Update-Dashboard {
    if (-not $script:SummaryCountLabel) { return }
    $selected = Get-SelectedCount
    $risky = Get-RiskyCount
    $script:SummaryCountLabel.Text = [string]$selected
    $script:SummaryRiskyLabel.Text = [string]$risky
    if ($risky -gt 0) {
        $script:SummaryRiskyLabel.ForeColor = $script:ColorOrange
    } else {
        $script:SummaryRiskyLabel.ForeColor = $script:ColorGreen
    }
}

function Show-Page {
    param([string]$Key)
    if (-not $script:Pages.ContainsKey($Key)) { return }
    foreach ($pageKey in $script:Pages.Keys) {
        $script:Pages[$pageKey].Visible = ($pageKey -eq $Key)
    }
    foreach ($navKey in $script:Nav.Keys) {
        $script:Nav[$navKey].Button.Active = ($navKey -eq $Key)
    }
    $script:ActivePage = $Key
    $meta = $script:PageMeta[$Key]
    $script:HeaderTitle.Text = $meta.Title
    $script:HeaderSubtitle.Text = $meta.Subtitle
}

function Set-DnsSelection {
    param([string]$Value)
    if (-not $script:DnsButtons.ContainsKey($Value)) { return }
    $script:DnsValue = $Value
    foreach ($key in $script:DnsButtons.Keys) {
        $chip = $script:DnsButtons[$key]
        if ($key -eq $Value) {
            $chip.BackColor = $script:ColorAccent
            $chip.ForeColor = [System.Drawing.Color]::White
            $chip.BorderColor = [System.Drawing.Color]::Transparent
            $chip.HoverColor = $script:ColorAccentHover
            $chip.PressedColor = $script:ColorAccentPressed
            $chip.Font = [System.Drawing.Font]::new('Segoe UI', 9.25, [System.Drawing.FontStyle]::Bold)
        } else {
            $chip.BackColor = $script:ColorChip
            $chip.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
            $chip.BorderColor = $script:ColorBorder
            $chip.HoverColor = $script:ColorHover
            $chip.PressedColor = $script:ColorBorder
            $chip.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
        }
    }
    Update-Dashboard
}

function Apply-Preset {
    param([string]$Name)
    if (-not $script:Presets.ContainsKey($Name)) { return }
    $preset = $script:Presets[$Name]
    foreach ($key in $script:PresetOrder) {
        if ($script:Toggles.ContainsKey($key) -and $preset.ContainsKey($key)) {
            $script:Toggles[$key].Checked = [bool]$preset[$key]
        }
    }
    Set-DnsSelection -Value ([string]$preset['Dns'])
    if ($script:Toggles.ContainsKey('riskack')) {
        $script:Toggles['riskack'].Checked = $false
    }
    Update-Dashboard
    if ($script:PresetStatus) {
        $script:PresetStatus.Text = "$Name preset applied. Review the options, then run a dry run."
        $script:PresetStatus.ForeColor = $script:ColorMuted
    }
    $script:StatusLabel.Text = "$Name preset applied"
    $script:StatusLabel.ForeColor = $script:ColorMuted
}

function Get-RunArguments {
    param([bool]$IsDryRun)
    $list = New-Object System.Collections.Generic.List[string]
    $list.Add('-Force')
    if ($IsDryRun) { $list.Add('-DryRun') }
    if (-not $script:Toggles['apps'].Checked) { $list.Add('-SkipApps') }
    if ($script:Toggles['aggressive'].Checked) { $list.Add('-Aggressive') }
    if ($script:Toggles['xbox'].Checked) { $list.Add('-RemoveXbox') }
    if ($script:Toggles['onedrive'].Checked) { $list.Add('-RemoveOneDrive') }
    if (-not $script:Toggles['privacy'].Checked) { $list.Add('-SkipPrivacy') }
    if (-not $script:Toggles['services'].Checked) { $list.Add('-SkipServices') }
    if (-not $script:Toggles['tasks'].Checked) { $list.Add('-SkipTasks') }
    if (-not $script:Toggles['background'].Checked) { $list.Add('-KeepBackgroundApps') }
    if (-not $script:Toggles['copilot'].Checked) { $list.Add('-KeepCopilot') }
    if (-not $script:Toggles['restore'].Checked) { $list.Add('-NoRestorePoint') }
    if ($script:Toggles['visuals'].Checked) { $list.Add('-DisableVisualEffects') }
    if ($script:Toggles['mouse'].Checked) { $list.Add('-DisableMouseAcceleration') }
    if ($script:Toggles['startdelay'].Checked) { $list.Add('-DisableStartupDelay') }
    if ($script:Toggles['gamedvr'].Checked) { $list.Add('-DisableGameDvr') }
    if ($script:Toggles['sysmain'].Checked) { $list.Add('-DisableSysMain') }
    if ($script:Toggles['searchidx'].Checked) { $list.Add('-DisableSearchIndexing') }
    if ($script:Toggles['wer'].Checked) { $list.Add('-DisableWerService') }
    if ($script:Toggles['recall'].Checked) { $list.Add('-DisableRecall') }
    if ($script:Toggles['location'].Checked) { $list.Add('-DisableLocation') }
    if ($script:Toggles['llmnr'].Checked) { $list.Add('-DisableLlmnr') }
    if ($script:Toggles['drivers'].Checked) { $list.Add('-DisableDriverUpdates') }
    if ($script:Toggles['temp'].Checked) { $list.Add('-CleanTemp') }
    if ($script:Toggles['updatecache'].Checked) { $list.Add('-CleanUpdateCache') }
    if ($script:Toggles['docache'].Checked) { $list.Add('-CleanDeliveryOptimization') }
    if ($script:Toggles['thumbs'].Checked) { $list.Add('-CleanThumbnailCache') }
    if ($script:Toggles['recycle'].Checked) { $list.Add('-EmptyRecycleBin') }
    if ($script:Toggles['hibernate'].Checked) { $list.Add('-DisableHibernation') }
    if ($script:Toggles['ultimate'].Checked) { $list.Add('-UltimatePerformance') }
    if ($script:DnsValue -ne 'None') {
        $list.Add('-DnsProvider "' + $script:DnsValue + '"')
    }
    $keep = ($script:KeepAppsBox.Text -replace '"', '').Trim()
    if ($keep.Length -gt 0) {
        $list.Add('-KeepApps "' + $keep + '"')
    }
    return ($list -join ' ')
}

function Set-Busy {
    param([bool]$Busy)
    foreach ($toggle in $script:Toggles.Values) {
        $toggle.Enabled = -not $Busy
    }
    foreach ($chip in $script:DnsButtons.Values) { $chip.Enabled = -not $Busy }
    if ($script:KeepAppsBox) { $script:KeepAppsBox.Enabled = -not $Busy }
    foreach ($button in $script:PresetButtons) { $button.Enabled = -not $Busy }
    foreach ($entry in $script:Nav.Values) { $entry.Button.Enabled = -not $Busy }
    $script:RunButton.Enabled = -not $Busy
    $script:DryButton.Enabled = -not $Busy
    $script:ExitButton.Enabled = -not $Busy
}

function Append-LogLine {
    param([string]$Line)
    $color = $script:ColorLogText
    if ($Line -match '\[FAIL\]') {
        $color = $script:ColorRed
    } elseif ($Line -match '\[WARN\]') {
        $color = $script:ColorOrange
    } elseif ($Line -match '\[OK\]') {
        $color = $script:ColorGreen
    } elseif ($Line -match '^== ') {
        $color = $script:ColorAccent
    } elseif ($Line -match '\[SKIP\]|\[WhatIf\]') {
        $color = $script:ColorDim
    }
    $script:LogBox.SelectionStart = $script:LogBox.TextLength
    $script:LogBox.SelectionLength = 0
    $script:LogBox.SelectionColor = $color
    $script:LogBox.AppendText($Line + "`r`n")
    $script:LogBox.SelectionStart = $script:LogBox.TextLength
    $script:LogBox.ScrollToCaret()
}

function Open-DebloatLogs {
    $dir = Join-Path $script:ScriptRoot 'logs'
    try {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $dir + '"') -ErrorAction Stop
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not open the logs folder.`r`n`r`n$($_.Exception.Message)", 'Logs', 'OK', 'Warning') | Out-Null
    }
}

function Start-DebloatRun {
    param([bool]$IsDryRun)
    if ($script:Running) { return }
    $selected = Get-SelectedCount
    if ($selected -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select at least one action.', 'Nothing selected', 'OK', 'Information') | Out-Null
        return
    }
    $risky = Get-RiskyCount
    if (-not $IsDryRun -and $risky -gt 0 -and -not $script:Toggles['riskack'].Checked) {
        Show-Page 'advanced'
        [System.Windows.Forms.MessageBox]::Show("$risky risky option(s) are selected.`r`n`r`nEnable the risk acknowledgement at the top of the Advanced page before running, or use Dry run to preview safely.", 'Risk acknowledgement required', 'OK', 'Warning') | Out-Null
        return
    }
    if (-not $IsDryRun) {
        $message = "Apply $selected selected actions now?"
        if ($script:Toggles['restore'].Checked) {
            $message += "`r`n`r`nA System Restore point will be attempted first."
        }
        if ($risky -gt 0) {
            $message += "`r`n`r`n$risky risky option(s) are enabled."
        }
        $message += "`r`n`r`nA reboot is recommended afterward."
        $answer = [System.Windows.Forms.MessageBox]::Show($message, 'Confirm changes', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    $arguments = Get-RunArguments -IsDryRun $IsDryRun
    $script:Runner = New-Object WinDebloatRunner
    try {
        $script:Runner.Start($script:EnginePath, $arguments, $script:ScriptRoot)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not start the debloat engine.`r`n`r`n$($_.Exception.Message)", 'Startup error', 'OK', 'Error') | Out-Null
        return
    }

    $script:Running = $true
    $script:DryRunActive = $IsDryRun
    $script:RunStart = Get-Date
    $script:LogBox.Clear()
    Append-LogLine ('WinDebloat - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    if ($IsDryRun) {
        Append-LogLine 'Mode: dry run (no changes)'
    } else {
        Append-LogLine 'Mode: apply changes'
    }
    Append-LogLine ''
    Show-Page 'log'
    Set-Busy $true
    $script:StatusLabel.Text = 'Running...'
    $script:StatusLabel.ForeColor = $script:ColorAccent
    $script:ProgressLine.Marquee = $true
    $script:Timer.Start()
}

function Clear-DebloatLog {
    $script:LogBox.Clear()
    Append-LogLine 'Log cleared.'
}

function Get-SystemSnapshot {
    $snapshot = @{
        OS = 'Windows'
        Build = 'Unknown'
        CPU = 'Unknown'
        Memory = 'Unknown'
        Disk = 'Unknown'
    }
    try {
        $key = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $osName = [string]$key.ProductName
        $build = [string]$key.CurrentBuildNumber
        if (-not $build) { $build = [string]$key.CurrentBuild }
        $buildNumber = 0
        if ([int]::TryParse($build, [ref]$buildNumber) -and $buildNumber -ge 22000) {
            $osName = $osName -replace 'Windows 10', 'Windows 11'
        }
        if ($key.UBR) { $build = $build + '.' + [string]$key.UBR }
        if ($osName) { $snapshot.OS = $osName.Trim() }
        if ($build) { $snapshot.Build = $build }
    } catch {
    }
    try {
        $cpuKey = Get-ItemProperty -Path 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction Stop
        $cpuName = [string]$cpuKey.ProcessorNameString
        if ($cpuName) { $snapshot.CPU = $cpuName.Trim() }
    } catch {
    }
    try {
        $memory = [NativeInfo]::TotalMemoryGB()
        if ($memory -gt 0) { $snapshot.Memory = ('{0:N1} GB' -f $memory) }
    } catch {
    }
    try {
        $drive = New-Object System.IO.DriveInfo($env:SystemDrive)
        $snapshot.Disk = ('{0:N0} GB free of {1:N0} GB' -f ($drive.AvailableFreeSpace / 1GB), ($drive.TotalSize / 1GB))
    } catch {
    }
    return $snapshot
}

$splash = New-Object System.Windows.Forms.Form
$splash.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$splash.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$splash.ClientSize = [System.Drawing.Size]::new(460, 190)
$splash.BackColor = $script:ColorSidebar
$splash.ShowInTaskbar = $false
$splash.TopMost = $true
$splash.add_Paint({
    param($sender, $eventArgs)
    $pen = New-Object System.Drawing.Pen($script:ColorBorder)
    $eventArgs.Graphics.DrawRectangle($pen, 0, 0, ($sender.Width - 1), ($sender.Height - 1))
    $pen.Dispose()
})

$splashIcon = New-Object IconBox
$splashIcon.Size = [System.Drawing.Size]::new(48, 48)
$splashIcon.Location = [System.Drawing.Point]::new(34, 30)
$splashIcon.GlyphData = Get-IconData 'shield-check'
$splashIcon.BoxColor = $script:ColorAccent
$splashIcon.IconColor = [System.Drawing.Color]::White
$splashIcon.CornerRadius = 13
$splashIcon.IconInset = 12
$splash.Controls.Add($splashIcon)

$splashTitle = New-Object System.Windows.Forms.Label
$splashTitle.Text = 'WinDebloat'
$splashTitle.AutoSize = $true
$splashTitle.Location = [System.Drawing.Point]::new(100, 32)
$splashTitle.Font = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$splashTitle.ForeColor = $script:ColorTextStrong
$splashTitle.BackColor = $script:ColorSidebar
$splash.Controls.Add($splashTitle)

$splashSub = New-Object System.Windows.Forms.Label
$splashSub.Text = 'SYSTEM OPTIMIZER'
$splashSub.AutoSize = $true
$splashSub.Location = [System.Drawing.Point]::new(102, 69)
$splashSub.Font = [System.Drawing.Font]::new('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)
$splashSub.ForeColor = $script:ColorAccent
$splashSub.BackColor = $script:ColorSidebar
$splash.Controls.Add($splashSub)

$splashLine = New-Object System.Windows.Forms.Panel
$splashLine.Size = [System.Drawing.Size]::new(392, 1)
$splashLine.Location = [System.Drawing.Point]::new(34, 103)
$splashLine.BackColor = $script:ColorBorder
$splash.Controls.Add($splashLine)

$splashStatus = New-Object System.Windows.Forms.Label
$splashStatus.Text = 'Preparing the interface...'
$splashStatus.AutoSize = $true
$splashStatus.Location = [System.Drawing.Point]::new(36, 120)
$splashStatus.Font = [System.Drawing.Font]::new('Segoe UI', 9.5)
$splashStatus.ForeColor = $script:ColorMuted
$splashStatus.BackColor = $script:ColorSidebar
$splash.Controls.Add($splashStatus)

$splashHint = New-Object System.Windows.Forms.Label
$splashHint.Text = 'Clean, private and reversible Windows tuning'
$splashHint.AutoSize = $true
$splashHint.Location = [System.Drawing.Point]::new(36, 152)
$splashHint.Font = [System.Drawing.Font]::new('Segoe UI', 8)
$splashHint.ForeColor = $script:ColorDim
$splashHint.BackColor = $script:ColorSidebar
$splash.Controls.Add($splashHint)

$splash.Show()
[System.Windows.Forms.Application]::DoEvents()
Write-StartupLog 'Splash shown.'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'WinDebloat'
$form.ClientSize = [System.Drawing.Size]::new(1180, 800)
$form.MinimumSize = [System.Drawing.Size]::new(1080, 720)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = $script:ColorBg
$form.ForeColor = $script:ColorText
$form.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.AutoScaleDimensions = [System.Drawing.SizeF]::new(96, 96)
$iconPath = Join-Path $script:GuiRoot 'assets\WinDebloat.ico'
if (Test-Path -LiteralPath $iconPath) {
    try {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
    } catch {
        $form.Icon = [System.Drawing.SystemIcons]::Shield
    }
} else {
    $form.Icon = [System.Drawing.SystemIcons]::Shield
}
Write-StartupLog 'Main form created.'

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = [System.Windows.Forms.DockStyle]::Fill
$root.ColumnCount = 2
$root.RowCount = 1
$root.Padding = [System.Windows.Forms.Padding]::new(0)
$root.Margin = [System.Windows.Forms.Padding]::new(0)
$root.ColumnStyles.Clear()
$root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 248)) | Out-Null
$root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$form.Controls.Add($root)

$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Dock = [System.Windows.Forms.DockStyle]::Fill
$sidebar.BackColor = $script:ColorSidebar
$sidebar.Margin = [System.Windows.Forms.Padding]::new(0)
$root.Controls.Add($sidebar, 0, 0)

$sidebarEdge = New-Object System.Windows.Forms.Panel
$sidebarEdge.Dock = [System.Windows.Forms.DockStyle]::Right
$sidebarEdge.Width = 1
$sidebarEdge.BackColor = $script:ColorBorder
$sidebar.Controls.Add($sidebarEdge)

$brandIcon = New-Object IconBox
$brandIcon.Size = [System.Drawing.Size]::new(40, 40)
$brandIcon.Location = [System.Drawing.Point]::new(20, 24)
$brandIcon.GlyphData = Get-IconData 'shield-check'
$brandIcon.BoxColor = $script:ColorAccent
$brandIcon.IconColor = [System.Drawing.Color]::White
$brandIcon.CornerRadius = 11
$brandIcon.IconInset = 10
$sidebar.Controls.Add($brandIcon)

$brandTitle = New-Object System.Windows.Forms.Label
$brandTitle.Text = 'WinDebloat'
$brandTitle.AutoSize = $true
$brandTitle.Location = [System.Drawing.Point]::new(72, 26)
$brandTitle.Font = [System.Drawing.Font]::new('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$brandTitle.ForeColor = $script:ColorTextStrong
$brandTitle.BackColor = $script:ColorSidebar
$sidebar.Controls.Add($brandTitle)

$brandSub = New-Object System.Windows.Forms.Label
$brandSub.Text = 'SYSTEM OPTIMIZER'
$brandSub.AutoSize = $true
$brandSub.Location = [System.Drawing.Point]::new(74, 51)
$brandSub.Font = [System.Drawing.Font]::new('Segoe UI', 7.25, [System.Drawing.FontStyle]::Bold)
$brandSub.ForeColor = $script:ColorAccent
$brandSub.BackColor = $script:ColorSidebar
$sidebar.Controls.Add($brandSub)

$navFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$navFlow.Location = [System.Drawing.Point]::new(16, 104)
$navFlow.Size = [System.Drawing.Size]::new(216, 326)
$navFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$navFlow.WrapContents = $false
$navFlow.BackColor = $script:ColorSidebar
$sidebar.Controls.Add($navFlow)

$navLabel = New-Object System.Windows.Forms.Label
$navLabel.Text = 'WORKSPACE'
$navLabel.AutoSize = $true
$navLabel.Font = [System.Drawing.Font]::new('Segoe UI', 7.25, [System.Drawing.FontStyle]::Bold)
$navLabel.ForeColor = $script:ColorDim
$navLabel.Margin = [System.Windows.Forms.Padding]::new(8, 0, 0, 8)
$navFlow.Controls.Add($navLabel)

$navFlow.Controls.Add((New-NavItem -Key 'dashboard' -Text 'Dashboard' -Icon 'dashboard'))
$navFlow.Controls.Add((New-NavItem -Key 'apps' -Text 'App Cleanup' -Icon 'package'))
$navFlow.Controls.Add((New-NavItem -Key 'performance' -Text 'Performance' -Icon 'gauge'))
$navFlow.Controls.Add((New-NavItem -Key 'privacy' -Text 'Privacy' -Icon 'shield'))
$navFlow.Controls.Add((New-NavItem -Key 'advanced' -Text 'Advanced' -Icon 'sliders'))
$navFlow.Controls.Add((New-NavItem -Key 'log' -Text 'Activity Log' -Icon 'terminal'))

$sideBottom = New-Object System.Windows.Forms.Panel
$sideBottom.Dock = [System.Windows.Forms.DockStyle]::Bottom
$sideBottom.Height = 138
$sideBottom.BackColor = $script:ColorSidebar
$sidebar.Controls.Add($sideBottom)

$sideLine = New-Object System.Windows.Forms.Panel
$sideLine.Dock = [System.Windows.Forms.DockStyle]::Top
$sideLine.Height = 1
$sideLine.BackColor = $script:ColorBorder
$sideBottom.Controls.Add($sideLine)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = 'Version 2.1.0'
$versionLabel.AutoSize = $true
$versionLabel.Location = [System.Drawing.Point]::new(22, 14)
$versionLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8)
$versionLabel.ForeColor = $script:ColorDim
$versionLabel.BackColor = $script:ColorSidebar
$sideBottom.Controls.Add($versionLabel)

$sideAdmin = New-Object Pill
$sideAdmin.Text = 'ADMINISTRATOR'
$sideAdmin.FillColor = $script:ColorGreenSoft
$sideAdmin.TextColor = $script:ColorGreen
$sideAdmin.DotColor = $script:ColorGreenDot
$sideAdmin.Location = [System.Drawing.Point]::new(22, 35)
$sideAdmin.Size = $sideAdmin.GetPreferredSize([System.Drawing.Size]::Empty)
$sideBottom.Controls.Add($sideAdmin)

$safetyLabel = New-Object System.Windows.Forms.Label
$safetyLabel.Text = 'Defender, Update and Store untouched'
$safetyLabel.AutoSize = $true
$safetyLabel.Location = [System.Drawing.Point]::new(22, 63)
$safetyLabel.Font = [System.Drawing.Font]::new('Segoe UI', 7.5)
$safetyLabel.ForeColor = $script:ColorDim
$safetyLabel.BackColor = $script:ColorSidebar
$sideBottom.Controls.Add($safetyLabel)

$githubIcon = New-Object IconBox
$githubIcon.Size = [System.Drawing.Size]::new(16, 16)
$githubIcon.Location = [System.Drawing.Point]::new(20, 89)
$githubIcon.GlyphData = Get-IconData 'github'
$githubIcon.BoxColor = $script:ColorSidebar
$githubIcon.IconColor = $script:ColorDim
$githubIcon.CornerRadius = 0
$githubIcon.IconInset = 1
$sideBottom.Controls.Add($githubIcon)

$madeByLabel = New-Object System.Windows.Forms.Label
$madeByLabel.Text = 'Made with ' + [char]0x2665 + ' by Muneeb Anjum'
$madeByLabel.AutoSize = $true
$madeByLabel.Location = [System.Drawing.Point]::new(42, 87)
$madeByLabel.Font = [System.Drawing.Font]::new('Segoe UI', 7.75)
$madeByLabel.ForeColor = $script:ColorDim
$madeByLabel.BackColor = $script:ColorSidebar
$sideBottom.Controls.Add($madeByLabel)

$githubLink = New-Object System.Windows.Forms.LinkLabel
$githubLink.Text = '@horizonbymuneeb'
$githubLink.AutoSize = $true
$githubLink.Location = [System.Drawing.Point]::new(42, 102)
$githubLink.Font = [System.Drawing.Font]::new('Segoe UI', 7.75)
$githubLink.LinkColor = $script:ColorAccent
$githubLink.ActiveLinkColor = $script:ColorAccentHover
$githubLink.VisitedLinkColor = $script:ColorAccent
$githubLink.LinkBehavior = [System.Windows.Forms.LinkBehavior]::HoverUnderline
$githubLink.BackColor = $script:ColorSidebar
$githubLink.add_Click({ Start-Process 'https://github.com/horizonbymuneeb' })
$sideBottom.Controls.Add($githubLink)

$content = New-Object System.Windows.Forms.TableLayoutPanel
$content.Dock = [System.Windows.Forms.DockStyle]::Fill
$content.ColumnCount = 1
$content.RowCount = 3
$content.BackColor = $script:ColorBg
$content.Margin = [System.Windows.Forms.Padding]::new(0)
$content.ColumnStyles.Clear()
$content.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$content.RowStyles.Clear()
$content.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 88)) | Out-Null
$content.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$content.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 88)) | Out-Null
$root.Controls.Add($content, 1, 0)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = [System.Windows.Forms.DockStyle]::Fill
$header.BackColor = $script:ColorBg
$header.Margin = [System.Windows.Forms.Padding]::new(0)
$content.Controls.Add($header, 0, 0)

$headerGrid = New-Object System.Windows.Forms.TableLayoutPanel
$headerGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerGrid.ColumnCount = 2
$headerGrid.RowCount = 1
$headerGrid.Padding = [System.Windows.Forms.Padding]::new(30, 15, 30, 8)
$headerGrid.BackColor = $script:ColorBg
$headerGrid.ColumnStyles.Clear()
$headerGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$headerGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
$header.Controls.Add($headerGrid)

$headerText = New-Object System.Windows.Forms.FlowLayoutPanel
$headerText.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerText.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$headerText.WrapContents = $false
$headerText.BackColor = $script:ColorBg
$headerText.Margin = [System.Windows.Forms.Padding]::new(0)
$headerText.Padding = [System.Windows.Forms.Padding]::new(0, 4, 0, 0)
$headerGrid.Controls.Add($headerText, 0, 0)

$script:HeaderTitle = New-Object System.Windows.Forms.Label
$script:HeaderTitle.Text = 'Dashboard'
$script:HeaderTitle.AutoSize = $true
$script:HeaderTitle.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$script:HeaderTitle.ForeColor = $script:ColorTextStrong
$script:HeaderTitle.BackColor = $script:ColorBg
$script:HeaderTitle.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
$headerText.Controls.Add($script:HeaderTitle)

$script:HeaderSubtitle = New-Object System.Windows.Forms.Label
$script:HeaderSubtitle.Text = 'Overview, system status and quick presets'
$script:HeaderSubtitle.AutoSize = $true
$script:HeaderSubtitle.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
$script:HeaderSubtitle.ForeColor = $script:ColorMuted
$script:HeaderSubtitle.BackColor = $script:ColorBg
$script:HeaderSubtitle.Margin = [System.Windows.Forms.Padding]::new(1, 4, 0, 0)
$headerText.Controls.Add($script:HeaderSubtitle)

$adminBadge = New-Object Pill
$adminBadge.Text = 'ELEVATED SESSION'
$adminBadge.FillColor = $script:ColorGreenSoft
$adminBadge.TextColor = $script:ColorGreen
$adminBadge.DotColor = $script:ColorGreenDot
$adminBadge.Anchor = [System.Windows.Forms.AnchorStyles]::Right
$adminBadge.Margin = [System.Windows.Forms.Padding]::new(0, 9, 0, 0)
$adminBadge.Size = $adminBadge.GetPreferredSize([System.Drawing.Size]::Empty)
$headerGrid.Controls.Add($adminBadge, 1, 0)

$script:PageHost = New-Object System.Windows.Forms.Panel
$script:PageHost.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:PageHost.BackColor = $script:ColorBg
$script:PageHost.Margin = [System.Windows.Forms.Padding]::new(0)
$content.Controls.Add($script:PageHost, 0, 1)

$footer = New-Object System.Windows.Forms.Panel
$footer.Dock = [System.Windows.Forms.DockStyle]::Fill
$footer.BackColor = $script:ColorSidebar
$footer.Margin = [System.Windows.Forms.Padding]::new(0)
$content.Controls.Add($footer, 0, 2)

$footerTop = New-Object System.Windows.Forms.Panel
$footerTop.Dock = [System.Windows.Forms.DockStyle]::Top
$footerTop.Height = 1
$footerTop.BackColor = $script:ColorBorder
$footer.Controls.Add($footerTop)

$footerGrid = New-Object System.Windows.Forms.TableLayoutPanel
$footerGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
$footerGrid.ColumnCount = 2
$footerGrid.RowCount = 1
$footerGrid.Padding = [System.Windows.Forms.Padding]::new(26, 14, 26, 14)
$footerGrid.BackColor = $footer.BackColor
$footerGrid.ColumnStyles.Clear()
$footerGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$footerGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 430)) | Out-Null
$footer.Controls.Add($footerGrid)

$statusStack = New-Object System.Windows.Forms.TableLayoutPanel
$statusStack.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusStack.ColumnCount = 1
$statusStack.RowCount = 2
$statusStack.BackColor = $footer.BackColor
$statusStack.Margin = [System.Windows.Forms.Padding]::new(0, 0, 20, 0)
$statusStack.ColumnStyles.Clear()
$statusStack.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$statusStack.RowStyles.Clear()
$statusStack.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$statusStack.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 8)) | Out-Null
$footerGrid.Controls.Add($statusStack, 0, 0)

$script:StatusLabel = New-Object System.Windows.Forms.Label
$script:StatusLabel.Text = 'Ready. Review the options and run a dry run first.'
$script:StatusLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$script:StatusLabel.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
$script:StatusLabel.ForeColor = $script:ColorMuted
$script:StatusLabel.BackColor = $footer.BackColor
$statusStack.Controls.Add($script:StatusLabel, 0, 0)

$script:ProgressLine = New-Object ProgressLine
$script:ProgressLine.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:ProgressLine.Margin = [System.Windows.Forms.Padding]::new(0, 2, 0, 2)
$statusStack.Controls.Add($script:ProgressLine, 0, 1)

$buttonBar = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonBar.Dock = [System.Windows.Forms.DockStyle]::Fill
$buttonBar.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$buttonBar.WrapContents = $false
$buttonBar.BackColor = $footer.BackColor
$buttonBar.Margin = [System.Windows.Forms.Padding]::new(0)
$buttonBar.Padding = [System.Windows.Forms.Padding]::new(0, 6, 0, 0)
$footerGrid.Controls.Add($buttonBar, 1, 0)

$script:RunButton = New-Object FlatButton
$script:RunButton.Text = 'Run now'
$script:RunButton.GlyphData = Get-IconData 'play'
$script:RunButton.Size = [System.Drawing.Size]::new(140, 38)
$script:RunButton.BackColor = $script:ColorAccent
$script:RunButton.ForeColor = [System.Drawing.Color]::White
$script:RunButton.HoverColor = $script:ColorAccentHover
$script:RunButton.PressedColor = $script:ColorAccentPressed
$script:RunButton.BorderColor = [System.Drawing.Color]::Transparent
$script:RunButton.Font = [System.Drawing.Font]::new('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$script:RunButton.Margin = [System.Windows.Forms.Padding]::new(10, 0, 0, 0)
$script:RunButton.add_Click({ Start-DebloatRun -IsDryRun $false })
$buttonBar.Controls.Add($script:RunButton)

$script:DryButton = New-Object FlatButton
$script:DryButton.Text = 'Dry run'
$script:DryButton.GlyphData = Get-IconData 'eye'
$script:DryButton.Size = [System.Drawing.Size]::new(122, 38)
$script:DryButton.BackColor = [System.Drawing.Color]::White
$script:DryButton.ForeColor = $script:ColorText
$script:DryButton.HoverColor = $script:ColorHover
$script:DryButton.PressedColor = $script:ColorBorder
$script:DryButton.BorderColor = $script:ColorBorderStrong
$script:DryButton.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
$script:DryButton.Margin = [System.Windows.Forms.Padding]::new(10, 0, 0, 0)
$script:DryButton.add_Click({ Start-DebloatRun -IsDryRun $true })
$buttonBar.Controls.Add($script:DryButton)

$script:ExitButton = New-Object FlatButton
$script:ExitButton.Text = 'Exit'
$script:ExitButton.GlyphData = Get-IconData 'log-out'
$script:ExitButton.Size = [System.Drawing.Size]::new(96, 38)
$script:ExitButton.BackColor = [System.Drawing.Color]::White
$script:ExitButton.ForeColor = $script:ColorMuted
$script:ExitButton.HoverColor = $script:ColorHover
$script:ExitButton.PressedColor = $script:ColorBorder
$script:ExitButton.BorderColor = [System.Drawing.Color]::Transparent
$script:ExitButton.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
$script:ExitButton.Margin = [System.Windows.Forms.Padding]::new(10, 0, 0, 0)
$script:ExitButton.add_Click({ $form.Close() })
$buttonBar.Controls.Add($script:ExitButton)
$dashStack = New-Page 'dashboard'

$heroCard = New-Card -Title 'Overview' -Subtitle 'Clean up bundled apps, telemetry and background activity, then apply the performance and privacy options you choose.' -Icon 'dashboard'
Add-StackCard -Stack $dashStack -Card $heroCard.Card

$presetFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$presetFlow.AutoSize = $true
$presetFlow.WrapContents = $false
$presetFlow.BackColor = $script:ColorCard
$presetFlow.Margin = [System.Windows.Forms.Padding]::new(0, 2, 0, 0)
Add-BodyControl -Body $heroCard.Body -Control $presetFlow

$btnSafe = New-Object FlatButton
$btnSafe.Text = 'Safe'
$btnSafe.GlyphData = Get-IconData 'shield-check'
$btnSafe.Size = [System.Drawing.Size]::new(112, 36)
$btnSafe.BackColor = [System.Drawing.Color]::White
$btnSafe.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$btnSafe.HoverColor = $script:ColorHover
$btnSafe.PressedColor = $script:ColorBorder
$btnSafe.BorderColor = $script:ColorBorderStrong
$btnSafe.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
$btnSafe.Margin = [System.Windows.Forms.Padding]::new(0, 0, 10, 0)
$btnSafe.Tag = 'Safe'
$btnSafe.add_Click({ Apply-Preset ([string]$this.Tag) })
$presetFlow.Controls.Add($btnSafe)
$script:PresetButtons += $btnSafe

$btnBalanced = New-Object FlatButton
$btnBalanced.Text = 'Balanced'
$btnBalanced.GlyphData = Get-IconData 'sliders'
$btnBalanced.Size = [System.Drawing.Size]::new(120, 36)
$btnBalanced.BackColor = $script:ColorAccent
$btnBalanced.ForeColor = [System.Drawing.Color]::White
$btnBalanced.HoverColor = $script:ColorAccentHover
$btnBalanced.PressedColor = $script:ColorAccentPressed
$btnBalanced.BorderColor = [System.Drawing.Color]::Transparent
$btnBalanced.Font = [System.Drawing.Font]::new('Segoe UI', 9.25, [System.Drawing.FontStyle]::Bold)
$btnBalanced.Margin = [System.Windows.Forms.Padding]::new(0, 0, 10, 0)
$btnBalanced.Tag = 'Balanced'
$btnBalanced.add_Click({ Apply-Preset ([string]$this.Tag) })
$presetFlow.Controls.Add($btnBalanced)
$script:PresetButtons += $btnBalanced

$btnAggressive = New-Object FlatButton
$btnAggressive.Text = 'Aggressive'
$btnAggressive.GlyphData = Get-IconData 'alert-triangle'
$btnAggressive.Size = [System.Drawing.Size]::new(128, 36)
$btnAggressive.BackColor = $script:ColorOrangeSoft
$btnAggressive.ForeColor = $script:ColorOrange
$btnAggressive.HoverColor = [System.Drawing.Color]::FromArgb(255, 237, 213)
$btnAggressive.PressedColor = [System.Drawing.Color]::FromArgb(254, 215, 170)
$btnAggressive.BorderColor = $script:ColorOrangeBorder
$btnAggressive.Font = [System.Drawing.Font]::new('Segoe UI', 9.25)
$btnAggressive.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
$btnAggressive.Tag = 'Aggressive'
$btnAggressive.add_Click({ Apply-Preset ([string]$this.Tag) })
$presetFlow.Controls.Add($btnAggressive)
$script:PresetButtons += $btnAggressive

$script:PresetStatus = New-Object System.Windows.Forms.Label
$script:PresetStatus.Text = 'Safe is recommended for most PCs. Balanced adds cleanup and performance. Aggressive enables risky options and requires acknowledgement.'
$script:PresetStatus.AutoSize = $true
$script:PresetStatus.MaximumSize = [System.Drawing.Size]::new(700, 0)
$script:PresetStatus.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
$script:PresetStatus.ForeColor = $script:ColorMuted
$script:PresetStatus.BackColor = $script:ColorCard
$script:PresetStatus.Margin = [System.Windows.Forms.Padding]::new(0, 10, 0, 0)
Add-BodyControl -Body $heroCard.Body -Control $script:PresetStatus

$snapshot = Get-SystemSnapshot
$systemCard = New-Card -Title 'This PC' -Subtitle 'Read-only snapshot of the system this session will modify.' -Icon 'monitor'
Add-StackCard -Stack $dashStack -Card $systemCard.Card

$systemGrid = New-Object System.Windows.Forms.TableLayoutPanel
$systemGrid.Dock = [System.Windows.Forms.DockStyle]::Top
$systemGrid.AutoSize = $true
$systemGrid.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$systemGrid.ColumnCount = 3
$systemGrid.RowCount = 2
$systemGrid.BackColor = $script:ColorCard
$systemGrid.Margin = [System.Windows.Forms.Padding]::new(0, 4, 0, 0)
$systemGrid.ColumnStyles.Clear()
$systemGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 33.34)) | Out-Null
$systemGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 33.33)) | Out-Null
$systemGrid.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 33.33)) | Out-Null
$systemGrid.RowStyles.Clear()
$systemGrid.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
$systemGrid.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize, 0)) | Out-Null
Add-BodyControl -Body $systemCard.Body -Control $systemGrid

$osBlock = New-StatBlock -Value $snapshot.OS -Label 'Operating system' -Width 240
$osBlock.Panel.Dock = [System.Windows.Forms.DockStyle]::Fill
$systemGrid.Controls.Add($osBlock.Panel, 0, 0)
$buildBlock = New-StatBlock -Value $snapshot.Build -Label 'Windows build' -Width 240
$buildBlock.Panel.Dock = [System.Windows.Forms.DockStyle]::Fill
$systemGrid.Controls.Add($buildBlock.Panel, 1, 0)
$cpuBlock = New-StatBlock -Value $snapshot.CPU -Label 'Processor' -Width 240
$cpuBlock.Panel.Dock = [System.Windows.Forms.DockStyle]::Fill
$systemGrid.Controls.Add($cpuBlock.Panel, 2, 0)
$memBlock = New-StatBlock -Value $snapshot.Memory -Label 'Memory' -Width 240
$memBlock.Panel.Dock = [System.Windows.Forms.DockStyle]::Fill
$systemGrid.Controls.Add($memBlock.Panel, 0, 1)
$diskBlock = New-StatBlock -Value $snapshot.Disk -Label 'System disk' -Width 240
$diskBlock.Panel.Dock = [System.Windows.Forms.DockStyle]::Fill
$systemGrid.Controls.Add($diskBlock.Panel, 1, 1)

$selectionCard = New-Card -Title 'Current selection' -Subtitle 'Live count of enabled actions. Nothing runs until you press Run now.' -Icon 'list-checks'
Add-StackCard -Stack $dashStack -Card $selectionCard.Card

$selectionFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$selectionFlow.AutoSize = $true
$selectionFlow.WrapContents = $true
$selectionFlow.BackColor = $script:ColorCard
$selectionFlow.Margin = [System.Windows.Forms.Padding]::new(0, 4, 0, 0)
Add-BodyControl -Body $selectionCard.Body -Control $selectionFlow

$countBlock = New-StatBlock -Value '0' -Label 'Actions selected' -Width 168
$selectionFlow.Controls.Add($countBlock.Panel)
$script:SummaryCountLabel = $countBlock.Value
$riskyBlock = New-StatBlock -Value '0' -Label 'Risky options' -Width 168
$selectionFlow.Controls.Add($riskyBlock.Panel)
$script:SummaryRiskyLabel = $riskyBlock.Value

$selectionNote = New-Object System.Windows.Forms.Label
$selectionNote.Text = 'Risky options require explicit acknowledgement on the Advanced page before a real run.'
$selectionNote.AutoSize = $true
$selectionNote.MaximumSize = [System.Drawing.Size]::new(700, 0)
$selectionNote.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
$selectionNote.ForeColor = $script:ColorDim
$selectionNote.BackColor = $script:ColorCard
$selectionNote.Margin = [System.Windows.Forms.Padding]::new(0, 2, 0, 0)
Add-BodyControl -Body $selectionCard.Body -Control $selectionNote

$guardCard = New-Card -Title 'Guardrails' -Subtitle 'The tool is deliberately conservative about core security and update components.' -Icon 'shield-check'
Add-StackCard -Stack $dashStack -Card $guardCard.Card

$guardItems = @(
    'A System Restore point is attempted before any change.',
    'Microsoft Defender, Windows Update, Microsoft Store, Edge and printing are left untouched.',
    'Telemetry and ad tweaks are reversible through Settings or policy.',
    'Risky options stay off until you enable them and acknowledge the risk.'
)
foreach ($item in $guardItems) {
    $guardRow = New-Object System.Windows.Forms.FlowLayoutPanel
    $guardRow.AutoSize = $true
    $guardRow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $guardRow.WrapContents = $false
    $guardRow.BackColor = $script:ColorCard
    $guardRow.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 3)

    $guardCheck = New-Object IconBox
    $guardCheck.Size = [System.Drawing.Size]::new(16, 16)
    $guardCheck.GlyphData = Get-IconData 'check'
    $guardCheck.BoxColor = [System.Drawing.Color]::Transparent
    $guardCheck.IconColor = $script:ColorGreen
    $guardCheck.IconInset = 1
    $guardCheck.Margin = [System.Windows.Forms.Padding]::new(0, 2, 8, 0)

    $guardLabel = New-Object System.Windows.Forms.Label
    $guardLabel.Text = $item
    $guardLabel.AutoSize = $true
    $guardLabel.MaximumSize = [System.Drawing.Size]::new(680, 0)
    $guardLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.75)
    $guardLabel.ForeColor = $script:ColorMuted
    $guardLabel.BackColor = $script:ColorCard
    $guardLabel.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)

    $guardRow.Controls.Add($guardCheck)
    $guardRow.Controls.Add($guardLabel)
    Add-BodyControl -Body $guardCard.Body -Control $guardRow
}

$appsStack = New-Page 'apps'
$appCard = New-Card -Title 'Preinstalled apps' -Subtitle 'Select which bundled apps to remove. Microsoft Store, Edge and Defender are never touched.' -Icon 'package'
Add-StackCard -Stack $appsStack -Card $appCard.Card
Add-ToggleRow -Body $appCard.Body -Key 'apps' -Title 'Remove bloatware apps' -Description 'Remove the curated list of preinstalled Store apps, games and hubs.' -Checked $true
Add-ToggleRow -Body $appCard.Body -Key 'aggressive' -Title 'Aggressive app removal' -Description 'Also remove Outlook, Teams, Phone Link, Media Player and Copilot. This can break workflows.' -Checked $false -Risky $true
Add-ToggleRow -Body $appCard.Body -Key 'xbox' -Title 'Remove Xbox components' -Description 'Remove Xbox apps and disable Xbox services and Game DVR. May affect Game Pass and Store games.' -Checked $false -Risky $true
Add-ToggleRow -Body $appCard.Body -Key 'onedrive' -Title 'Remove OneDrive client' -Description 'Uninstall the OneDrive client. Local files are kept and can be restored by reinstalling.' -Checked $false

$keepCard = New-Card -Title 'Keep apps' -Subtitle 'Protect specific packages from removal. Wildcards are supported.' -Icon 'pin'
Add-StackCard -Stack $appsStack -Card $keepCard.Card

$keepShell = New-Object CardPanel
$keepShell.FillColor = [System.Drawing.Color]::White
$keepShell.BorderColor = $script:ColorBorderStrong
$keepShell.CornerRadius = 9
$keepShell.Size = [System.Drawing.Size]::new(430, 40)
$keepShell.Margin = [System.Windows.Forms.Padding]::new(0, 4, 0, 0)

$script:KeepAppsBox = New-Object System.Windows.Forms.TextBox
$script:KeepAppsBox.Width = 398
$script:KeepAppsBox.Location = [System.Drawing.Point]::new(12, 10)
$script:KeepAppsBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$script:KeepAppsBox.BackColor = [System.Drawing.Color]::White
$script:KeepAppsBox.ForeColor = $script:ColorText
$script:KeepAppsBox.Font = [System.Drawing.Font]::new('Segoe UI', 9.5)
$script:KeepAppsBox.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
$keepShell.Controls.Add($script:KeepAppsBox)
Add-BodyControl -Body $keepCard.Body -Control $keepShell

$keepHint = New-Object System.Windows.Forms.Label
$keepHint.Text = 'Comma-separated package names, for example: MSTeams*, Microsoft.YourPhone'
$keepHint.AutoSize = $true
$keepHint.MaximumSize = [System.Drawing.Size]::new(700, 0)
$keepHint.Font = [System.Drawing.Font]::new('Segoe UI', 8.25)
$keepHint.ForeColor = $script:ColorDim
$keepHint.BackColor = $script:ColorCard
$keepHint.Margin = [System.Windows.Forms.Padding]::new(0, 6, 0, 0)
Add-BodyControl -Body $keepCard.Body -Control $keepHint

$perfStack = New-Page 'performance'
$respCard = New-Card -Title 'Responsiveness' -Subtitle 'Reduce visual overhead and remove artificial delays. Reversible through Windows Settings.' -Icon 'zap'
Add-StackCard -Stack $perfStack -Card $respCard.Card
Add-ToggleRow -Body $respCard.Body -Key 'visuals' -Title 'Disable visual effects' -Description 'Switch to best performance: animation, transparency and effects off.' -Checked $false
Add-ToggleRow -Body $respCard.Body -Key 'mouse' -Title 'Disable mouse acceleration' -Description 'Turn off enhanced pointer precision for raw, consistent pointer movement.' -Checked $false
Add-ToggleRow -Body $respCard.Body -Key 'startdelay' -Title 'Remove startup app delay' -Description 'Remove the artificial delay Windows adds before launching startup apps.' -Checked $false
Add-ToggleRow -Body $respCard.Body -Key 'gamedvr' -Title 'Disable Game DVR' -Description 'Turn off Game DVR background capture and apply the Game DVR policy.' -Checked $false

$svcCard = New-Card -Title 'Services and background' -Subtitle 'These trade some Windows functionality for lower background overhead.' -Icon 'server'
Add-StackCard -Stack $perfStack -Card $svcCard.Card
Add-ToggleRow -Body $svcCard.Body -Key 'sysmain' -Title 'Disable SysMain' -Description 'Stop the SysMain prefetch service. This can slow app launches on hard drives.' -Checked $false -Risky $true
Add-ToggleRow -Body $svcCard.Body -Key 'searchidx' -Title 'Disable Search indexing' -Description 'Stop Windows Search indexing. Search still works but is slower and less complete.' -Checked $false -Risky $true
Add-ToggleRow -Body $svcCard.Body -Key 'wer' -Title 'Disable Error Reporting' -Description 'Disable Windows Error Reporting and its policy. Crash diagnostics will be limited.' -Checked $false -Risky $true

$privacyStack = New-Page 'privacy'
$privacyCard = New-Card -Title 'Privacy and ads' -Subtitle 'Reduce telemetry, suggested content and background app activity.' -Icon 'shield'
Add-StackCard -Stack $privacyStack -Card $privacyCard.Card
Add-ToggleRow -Body $privacyCard.Body -Key 'privacy' -Title 'Privacy, ads and search cleanup' -Description 'Disable diagnostic data, ad suggestions, Start web results, widgets and search clutter.' -Checked $true
Add-ToggleRow -Body $privacyCard.Body -Key 'background' -Title 'Disable UWP background activity' -Description 'Turn off background activity for Store apps. Notifications may be delayed.' -Checked $true
Add-ToggleRow -Body $privacyCard.Body -Key 'copilot' -Title 'Hide Copilot' -Description 'Hide the taskbar Copilot button and apply the Copilot-off policy.' -Checked $true

$telemetryCard = New-Card -Title 'Telemetry services and tasks' -Subtitle 'Disable services and scheduled tasks that report diagnostics and feedback.' -Icon 'activity'
Add-StackCard -Stack $privacyStack -Card $telemetryCard.Card
Add-ToggleRow -Body $telemetryCard.Body -Key 'services' -Title 'Disable telemetry services' -Description 'Disable DiagTrack, MapsBroker, RemoteRegistry and related background services.' -Checked $true
Add-ToggleRow -Body $telemetryCard.Body -Key 'tasks' -Title 'Disable telemetry tasks' -Description 'Disable telemetry, compatibility appraisal, feedback and error queue tasks.' -Checked $true

$advStack = New-Page 'advanced'
$advPrivacyCard = New-Card -Title 'Advanced privacy' -Subtitle 'Deeper policy changes. Some can affect legacy software or update behavior.' -Icon 'lock'
Add-StackCard -Stack $advStack -Card $advPrivacyCard.Card
Add-ToggleRow -Body $advPrivacyCard.Body -Key 'recall' -Title 'Disable Recall' -Description 'Disable Recall AI data analysis through policy.' -Checked $false
Add-ToggleRow -Body $advPrivacyCard.Body -Key 'location' -Title 'Disable location' -Description 'Disable the location policy and the Windows location service.' -Checked $false
Add-ToggleRow -Body $advPrivacyCard.Body -Key 'llmnr' -Title 'Disable LLMNR' -Description 'Disable LLMNR broadcast name resolution. Legacy devices may fail to resolve by name.' -Checked $false -Risky $true
Add-ToggleRow -Body $advPrivacyCard.Body -Key 'drivers' -Title 'Exclude driver updates' -Description 'Exclude driver updates from Windows Update. Drivers must then be installed manually.' -Checked $false -Risky $true

$cleanupCard = New-Card -Title 'Cleanup' -Subtitle 'Reclaim disk space. File sizes are reported in the run summary.' -Icon 'trash-2'
Add-StackCard -Stack $advStack -Card $cleanupCard.Card
Add-ToggleRow -Body $cleanupCard.Body -Key 'temp' -Title 'Clear temp files' -Description 'Clear user and Windows temp folders. In-use files are skipped.' -Checked $false
Add-ToggleRow -Body $cleanupCard.Body -Key 'updatecache' -Title 'Clear Windows Update cache' -Description 'Pause Windows Update briefly and clear downloaded update files.' -Checked $false
Add-ToggleRow -Body $cleanupCard.Body -Key 'docache' -Title 'Clear Delivery Optimization cache' -Description 'Remove cached Delivery Optimization content used for peer updates.' -Checked $false
Add-ToggleRow -Body $cleanupCard.Body -Key 'thumbs' -Title 'Clear thumbnail cache' -Description 'Delete Explorer thumbnail cache files. Explorer rebuilds them on demand.' -Checked $false
Add-ToggleRow -Body $cleanupCard.Body -Key 'recycle' -Title 'Empty Recycle Bin' -Description 'Permanently delete everything currently in the Recycle Bin.' -Checked $false

$powerCard = New-Card -Title 'Power' -Subtitle 'Power changes apply to the whole system and can affect laptops on battery.' -Icon 'power'
Add-StackCard -Stack $advStack -Card $powerCard.Card
Add-ToggleRow -Body $powerCard.Body -Key 'hibernate' -Title 'Disable hibernation' -Description 'Disable hibernation and Fast Startup with powercfg. Frees the hiberfil.sys file.' -Checked $false -Risky $true
Add-ToggleRow -Body $powerCard.Body -Key 'ultimate' -Title 'Ultimate Performance plan' -Description 'Add and activate the Ultimate Performance power plan. Higher power use on laptops.' -Checked $false -Risky $true

$networkCard = New-Card -Title 'Network' -Subtitle 'Change DNS for active physical adapters. Automatic resets the adapter to DHCP-provided DNS.' -Icon 'globe'
Add-StackCard -Stack $advStack -Card $networkCard.Card

Add-BodyControl -Body $networkCard.Body -Control (New-Separator)

$dnsTitle = New-Object System.Windows.Forms.Label
$dnsTitle.Text = 'DNS provider'
$dnsTitle.AutoSize = $true
$dnsTitle.Font = [System.Drawing.Font]::new('Segoe UI', 9.75)
$dnsTitle.ForeColor = $script:ColorText
$dnsTitle.BackColor = $script:ColorCard
$dnsTitle.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 0)
Add-BodyControl -Body $networkCard.Body -Control $dnsTitle

$dnsDesc = New-Object System.Windows.Forms.Label
$dnsDesc.Text = 'Cloudflare, Google and Quad9 are public resolvers. Automatic restores DHCP DNS.'
$dnsDesc.AutoSize = $true
$dnsDesc.MaximumSize = [System.Drawing.Size]::new(640, 0)
$dnsDesc.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
$dnsDesc.ForeColor = $script:ColorMuted
$dnsDesc.BackColor = $script:ColorCard
$dnsDesc.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 0)
Add-BodyControl -Body $networkCard.Body -Control $dnsDesc

$dnsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$dnsFlow.AutoSize = $true
$dnsFlow.WrapContents = $true
$dnsFlow.BackColor = $script:ColorCard
$dnsFlow.Margin = [System.Windows.Forms.Padding]::new(0, 9, 0, 0)
Add-BodyControl -Body $networkCard.Body -Control $dnsFlow

$dnsOptions = @(
    @{ Name = 'None'; Width = 64 }
    @{ Name = 'Cloudflare'; Width = 98 }
    @{ Name = 'Google'; Width = 82 }
    @{ Name = 'Quad9'; Width = 72 }
    @{ Name = 'Automatic'; Width = 96 }
)
foreach ($option in $dnsOptions) {
    $chip = New-Object FlatButton
    $chip.Text = $option.Name
    $chip.Size = [System.Drawing.Size]::new($option.Width, 32)
    $chip.CornerRadius = 8
    $chip.TabStop = $false
    $chip.Cursor = [System.Windows.Forms.Cursors]::Hand
    $chip.Margin = [System.Windows.Forms.Padding]::new(0, 0, 8, 8)
    $chip.Tag = $option.Name
    $chip.add_Click({ Set-DnsSelection ([string]$this.Tag) })
    $script:DnsButtons[$option.Name] = $chip
    $dnsFlow.Controls.Add($chip)
}
Set-DnsSelection -Value 'None'

$safetyCard = New-Card -Title 'Safety' -Subtitle 'Risky options require explicit acknowledgement before a real run.' -Icon 'shield-check'
Add-StackCard -Stack $advStack -Card $safetyCard.Card
Add-ToggleRow -Body $safetyCard.Body -Key 'restore' -Title 'Create a restore point first' -Description 'Attempt a System Restore point before making changes. Recommended.' -Checked $true

$riskNote = New-Object System.Windows.Forms.Label
$riskNote.Text = 'Risky options can reduce Windows functionality, affect security tooling or be harder to reverse. Dry run never requires acknowledgement.'
$riskNote.AutoSize = $true
$riskNote.MaximumSize = [System.Drawing.Size]::new(700, 0)
$riskNote.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
$riskNote.ForeColor = $script:ColorOrange
$riskNote.BackColor = $script:ColorCard
$riskNote.Margin = [System.Windows.Forms.Padding]::new(0, 9, 0, 2)
Add-BodyControl -Body $safetyCard.Body -Control $riskNote

Add-ToggleRow -Body $safetyCard.Body -Key 'riskack' -Title 'I understand the risks' -Description 'Required to run while any risky option is enabled. This is reset by presets.' -Checked $false

$advStack.Controls.Clear()
$advStack.RowStyles.Clear()
$advStack.RowCount = 0
Add-StackCard -Stack $advStack -Card $safetyCard.Card
Add-StackCard -Stack $advStack -Card $advPrivacyCard.Card
Add-StackCard -Stack $advStack -Card $cleanupCard.Card
Add-StackCard -Stack $advStack -Card $powerCard.Card
Add-StackCard -Stack $advStack -Card $networkCard.Card

$logPage = New-Object System.Windows.Forms.Panel
$logPage.Dock = [System.Windows.Forms.DockStyle]::Fill
$logPage.BackColor = $script:ColorBg
$logPage.Visible = $false
$logPage.Padding = [System.Windows.Forms.Padding]::new(28, 8, 28, 24)
$script:Pages['log'] = $logPage
$script:PageHost.Controls.Add($logPage)

$logLayout = New-Object System.Windows.Forms.TableLayoutPanel
$logLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$logLayout.ColumnCount = 1
$logLayout.RowCount = 2
$logLayout.BackColor = $script:ColorBg
$logLayout.ColumnStyles.Clear()
$logLayout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$logLayout.RowStyles.Clear()
$logLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 42)) | Out-Null
$logLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) | Out-Null
$logPage.Controls.Add($logLayout)

$logToolbar = New-Object System.Windows.Forms.Panel
$logToolbar.Dock = [System.Windows.Forms.DockStyle]::Fill
$logToolbar.BackColor = $script:ColorBg
$logToolbar.Margin = [System.Windows.Forms.Padding]::new(0)
$logLayout.Controls.Add($logToolbar, 0, 0)

$liveIcon = New-Object IconBox
$liveIcon.Size = [System.Drawing.Size]::new(18, 18)
$liveIcon.Location = [System.Drawing.Point]::new(1, 11)
$liveIcon.GlyphData = Get-IconData 'terminal'
$liveIcon.BoxColor = [System.Drawing.Color]::Transparent
$liveIcon.IconColor = $script:ColorDim
$liveIcon.IconInset = 1
$logToolbar.Controls.Add($liveIcon)

$liveLabel = New-Object System.Windows.Forms.Label
$liveLabel.Text = 'LIVE OUTPUT'
$liveLabel.AutoSize = $true
$liveLabel.Font = [System.Drawing.Font]::new('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)
$liveLabel.ForeColor = $script:ColorDim
$liveLabel.BackColor = $script:ColorBg
$liveLabel.Location = [System.Drawing.Point]::new(27, 13)
$logToolbar.Controls.Add($liveLabel)

$logButtonBar = New-Object System.Windows.Forms.FlowLayoutPanel
$logButtonBar.Dock = [System.Windows.Forms.DockStyle]::Right
$logButtonBar.AutoSize = $true
$logButtonBar.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$logButtonBar.WrapContents = $false
$logButtonBar.BackColor = $script:ColorBg
$logToolbar.Controls.Add($logButtonBar)

$btnOpenLogs = New-Object FlatButton
$btnOpenLogs.Text = 'Open logs'
$btnOpenLogs.GlyphData = Get-IconData 'folder-open'
$btnOpenLogs.Size = [System.Drawing.Size]::new(116, 34)
$btnOpenLogs.BackColor = [System.Drawing.Color]::White
$btnOpenLogs.ForeColor = $script:ColorText
$btnOpenLogs.HoverColor = $script:ColorHover
$btnOpenLogs.PressedColor = $script:ColorBorder
$btnOpenLogs.BorderColor = $script:ColorBorderStrong
$btnOpenLogs.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$btnOpenLogs.Margin = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
$btnOpenLogs.add_Click({ Open-DebloatLogs })
$logButtonBar.Controls.Add($btnOpenLogs)

$btnClearLog = New-Object FlatButton
$btnClearLog.Text = 'Clear'
$btnClearLog.GlyphData = Get-IconData 'trash-2'
$btnClearLog.Size = [System.Drawing.Size]::new(94, 34)
$btnClearLog.BackColor = [System.Drawing.Color]::White
$btnClearLog.ForeColor = $script:ColorMuted
$btnClearLog.HoverColor = $script:ColorHover
$btnClearLog.PressedColor = $script:ColorBorder
$btnClearLog.BorderColor = [System.Drawing.Color]::Transparent
$btnClearLog.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$btnClearLog.Margin = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
$btnClearLog.add_Click({ Clear-DebloatLog })
$logButtonBar.Controls.Add($btnClearLog)

$logCard = New-Object CardPanel
$logCard.Dock = [System.Windows.Forms.DockStyle]::Fill
$logCard.FillColor = [System.Drawing.Color]::White
$logCard.BorderColor = $script:ColorBorder
$logCard.CornerRadius = 14
$logCard.Padding = [System.Windows.Forms.Padding]::new(14, 14, 14, 14)
$logCard.Margin = [System.Windows.Forms.Padding]::new(0, 4, 0, 0)
$logLayout.Controls.Add($logCard, 0, 1)

$script:LogBox = New-Object System.Windows.Forms.RichTextBox
$script:LogBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:LogBox.ReadOnly = $true
$script:LogBox.BackColor = [System.Drawing.Color]::White
$script:LogBox.ForeColor = $script:ColorLogText
$script:LogBox.Font = [System.Drawing.Font]::new('Consolas', 9.5)
$script:LogBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$script:LogBox.WordWrap = $false
$script:LogBox.HideSelection = $false
$script:LogBox.DetectUrls = $false
$script:LogBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both
$logCard.Controls.Add($script:LogBox)

$script:Toggles['aggressive'].add_CheckedChanged({
    if ($script:Toggles['aggressive'].Checked -and -not $script:Toggles['apps'].Checked) {
        $script:Toggles['apps'].Checked = $true
    }
})
$script:Toggles['xbox'].add_CheckedChanged({
    if ($script:Toggles['xbox'].Checked -and -not $script:Toggles['apps'].Checked) {
        $script:Toggles['apps'].Checked = $true
    }
})
$script:Toggles['apps'].add_CheckedChanged({
    if (-not $script:Toggles['apps'].Checked) {
        if ($script:Toggles['aggressive'].Checked) { $script:Toggles['aggressive'].Checked = $false }
        if ($script:Toggles['xbox'].Checked) { $script:Toggles['xbox'].Checked = $false }
    }
})

$script:Timer = New-Object System.Windows.Forms.Timer
$script:Timer.Interval = 150
$script:Timer.add_Tick({
    if (-not $script:Running -or $null -eq $script:Runner) { return }
    foreach ($line in $script:Runner.Drain()) {
        Append-LogLine $line
    }
    $script:ProgressLine.Step()
    if ($script:RunStart) {
        $elapsed = (Get-Date) - $script:RunStart
        $script:StatusLabel.Text = 'Running - ' + $elapsed.ToString('mm\:ss')
    }
    if ($script:Runner.HasExited) {
        try { $script:Runner.WaitForExit() } catch { }
        foreach ($line in $script:Runner.Drain()) {
            Append-LogLine $line
        }
        $code = $script:Runner.ExitCode
        $script:Running = $false
        $script:Runner = $null
        $script:Timer.Stop()
        $script:ProgressLine.Marquee = $false
        Set-Busy $false
        if ($code -eq 0) {
            $script:ProgressLine.Value = 100
            if ($script:DryRunActive) {
                $script:StatusLabel.Text = 'Dry run complete - no changes were made'
                $script:StatusLabel.ForeColor = $script:ColorAccent
            } else {
                $script:StatusLabel.Text = 'Completed - reboot recommended'
                $script:StatusLabel.ForeColor = $script:ColorGreen
            }
            Append-LogLine ''
            Append-LogLine 'Process finished (exit code 0).'
        } else {
            $script:ProgressLine.Value = 0
            $script:StatusLabel.Text = "Finished with exit code $code"
            $script:StatusLabel.ForeColor = $script:ColorOrange
            Append-LogLine ''
            Append-LogLine "Process exited with code $code. Check the log for details."
        }
    }
})

$form.add_FormClosing({
    param($sender, $eventArgs)
    if ($script:Running) {
        [System.Windows.Forms.MessageBox]::Show('A debloat run is still in progress. Please wait for it to finish.', 'Still running', 'OK', 'Information') | Out-Null
        $eventArgs.Cancel = $true
    }
})

$form.add_Shown({
    Write-StartupLog 'Main form shown.'
    $targetPage = 'dashboard'
    if ($SelfTest -and $SelfTestPage) { $targetPage = $SelfTestPage }
    Show-Page $targetPage
    Update-Dashboard
    Append-LogLine 'Ready. Select options and click Run, or use Dry run to preview safely.'
    Append-LogLine 'Defender, Windows Update, Microsoft Store, Edge and printing are left untouched.'

    if ($SelfTest) {
        $form.TopMost = $true
        $script:SelfTestTimer = New-Object System.Windows.Forms.Timer
        $script:SelfTestTimer.Interval = 1500
        $script:SelfTestTimer.add_Tick({
            $script:SelfTestTimer.Stop()
            try {
                $origin = $form.PointToScreen([System.Drawing.Point]::Empty)
                $size = $form.ClientSize
                $bitmap = New-Object System.Drawing.Bitmap($size.Width, $size.Height)
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                $graphics.CopyFromScreen($origin, [System.Drawing.Point]::Empty, $size)
                $graphics.Dispose()
                $assetsDir = Join-Path $script:GuiRoot 'assets'
                if (-not (Test-Path -LiteralPath $assetsDir)) {
                    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
                }
                $shotName = 'screenshot.png'
                if ($SelfTestPage -and $SelfTestPage -ne 'dashboard') { $shotName = 'screenshot-' + $SelfTestPage + '.png' }
                $shotPath = Join-Path $assetsDir $shotName
                $bitmap.Save($shotPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $bitmap.Dispose()
                Write-StartupLog ('Self-test screenshot saved: ' + $shotPath)
            } catch {
                Write-StartupLog ('Self-test screenshot failed: ' + $_.Exception.ToString())
            }
            $form.Close()
        })
        $script:SelfTestTimer.Start()
    }
})

if ($splash) {
    $splash.Close()
    $splash.Dispose()
    $splash = $null
    Write-StartupLog 'Splash closed.'
}

try {
    [System.Windows.Forms.Application]::Run($form)
} catch {
    Write-StartupLog ('Application.Run failed: ' + $_.Exception.ToString())
    throw
} finally {
    Write-StartupLog 'Application.Run returned; GUI closed.'
}
