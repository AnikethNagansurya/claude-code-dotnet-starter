# Contributing to claude-code-dotnet-starter

Thanks for taking the time to contribute. This is a small toolkit, so contributions go a long way.

## Before you start

- **Bug fixes and small improvements** — open a PR directly. No prior issue needed.
- **New agents or skills** — open an issue first so we can discuss scope and fit before you invest time writing it.
- **Changes to existing agent logic** — describe the .NET scenario it fixes or improves in the PR body.

## Development setup

This repo contains markdown files, shell scripts, and PowerShell scripts — no build step required.

```bash
git clone https://github.com/YOUR-USERNAME/claude-code-dotnet-starter
cd claude-code-dotnet-starter
```

To test the installer against a real .NET project:

```bash
# Linux / macOS / WSL
dotnet new webapi -n TestTarget -o /tmp/test-target
./setup/install.sh /tmp/test-target

# Windows
dotnet new webapi -n TestTarget -o C:\Temp\TestTarget
powershell -ExecutionPolicy Bypass -File .\setup\install.ps1 -TargetPath C:\Temp\TestTarget
```

Then open the target project in Claude Code and run `/onboard-project` to verify the full flow.

## What makes a good agent or skill

- **Project-agnostic** — use `{Resource}`, `{Service}`, `{Project}` placeholders; never hardcode domain names
- **Minimal tool list** — only declare tools the agent actually needs in YAML frontmatter
- **Defined output shape** — reviewer/analyzer agents end with an `## Output Format` block; generator agents produce the artifact directly
- **Read-only reviewers** — no agent except `lesson-curator` writes to `.claude/lessons.md`
- **Reads `agent-context.md` first** — every agent must read `.claude/agent-context.md` as its first action

## Pull request checklist

- [ ] Installer smoke test passes (`setup/install.sh` against a blank `dotnet new webapi`)
- [ ] New/changed agents follow the YAML frontmatter format (`name`, `description`, `tools`)
- [ ] Shell scripts pass `shellcheck`
- [ ] PowerShell scripts pass `PSScriptAnalyzer` (Warning + Error level)
- [ ] `setup/templates/settings.json` is valid JSON

## Commit style

Follow [Conventional Commits](https://www.conventionalcommits.org):

```
feat: add @saga-reviewer agent for MassTransit flow validation
fix: correct session-start.sh path expansion on macOS
docs: add Vertical Slice example to README use cases
chore: bump shellcheck version in CI
```

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Be kind.
