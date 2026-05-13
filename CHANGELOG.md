# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [1.0.0] — 2026-05-13

### Added

- **8 subagents**: `architecture-reviewer`, `code-reviewer`, `pr-reviewer`, `doc-generator`, `test-writer`, `migration-writer`, `refactoring-agent`, `lesson-curator`
- **12 skills**: `onboard-project`, `customize-service-setup`, `fix-bug`, `create-pr`, `update-deps`, `security-review`, `review-pr`, `optimize-performance`, `agent-developer`, `agent-architect`, `agent-reviewer`, `agent-security`
- **3 baseline rules**: `coding-standards.md`, `git-workflow.md`, `testing.md`
- **2 output styles**: `terse`, `teaching`
- **6 task prompt templates**: `system-design.md`, `bug-report.md`, `feature-request.md`, `architecture-decision.md`, `code-review-request.md`, `technical-debt.md`
- **Session hooks**: `session-start.{sh,ps1}` (context flattening) and `session-end.{sh,ps1}` (log trimming)
- **Cross-platform installer**: `install.sh` (Linux / macOS / WSL) and `install.ps1` (Windows) with manifest tracking
- **CI workflow**: ShellCheck, PSScriptAnalyzer, JSON validation, and smoke-test install on every PR
- MIT license, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, issue and PR templates
