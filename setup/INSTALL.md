# Installing the .NET Core Agent Library

Drop these agents into any .NET 8+ project in about 5 minutes. After the file copy, the `/onboard-project` skill scans your codebase and customises everything in one main-session turn (~5–8 min). Total time from clone to project-aware agents: **~8–12 minutes.**

## Quick Start

### Before you run

Make sure the **target project** is on its primary branch (typically `main` or `master`) before installing. The installer creates new files under `.claude/` and writes `.claude/settings.json` — those changes should land on a clean primary branch, not on a feature branch where they'd mix with unrelated work.

```bash
cd /path/to/your/dotnet/project
git checkout main          # or master / trunk / develop
git status                 # confirm clean working tree
```

The installer detects the current branch and will prompt you if you're not on a primary branch (or in a detached-HEAD state). You can override the warning, but it's better to start clean.

Run the installer from the **agent library root** (the folder that contains `CLAUDE.md` and the agent `.md` files).

### Option A — PowerShell (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File .\setup\install.ps1 -TargetPath C:\path\to\your\dotnet\project
```

### Option B — Bash (Linux / macOS / Git Bash / WSL)

```bash
./setup/install.sh /path/to/your/dotnet/project
```

The script:

1. Verifies the target looks like a .NET project (`.sln` / `.csproj` present)
2. Creates `.claude/agents/`, `.claude/skills/`, `.claude/rules/`, `.claude/output-styles/`, `.claude/scripts/`, `.claude/prompts/`, and `.claude/context/` in the target
3. Copies 8 agent definitions, 12 skill directories, 3 baseline rules (coding-standards / git-workflow / testing), 2 output styles (terse / teaching), 4 hook scripts, 7 prompt templates, and 3 example files
4. Deploys 3 context file templates to `.claude/context/` (`architecture.md`, `tech-stack.md`, `coding-standards.md`) — only if they don't already exist; drops `lessons.md` and `session-log.md` skeletons under `.claude/` on first install
5. Tracks every installed file in `.claude/BOOTSTRAP_MANIFEST.json` so re-runs can update bootstrap-origin files cleanly without touching service-specific overrides
6. Installs `.claude/settings.json` from `setup/templates/settings.json` — which includes a `defaultMode: acceptEdits` setting, an `allow` list for common dotnet/git/gh commands, a `deny` list for destructive operations, and the SessionStart/Stop hooks. If a `settings.json` already exists: merges permissions (allow/deny dedup) and hooks idempotently rather than overwriting
7. Copies `CLAUDE.md` to the project root — or, if one already exists, saves the template alongside as `CLAUDE.md.agents-template` so you can merge by hand
8. Drops `.claude/BOOTSTRAP_PENDING.md` to signal that customization is the next step

### Re-running the installer (upgrade flow)

```bash
# Default — picks up files added since last install, never touches existing
./setup/install.sh /path/to/your/project

# --force — also updates files registered in BOOTSTRAP_MANIFEST.json (bootstrap-origin)
./setup/install.sh /path/to/your/project --force

# --force --skip-analysis — update without dropping BOOTSTRAP_PENDING.md (CI/CD)
./setup/install.sh /path/to/your/project --force --skip-analysis
```

```powershell
# Same on Windows
.\setup\install.ps1 -TargetPath C:\path\to\your\project
.\setup\install.ps1 -TargetPath C:\path\to\your\project -Force
.\setup\install.ps1 -TargetPath C:\path\to\your\project -Force -SkipAnalysis
```

`--force` mode first **repairs the manifest** by registering pre-existing bootstrap files, then updates them. Service-specific files (anything not in the manifest) are never touched. `CLAUDE.md` is preserved regardless of flags.

> **⚠️ Phase 6 customisations are overwritten by `--force`.** When `/onboard-project` runs Phase 6, it appends `## Service-Specific Context` sections to bootstrap utility skills (6a) and `## Service-Specific Routing` sections to persona skills — `agent-developer`, `agent-architect` (6b). These sections live inside the bootstrap skill files themselves, so a `--force` refresh replaces them with the generic latest version. The installer detects this and writes a `BOOTSTRAP_PENDING.md` that explains exactly what was lost. Re-run `/onboard-project` to restore: Phase 6 will re-detect your service-specific skills, re-add the cross-pointers, and re-ask the A/B/C/D routing question.

