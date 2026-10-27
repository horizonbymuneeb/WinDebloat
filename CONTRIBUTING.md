# Contributing to WinDebloat

Thanks for helping improve WinDebloat. Bug reports, ideas, docs fixes and pull requests are all welcome.

## Ways to contribute

- Report a bug with the issue template (include your `logs/` output)
- Suggest a feature or a new tweak
- Improve the README, screenshots or docs
- Submit a pull request

## Development setup

- Windows 10 or 11
- Windows PowerShell 5.1 — the app must stay compatible with the built-in PowerShell
- No build step: run `Debloat-GUI.bat` or `.\WinDebloat.ps1 -DryRun`
- Run `.\tools\validate.ps1` before opening a PR — it checks PowerShell syntax, compiles the C# UI and validates every SVG icon

## Guidelines

- Keep PowerShell 5.1 compatibility. Do not use PS7-only syntax such as `??`, `?.` or ternary operators.
- Do not add external dependencies. The app must run from a single extracted folder without downloading modules.
- Test GUI changes with `.\WinDebloat-GUI.ps1 -SelfTest` and `-SelfTestPage <page>` (`dashboard`, `apps`, `performance`, `privacy`, `advanced`, `log`).
- Test engine changes with `-DryRun` first. Never test destructive options on a machine you care about.
- Follow the existing style: 4 spaces, clear names, no aliases in engine code, no comments unless they explain something non-obvious.
- Never log personal data, secrets or full user paths.
- Update `README.md` and `CHANGELOG.md` when behavior changes.

## Pull requests

- One focused change per PR
- Describe what changed and how you tested it
- Link related issues
- Attach before/after screenshots for UI changes
- Keep the diff free of unrelated formatting changes

## Commit messages

Use a short imperative summary, for example:

```
fix: match keep-list wildcards case-insensitively
feat: add DNS provider reset button
docs: clarify restore point behavior
```
