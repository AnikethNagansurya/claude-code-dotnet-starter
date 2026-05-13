# Security Policy

## Scope

This repository contains markdown agent definitions, shell scripts, and PowerShell scripts. It does not process user data, store credentials, or run as a service.

Security concerns most likely to be relevant:

- **Installer scripts** (`setup/install.sh`, `setup/install.ps1`) — command injection, unsafe file operations, path traversal
- **Session hook scripts** (`setup/templates/session-start.*`, `session-end.*`) — similar concerns
- **`settings.json` template** — overly broad permission grants that get copied to target projects

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report security issues privately by emailing the maintainer or using [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) feature (Security → Report a vulnerability).

Include:

1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested fix (if you have one)

You can expect an acknowledgement within 48 hours and a fix or mitigation plan within 7 days for confirmed issues.

## What is NOT in scope

- Social engineering attacks
- Issues in Claude Code itself (report those to Anthropic)
- Issues in the target .NET project installed into (those are the responsibility of that project's team)
