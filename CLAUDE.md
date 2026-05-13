# [Service Name] — Developer Context

> **First-time setup:** After running `install.sh` / `install.ps1`, open this service in Claude Code and run `/onboard-project`. The skill scans the codebase and populates every section below (~8–12 min).

---

## What This Service Does

<!-- 1–3 sentences: purpose, who uses it, core value it provides. Populated by /onboard-project. -->
_populated by /onboard-project_

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Language | _populated by /onboard-project_ |
| Framework | _populated by /onboard-project_ |
| ORM | _populated by /onboard-project_ |
| Database | _populated by /onboard-project_ |
| Messaging | _populated by /onboard-project_ |
| Auth | _populated by /onboard-project_ |
| Logging | _populated by /onboard-project_ |
| Validation | _populated by /onboard-project_ |
| Resilience | _populated by /onboard-project_ |
| Hosting | _populated by /onboard-project_ |

---

## Architecture Overview

<!-- 2–4 sentences: how requests flow, key components, integration boundaries. Populated by /onboard-project. -->
_populated by /onboard-project_

```
<!-- ASCII data-flow diagram — populated by /onboard-project. Example:

[Client] ──HTTP──> [API Controller]
                       │
                  [Service Layer]
                       │
               ┌───────┴───────┐
        [EF Core Repo]    [Message Bus]
               │
          [SQL Server]
-->
```

### Key boundaries
<!-- Rules that must not be crossed — e.g.:
- All external input validated at the controller/consumer layer — never inside domain services
- Database access only through repository interfaces — no DbContext in controllers or services
-->
_populated by /onboard-project_

---

## Folder Structure

```
<!-- Annotated tree — populated by /onboard-project. Example:

src/
  [ProjectName]/
    Controllers/          ← HTTP endpoints (thin — delegate to services)
    Services/             ← Domain logic
    Data/
      Models/             ← EF Core entity classes
      Repos/              ← IRepository implementations
      Migrations/         ← EF Core migration files
tests/
  [ProjectName].Tests/   ← xUnit unit + integration tests
-->
```

---

## Project Facts

Concrete project specifics. Filled in by `/onboard-project` skill. Until populated, agents fall back to .NET defaults embedded in their own templates (xUnit, EF Core, Polly v8, OpenTelemetry, FluentValidation). Keep this section short — one line per fact.

- **Target framework:** _populated by bootstrap_
- **Test framework:** _populated by bootstrap_
- **Mocking / fakes:** _populated by bootstrap_
- **DI container:** _populated by bootstrap_
- **ORM / data access:** _populated by bootstrap_
- **Database:** _populated by bootstrap_
- **Auth scheme:** _populated by bootstrap_
- **Solution layout:** _populated by bootstrap_
- **Hosting / deployment target:** _populated by bootstrap_
- **Compliance regimes in scope:** _populated by bootstrap_

---

## C# Conventions

<!-- Project-specific extensions to .claude/rules/coding-standards.md. Populated by /onboard-project.
     Example conventions:
- Private fields: `_camelCase` (underscore prefix)
- DTOs: `XxxDTO` suffix
- Async methods: `XxxAsync` suffix on every Task-returning method
- Nullable reference types: enabled — #nullable enable in all files
- No async void — only async Task (except event handlers)
- CancellationToken required on all I/O methods
-->
_populated by /onboard-project_

---

## Domain Rules (Do Not Change)

<!-- Critical business invariants that must never be broken. Populated by /onboard-project.
     Example:
- An alarm must be acknowledged before a clear is processed
- Deterministic GUIDs via SHA-256 for all type constants
-->
_populated by /onboard-project_

---

## Key Files Quick Reference

| File | Role |
|------|------|
| `Program.cs` | Service startup, DI registration |
| _populated by /onboard-project_ | |

---

## Slash Commands Available

### Development workflows
```
/fix-bug              ← Reproduce → root cause → fix → regression test
/optimize-performance ← EF Core N+1, async blocking, BenchmarkDotNet
```

### Quality & security
```
/security-review      ← ASP.NET Core security: auth, CORS, secrets, injection
/review-pr            ← Fetch GitHub PR, run pr-reviewer checklist, post inline comments
```

### Delivery
```
/create-pr            ← Structured PR with dotnet test verification
/update-deps          ← NuGet audit + safe upgrade (dotnet list package --vulnerable)
```

### Onboarding
```
/onboard-project          ← Re-analyse codebase → refresh CLAUDE.md + .claude/context/ after major refactor
/customize-service-setup  ← Detect domain patterns → generate skill stubs → re-run skill alignment (Phase 6)
```

