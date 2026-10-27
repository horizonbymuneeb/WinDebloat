# WinDebloat

<p align="center">
  <img src="assets/logo.svg" width="72" height="72" alt="WinDebloat logo">
</p>

<p align="center">
  A free, open-source Windows 10/11 debloater and optimizer — with a clean GUI and a scriptable PowerShell CLI.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-2563EB">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE">
  <img alt="Version" src="https://img.shields.io/badge/version-2.1.0-2563EB">
  <img alt="Dependencies" src="https://img.shields.io/badge/dependencies-none-15803D">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-15803D">
  <a href="https://github.com/horizonbymuneeb/WinDebloat/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/horizonbymuneeb/WinDebloat?color=2563EB"></a>
  <a href="https://github.com/horizonbymuneeb/WinDebloat/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/horizonbymuneeb/WinDebloat/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/horizonbymuneeb"><img alt="GitHub" src="https://img.shields.io/badge/GitHub-@horizonbymuneeb-181717?logo=github&logoColor=white"></a>
</p>

![WinDebloat dashboard](assets/screenshot.png)

**WinDebloat** is a Windows 10 and 11 debloater and optimizer. It removes curated preinstalled apps, trims telemetry and background noise, and applies reversible performance tweaks — from a clean GUI or a scriptable PowerShell CLI. Everything runs locally from a single extracted folder: no installers, no cloud calls, no third-party dependencies.

## Features

- **App cleanup** — remove a curated list of preinstalled Store apps, games and hubs. Microsoft Store, Edge and Defender are never touched.
- **Keep apps** — protect specific packages with a comma-separated list, wildcards supported (`MSTeams*`).
- **Performance** — disable visual effects, mouse acceleration, startup app delay, Game DVR, SysMain, search indexing and error reporting.
- **Privacy** — disable telemetry services and scheduled tasks, ads and suggestions, UWP background activity, Copilot, Recall, location and LLMNR.
- **Cleanup** — temp files, Windows Update cache, Delivery Optimization files, thumbnail cache and the recycle bin.
- **Network** — set DNS to Cloudflare, Google or Quad9, or restore automatic DNS.
- **Power** — disable hibernation or enable the Ultimate Performance plan.
- **Presets** — Safe, Balanced and Aggressive configurations in the GUI.
- **Dry run** — preview every action without changing anything.
- **Live log** — watch the engine output in real time; every run is transcribed to `logs/`.

## Why WinDebloat?

| | Typical debloat script | WinDebloat |
| --- | --- | --- |
| Safe defaults | Varies by script | Curated list; protected components are never touched |
| Preview changes | Rarely | Dry run for every action |
| Restore point | Sometimes | Attempted before changes |
| Keep list | Rarely | Wildcard keep list for protected packages |
| Interface | CLI only | GUI and CLI share the same engine |
| Logs | Sometimes | Every run is logged |
| Dependencies | Varies | None — built-in PowerShell only |
| License | Varies | MIT, fully open source |

## Safety

- Microsoft Defender, Windows Update, Microsoft Store, Microsoft Edge and printing are never removed. Optional cache cleanup does not uninstall Windows Update.
- A System Restore point is attempted before any change (can be disabled; Windows may skip it if one was created in the last 24 hours).
- Risky options are badged and require explicit acknowledgement in the GUI before a real run.
- Dry runs never modify the system.
- Every run is logged to `logs/` next to the scripts.

> [!WARNING]
> This tool changes system settings and removes preinstalled apps. Review the selected options, run a dry run first, and keep a backup or restore point. Use at your own risk.

## Quick start

**Requirements:** Windows 10 or 11, Windows PowerShell 5.1, administrator rights.

