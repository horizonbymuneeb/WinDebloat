[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Fail {
    param([string]$Message)
    $failures.Add($Message)
    Write-Host ('FAIL  ' + $Message) -ForegroundColor Red
}

function Pass {
    param([string]$Message)
    Write-Host ('OK    ' + $Message) -ForegroundColor Green
}

foreach ($script in @('WinDebloat.ps1', 'WinDebloat-GUI.ps1', 'tools\validate.ps1')) {
    $path = Join-Path $root $script
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        foreach ($parseError in $parseErrors) {
            Fail ($script + ': ' + $parseError.Message)
        }
    } else {
        Pass ($script + ' syntax')
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

try {
    Add-Type -Path (Join-Path $root 'ui\WinDebloatUi.cs') -ReferencedAssemblies $uiReferences -ErrorAction Stop
    Pass 'ui\WinDebloatUi.cs compiles'
} catch {
    Fail ('C# compile: ' + $_.Exception.Message)
}

try {
    [System.Reflection.Assembly]::LoadFrom((Join-Path $wpfDirectory 'PresentationCore.dll')) | Out-Null
    [System.Reflection.Assembly]::LoadFrom((Join-Path $wpfDirectory 'WindowsBase.dll')) | Out-Null
} catch {
    Fail ('WPF load: ' + $_.Exception.Message)
}

$iconDirectory = Join-Path $root 'assets\icons'
$icons = @(Get-ChildItem -LiteralPath $iconDirectory -Filter '*.svg' -File -ErrorAction SilentlyContinue)
if ($icons.Count -eq 0) {
    Fail 'No SVG icons found in assets\icons.'
} else {
    $invalid = 0
    foreach ($icon in $icons) {
        $svg = Get-Content -LiteralPath $icon.FullName -Raw
        $pathMatches = [regex]::Matches($svg, '\sd="([^"]+)"')
        if ($pathMatches.Count -eq 0) {
            Fail ('No path data: ' + $icon.Name)
            $invalid++
            continue
        }
        $data = (($pathMatches | ForEach-Object { $_.Groups[1].Value.Trim() }) -join ' ')
        try {
            [System.Windows.Media.Geometry]::Parse($data) | Out-Null
        } catch {
            Fail ('Invalid SVG path: ' + $icon.Name)
            $invalid++
        }
    }
    if ($invalid -eq 0) {
        Pass ($icons.Count.ToString() + ' SVG icons parse')
    }
}

foreach ($asset in @('assets\logo.svg', 'assets\logo.png', 'assets\WinDebloat.ico')) {
    if (Test-Path -LiteralPath (Join-Path $root $asset)) {
        Pass $asset
    } else {
        Fail ('Missing ' + $asset)
    }
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host ('Validation failed: ' + $failures.Count + ' problem(s).') -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host 'Validation passed.' -ForegroundColor Green
exit 0
