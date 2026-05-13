#!/usr/bin/env bash
# install.sh — drop the .NET Core agent library into a target project.
#
# Usage:
#   ./setup/install.sh <path-to-target-project>                         (first install or pick up new files)
#   ./setup/install.sh <path-to-target-project> --force                 (also update bootstrap-origin files)
#   ./setup/install.sh <path-to-target-project> --force --skip-analysis (update without dropping BOOTSTRAP_PENDING.md)
#
# Behaviour:
#   - Default: copies files that don't yet exist in the target. Existing files
#     are preserved. Use this to pick up new agents/skills/rules added since
#     last install.
#   - --force: also updates files that originated from bootstrap (tracked in
#     .claude/BOOTSTRAP_MANIFEST.json). Files NOT in the manifest (service-
#     specific overrides) are never touched.
#     NOTE: --force overwrites bootstrap skill files including any
#     ## Service-Specific Context and ## Service-Specific Routing sections
#     appended by /onboard-project Phase 6. Re-run /onboard-project after
#     a --force update to restore those customisations.
#   - --skip-analysis: skip writing BOOTSTRAP_PENDING.md. Use in CI/CD or
#     when you intend to run /onboard-project separately.
#   - CLAUDE.md is never overwritten regardless of flags.
#   - settings.json is always merged (allow/deny dedup, hooks wired idempotently).

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <target-project-dir> [--force] [--skip-analysis]"
    echo "Example: $0 ../MyDotNetService"
    echo "         $0 ../MyDotNetService --force                (update bootstrap-origin files)"
    echo "         $0 ../MyDotNetService --force --skip-analysis (update without BOOTSTRAP_PENDING.md)"
    exit 1
fi

TARGET="$1"
FORCE=0
SKIP_ANALYSIS=0
for arg in "${@:2}"; do
    case "$arg" in
        --force)          FORCE=1 ;;
        --skip-analysis)  SKIP_ANALYSIS=1 ;;
    esac
done

# Source = parent directory of this script (the agent library root)
SOURCE="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$TARGET" ]]; then
    echo "Error: '$TARGET' does not exist or is not a directory"
    exit 1
fi

# Resolve target to absolute path
TARGET="$(cd "$TARGET" && pwd)"
MANIFEST="$TARGET/.claude/BOOTSTRAP_MANIFEST.json"

# ---------------------------------------------------------------------------
# Pre-flight: branch + .NET project sanity checks
# ---------------------------------------------------------------------------
if (cd "$TARGET" && git rev-parse --git-dir >/dev/null 2>&1); then
    BRANCH=$(cd "$TARGET" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
    case "$BRANCH" in
        main|master|trunk|develop) ;;
        HEAD)
            echo "[!]  Target is in detached HEAD state — checkout a branch (main/master) before installing."
            read -r -p "    Continue anyway? [y/N] " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
            ;;
        *)
            echo "[!]  Target is on branch '$BRANCH', not main/master/trunk/develop."
            echo "     The installer creates new files and writes .claude/settings.json."
            read -r -p "    Continue on '$BRANCH'? [y/N] " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
            ;;
    esac
fi

if ! ls "$TARGET"/*.sln "$TARGET"/*.csproj "$TARGET"/**/*.csproj 2>/dev/null | head -1 | grep -q .; then
    echo "[!]  No .sln or .csproj found in $TARGET — these agents target .NET Core projects."
    read -r -p "    Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

echo ""
echo "  Bootstrap : $SOURCE"
echo "  Target    : $TARGET"
echo "  Force     : $([[ $FORCE -eq 1 ]] && echo "yes" || echo "no")
  Skip-Analysis : $([[ $SKIP_ANALYSIS -eq 1 ]] && echo "yes" || echo "no")"
echo ""

# ---------------------------------------------------------------------------
# Manifest helpers — JSON array of relative paths (forward-slash)
# ---------------------------------------------------------------------------
load_manifest() {
    if [[ -f "$MANIFEST" ]]; then
        # Strip JSON brackets/quotes, output one path per line
        sed -e 's/^\[//' -e 's/\]$//' -e 's/"//g' -e 's/, */\n/g' "$MANIFEST" | grep -v '^[[:space:]]*$' || true
    fi
}