`--skip-analysis` suppresses `BOOTSTRAP_PENDING.md` entirely. Use it in CI/CD pipelines that install the bootstrap as part of a build step, or when you plan to run `/onboard-project` manually at your own pace without the reminder.

## After Install — Customization Workflow

The installed agents are generic templates. They become project-aware once Claude has loaded **your** project's facts into context. One command does the entire customization:

```
/onboard-project
```

The skill is a single main-session execution covering 12 phases (0–11):

| Phase | What | WAIT gate? |
|---|---|---|
| 0 | Branch check — confirms primary branch, clean working tree | ✋ Proceed / abort |
| 1 | Service Discovery — scans `*.csproj`, `Program.cs`, `appsettings*.json`, project structure | — |
| 2 | Codebase Deep Dive — DbContext, services, hosted services, test conventions, compliance signals, skill inventory (2g) | — |
| 3a | Populate `CLAUDE.md` Project Facts (10 fields) | — |
| 3b | Populate `CLAUDE.md` scaffold sections (What This Service Does, Tech Stack, Architecture Overview, Folder Structure, C# Conventions, Domain Rules, Key Files, Slash Commands, External Dependencies, Env Vars) | — |
| 4 | Initialise 3 context files — `.claude/context/architecture.md`, `.claude/context/tech-stack.md`, `.claude/context/coding-standards.md` | ✋ One question: Current Phase |
| 5 | Emit Lesson Candidates across all 9 `lessons.md` headings | — |
| 6 | Skill Alignment — 6a: cross-pointers into bootstrap skills; 6b: persona routing (optional); 6c: suggest missing skills | ✋ Phase 6b only (skipped if no service-specific workflow skills found) |
| 7 | Cleanup `BOOTSTRAP_PENDING.md` (with verify-by-reading-back) | — |
| 8 | `@lesson-curator` workflow — dedupe, classify, write `lessons.md` | ✋ Curator diff approval |
| 9 | Auto-write today's session-log entry | — |
| 10 | Mechanical verification — disk checks + subagent context smoke test | — |
| 11 | Final output report | — |

**Total: ~8–12 min** (large codebases with 500+ files or 10+ projects may take longer — Phase 1–2 scans scale with project size). WAIT gates: one mandatory (Phase 4 — Current Phase question); optionally Phase 0 (branch/dirty-tree check — fires only when not on a primary branch or working tree is dirty); optionally Phase 6b (persona routing A/B/C/D — fires only when service-specific workflow skills are detected, silently skipped on fresh installs). Maximum three WAIT gates total. Phase 8 curator auto-applies after displaying the diff — no WAIT gate required. Everything else runs linearly within one main-session turn.

### Why one skill (history)

Earlier versions split this into `/onboard-project` (Phases 1–6) followed by a separate `bootstrap.md` prompt for curator + session-log + verification. Real-world audits showed users running the skill and stopping — leaving `lessons.md` empty, `session-log.md` placeholder-only, and `BOOTSTRAP_PENDING.md` undeleted. The current version absorbs all those gates into the skill (Phases 6–11) and the branch check (Phase 0), so completion is guaranteed and there's only one entry point. `bootstrap.md` no longer exists.

### Optional: system design

```
Use prompts/system-design.md
```

Generates `docs/system-design.md` with mermaid diagrams. Independent of the onboarding workflow. Run before, after, or never. Adds 5–10 min when invoked.

> **Note on `project-state.md`:** the library does NOT install one. Sprint state (in-progress / built / next-up) belongs in your team's issue tracker (Jira / GitHub Issues / Linear). The library reads `session-log.md` for cross-session continuity and `.claude/context/architecture.md` for high-level shape.


## What Gets Installed

The installer scaffolds the **full split-context pattern** — agents (subagents), skills (auto-loaded), rules (baseline conventions), output styles, hooks, prompts, and working files. Imports are pre-wired in the installed `CLAUDE.md` so Claude Code auto-loads them every session.

```
your-project/
├── CLAUDE.md                                      ← identity, rules, dispatch, @-imports (scaffold filled by /onboard-project)
├── .gitignore                                     ← gitignores .claude/agent-context.md, .claude/session-log.md, personal overrides, credentials
└── .claude/
    ├── context/                                   ← 3-file project context (populated by /onboard-project Phase 4)
    │   ├── architecture.md                        ← service type, data flow diagram, boundaries, integration points
    │   ├── tech-stack.md                          ← runtime, NuGet packages table, framework choices
    │   └── coding-standards.md                    ← naming, async, EF Core, GUID, logging conventions for this service
    ├── BOOTSTRAP_MANIFEST.json                    ← tracks bootstrap-origin files for clean upgrades
    ├── BOOTSTRAP_PENDING.md                       ← signals customization is the next step (deleted by /onboard-project)
    ├── settings.json                              ← permissions block (allow/deny) + SessionStart/Stop hooks + defaultMode: acceptEdits
    ├── agents/                                    (8 subagent definitions)
    │   ├── architecture-reviewer.md
    │   ├── code-reviewer.md
    │   ├── doc-generator.md
    │   ├── pr-reviewer.md
    │   ├── test-writer.md
    │   ├── migration-writer.md                    (safe EF Core migrations)
    │   ├── refactoring-agent.md                   (dead code / duplication / extracts)
    │   └── lesson-curator.md                      (curates lessons.md)
    ├── skills/                                    (12 skills — invoked with /skill-name)
    │   ├── onboard-project/SKILL.md               ← post-install deep customization (12 phases, 0–11)
    │   ├── customize-service-setup/SKILL.md       ← detect domain patterns + generate skill stubs + re-run Phase 6 alignment
    │   ├── fix-bug/SKILL.md                       ← diagnose → fix → regression test
    │   ├── create-pr/SKILL.md                     ← PR title + body + gh pr create
    │   ├── update-deps/SKILL.md                   ← NuGet audit → risk-grouped updates
    │   ├── security-review/SKILL.md               ← OWASP + ASP.NET Core + microservice checks
    │   ├── review-pr/SKILL.md                     ← fetch GitHub PR → pr-reviewer checklist → post inline comments (MCP) or review comment (gh CLI)
    │   ├── optimize-performance/SKILL.md          ← EF Core / async / memory / caching
    │   ├── agent-developer/SKILL.md               ← senior C# developer persona
    │   ├── agent-architect/SKILL.md               ← senior .NET architect persona
    │   ├── agent-reviewer/SKILL.md                ← adversarial reviewer persona
    │   └── agent-security/SKILL.md                ← security engineer persona
    ├── rules/                                     ← baseline conventions auto-loaded into every session
    │   ├── coding-standards.md                    (C# / .NET — naming, async, null safety, EF Core, SOLID)
    │   ├── git-workflow.md                        (branch naming, conventional commits, PRs)
    │   └── testing.md                             (xUnit, Moq, integration tests, Testcontainers)
    ├── output-styles/                             ← behavioural modes you can switch between
    │   ├── terse.md                               (minimal output — no narration, no preambles)
    │   └── teaching.md                            (explanatory output — pair-programming with juniors)
    ├── lessons.md                                 ← project-specific overrides (curated by @lesson-curator; cap 20 bullets)
    ├── session-log.md                             ← reverse-chronological session notes (last 10 entries)
    ├── agent-context.md                           ← auto-generated by SessionStart hook; flattens CLAUDE.md + .claude/context/*.md + lessons.md + session-log.md (last 3) for subagent consumption
    ├── scripts/                                   ← hook scripts
    │   ├── session-start.sh                       (SessionStart: regenerates agent-context.md + staleness reminders)
    │   ├── session-start.ps1
    │   ├── session-end.sh                         (Stop: trim session-log to 10, trim lessons to 20, discard old pending markers)
    │   └── session-end.ps1
    └── prompts/                                   ← reusable task prompts
        ├── system-design.md                       ← optional: generate docs/system-design.md with mermaid diagrams
        ├── architecture-decision.md               ← ADR template (pair with @architecture-reviewer)
        ├── bug-report.md                          ← bug investigation template (pair with /fix-bug)
        ├── code-review-request.md                 ← focused code-review request (pair with @code-reviewer)
        ├── feature-request.md                     ← feature spec template (lightweight — fill in the brackets)
        └── technical-debt.md                      ← debt-prioritisation template (pair with @refactoring-agent)
```

**Why each file exists:**

| File / dir | Purpose | Update cadence |
|------|---------|----------------|
| `.claude/context/architecture.md` | Service type, data-flow diagram, key boundaries, integration points | Populated by `/onboard-project`; refresh after major architecture changes |
| `.claude/context/tech-stack.md` | Runtime version, NuGet packages table, framework choices | Populated by `/onboard-project`; update when stack changes |
| `.claude/context/coding-standards.md` | Service-specific naming, async, EF Core, logging, and GUID conventions | Populated by `/onboard-project`; update as team standards evolve |
| `agents/` | Subagent definitions for code-review, refactoring, generation, etc. | Updated by re-running installer with `--force` |
| `skills/` | 14 skills invoked with `/skill-name` (onboarding, daily workflows, personas) | Updated by re-running installer with `--force` |
| `rules/` | Baseline `.NET` / git / testing conventions auto-loaded into context | Rarely; project-specific deltas go to `lessons.md` |
| `output-styles/` | Switchable behavioural modes (terse / teaching) | Personal preference per developer |
| `lessons.md` | Long-term project facts that adjust agent advice | Curated by `@lesson-curator` after reviews; **cap 20 bullets** (auto-trim by Stop hook) |
| `session-log.md` | Recent session activity (decisions, open threads) | At session end; **only last 10 sessions kept** (auto-trim by Stop hook) |
| `agent-context.md` | Auto-flattened bundle that subagents Read at startup (1 file instead of 4+) | Auto-regenerated by SessionStart hook every session from CLAUDE.md + .claude/context/*.md + lessons.md + session-log.md |
| `scripts/` | Hook scripts wired by installer | Updated by re-running installer with `--force` |
| `prompts/` | Reusable task prompts (7 task templates) | Updated by re-running installer with `--force` |
| `BOOTSTRAP_MANIFEST.json` | Tracks bootstrap-origin files for clean `--force` upgrades | Auto-maintained by installer |
| `BOOTSTRAP_PENDING.md` | Marker that customization hasn't been run yet | Deleted by `/onboard-project` on completion |

### Why no `project-state.md`?

Earlier versions of the library installed `project-state.md` to hold "what's in progress / built / blocked / next up." It was removed in this version because:

- For sprint-driven teams, that information already lives in the issue tracker (Jira / GitHub Issues / Linear). Maintaining it in two places means one rots.
- The high-rot file produced the most nag warnings without proportional value.
- Removing it consolidates the library's job: `session-log.md` for what just happened, `lessons.md` for project rules, `.claude/context/*.md` for stable architecture + tech stack + coding standards. Three context files instead of one monolithic state file.

Sprint state still has a home — your tracker. The library no longer competes with it. If your team has no formal tracking and you genuinely need a Claude-readable status file, you can re-introduce a simple `project-state.md` manually (the hooks tolerate its absence; they won't error if you add it).

### Recommended `.gitignore` entries

Some installed files are team-shared (commit them so every developer benefits); others are per-developer transient state (gitignore them to avoid merge churn and cross-developer collisions). Suggested split:

| File / folder | Commit? | Reason |
|---------------|---------|--------|
| `.claude/context/architecture.md` | ✅ commit | Team-shared architecture snapshot |
| `.claude/context/tech-stack.md` | ✅ commit | Team-shared stack reference |
| `.claude/context/coding-standards.md` | ✅ commit | Team-shared service-specific standards |
| `.claude/agents/*.md` | ✅ commit | Team-shared agent definitions |
| `.claude/skills/**/*.md` | ✅ commit | Team-shared skill definitions (auto-load) |
| `.claude/rules/*.md` | ✅ commit | Team-shared baseline conventions |
| `.claude/output-styles/*.md` | ✅ commit | Team-shared behavioural modes |
| `.claude/lessons.md` | ✅ commit | Project knowledge — every developer benefits |
| `.claude/scripts/*` | ✅ commit | Hooks must work for every developer |
| `.claude/settings.json` | ✅ commit | Permissions block + hooks are project workflow, shared |
| `.claude/prompts/*.md` | ✅ commit | Reusable team prompts |
| `.claude/BOOTSTRAP_MANIFEST.json` | ✅ commit | Manifest of bootstrap-origin files; needed for safe `--force` upgrades |
| `.claude/session-log.md` | ❌ gitignore | Per-developer activity; constant churn if shared |
| `.claude/.pending-lesson-candidates` | ❌ gitignore | Transient marker; cross-developer collisions break the SessionStart loop |
| `.claude/agent-context.md` | ❌ gitignore | Auto-generated by SessionStart hook from CLAUDE.md + .claude/context/*.md + lessons.md + session-log.md; regenerated every session start |
| `.claude/BOOTSTRAP_PENDING.md` | ❌ gitignore | Per-developer install marker; deleted after `/onboard-project` runs |
| `CLAUDE.local.md` / `.claude/settings.local.json` | ❌ gitignore | Personal overrides — never share; create these files locally if needed |
| `.env*` / `**/secrets/**` / `**/*.pem` / `**/*.pfx` | ❌ gitignore | Credentials |

The installer drops a starter `.gitignore` at the project root with these defaults pre-populated. If your project already had one, the installer doesn't overwrite — you can copy the relevant entries from `setup/templates/examples/.gitignore` manually.

### Keeping `session-log.md` and `lessons.md` fresh (automatic)

The installer wires **two hooks** in `.claude/settings.json` — one at session **end**, one at session **start** — that together keep the working files current without manual effort.

| Hook | Script | What it does |
|------|--------|--------------|
| `Stop` | `session-end.{sh,ps1}` | Trims `session-log.md` to the 10 most recent entries; trims `lessons.md` to the 20 most recent bullets (curator inserts new bullets at TOP of each section, so first 20 = newest); auto-discards `.pending-lesson-candidates` entries older than 60 days |
| `SessionStart` | `session-start.{sh,ps1}` | (1) Flattens `CLAUDE.md` + `context/*.md` (architecture, tech-stack, coding-standards — or `.claude/context.md` for legacy installs) + `.claude/lessons.md` + last 3 entries of `.claude/session-log.md` into `.claude/agent-context.md` so subagents can read it as a single file. (2) Three reminders, fired only when triggered: (a) un-curated Lesson Candidates from prior sessions; (b) `lessons.md` stale (>30 days); (c) **previous session not logged** — if latest `## YYYY-MM-DD` heading isn't today AND git shows commits in last 24h, prompts Claude to write a session-log entry |

Net effect:

- When a reviewer (`@architecture-reviewer` / `@code-reviewer` / `@pr-reviewer`) emits Lesson Candidates and the session ends without `@lesson-curator` running, those reviewers append a marker line to `.claude/.pending-lesson-candidates`. The next time Claude Code starts on that project, the SessionStart hook detects the marker and prompts Claude to invoke `@lesson-curator` first — either applying or discarding the candidates clears the marker.
- When `lessons.md` itself hasn't been updated in over 30 days, the SessionStart hook prompts Claude to verify recorded project conventions (test framework, DI container, ORM, frozen names, stack deltas) still match reality. If they have drifted, the lessons get refreshed; if not, touching the file clears the reminder.

**Threshold rationale:**

| File | Threshold | Why |
|------|-----------|-----|
| `session-log.md` size | 10 entries (auto-trimmed by Stop hook) | Bounded for context; recent enough to give cross-session continuity |
| `lessons.md` size | 20 bullets (auto-trimmed by Stop hook) | Bounded growth; curator inserts at top so newest survive trim |
| `lessons.md` staleness | 30 days | Lessons should be stable; refreshed at retros (every 2 sprints) or when the stack changes |
| `session-log.md` staleness | 24h + recent commits | If git shows work happened but no entry was logged, prompt at next SessionStart |
| `.pending-lesson-candidates` (per entry) | 60 days (auto-discarded) | If a marker is ignored for 4+ sprints, the candidate is clearly no longer relevant |
| `.pending-lesson-candidates` (file vs. lessons.md) | newer-than | Driven by reviewer activity, not absolute time |
| `agent-context.md` regeneration | Every SessionStart | Always fresh at start of each session; mid-session refreshes triggered by curator after lessons.md write |

There is **no `project-state.md` staleness check** in this version — the library doesn't install that file. Sprint state (in-progress / built / next-up) lives in your team's issue tracker.

**No manual editing, no extra API calls, human stays in the loop.** Forgotten candidates surface on the next launch instead of being lost.

#### Cross-session catch-up — illustrated walkthrough

The marker mechanism makes the round-trip concrete:

```
Session 1  (Tuesday afternoon)
─────────
> @code-reviewer  review OrderService.cs
[code-reviewer emits findings + 📚 Lesson Candidates:
   - Stack Deltas: "Uses NUnit not xUnit"
   - DI Quirks: "IUserContext registered transient on purpose"]
[code-reviewer runs:
   bash -c 'echo "$(date -u +%FT%TZ) code-reviewer" >> .claude/.pending-lesson-candidates']

> [you get pulled into a meeting, close the terminal]
[Stop hook runs session-end.sh — trims session-log to 10 entries]
[.pending-lesson-candidates now contains:
   2026-04-30T14:32:15Z code-reviewer]


Session 2  (Wednesday morning)
─────────
> claude
[SessionStart hook runs session-start.sh]
[Detects marker exists, marker mtime > lessons.md mtime → injects additionalContext]

[Claude opens with:]
   "REMINDER: There are 1 un-curated Lesson Candidate marker(s) from
    prior sessions (from: code-reviewer). Before starting on the user's
    request, run @lesson-curator..."

> @lesson-curator
[curator reads .claude/.pending-lesson-candidates]
[curator: "I see one marker from code-reviewer at 2026-04-30T14:32:15Z.
   Do you have the candidates handy from that session, or should I
   re-run @code-reviewer to surface them again, or discard the marker
   if those candidates are no longer relevant?"]

> [you paste the two candidates from yesterday's notes]
[curator dedupes against lessons.md, shows diff:]
   + ## Stack Deltas
   +   - Uses NUnit ([Test], Assert.That) not xUnit.
   + ## DI Quirks
   +   - IUserContext registered transient on purpose - captures HttpContext
   +     per call via factory.

> apply
[curator writes lessons.md, then bash -c 'rm -f .claude/.pending-lesson-candidates']
[reports: "2 lessons added, 0 merged, 0 skipped. Marker cleared."]


Session 3  (next launch)
─────────
[SessionStart hook fires session-start.sh]
[No marker file → no reminder, exits 0 silently]
[Claude responds normally to whatever you ask]
```

The mechanism is **self-clearing**: once curator applies (or you tell it to discard), the marker disappears and the SessionStart prompt goes silent. No nag fatigue. If you ignore the prompt at session 2, it fires again at session 3, 4, 5… until you address it — which is the design.

Both scripts always exit 0 — they never block session start or shutdown.

**The installed `settings.json`:**
```jsonc
{
  "defaultMode": "acceptEdits",           // no per-edit confirmation prompts
  "permissions": {
    "allow": [
      // dotnet dev operations — routine, non-destructive
      "Bash(dotnet build*)", "Bash(dotnet test*)", "Bash(dotnet restore*)",
      "Bash(dotnet run*)", "Bash(dotnet watch*)", "Bash(dotnet publish*)",
      "Bash(dotnet clean*)", "Bash(dotnet format*)", "Bash(dotnet list*)",
      // git read operations
      "Bash(git status*)", "Bash(git log*)", "Bash(git diff*)",
      "Bash(git branch*)", "Bash(git fetch*)",
      // safe git write operations
      "Bash(git add*)", "Bash(git commit*)", "Bash(git checkout*)",
      "Bash(git stash*)", "Bash(git merge*)", "Bash(git rebase*)",
      "Bash(git tag*)", "Bash(git push origin*)",
      // GitHub CLI
      "Bash(gh pr*)", "Bash(gh issue*)", "Bash(gh run*)", "Bash(gh repo*)",
      "Bash(gh auth status*)"
    ],
    "deny": [
      // EF Core migrations — require explicit human approval before executing
      "Bash(dotnet ef migrations add*)", "Bash(dotnet ef database update*)",
      "Bash(dotnet ef database drop*)",
      // destructive git — never run without explicit confirmation
      "Bash(git push --force*)", "Bash(git push -f*)",
      "Bash(git reset --hard*)", "Bash(git clean -f*)",
      // secrets and credential files
      "Bash(*secrets*)", "Bash(*.pem*)", "Bash(*.pfx*)", "Bash(*.key*)"
    ]
  },
  "hooks": {
    "SessionStart": [{ "matcher": "", "hooks": [
      { "type": "command",
        "command": "bash .claude/scripts/session-start.sh 2>/dev/null || pwsh -NoProfile -File .claude/scripts/session-start.ps1" }
    ] }],
    "Stop": [{ "matcher": "", "hooks": [
      { "type": "command",
        "command": "bash .claude/scripts/session-end.sh 2>/dev/null || pwsh -NoProfile -File .claude/scripts/session-end.ps1" }
    ] }]
  }
}
```

**`defaultMode: acceptEdits`** tells Claude Code to apply file edits without prompting for each one — the model still shows you what it's about to do, but doesn't wait for per-file confirmation. Disable by removing the key if you prefer manual approval.

**Permissions block:** the `allow` list covers routine dotnet/git/gh operations so you don't see permission prompts during `dotnet build`, `git status`, `gh pr list`, etc. The `deny` list hard-blocks destructive operations (EF Core migration execution, `git push --force`, `git reset --hard`) and credential files — these require you to run them manually.

**Both installers (bash and PowerShell) write the same hook command with a bash → PowerShell fallback.** On Linux/macOS/Git Bash the bash variant runs and the PowerShell fallback is never triggered. On pure Windows without bash on PATH, bash exits non-zero and PowerShell takes over. Both `.sh` and `.ps1` script variants ship for both code paths to work.

**If `.claude/settings.json` already exists with hooks but no permissions block:** the installer merges the `permissions` object in without touching your existing hooks or other settings. If it has neither hooks nor permissions (or doesn't exist), the full template is used.

**To opt out:** delete the `SessionStart` and/or `Stop` blocks from `.claude/settings.json`. The skeletons remain functional without the hooks; trims and reminders simply stop firing automatically.

**Discipline note:** none of this is magic. The hooks make staleness *visible and addressable*; the actual edit is still made by Claude (with your approval) or by you. The system fails gracefully — if you ignore a prompt, the file stays stale and the prompt fires again next session.

**Imports pre-wired in `CLAUDE.md`:**

```
@.claude/context/architecture.md
@.claude/context/tech-stack.md
@.claude/context/coding-standards.md
@.claude/session-log.md
@.claude/lessons.md
```

Note: Subagents (spawned via the Agent/Task tool) do NOT inherit `@`-imports. The SessionStart hook flattens `CLAUDE.md` + the three context files + `lessons.md` + session-log (last 3 entries) into `.claude/agent-context.md`, which every agent definition's `**Prerequisite:**` line tells it to Read. One Read instead of five; harness-injected via the hook rather than per-turn re-reads.

Empty / skeleton files are fine — Claude just sees minimal content. As you fill them in, the model gains awareness without you having to remind it.

> **Discipline matters.** Stale `session-log.md`, `lessons.md`, or `.claude/context/*.md` files are worse than no files at all — the model trusts what it reads. Update them as part of natural workflow (session-log at session end, lessons via `@lesson-curator` after reviews, context files at sprint planning / retro or after architecture changes). The hooks remind; they don't substitute for human discipline.

## Updating Later

The installer tracks every bootstrap-origin file in `.claude/BOOTSTRAP_MANIFEST.json`. Re-runs use the manifest to know which files came from bootstrap (safe to update) vs which came from your team (never touch).

```bash
# Default — picks up new bootstrap files since last run; preserves existing
./setup/install.sh /path/to/your/project

# --force — also refreshes files registered in BOOTSTRAP_MANIFEST.json
./setup/install.sh /path/to/your/project --force
```

```powershell
# Same on Windows
.\setup\install.ps1 -TargetPath C:\path\to\your\project
.\setup\install.ps1 -TargetPath C:\path\to\your\project -Force
```

What happens on re-run:

| File category | Default mode | `--force` mode |
|---|---|---|
| **New bootstrap files** (skill / rule / prompt / context template added since your last install) | ✅ Installed | ✅ Installed |
| **Existing bootstrap files** in manifest | Skipped (with hint to use `--force`) | ✅ Updated to latest (⚠️ Phase 6 custom sections overwritten — re-run `/onboard-project`) |
| **Service-specific files** not in manifest | Skipped (preserved) | Skipped (preserved) |
| **`CLAUDE.md`** | Never overwritten (template saved as `CLAUDE.md.agents-template`) | Never overwritten |
| **`settings.json`** | Merged (allow/deny dedup, hooks idempotent) | Merged |
| **`.claude/context/*.md`** | Skipped if present (skeleton only on first install) | Skipped if service-specific; updated if still bootstrap-origin (in manifest) |
| **`lessons.md`, `session-log.md`** | Skipped if present (skeletons only on first install) | Skipped (preserved) |
| **`BOOTSTRAP_PENDING.md`** | Written on first install; skipped if present | Written if `$N_UPDATED > 0`; suppressed with `--skip-analysis` |

After a `--force` run, a `BOOTSTRAP_PENDING.md` is dropped if any bootstrap-origin files were updated — re-run `/onboard-project` if those updates touched files that were previously tailored for your service.

## Uninstall

```bash
rm -rf .claude/agents .claude/skills .claude/rules .claude/output-styles \
       .claude/scripts .claude/prompts \
       .claude/BOOTSTRAP_MANIFEST.json .claude/BOOTSTRAP_PENDING.md \
       .claude/agent-context.md
# Delete .claude/context/ only if you want to discard the project architecture/tech-stack/standards files
# Delete .claude/lessons.md and .claude/session-log.md only if you want to discard project knowledge
# Delete CLAUDE.md only if you didn't customize it
# Delete the .example files at root and .claude/ if they're unused
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Claude doesn't see the agents | Verify they're under `.claude/agents/` (not `.claude/`); run `claude` from the project root |
| `/onboard-project` not found | Verify `.claude/skills/onboard-project/SKILL.md` exists; re-run installer if missing |
| `/fix-bug`, `/create-pr`, etc. not found | Verify `.claude/skills/<skill-name>/SKILL.md` exists; re-run installer to deploy missing skills |
| Agents give generic advice | You skipped `/onboard-project`. Run it. |
| Agent advice doesn't match your stack | Add a `Stack Deltas` entry in `.claude/lessons.md` via `@lesson-curator` (e.g., "uses NUnit, not xUnit") |
| Want personal/local-only rules | Create `CLAUDE.local.md` at the project root (gitignored); it loads on top of `CLAUDE.md` automatically. Create `.claude/settings.local.json` for personal Claude Code settings overrides (different model, extra permissions). |
| Want to switch between terse / teaching mode | In Claude Code, switch the active output style to `terse` or `teaching` (loaded from `.claude/output-styles/`) |
| Just edited `CLAUDE.md` / `.claude/context/*.md` mid-session and subagents don't see the change | The flattened `.claude/agent-context.md` is generated at session start. To refresh without restarting: ask Claude to run `bash .claude/scripts/session-start.sh` (or `pwsh -File .claude/scripts/session-start.ps1` on Windows). The curator does this automatically after writing `lessons.md`, but manual edits to other source files don't trigger it. |
| Subagents see stale lessons after `@lesson-curator apply` | The curator should auto-refresh `agent-context.md` at Step 8 of its workflow. If it didn't (e.g., the regen script failed silently), run `bash .claude/scripts/session-start.sh` manually before spawning the next subagent. |
| `.claude/context/` folder missing (upgrade from older install) | The `.claude/context/` folder was added in the V3 fusion. Re-run `./setup/install.sh /path/to/project` (or the `.ps1` equivalent) — it will deploy the three context templates without touching existing files. Then run `/onboard-project` Phase 4 to populate them. The `agent-context.md` flattener falls back to `.claude/context.md` if the `.claude/context/` folder is absent, so old installs continue to work without migration. |
| Re-running installer overwrote a file I customised | Files NOT in `BOOTSTRAP_MANIFEST.json` are never overwritten. If your customisation was overwritten, the file was bootstrap-origin (in the manifest) and `--force` was used. To prevent: don't customise bootstrap-origin files in place; either (a) override via `lessons.md`, or (b) commit the file's removal from `BOOTSTRAP_MANIFEST.json` so it's treated as service-specific from then on |
| Bootstrap took longer than 12 min | The skill spent extra time on Phase 1–2 scans for an unusually large or unusual codebase. If consistently >15 min, capture observations as a Lesson Candidate so future runs can scope-limit the scan. |
