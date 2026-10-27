[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoRestorePoint,
    [switch]$Aggressive,
    [switch]$RemoveXbox,
    [switch]$RemoveOneDrive,
    [switch]$KeepCopilot,
    [switch]$SkipApps,
    [switch]$SkipServices,
    [switch]$SkipTasks,
    [switch]$SkipPrivacy,
    [switch]$KeepBackgroundApps,
    [string[]]$KeepApps = @(),
    [switch]$DisableSysMain,
    [switch]$DisableHibernation,
    [switch]$UltimatePerformance,
    [switch]$DisableSearchIndexing,
    [switch]$DisableVisualEffects,
    [switch]$DisableMouseAcceleration,
    [switch]$DisableStartupDelay,
    [switch]$DisableWerService,
    [switch]$DisableGameDvr,
    [switch]$DisableRecall,
    [switch]$DisableLocation,
    [switch]$DisableLlmnr,
    [switch]$DisableDriverUpdates,
    [switch]$CleanTemp,
    [switch]$CleanUpdateCache,
    [switch]$CleanDeliveryOptimization,
    [switch]$CleanThumbnailCache,
    [switch]$EmptyRecycleBin,
    [ValidateSet('None', 'Cloudflare', 'Google', 'Quad9', 'Automatic')]
    [string]$DnsProvider = 'None'
)

$ErrorActionPreference = 'Continue'

$KeepApps = @($KeepApps | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$script:Stats = @{
    AppsInstalled   = 0
    AppsProvisioned = 0
    Services        = 0
    Tasks           = 0
    Registry        = 0
    OneDrive        = 0
    Performance     = 0
    Power           = 0
    Network         = 0
    CleanupBytes    = [long]0
    CleanupActions  = 0
}
$script:Warnings = @()
$script:LastActionOk = $false

$BloatApps = @(
    'Microsoft.549981C3F5F10'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Clipchamp.Clipchamp'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.Microsoft3DViewer'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MixedReality.Portal'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.SkypeApp'
    'Microsoft.Todos'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.Wallet'
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftTeams'
    '7EE7776C.LinkedInforWindows'
)

$AggressiveApps = @(
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'MSTeams'
    'Microsoft.OutlookForWindows'
    'Microsoft.Copilot'
    'Microsoft.BingSearch'
)

$XboxApps = @(
    'Microsoft.GamingApp'
    'Microsoft.Xbox*'
)

$serviceTargets = @(
    @{ Name = 'DiagTrack'; Startup = 'Disabled' }
    @{ Name = 'dmwappushservice'; Startup = 'Disabled' }
    @{ Name = 'MapsBroker'; Startup = 'Disabled' }
    @{ Name = 'WMPNetworkSvc'; Startup = 'Disabled' }
    @{ Name = 'Fax'; Startup = 'Disabled' }
    @{ Name = 'RemoteRegistry'; Startup = 'Disabled' }
    @{ Name = 'RetailDemo'; Startup = 'Disabled' }
)

$scheduledTasks = @(
    @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater' }
    @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser' }
    @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'AITAgent' }
    @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy' }
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' }
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' }
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'KernelCeipTask' }
    @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClient' }
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClientOnScenarioDownload' }
    @{ Path = '\Microsoft\Windows\Windows Error Reporting\'; Name = 'QueueReporting' }
)

