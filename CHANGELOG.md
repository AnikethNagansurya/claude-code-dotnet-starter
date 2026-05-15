# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [2.0.0] — 2026-05-15

### Added

- **`context-minimal.md` architecture**: SessionStart hook now generates a lightweight `@-import` file (`context-minimal.md`) containing only the top 5 lessons and last session header. The main session loads this token-efficient summary; subagents load the full `agent-context.md`. Cuts main-session token load significantly on large projects.
- **Staleness guard**: SessionStart hook warns if `context-minimal.md` is older than 24 h — catches silent hook failures before stale lessons are used as authoritative.
- **Session-log missed-entry detection**: SessionStart Check 3 — if the last log entry pre-dates today but git shows commits in the last 24 h, reminds the user to write a session log entry.
- **Diff filtering in `/review-pr`**: Phase 0c now strips `*.Designer.cs` (EF migration snapshots) and `.claude/` agent files from the PR diff before passing to `@pr-reviewer`, removing auto-generated noise from review comments.
- **Minimal APIs guidance**: `coding-standards.md` now includes a decision table (Minimal APIs vs. Controllers) and four rules for when each pattern is preferred.
- **DDD tactical patterns guidance**: `coding-standards.md` adds opt-in sections for Value Objects, strongly-typed IDs, Domain Events, and Aggregate Roots — with C# examples.

### Fixed

- **Session-log trim consistency**: `session-end.ps1` and `session-end.sh` now trim to **last 3 entries** (was incorrectly set to 10 — inconsistent with the 3-entry window read by session-start and `agent-context.md`).
- **INSTALL.md agent/skill counts**: corrected "10 agent definitions, 14 skill directories" → 8 agents, 12 skills to match actual installer manifests.

### Changed

- **`CLAUDE.md` auto-import strategy**: replaced five individual `@-import` lines with a single lightweight `@.claude/context-minimal.md` import. Full context still available to subagents via `agent-context.md`.
- **Session-start scripts rebuilt**: `session-start.ps1` and `session-start.sh` now perform two jobs (agent-context flatten **and** context-minimal generation) plus the staleness guard and session-log missed-entry reminder.

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
