# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 2.1.x | Yes |
| < 2.1 | No |

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Use GitHub private vulnerability reporting:

https://github.com/horizonbymuneeb/WinDebloat/security/advisories/new

Include the affected version, Windows build, reproduction steps and impact. We aim to respond within 7 days.

## Scope

WinDebloat runs with administrator rights and changes system settings, so security-relevant issues include:

- Command injection or unsafe argument handling
- Unsafe temporary file or path handling
- Privilege misuse or unintended elevation
- Unintended data loss or removal of protected components
- Supply-chain concerns in the launcher scripts

## Safe usage

- Download releases only from this repository's Releases page
- Verify the published SHA-256 checksum for the ZIP
- Review the selected options and run a Dry run before a real run