save_manifest() {
    mkdir -p "$(dirname "$MANIFEST")"
    {
        printf '['
        local first=1
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            if [[ $first -eq 1 ]]; then
                printf '\n  "%s"' "$path"
                first=0
            else
                printf ',\n  "%s"' "$path"
            fi
        done < <(printf '%s\n' "${MANIFEST_ENTRIES[@]}" | sort -u)
        printf '\n]\n'
    } > "$MANIFEST"
}

# Load existing manifest into array
declare -a MANIFEST_ENTRIES=()
if [[ -f "$MANIFEST" ]]; then
    while IFS= read -r line; do
        MANIFEST_ENTRIES+=("$line")
    done < <(load_manifest)
fi

manifest_contains() {
    local needle="$1"
    for entry in "${MANIFEST_ENTRIES[@]}"; do
        [[ "$entry" == "$needle" ]] && return 0
    done
    return 1
}

manifest_add() {
    local path="$1"
    if ! manifest_contains "$path"; then
        MANIFEST_ENTRIES+=("$path")
    fi
}

# Stats
N_COPIED=0
N_UPDATED=0
N_SKIPPED=0
N_MERGED=0
N_REPAIRED=0

# ---------------------------------------------------------------------------
# Manifest repair (only with --force, runs before install)
# Walks every destination this installer writes to. If a destination file
# already exists in the target but isn't in the manifest, register it so
# --force can update it. CLAUDE.md is always excluded.
# ---------------------------------------------------------------------------
repair_check() {
    local dst_rel="$1"
    local dst="$TARGET/$dst_rel"
    if [[ -f "$dst" ]] && ! manifest_contains "$dst_rel"; then
        manifest_add "$dst_rel"
        ((N_REPAIRED++)) || true
    fi
}