$registryTweaks = @(
    @{ Label = 'Telemetry: diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
    @{ Label = 'Telemetry: feedback prompts'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1 }
    @{ Label = 'Privacy: tailored experiences'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0 }
    @{ Label = 'Privacy: advertising ID'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0 }
    @{ Label = 'Privacy: activity feed policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 }
    @{ Label = 'Privacy: publish activities policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 }
    @{ Label = 'Privacy: upload activities policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 }
    @{ Label = 'Privacy: publish activities'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'PublishUserActivities'; Value = 0 }
    @{ Label = 'Privacy: upload activities'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'UploadUserActivities'; Value = 0 }
    @{ Label = 'Privacy: feedback frequency'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0 }
    @{ Label = 'Privacy: feedback period'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'PeriodInNanoSeconds'; Value = 0 }
    @{ Label = 'Ads: Windows consumer features'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1 }
    @{ Label = 'Ads: Windows soft landing'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableSoftLanding'; Value = 1 }
    @{ Label = 'Ads: silent app installs'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0 }
    @{ Label = 'Ads: suggested settings content'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Value = 0 }
    @{ Label = 'Ads: Windows tips'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0 }
    @{ Label = 'Ads: occasional suggestions'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0 }
    @{ Label = 'Ads: Start menu suggestions'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0 }
    @{ Label = 'Ads: preinstalled apps'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0 }
    @{ Label = 'Ads: OEM preinstalled apps'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0 }
    @{ Label = 'Ads: suggested apps 310093'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0 }
    @{ Label = 'Ads: lock screen tips'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338387Enabled'; Value = 0 }
    @{ Label = 'Ads: suggested apps 353694'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Value = 0 }
    @{ Label = 'Ads: suggested apps 353696'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353696Enabled'; Value = 0 }
    @{ Label = 'Ads: suggested apps 353698'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353698Enabled'; Value = 0 }
    @{ Label = 'Ads: sync provider notifications'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSyncProviderNotifications'; Value = 0 }
    @{ Label = 'Ads: Windows welcome experience'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0 }
    @{ Label = 'Ads: Start recommendations'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Value = 0 }
    @{ Label = 'Ads: Start account notifications'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_AccountNotifications'; Value = 0 }
    @{ Label = 'Search: web results in Start'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 }
    @{ Label = 'Search: Cortana consent'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'CortanaConsent'; Value = 0 }
    @{ Label = 'Search: Cortana policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana'; Value = 0 }
    @{ Label = 'Search: web search policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'DisableWebSearch'; Value = 1 }
    @{ Label = 'Search: connected search web'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'ConnectedSearchUseWeb'; Value = 0 }
    @{ Label = 'Search: search highlights'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0 }
    @{ Label = 'Taskbar: widgets button'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarDa'; Value = 0 }
    @{ Label = 'Taskbar: widgets policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0 }
)

$copilotTweaks = @(
    @{ Label = 'Taskbar: Copilot button'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0 }
    @{ Label = 'Copilot: policy disabled'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
)

$backgroundTweaks = @(
    @{ Label = 'Background: UWP apps disabled'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name = 'GlobalUserDisabled'; Value = 1 }
    @{ Label = 'Background: app global toggle'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BackgroundAppGlobalToggle'; Value = 0 }
)

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  [SKIP] $Message" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
    $script:Warnings += $Message
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Test-AppMatch {
    param([string]$Name, [string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

function Test-KeepApp {
    param([string]$Name)
    foreach ($pattern in $KeepApps) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

function Test-AllSsds {
    try {
        $disks = @(Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.BusType -ne 'File Backed Virtual' })
        if ($disks.Count -eq 0) { return $false }
        foreach ($disk in $disks) {
            if ($disk.MediaType -ne 'SSD') { return $false }
        }
        return $true
    } catch {
        return $false
    }
}

function New-DebloatRestorePoint {
    Write-Step 'Creating a restore point'
    if ($NoRestorePoint) {
        Write-Skip 'Skipped by -NoRestorePoint'
        return
    }
    if ($DryRun) {
        Write-Info '[WhatIf] Create a system restore point'
        return
    }
    try {
        Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction Stop
        Checkpoint-Computer -Description 'Before WinDebloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Ok 'Restore point created'
    } catch {
        Write-Warn "Restore point not created: $($_.Exception.Message)"
    }
}

function Remove-BloatApps {
    Write-Step 'Removing bloatware apps'
    $patterns = @($BloatApps)
    if ($Aggressive) {
        foreach ($app in $AggressiveApps) {
            if ($KeepCopilot -and $app -eq 'Microsoft.Copilot') { continue }
            $patterns += $app
        }
    }
    if ($RemoveXbox) { $patterns += $XboxApps }

    $provisioned = @()
    try {
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop)
    } catch {
        Write-Warn "Could not enumerate provisioned packages: $($_.Exception.Message)"
    }
    foreach ($package in $provisioned) {
        $name = $package.DisplayName
        if (-not (Test-AppMatch -Name $name -Patterns $patterns)) { continue }
        if (Test-KeepApp -Name $name) {
            Write-Skip "$name (kept by -KeepApps)"
            continue
        }
        if ($DryRun) {
            Write-Info "[WhatIf] Remove provisioned app: $name"
            $script:Stats.AppsProvisioned++
            continue
        }
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
            Write-Ok "Provisioned: $name"
            $script:Stats.AppsProvisioned++
        } catch {
            Write-Warn "Provisioned $name : $($_.Exception.Message)"
        }
    }

    $installed = @()
    try {
        $installed = @(Get-AppxPackage -AllUsers -ErrorAction Stop)
    } catch {
        try {
            $installed = @(Get-AppxPackage -ErrorAction Stop)
        } catch {
            Write-Warn "Could not enumerate installed packages: $($_.Exception.Message)"
        }
    }
    foreach ($package in $installed) {
        $name = $package.Name
        if (-not (Test-AppMatch -Name $name -Patterns $patterns)) { continue }
        if (Test-KeepApp -Name $name) {
            Write-Skip "$name (kept by -KeepApps)"
            continue
        }
        if ($DryRun) {
            Write-Info "[WhatIf] Remove installed app: $name"
            $script:Stats.AppsInstalled++
            continue
        }
        try {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
            Write-Ok "Removed: $name"
            $script:Stats.AppsInstalled++
        } catch {
            try {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                Write-Ok "Removed: $name"
                $script:Stats.AppsInstalled++
            } catch {
                Write-Warn "Could not remove $name : $($_.Exception.Message)"
            }
        }
    }

    if (($script:Stats.AppsProvisioned + $script:Stats.AppsInstalled) -eq 0) {
        Write-Info 'No matching bloatware apps found'
    }
}

function Set-ServiceConfig {
    param([string]$Name, [string]$Startup)
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Skip "$Name (not installed)"
        $script:LastActionOk = $false
        return
    }
    if ($DryRun) {
        Write-Info "[WhatIf] Service $Name -> $Startup"
        $script:Stats.Services++
        $script:LastActionOk = $true
        return
    }
    try {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Name -StartupType $Startup -ErrorAction Stop
        Write-Ok "$Name -> $Startup"
        $script:Stats.Services++
        $script:LastActionOk = $true
    } catch {
        Write-Warn "Service $Name : $($_.Exception.Message)"
        $script:LastActionOk = $false
    }
}

function Optimize-Services {
    Write-Step 'Optimizing services'
    foreach ($serviceInfo in $serviceTargets) {
        Set-ServiceConfig -Name $serviceInfo.Name -Startup $serviceInfo.Startup
    }
    if ($Aggressive) {
        if (Test-AllSsds) {
            Set-ServiceConfig -Name 'SysMain' -Startup 'Disabled'
        } else {
            Write-Skip 'SysMain left enabled (not all physical disks are SSD)'
        }
    }
    if ($RemoveXbox) {
        Set-ServiceConfig -Name 'XblAuthManager' -Startup 'Disabled'
        Set-ServiceConfig -Name 'XblGameSave' -Startup 'Disabled'
        Set-ServiceConfig -Name 'XboxGipSvc' -Startup 'Disabled'
        Set-ServiceConfig -Name 'XboxNetApiSvc' -Startup 'Disabled'
        Set-DebloatRegistryValue -Label 'Xbox: Game DVR disabled' -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0
        Set-DebloatRegistryValue -Label 'Xbox: Game DVR policy disabled' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0
    }
}

function Disable-TelemetryTasks {
    Write-Step 'Disabling telemetry scheduled tasks'
    foreach ($taskInfo in $scheduledTasks) {
        $task = Get-ScheduledTask -TaskPath $taskInfo.Path -TaskName $taskInfo.Name -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Skip "$($taskInfo.Name) (not present)"
            continue
        }
        if ($DryRun) {
            Write-Info "[WhatIf] Disable task $($taskInfo.Name)"
            $script:Stats.Tasks++
            continue
        }
        try {
            Disable-ScheduledTask -TaskPath $taskInfo.Path -TaskName $taskInfo.Name -ErrorAction Stop | Out-Null
            Write-Ok "$($taskInfo.Name) disabled"
            $script:Stats.Tasks++
        } catch {
            Write-Warn "Task $($taskInfo.Name) : $($_.Exception.Message)"
        }
    }
}

function Set-DebloatRegistryValue {
    param([string]$Label, [string]$Path, [string]$Name, $Value)
    if ($DryRun) {
        Write-Info "[WhatIf] $Label"
        $script:Stats.Registry++
        $script:LastActionOk = $true
        return
    }
    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Ok $Label
        $script:Stats.Registry++
        $script:LastActionOk = $true
    } catch {
        Write-Warn "$Label : $($_.Exception.Message)"
        $script:LastActionOk = $false
    }
}

function Set-PrivacyTweaks {
    Write-Step 'Applying privacy, ads and search tweaks'
    foreach ($tweak in $registryTweaks) {
        Set-DebloatRegistryValue -Label $tweak.Label -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value
    }
}

function Set-CopilotTweaks {
    Write-Step 'Applying Copilot tweaks'
    foreach ($tweak in $copilotTweaks) {
        Set-DebloatRegistryValue -Label $tweak.Label -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value
    }
}

function Set-BackgroundTweaks {
    Write-Step 'Disabling background app activity'
    foreach ($tweak in $backgroundTweaks) {
        Set-DebloatRegistryValue -Label $tweak.Label -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value
    }
}

function Set-PerformanceValue {
    param([string]$Label, [string]$Path, [string]$Name, $Value)
    Set-DebloatRegistryValue -Label $Label -Path $Path -Name $Name -Value $Value
    if ($script:LastActionOk) {
        $script:Stats.Performance++
    }
}

function Disable-MouseAcceleration {
    $code = @'
using System;
using System.Runtime.InteropServices;
public static class WinDebloatMouse
{
    private const uint SPI_SETMOUSE = 0x0004;
    private const uint SPIF_UPDATEINIFILE = 0x0001;
    private const uint SPIF_SENDCHANGE = 0x0002;
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SystemParametersInfo(uint action, uint param, int[] values, uint winIni);
    public static bool Disable()
    {
        int[] values = new int[3] { 0, 0, 0 };
        return SystemParametersInfo(SPI_SETMOUSE, 0, values, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
    }
}
'@
    try {
        if (-not ('WinDebloatMouse' -as [type])) {
            Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
        }
        if ([WinDebloatMouse]::Disable()) {
            Write-Ok 'Mouse acceleration disabled'
            $script:Stats.Performance++
        } else {
            Write-Warn 'Mouse acceleration could not be disabled'
        }
    } catch {
        Write-Warn "Mouse acceleration: $($_.Exception.Message)"
    }
}

function Invoke-PerformanceTweaks {
    $enabled = $DisableSysMain -or $DisableSearchIndexing -or $DisableVisualEffects -or $DisableMouseAcceleration -or $DisableStartupDelay -or $DisableGameDvr -or $DisableWerService
    if (-not $enabled) { return }
    Write-Step 'Applying performance tweaks'
    if ($DisableSysMain) {
        if (-not (Test-AllSsds)) {
            Write-Warn 'SysMain is being disabled on a non-SSD system; app launches may slow down'
        }
        Set-ServiceConfig -Name 'SysMain' -Startup 'Disabled'
        if ($script:LastActionOk) { $script:Stats.Performance++ }
    }
    if ($DisableSearchIndexing) {
        Set-ServiceConfig -Name 'WSearch' -Startup 'Disabled'
        if ($script:LastActionOk) { $script:Stats.Performance++ }
        Write-Info 'Start menu search still works; file content indexing is disabled'
    }
    if ($DisableWerService) {
        Set-ServiceConfig -Name 'WerSvc' -Startup 'Disabled'
        if ($script:LastActionOk) { $script:Stats.Performance++ }
        Set-PerformanceValue -Label 'Error reporting: policy disabled' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1
    }
    if ($DisableVisualEffects) {
        Set-PerformanceValue -Label 'Visual effects: performance mode' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2
        Set-PerformanceValue -Label 'Visual effects: transparency off' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0
        Set-PerformanceValue -Label 'Visual effects: window animations off' -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value 0
        Set-PerformanceValue -Label 'Visual effects: taskbar animations off' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0
    }
    if ($DisableMouseAcceleration) {
        if ($DryRun) {
            Write-Info '[WhatIf] Disable mouse acceleration'
            $script:Stats.Performance++
        } else {
            Disable-MouseAcceleration
        }
    }
    if ($DisableStartupDelay) {
        Set-PerformanceValue -Label 'Startup: app launch delay removed' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Value 0
    }
    if ($DisableGameDvr) {
        Set-PerformanceValue -Label 'Game DVR: capture disabled' -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0
        Set-PerformanceValue -Label 'Game DVR: app capture disabled' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0
        Set-PerformanceValue -Label 'Game DVR: policy disabled' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0
    }
}

function Set-AdvancedPrivacyTweaks {
    $enabled = $DisableRecall -or $DisableLocation -or $DisableLlmnr -or $DisableDriverUpdates
    if (-not $enabled) { return }
    Write-Step 'Applying advanced privacy tweaks'
    if ($DisableRecall) {
        Set-DebloatRegistryValue -Label 'Recall: AI data analysis disabled' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1
    }
    if ($DisableLocation) {
        Set-DebloatRegistryValue -Label 'Location: policy disabled' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1
        Set-ServiceConfig -Name 'lfsvc' -Startup 'Disabled'
    }
    if ($DisableLlmnr) {
        Set-DebloatRegistryValue -Label 'Network: LLMNR disabled' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Value 0
    }
    if ($DisableDriverUpdates) {
        Set-DebloatRegistryValue -Label 'Update: driver search disabled' -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Name 'SearchOrderConfig' -Value 0
        Set-DebloatRegistryValue -Label 'Update: drivers excluded from quality updates' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'ExcludeWUDriversInQualityUpdate' -Value 1
    }
}

function Get-PathSize {
    param([string]$Path)
    $size = [long]0
    try {
        $measured = Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
        if ($measured -and $measured.Sum) { $size = [long]$measured.Sum }
    } catch {
    }
    return $size
}

function Clear-CleanupPath {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path -ErrorAction SilentlyContinue)) {
        Write-Skip "$Label (not present)"
        return
    }
    $size = Get-PathSize -Path $Path
    if ($DryRun) {
        Write-Info ("[WhatIf] Clear {0} ({1})" -f $Label, (Format-Bytes $size))
        $script:Stats.CleanupBytes += $size
        $script:Stats.CleanupActions++
        return
    }
    try {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $script:Stats.CleanupBytes += $size
        $script:Stats.CleanupActions++
        Write-Ok ("Cleared {0} ({1})" -f $Label, (Format-Bytes $size))
    } catch {
        Write-Warn "$Label : $($_.Exception.Message)"
    }
}

function Clear-CleanupFiles {
    param([object[]]$Files, [string]$Label)
    $items = @($Files | Where-Object { $_ -ne $null })
    if ($items.Count -eq 0) {
        Write-Skip "$Label (nothing to clean)"
        return
    }
    $size = [long]0
    foreach ($item in $items) {
        try { $size += [long]$item.Length } catch {
        }
    }
    if ($DryRun) {
        Write-Info ("[WhatIf] Clear {0} ({1})" -f $Label, (Format-Bytes $size))
        $script:Stats.CleanupBytes += $size
        $script:Stats.CleanupActions++
        return
    }
    $removed = 0
    foreach ($item in $items) {
        try {
            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            $removed++
        } catch {
        }
    }
    if ($removed -gt 0) {
        $script:Stats.CleanupBytes += $size
        $script:Stats.CleanupActions++
        Write-Ok ("Cleared {0} ({1} files, {2})" -f $Label, $removed, (Format-Bytes $size))
    } else {
        Write-Warn "$Label could not be cleared; files are in use"
    }
}

function Invoke-Cleanup {
    $enabled = $CleanTemp -or $CleanUpdateCache -or $CleanDeliveryOptimization -or $CleanThumbnailCache -or $EmptyRecycleBin
    if (-not $enabled) { return }
    Write-Step 'Cleaning temporary data'
    if ($CleanTemp) {
        Clear-CleanupPath -Path $env:TEMP -Label 'User temp files'
        Clear-CleanupPath -Path (Join-Path $env:SystemRoot 'Temp') -Label 'Windows temp files'
    }
    if ($CleanUpdateCache) {
        $wasRunning = $false
        if (-not $DryRun) {
            $wu = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
            if ($wu -and $wu.Status -eq 'Running') {
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                $wasRunning = $true
            }
        }
        Clear-CleanupPath -Path (Join-Path $env:SystemRoot 'SoftwareDistribution\Download') -Label 'Windows Update cache'
        if ($wasRunning) {
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        }
    }
    if ($CleanDeliveryOptimization) {
        Clear-CleanupPath -Path (Join-Path $env:SystemRoot 'SoftwareDistribution\DeliveryOptimization') -Label 'Delivery Optimization cache'
        Clear-CleanupPath -Path (Join-Path $env:SystemRoot 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache') -Label 'Delivery Optimization user cache'
    }
    if ($CleanThumbnailCache) {
        $thumbDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
        $thumbFiles = @()
        if (Test-Path -LiteralPath $thumbDir -ErrorAction SilentlyContinue) {
            $thumbFiles = @(Get-ChildItem -LiteralPath $thumbDir -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue)
        }
        Clear-CleanupFiles -Files $thumbFiles -Label 'Thumbnail cache'
    }
    if ($EmptyRecycleBin) {
        $binPath = Join-Path $env:SystemDrive '$Recycle.Bin'
        $binSize = Get-PathSize -Path $binPath
        if ($binSize -le 0) {
            Write-Skip 'Recycle Bin is already empty'
        } elseif ($DryRun) {
            Write-Info ("[WhatIf] Empty Recycle Bin ({0})" -f (Format-Bytes $binSize))
            $script:Stats.CleanupBytes += $binSize
            $script:Stats.CleanupActions++
        } else {
            try {
                Clear-RecycleBin -Force -ErrorAction Stop
                $script:Stats.CleanupBytes += $binSize
                $script:Stats.CleanupActions++
                Write-Ok ("Emptied Recycle Bin ({0})" -f (Format-Bytes $binSize))
            } catch {
                Write-Warn "Recycle Bin: $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-PowerTweaks {
    if (-not ($DisableHibernation -or $UltimatePerformance)) { return }
    Write-Step 'Configuring power settings'
    if ($DisableHibernation) {
        if ($DryRun) {
            Write-Info '[WhatIf] Disable hibernation and Fast Startup'
            $script:Stats.Power++
        } else {
            & powercfg.exe /hibernate off | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok 'Hibernation and Fast Startup disabled'
                $script:Stats.Power++
            } else {
                Write-Warn "powercfg /hibernate off failed with code $LASTEXITCODE"
            }
        }
    }
    if ($UltimatePerformance) {
        if ($DryRun) {
            Write-Info '[WhatIf] Activate the Ultimate Performance power plan'
            $script:Stats.Power++
        } else {
            $ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
            $highGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            $output = & powercfg.exe -duplicatescheme $ultimateGuid 2>&1 | Out-String
            $match = [regex]::Match($output, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
            $target = $null
            if ($match.Success) { $target = $match.Value }
            if ($target) {
                & powercfg.exe -setactive $target | Out-Null
                if ($LASTEXITCODE -ne 0) { $target = $null }
            }
            if (-not $target) {
                & powercfg.exe -setactive $ultimateGuid | Out-Null
                if ($LASTEXITCODE -eq 0) { $target = $ultimateGuid }
            }
            if (-not $target) {
                & powercfg.exe -setactive $highGuid | Out-Null
                if ($LASTEXITCODE -eq 0) { $target = $highGuid }
            }
            if ($target) {
                Write-Ok "Power plan activated: $target"
                $script:Stats.Power++
            } else {
                Write-Warn 'Could not activate the Ultimate Performance power plan'
            }
        }
    }
}

function Set-DnsProvider {
    if ($DnsProvider -eq 'None') { return }
    Write-Step "Configuring DNS ($DnsProvider)"
    $servers = @()
    if ($DnsProvider -eq 'Cloudflare') { $servers = @('1.1.1.1', '1.0.0.1') }
    elseif ($DnsProvider -eq 'Google') { $servers = @('8.8.8.8', '8.8.4.4') }
    elseif ($DnsProvider -eq 'Quad9') { $servers = @('9.9.9.9', '149.112.112.112') }
    $adapters = @()
    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' })
    } catch {
        Write-Warn "Could not enumerate network adapters: $($_.Exception.Message)"
        return
    }
    if ($adapters.Count -eq 0) {
        Write-Warn 'No active physical network adapters found'
        return
    }
    foreach ($adapter in $adapters) {
        if ($DryRun) {
            if ($DnsProvider -eq 'Automatic') {
                Write-Info "[WhatIf] $($adapter.Name): DNS automatic"
            } else {
                Write-Info "[WhatIf] $($adapter.Name): DNS $($servers -join ', ')"
            }
            $script:Stats.Network++
            continue
        }
        try {
            if ($DnsProvider -eq 'Automatic') {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction Stop
                Write-Ok "$($adapter.Name): DNS automatic"
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $servers -ErrorAction Stop
                Write-Ok "$($adapter.Name): DNS $($servers -join ', ')"
            }
            $script:Stats.Network++
        } catch {
            Write-Warn "DNS on $($adapter.Name): $($_.Exception.Message)"
        }
    }
    if (-not $DryRun) {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    }
}

function Show-RiskyNotice {
    $items = @()
    if ($DisableSysMain) { $items += 'SysMain disabled (HDD systems may slow down)' }
    if ($DisableSearchIndexing) { $items += 'Windows Search indexing disabled' }
    if ($DisableWerService) { $items += 'Windows Error Reporting disabled' }
    if ($DisableLlmnr) { $items += 'LLMNR disabled (legacy name resolution)' }
    if ($DisableDriverUpdates) { $items += 'Automatic driver updates excluded' }
    if ($DisableHibernation) { $items += 'Hibernation and Fast Startup disabled' }
    if ($UltimatePerformance) { $items += 'Ultimate Performance power plan' }
    if ($DnsProvider -ne 'None') { $items += "DNS provider changed to $DnsProvider" }
    if ($items.Count -eq 0) { return }
    Write-Host ''
    Write-Host 'Advanced options enabled:' -ForegroundColor Yellow
    foreach ($item in $items) {
        Write-Host "  - $item" -ForegroundColor DarkYellow
    }
    Write-Host '  Use -DryRun to preview these changes safely.' -ForegroundColor DarkGray
}

function Remove-OneDriveClient {
    Write-Step 'Removing OneDrive client'
    if ($DryRun) {
        Write-Info '[WhatIf] Uninstall OneDrive client (local files kept)'
        $script:Stats.OneDrive++
        return
    }
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    $candidates = @(
        (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe')
        (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe')
    )
    $setup = $null
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $setup = $candidate
            break
        }
    }
    if (-not $setup) {
        Write-Skip 'OneDrive is not installed'
        return
    }
    try {
        $process = Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($process.ExitCode -eq 0) {
            Write-Ok 'OneDrive client uninstalled (local files kept)'
            $script:Stats.OneDrive++
        } else {
            Write-Warn "OneDrive uninstaller exited with code $($process.ExitCode)"
        }
    } catch {
        Write-Warn "OneDrive uninstall failed: $($_.Exception.Message)"
    }
}

function Show-StartupPrograms {
    Write-Step 'Startup programs (informational)'
    $startupItems = @(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue)
    if ($startupItems.Count -eq 0) {
        Write-Info 'No startup entries found'
        return
    }
    foreach ($item in $startupItems) {
        $command = [string]$item.Command
        if ($command.Length -gt 120) {
            $command = $command.Substring(0, 117) + '...'
        }
        Write-Info ("{0} | {1}" -f $item.Name, $command)
    }
    Write-Info 'Review unnecessary entries in Task Manager > Startup apps'
}

function Show-Summary {
    Write-Step 'Summary'
    $planned = ''
    if ($DryRun) { $planned = '[planned] ' }
    Write-Info ($planned + "Installed apps removed: $($script:Stats.AppsInstalled)")
    Write-Info ($planned + "Provisioned packages removed: $($script:Stats.AppsProvisioned)")
    Write-Info ($planned + "Services configured: $($script:Stats.Services)")
    Write-Info ($planned + "Scheduled tasks disabled: $($script:Stats.Tasks)")
    Write-Info ($planned + "Registry values applied: $($script:Stats.Registry)")
    if ($script:Stats.Performance -gt 0) {
        Write-Info ($planned + "Performance tweaks applied: $($script:Stats.Performance)")
    }
    if ($script:Stats.CleanupActions -gt 0) {
        Write-Info ($planned + ("Cleanup: {0} actions, {1} reclaimed" -f $script:Stats.CleanupActions, (Format-Bytes $script:Stats.CleanupBytes)))
    }
    if ($script:Stats.Power -gt 0) {
        Write-Info ($planned + "Power settings changed: $($script:Stats.Power)")
    }
    if ($script:Stats.Network -gt 0) {
        Write-Info ($planned + "Network adapters configured: $($script:Stats.Network)")
    }
    if ($RemoveOneDrive) {
        Write-Info ($planned + "OneDrive actions: $($script:Stats.OneDrive)")
    }
    if ($script:Warnings.Count -gt 0) {
        Write-Host ''
        Write-Host "Warnings: $($script:Warnings.Count) (see log)" -ForegroundColor Yellow
    }
    if ($transcriptStarted) {
        Write-Info "Log: $logPath"
    }
    if ($DryRun) {
        Write-Host 'Dry run complete. No changes were made.' -ForegroundColor Yellow
    } else {
        Write-Host 'Done. Restart Windows to finish applying changes.' -ForegroundColor Green
    }
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'This script must run as Administrator.' -ForegroundColor Red
    Write-Host 'Right-click OneClick-Debloat.bat and choose Run as administrator.' -ForegroundColor Yellow
    exit 1
}

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$logDir = Join-Path $scriptRoot 'logs'
$logPath = Join-Path $logDir ('WinDebloat_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
$transcriptStarted = $false
try {
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
    }
    Start-Transcript -Path $logPath -Force -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Host "Logging disabled: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    $mode = 'Standard'
    if ($DryRun) { $mode = 'Dry run' }
    elseif ($Aggressive) { $mode = 'Aggressive' }

    Write-Host ''
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ' Windows Debloat + Background Optimizer' -ForegroundColor White
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host " Mode: $mode" -ForegroundColor Gray
    Write-Host ' Removes curated apps, telemetry tasks and ads. A restore point is attempted.' -ForegroundColor DarkGray
    Write-Host ' Per-user tweaks apply to the elevated account.' -ForegroundColor DarkGray
    Show-RiskyNotice

    if ($DryRun) {
        Write-Host ''
        Write-Host 'DRY RUN: nothing will be changed.' -ForegroundColor Yellow
    } elseif (-not $Force) {
        for ($seconds = 5; $seconds -ge 1; $seconds--) {
            Write-Host ("`rStarting in {0}s. Press Ctrl+C to cancel." -f $seconds) -NoNewline
            Start-Sleep -Seconds 1
        }
        Write-Host "`rStarting now.                              "
    }

    New-DebloatRestorePoint
    if (-not $SkipApps) { Remove-BloatApps }
    if (-not $SkipServices) { Optimize-Services }
    if (-not $SkipTasks) { Disable-TelemetryTasks }
    Invoke-PerformanceTweaks
    Set-AdvancedPrivacyTweaks
    if (-not $SkipPrivacy) { Set-PrivacyTweaks }
    if (-not $KeepCopilot) { Set-CopilotTweaks }
    if (-not $KeepBackgroundApps) { Set-BackgroundTweaks }
    Invoke-Cleanup
    Invoke-PowerTweaks
    Set-DnsProvider
    if ($RemoveOneDrive) {
        Remove-OneDriveClient
    }
    Show-StartupPrograms
    Show-Summary
} finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