### Expert personas (pair programming + design conversations)
```
/agent-architect      ← .NET architecture: Clean Architecture, CQRS, ADRs, hosted service design
/agent-developer      ← Senior C# developer pair-programming — implementation + code walkthroughs
/agent-reviewer       ← Adversarial .NET code reviewer (deeper than ad-hoc review prompts)
/agent-security       ← ASP.NET Core security threat modelling + incident response
```

---

## External Dependencies

| System | Purpose | Config location |
|--------|---------|-----------------|
| _populated by /onboard-project_ | | |

---

## Environment Variables / appsettings

| Key | Purpose | Example |
|-----|---------|---------|
| `ConnectionStrings:DefaultConnection` | Primary datastore | `Server=...;Database=...` |
| `DOTNET_ENVIRONMENT` | Runtime environment | `Development` |
| _populated by /onboard-project_ | | |

---

## Permanent Rules

- Agents stay project-agnostic — use `{Resource}`, `{Service}`, `{Project}` placeholders, never project-specific names
- Every agent has YAML frontmatter (`name`, `description`, `tools`) with the minimum tools needed
- Every agent defines its response shape. Reviewer / analyzer / curator agents (architecture-reviewer, code-reviewer, pr-reviewer, refactoring-agent, migration-writer, lesson-curator) end with an explicit `## Output Format` block. Pure generator agents (doc-generator, test-writer) document their output via embedded templates — their response *is* the generated artifact, not a structured report
- Reviewers are **read-only**; only `lesson-curator` writes to `.claude/lessons.md`
- Project-specific rules live in `.claude/lessons.md`, never inlined into agents
- **Approval gates: re-spawn the agent with the full decision context, never with just the approval keyword.** Claude Code does not expose a "resume this agent instance" mechanism — every approval reply that looks like `apply` / `write` / `proceed` / `yes` must be turned into a fresh agent invocation that carries the **complete payload the agent was about to act on** (the diff, the candidate list, the proposed refactor) explicitly in the prompt, plus an `apply` directive. Spawning the agent with only the keyword fails silently — the new agent has no context and either refuses, hallucinates a different action, or reports success on a write that never happened. Always verify file writes by reading the target file afterward; if the read shows no change, the context-loss happened — re-run with the full payload.
- **Every agent must read `.claude/agent-context.md` before any action.** The SessionStart hook (`.claude/scripts/session-start.{sh,ps1}`) flattens `CLAUDE.md` + `context/*.md` + `.claude/lessons.md` + the last 3 entries of `.claude/session-log.md` into that single file at every session start, so subagents spawned via the Agent/Task tool get all project context via one Read instead of four. If the flattened file is absent, the agent falls back to reading the source files directly and notifies the user that the SessionStart hook should be wired in `.claude/settings.json`. Mid-session edits to lessons.md / context/ files require re-running the hook (or restarting the session) for subagent context to refresh — the snapshot is captured at session start.

## Dispatch

### Subagents (multi-file, multi-tool orchestration)

| Task | Invoke |
|------|--------|
| Build / test / log failure | `/fix-bug` |
| After writing code | `@code-reviewer` |
| Documenting APIs | `@doc-generator` |
| Pre-merge | `@pr-reviewer` |
| Writing tests | `@test-writer` |
| Adding / altering a database schema | `@migration-writer` (then `@pr-reviewer`) |
| Cleaning up dead code, duplication, long methods | `@refactoring-agent` |
| Capture review findings as durable lessons | `@lesson-curator` |

### Skills (self-contained slash commands)

| Task | Invoke |
|------|--------|
| Investigate and fix a bug | `/fix-bug` |
| Security audit of current branch | `/security-review` |
| Review a GitHub PR and post inline comments | `/review-pr` |
| Performance profiling and fixes | `/optimize-performance` |
| Create a pull request | `/create-pr` |
| Audit and update NuGet packages | `/update-deps` |
| Pair programming — implementation | `/agent-developer` |
| Architecture design + ADRs | `/agent-architect` |
| Adversarial code review persona | `/agent-reviewer` |
| Security threat modelling persona | `/agent-security` |
| Re-onboard after adding service-specific skills | `/onboard-project` |
| Detect domain patterns + generate skill stubs + re-run skill alignment | `/customize-service-setup` |

## Auto-loaded Context

These imports are pulled into every session — they are how Claude knows the project state, history, and rules. Files are created by the installer and populated by `/onboard-project`; missing files are skipped silently.

@.claude/context/architecture.md
@.claude/context/tech-stack.md
@.claude/context/coding-standards.md
@.claude/session-log.md
@.claude/lessons.md