1. Download the [latest release](https://github.com/horizonbymuneeb/WinDebloat/releases/latest) ZIP and extract it, or clone this repository.
2. Double-click `Debloat-GUI.bat` and approve the UAC prompt.
3. Pick a preset, run a **Dry run**, then click **Run now**.

```powershell
git clone https://github.com/horizonbymuneeb/WinDebloat.git
cd WinDebloat
.\Debloat-GUI.bat
```

For a one-click CLI run with safe defaults, use `OneClick-Debloat.bat` instead.

## GUI

| Page | What it controls |
| --- | --- |
| Dashboard | Presets, session summary and run controls |
| App Cleanup | Curated app removal, aggressive/Xbox/OneDrive options, keep list |
| Performance | Visual effects, input, startup delay, Game DVR, services |
| Privacy | Telemetry, ads, background apps, Copilot, Recall, location |
| Advanced | Risky tweaks, cleanup, DNS, power and restore point |
| Activity Log | Live engine output, open logs or clear the view |

## Screenshots

| Dashboard | App Cleanup |
| --- | --- |
| ![WinDebloat dashboard on Windows 11](assets/screenshot.png) | ![WinDebloat App Cleanup page](assets/screenshot-apps.png) |
| **Performance** | **Privacy** |
| ![WinDebloat Performance page](assets/screenshot-performance.png) | ![WinDebloat Privacy page](assets/screenshot-privacy.png) |
| **Advanced** | **Activity Log** |
| ![WinDebloat Advanced page](assets/screenshot-advanced.png) | ![WinDebloat Activity Log page](assets/screenshot-log.png) |

## CLI usage

Run from an elevated PowerShell prompt:

```powershell
# Preview the default run without changing anything
.\WinDebloat.ps1 -DryRun

# Safe defaults: restore point, curated apps, telemetry and ads
.\WinDebloat.ps1

# Performance and cleanup
.\WinDebloat.ps1 -DisableVisualEffects -DisableMouseAcceleration -DisableStartupDelay `
  -CleanTemp -CleanUpdateCache -EmptyRecycleBin -DnsProvider Cloudflare

# More aggressive, with risky options
.\WinDebloat.ps1 -Aggressive -DisableSysMain -DisableSearchIndexing -DisableWerService `
  -DisableRecall -DisableLocation -DisableLlmnr -DisableDriverUpdates

# Keep specific packages
.\WinDebloat.ps1 -KeepApps "MSTeams*","Microsoft.YourPhone"
```

Useful switches:

| Switch | Effect |
| --- | --- |
| `-DryRun` | Preview only, no changes |
| `-Force` | Skip the 5-second countdown |
| `-NoRestorePoint` | Skip restore point creation |
| `-Aggressive` | Include Outlook, Teams, Phone Link, Media Player and Copilot |
| `-RemoveXbox` / `-RemoveOneDrive` | Remove Xbox components / the OneDrive client |
| `-SkipApps` / `-SkipServices` / `-SkipTasks` / `-SkipPrivacy` | Skip a whole category |
| `-KeepApps <names>` | Comma-separated packages to protect |
| `-DnsProvider <name>` | `Cloudflare`, `Google`, `Quad9`, `Automatic` or `None` |
| `-CleanTemp`, `-CleanUpdateCache`, `-CleanDeliveryOptimization`, `-CleanThumbnailCache`, `-EmptyRecycleBin` | Cleanup actions |
| `-DisableHibernation`, `-UltimatePerformance` | Power tweaks |

Run `Get-Help .\WinDebloat.ps1 -Full` for the complete parameter list.

## Project structure

```
WinDebloat/
├─ WinDebloat-GUI.ps1    # WinForms GUI with a custom light theme
├─ WinDebloat.ps1        # CLI debloat engine
├─ ui/
│  └─ WinDebloatUi.cs    # Custom controls and SVG icon renderer
├─ assets/
│  ├─ icons/             # SVG icon set used by the GUI
│  ├─ logo.svg
│  ├─ screenshot.png
│  └─ social-preview.png # Repository social preview (1280x640)
├─ tools/
│  └─ validate.ps1       # Syntax, C# compile and SVG validation
├─ .github/              # CI workflow, issue and PR templates
├─ Debloat-GUI.bat       # GUI launcher
├─ OneClick-Debloat.bat  # CLI launcher
├─ CONTRIBUTING.md
├─ SECURITY.md
├─ CHANGELOG.md
└─ logs/                 # Created at runtime
```

## How it works

- The GUI is Windows PowerShell 5.1 + WinForms. Custom controls in `ui/WinDebloatUi.cs` provide the rounded cards, toggles and SVG icons; no external UI libraries are used.
- The CLI engine is a single PowerShell script. It uses built-in cmdlets only and writes a transcript to `logs/`.
- Nothing is downloaded or sent anywhere at runtime.

## FAQ

### Is WinDebloat safe to run?

Yes, when you review the options first. Safe defaults remove only curated bloatware and telemetry, protected components are never touched, a restore point is attempted before changes, and every run is logged. Risky tweaks are clearly badged and require acknowledgement in the GUI.

### Will it remove Microsoft Store, Edge or Defender?

No. Microsoft Store, Microsoft Edge, Microsoft Defender, Windows Update and printing are intentionally left untouched. Optional Windows Update cache cleanup does not uninstall or disable Windows Update.

### Does it work on Windows 11?

Yes. WinDebloat supports Windows 10 and Windows 11 and targets the built-in Windows PowerShell 5.1, so no extra runtime is needed.

### Can I undo the changes?

Most tweaks are reversible through Windows Settings, the CLI or a restore point. Removed Store apps can be reinstalled from the Microsoft Store, and the OneDrive client can be reinstalled. Always keep a restore point before a real run.

### Does it need an internet connection?

No. The app runs entirely offline from the extracted folder. Only downloading the release or reinstalling Store apps needs a connection.

### Which apps are removed?

A curated list of preinstalled Store apps, games and hubs. `-Aggressive` also includes Outlook, Teams, Phone Link, Media Player and Copilot. Use `-KeepApps` to protect specific packages.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup and guidelines, run `.\tools\validate.ps1` before opening a PR, and test engine changes with `-DryRun` first.

For security problems, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

If WinDebloat helped you, a star helps other people find it.

## License

[MIT](LICENSE) © WinDebloat contributors

---

<p align="center">
  <sub>Made with ♥ by <a href="https://github.com/horizonbymuneeb">Muneeb Anjum</a> · <a href="https://github.com/horizonbymuneeb">@horizonbymuneeb</a></sub>
</p>
