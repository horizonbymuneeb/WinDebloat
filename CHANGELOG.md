# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-10-27

First public release.

### Added

- Light-theme WinForms GUI with rounded cards, custom controls and an SVG icon set
- Safe, Balanced and Aggressive presets
- Curated app cleanup with aggressive, Xbox and OneDrive options
- Keep list with wildcard support for protected packages
- Performance, privacy, cleanup, DNS and power tweaks
- Dry run mode, restore point option and risky-option acknowledgement
- Live activity log with open/clear controls
- Scriptable CLI engine shared with the GUI
- Self-test mode for visual QA (`-SelfTest`, `-SelfTestPage`)
- Validation script, CI workflow, release package and SHA-256 checksum

### Security

- Microsoft Defender, Windows Update, Microsoft Store, Microsoft Edge and printing are never removed
- Every run is logged to `logs/`
- GitHub private vulnerability reporting enabled

[2.1.0]: https://github.com/horizonbymuneeb/WinDebloat/releases/tag/v2.1.0