repair_manifest() {
    [[ $FORCE -eq 0 ]] && return

    # Agents (from Personas/)
    for f in "$SOURCE/Personas"/*.md; do
        [[ -f "$f" ]] && repair_check ".claude/agents/$(basename "$f")"
    done

    # Skills, rules, output-styles (from .claude/)
    if [[ -d "$SOURCE/.claude" ]]; then
        while IFS= read -r src; do
            local rel="${src#$SOURCE/}"
            repair_check "$rel"
        done < <(find "$SOURCE/.claude" -type f 2>/dev/null | grep -v 'settings.local.json' || true)
    fi

    # Hook scripts (from setup/templates/)
    for f in session-end.sh session-end.ps1 session-start.sh session-start.ps1; do
        [[ -f "$SOURCE/setup/templates/$f" ]] && repair_check ".claude/scripts/$f"
    done

    # Top-level prompts (from setup/templates/)
    for f in system-design.md; do
        [[ -f "$SOURCE/setup/templates/$f" ]] && repair_check ".claude/prompts/$f"
    done

    # Tier 2 prompts (from setup/templates/prompts/)
    if [[ -d "$SOURCE/setup/templates/prompts" ]]; then
        for f in "$SOURCE/setup/templates/prompts"/*.md; do
            [[ -f "$f" ]] && repair_check ".claude/prompts/$(basename "$f")"
        done
    fi

    # Example files (from setup/templates/examples/)
    if [[ -d "$SOURCE/setup/templates/examples" ]]; then
        for f in "$SOURCE/setup/templates/examples"/.[!.]* "$SOURCE/setup/templates/examples"/*; do
            [[ -f "$f" ]] || continue
            repair_check "$(basename "$f")"
        done
    fi

    # Context files (from setup/templates/context/)
    if [[ -d "$SOURCE/setup/templates/context" ]]; then
        for f in "$SOURCE/setup/templates/context"/*.md; do
            [[ -f "$f" ]] && repair_check ".claude/context/$(basename "$f")"
        done
    fi

    if [[ $N_REPAIRED -gt 0 ]]; then
        echo "[!]  Manifest repair: registered $N_REPAIRED pre-existing bootstrap file(s)."
        echo "     These will now be updatable via --force."
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# install_file SRC DST
#   File absent in target              → copy (always)
#   File present + in manifest + force → update
#   File present + in manifest + !force → skip with hint
#   File present + NOT in manifest     → skip (service-specific, never touch)
# ---------------------------------------------------------------------------
install_file() {
    local src="$1" dst="$2"
    local rel="${dst#$TARGET/}"
    mkdir -p "$(dirname "$dst")"
    if [[ ! -f "$dst" ]]; then
        cp "$src" "$dst"
        manifest_add "$rel"
        echo "  [OK] Installed    : $rel"
        ((N_COPIED++)) || true
    elif manifest_contains "$rel"; then
        if [[ $FORCE -eq 1 ]]; then
            cp "$src" "$dst"
            echo "  [OK] Updated      : $rel  (bootstrap origin, --force)"
            ((N_UPDATED++)) || true
        else
            echo "  [--] Exists (bootstrap): $rel  (rerun with --force to update)"
            ((N_SKIPPED++)) || true
        fi
    else
        echo "  [--] Kept (service-specific): $rel"
        ((N_SKIPPED++)) || true
    fi
}

repair_manifest

# ---------------------------------------------------------------------------
# Step 1: Agents
# ---------------------------------------------------------------------------
echo "  >> Agents"
mkdir -p "$TARGET/.claude/agents"
AGENTS=(
    architecture-reviewer.md code-reviewer.md
    doc-generator.md pr-reviewer.md
    test-writer.md migration-writer.md refactoring-agent.md
    lesson-curator.md
)
for f in "${AGENTS[@]}"; do
    install_file "$SOURCE/Personas/$f" "$TARGET/.claude/agents/$f"
done

# ---------------------------------------------------------------------------
# Step 2: Skills (NEW — Tier 1 from V2)
# ---------------------------------------------------------------------------
echo "  >> Skills"
if [[ -d "$SOURCE/.claude/skills" ]]; then
    for skill_dir in "$SOURCE/.claude/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            install_file "$skill_dir/SKILL.md" "$TARGET/.claude/skills/$skill_name/SKILL.md"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Step 3: Rules (NEW — Tier 2 from V2)
# ---------------------------------------------------------------------------
echo "  >> Rules"
if [[ -d "$SOURCE/.claude/rules" ]]; then
    for rule in "$SOURCE/.claude/rules"/*.md; do
        [[ -f "$rule" ]] || continue
        install_file "$rule" "$TARGET/.claude/rules/$(basename "$rule")"
    done
fi

# ---------------------------------------------------------------------------
# Step 4: Output styles (NEW — Tier 2 from V2)
# ---------------------------------------------------------------------------
echo "  >> Output styles"
if [[ -d "$SOURCE/.claude/output-styles" ]]; then
    for style in "$SOURCE/.claude/output-styles"/*.md; do
        [[ -f "$style" ]] || continue
        install_file "$style" "$TARGET/.claude/output-styles/$(basename "$style")"
    done
fi

# ---------------------------------------------------------------------------
# Step 5: Context files (template-based, from setup/templates/context/)
# ---------------------------------------------------------------------------
echo "  >> Context files (architecture.md, tech-stack.md, coding-standards.md)"
if [[ -d "$SOURCE/setup/templates/context" ]]; then
    mkdir -p "$TARGET/.claude/context"
    for ctx in "$SOURCE/setup/templates/context"/*.md; do
        [[ -f "$ctx" ]] || continue
        install_file "$ctx" "$TARGET/.claude/context/$(basename "$ctx")"
    done
fi

# ---------------------------------------------------------------------------
# Step 5b: Skeleton files (created only if missing — NOT manifest-tracked)
# ---------------------------------------------------------------------------
echo "  >> Skeletons (lessons.md, session-log.md)"

if [[ ! -f "$TARGET/.claude/lessons.md" ]]; then
    cat > "$TARGET/.claude/lessons.md" <<'EOF'
# Project-Specific Lessons

Capture rules that override or extend the generic agent guidance. Keep entries
short and link to commits/issues where relevant. Curated by `@lesson-curator`
— prefer running that agent over hand-editing.

**RULE: Cap of 20 bullets total.** The Stop hook (`.claude/scripts/session-end.sh`)
trims this file to the first 20 bullets in file order at the end of every Claude
Code session. The curator MUST insert new lessons at the TOP of their matching
section so recent learnings stay; bullets beyond #20 (counted top-to-bottom across
all sections) are silently pruned. Section headers, prose, and blank lines are
preserved regardless of count.

## Build Errors

## Naming Constraints

## DI Quirks

## Test Setup

## Architecture Deltas

## Stack Deltas

## Compliance Posture
EOF
    echo "  [OK] Installed    : .claude/lessons.md (skeleton)"
fi

if [[ ! -f "$TARGET/.claude/session-log.md" ]]; then
    cat > "$TARGET/.claude/session-log.md" <<'EOF'
# Session Log

Reverse-chronological. Latest session at top. One block per session.

**RULE: Keep only the last 10 sessions.** A Stop hook (auto-wired by the
installer) trims this file at end of every Claude Code session.

**Dynamic dates only.** Get today's date by running:
- Bash: `date -u +%F`
- PowerShell: `(Get-Date -Format 'yyyy-MM-dd')`

The heading format is `## YYYY-MM-DD — short title`.

## YYYY-MM-DD
- {what was worked on}
- {decisions made}
- {open threads carried into next session}
EOF
    echo "  [OK] Installed    : .claude/session-log.md (skeleton)"
fi


# ---------------------------------------------------------------------------
# Step 6: Hook scripts (always rewritten — bootstrap-origin)
# ---------------------------------------------------------------------------
echo "  >> Hook scripts"
mkdir -p "$TARGET/.claude/scripts"
install_file "$SOURCE/setup/templates/session-end.sh"     "$TARGET/.claude/scripts/session-end.sh"
install_file "$SOURCE/setup/templates/session-end.ps1"    "$TARGET/.claude/scripts/session-end.ps1"
install_file "$SOURCE/setup/templates/session-start.sh"   "$TARGET/.claude/scripts/session-start.sh"
install_file "$SOURCE/setup/templates/session-start.ps1"  "$TARGET/.claude/scripts/session-start.ps1"
chmod +x "$TARGET/.claude/scripts/session-end.sh" "$TARGET/.claude/scripts/session-start.sh"

# ---------------------------------------------------------------------------
# Step 7: Installable prompts
# ---------------------------------------------------------------------------
echo "  >> Prompts"
mkdir -p "$TARGET/.claude/prompts"
install_file "$SOURCE/setup/templates/system-design.md"    "$TARGET/.claude/prompts/system-design.md"

# Tier 2 prompt templates
if [[ -d "$SOURCE/setup/templates/prompts" ]]; then
    for prompt in "$SOURCE/setup/templates/prompts"/*.md; do
        [[ -f "$prompt" ]] || continue
        install_file "$prompt" "$TARGET/.claude/prompts/$(basename "$prompt")"
    done
fi

# ---------------------------------------------------------------------------
# Step 8: Example files (.gitignore only)
# ---------------------------------------------------------------------------
echo "  >> Example files"
if [[ -d "$SOURCE/setup/templates/examples" ]]; then
    for example in "$SOURCE/setup/templates/examples"/.[!.]* "$SOURCE/setup/templates/examples"/*; do
        [[ -f "$example" ]] || continue
        install_file "$example" "$TARGET/$(basename "$example")"
    done
fi

# ---------------------------------------------------------------------------
# Step 9: CLAUDE.md — NEVER overwrite, even with --force
# ---------------------------------------------------------------------------
if [[ -f "$TARGET/CLAUDE.md" ]]; then
    cp "$SOURCE/CLAUDE.md" "$TARGET/CLAUDE.md.agents-template"
    CLAUDE_MSG="[!]  CLAUDE.md already existed — agents template copied to CLAUDE.md.agents-template for manual merge"
else
    cp "$SOURCE/CLAUDE.md" "$TARGET/CLAUDE.md"
    CLAUDE_MSG="[OK] CLAUDE.md installed at project root"
fi

# ---------------------------------------------------------------------------
# Step 10: settings.json — install from template (idempotent merge if exists)
# ---------------------------------------------------------------------------
SETTINGS="$TARGET/.claude/settings.json"
SETTINGS_TEMPLATE="$SOURCE/setup/templates/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
    if [[ -f "$SETTINGS_TEMPLATE" ]]; then
        cp "$SETTINGS_TEMPLATE" "$SETTINGS"
        SETTINGS_MSG="[OK] settings.json installed (permissions + hooks + defaultMode: acceptEdits)"
    else
        # Fallback: write minimal hooks-only block
        printf '{\n  "hooks": {\n    "SessionStart": [{"matcher":"","hooks":[{"type":"command","command":"bash .claude/scripts/session-start.sh 2>/dev/null || pwsh -NoProfile -File .claude/scripts/session-start.ps1"}]}],\n    "Stop": [{"matcher":"","hooks":[{"type":"command","command":"bash .claude/scripts/session-end.sh 2>/dev/null || pwsh -NoProfile -File .claude/scripts/session-end.ps1"}]}]\n  }\n}\n' > "$SETTINGS"
        SETTINGS_MSG="[OK] settings.json installed with hooks wired (template not found — minimal fallback)"
    fi
elif grep -q 'session-end' "$SETTINGS"; then
    if grep -q '"permissions"' "$SETTINGS"; then
        SETTINGS_MSG="[OK] settings.json already has hooks + permissions block (no change)"
    else
        # Existing file has hooks but no permissions — merge in the permissions block if jq available
        if command -v jq >/dev/null 2>&1 && [[ -f "$SETTINGS_TEMPLATE" ]]; then
            TMP="$SETTINGS.tmp"
            jq -s '.[0] * .[1]' "$SETTINGS" "$SETTINGS_TEMPLATE" > "$TMP" && mv "$TMP" "$SETTINGS"
            SETTINGS_MSG="[OK] settings.json merged — permissions block added via jq"
            ((N_MERGED++)) || true
        else
            cp "$SETTINGS_TEMPLATE" "$SETTINGS.agents-template" 2>/dev/null || true
            SETTINGS_MSG="[!]  settings.json has hooks but no permissions. New template saved to settings.json.agents-template — merge permissions block manually."
        fi
    fi
else
    # Existing file, no hooks — full install from template
    if [[ -f "$SETTINGS_TEMPLATE" ]]; then
        cp "$SETTINGS_TEMPLATE" "$SETTINGS"
        SETTINGS_MSG="[OK] settings.json replaced with full template (permissions + hooks)"
        ((N_MERGED++)) || true
    else
        SETTINGS_MSG="[!]  settings.json exists without hooks and template not found — manual update needed"
    fi
fi

# ---------------------------------------------------------------------------
# Step 11: BOOTSTRAP_PENDING.md marker (signals onboard-project is needed)
# ---------------------------------------------------------------------------
PENDING="$TARGET/.claude/BOOTSTRAP_PENDING.md"
if [[ $SKIP_ANALYSIS -eq 0 && ! -f "$PENDING" ]]; then
    if [[ $FORCE -eq 1 && $N_UPDATED -gt 0 ]]; then
        cat > "$PENDING" <<'EOF'
# Bootstrap Updated — Re-customisation Required

The Claude Code agent library has been updated (one or more bootstrap-origin
files refreshed via --force).

Bootstrap skill files are refreshed to their latest generic versions, which
means any service-specific sections that /onboard-project Phase 6 appended
to them have been overwritten:
  - ## Service-Specific Context sections (Phase 6a — added to bootstrap
    utility/workflow skills to cross-reference dedicated service skills)
  - ## Service-Specific Routing sections (Phase 6b — added to persona skills
    agent-developer / agent-architect to delegate to service-specific skills)

Re-run /onboard-project to restore and extend all service-specific content:

```
/onboard-project
```

Claude will:
- Re-scan the codebase and re-populate CLAUDE.md + context/ files if needed
- Re-run Phase 6a to restore ## Service-Specific Context cross-pointers
- Re-run Phase 6b to re-wire persona skill routing (asks A/B/C/D again)
- Pick up any new service-specific skills added since the last run
- Suggest new bootstrap capabilities added in this update
- Remove this file when done
EOF
    else
        cat > "$PENDING" <<'EOF'
# Bootstrap Customization Pending

The generic Claude Code agent library has been installed. Run the
customization skill to let Claude analyse this service and tailor everything:

```
/onboard-project
```

The skill is a single main-session execution covering 12 phases (0–11):
  Phase 0  — Branch / state check (WAIT if non-default branch or dirty tree)
  Phase 1  — Service Discovery (csproj scan, Program.cs, appsettings)
  Phase 2  — Codebase Deep Dive (entities, services, hosted services, tests,
              skill inventory — Phase 2g)
  Phase 3  — Populate CLAUDE.md (Project Facts + scaffold sections)
  Phase 4  — Populate context/ files (architecture.md, tech-stack.md,
              coding-standards.md) — WAIT for Current Phase question
  Phase 5  — Emit Lesson Candidates across all 9 lessons.md headings
  Phase 6  — Skill Alignment:
              6a: add ## Service-Specific Context to overlapping bootstrap skills
              6b: persona routing analysis (agent-developer / agent-architect)
                  — WAIT for A/B/C/D choice (only if service-specific skills exist)
              6c: suggest missing skills
  Phase 7  — Delete this BOOTSTRAP_PENDING.md (with verify)
  Phase 8  — Run @lesson-curator to write lessons.md — WAIT for diff approval
  Phase 9  — Auto-write today's session-log entry
  Phase 10 — Mechanical verification — disk checks + subagent context smoke test
  Phase 11 — Final output report

Total: ~8–12 min. Three WAIT gates on fresh install (Phase 0 if non-default,
Phase 4 Current Phase question, Phase 8 curator diff approval). A fourth WAIT
gate fires at Phase 6b only if service-specific skills are found.

Delete this file manually to skip customization and use the generic library as-is.
EOF
    fi
    echo "  [OK] Installed    : .claude/BOOTSTRAP_PENDING.md"
fi

# ---------------------------------------------------------------------------
# Persist the manifest
# ---------------------------------------------------------------------------
save_manifest

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
cat <<EOF

  ----------------------------------------------------------------------------
  Installed : $N_COPIED new file(s)
  Updated   : $N_UPDATED bootstrap-origin file(s) refreshed
  Merged    : $N_MERGED settings.json
  Skipped   : $N_SKIPPED file(s) (kept existing)
  Repaired  : $N_REPAIRED manifest entries

$CLAUDE_MSG
$SETTINGS_MSG

Next steps (recommended — takes ~8–12 min total):
  1. cd "$TARGET"
  2. Launch Claude Code:           claude
  3. Inside Claude, paste:         /onboard-project
     The skill scans the codebase and populates: Project Facts in CLAUDE.md,
     context/architecture.md + tech-stack.md + coding-standards.md,
     Lesson Candidates → lessons.md (via curator, with diff approval),
     and session-log entry. Three WAIT gates.
  4. Optional:                     Use prompts/system-design.md
     If you want a docs/system-design.md artefact (mermaid diagrams).
     Independent of onboarding; adds 5–10 min.

Re-running the installer:
  Default        : preserves all existing files (only adds new bootstrap files).
  --force        : also updates files in BOOTSTRAP_MANIFEST.json (CLAUDE.md always preserved).
                   NOTE: --force overwrites Phase 6 skill customisations — re-run /onboard-project to restore.
  --skip-analysis: skip BOOTSTRAP_PENDING.md (useful for CI/CD).

EOF
