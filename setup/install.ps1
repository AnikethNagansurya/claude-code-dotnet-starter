<#
.SYNOPSIS
    Install or update the .NET Core agent library in a target project.

.DESCRIPTION
    Copies agents, skills, rules, output-styles, hook scripts, prompts, and example
    files into the target's .claude/ folder. Tracks bootstrap-origin files in
    .claude/BOOTSTRAP_MANIFEST.json so re-runs can update them safely without
    touching service-specific overrides.

    Default (no -Force):
        Installs files that don't exist in the target. Existing files preserved.
        Use to pick up new agents/skills added to bootstrap since last install.

    -Force:
        Updates files that originated from bootstrap (tracked in manifest).
        Files NOT in the manifest (service-specific) are never touched.
        NOTE: -Force overwrites bootstrap skill files including any
        ## Service-Specific Context and ## Service-Specific Routing sections
        appended by /onboard-project Phase 6. Re-run /onboard-project after
        a -Force update to restore those customisations.

    -SkipAnalysis:
        Skip writing BOOTSTRAP_PENDING.md. Use in CI/CD or when you intend
        to run /onboard-project separately at your own pace.

    Special rules:
        CLAUDE.md       - never overwritten regardless of flags
        settings.json   - always merged (allow/deny dedup, hooks idempotent)

    After first install, run /onboard-project inside the service to
    deep-scan the codebase and populate Project Facts + context/ files +
    Lesson Candidates in one main-session turn.

.PARAMETER TargetPath
    Path to the target .NET service root (folder containing .sln or .csproj).

.PARAMETER Force
    Update bootstrap-origin files (tracked in BOOTSTRAP_MANIFEST.json).
    WARNING: this overwrites bootstrap skill files, including any
    ## Service-Specific Context and ## Service-Specific Routing sections
    added by /onboard-project Phase 6. Re-run /onboard-project afterward
    to restore those customisations.

.PARAMETER SkipAnalysis
    Do not write BOOTSTRAP_PENDING.md. Use in CI/CD pipelines or when you
    plan to run /onboard-project manually at your own pace.

.EXAMPLE
    # First install
    .\setup\install.ps1 -TargetPath C:\repos\my-service

    # Pick up bootstrap improvements
    .\setup\install.ps1 -TargetPath C:\repos\my-service -Force

    # Update without dropping the pending marker (CI/CD)
    .\setup\install.ps1 -TargetPath C:\repos\my-service -Force -SkipAnalysis
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetPath,

    [switch]$Force,

    [switch]$SkipAnalysis
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not (Test-Path -Path $TargetPath -PathType Container)) {
    Write-Error "'$TargetPath' does not exist or is not a directory"
    exit 1
}
$target = (Resolve-Path $TargetPath).Path
$manifestPath = Join-Path $target ".claude\BOOTSTRAP_MANIFEST.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step  ([string]$msg) { Write-Host "  >> $msg" -ForegroundColor Cyan }
function Write-Ok    ([string]$msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip  ([string]$msg) { Write-Host "  [--] $msg" -ForegroundColor DarkGray }
function Write-Warn2 ([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }

function Rel ([string]$fullPath) {
    $fullPath.Replace($target, '').TrimStart('\').Replace('\', '/')
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
Push-Location $target
try {
    $null = & git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -eq 0) {
        $branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        $primaryBranches = @('main', 'master', 'trunk', 'develop')
        if ($branch -eq 'HEAD') {
            Write-Warning "Target is in detached HEAD state - checkout a branch before installing."
            $confirm = Read-Host "Continue anyway? [y/N]"
            if ($confirm -notmatch '^[Yy]$') { exit 1 }
        }
        elseif ($primaryBranches -notcontains $branch) {
            Write-Warning "Target is on branch '$branch', not main/master/trunk/develop."
            $confirm = Read-Host "Continue on '$branch'? [y/N]"
            if ($confirm -notmatch '^[Yy]$') { exit 1 }
        }
    }
} finally { Pop-Location }

$dotnetFiles = Get-ChildItem -Path $target -Recurse -Include *.sln, *.csproj -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $dotnetFiles) {
    Write-Warning "No .sln or .csproj found in $target - these agents target .NET Core projects."
    $confirm = Read-Host "Continue anyway? [y/N]"
    if ($confirm -notmatch '^[Yy]$') { exit 1 }
}

Write-Host ""
Write-Host "  Bootstrap     : $source"
Write-Host "  Target        : $target"
Write-Host "  Force         : $($Force.IsPresent)"
Write-Host "  SkipAnalysis  : $($SkipAnalysis.IsPresent)"
Write-Host ""

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------
function Load-Manifest {
    if (Test-Path $manifestPath) {
        try { return @(Get-Content $manifestPath -Raw | ConvertFrom-Json) }
        catch { return @() }
    }
    return @()
}

function Save-Manifest ([string[]]$entries) {
    $dir = Split-Path $manifestPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($entries | Sort-Object -Unique | ConvertTo-Json) | Set-Content $manifestPath -Encoding UTF8
}

$script:manifest = Load-Manifest
$script:nCopied = 0
$script:nUpdated = 0
$script:nSkipped = 0
$script:nMerged = 0
$script:nRepaired = 0

function Add-ToManifest ([string]$relPath) {
    if ($relPath -notin $script:manifest) {
        $script:manifest = @($script:manifest) + $relPath
    }
}

# Manifest repair (-Force only): registers pre-existing bootstrap files
if ($Force) {
    $bootstrapFiles = Get-ChildItem -Path (Join-Path $source ".claude") -Recurse -File -ErrorAction SilentlyContinue
    foreach ($srcFile in $bootstrapFiles) {
        $relSrc = $srcFile.FullName.Replace($source, '').TrimStart('\').Replace('\', '/')
        if ($relSrc -eq 'CLAUDE.md' -or $relSrc -eq '.claude/settings.local.json') { continue }
        $dstFile = Join-Path $target $relSrc.Replace('/', '\')
        if ((Test-Path $dstFile) -and ($relSrc -notin $script:manifest)) {
            Add-ToManifest $relSrc
            $script:nRepaired++
        }
    }
    # Context files
    $srcContextDir = Join-Path $source "setup\templates\context"
    if (Test-Path $srcContextDir) {
        foreach ($f in Get-ChildItem -Path $srcContextDir -Filter "*.md") {
            $dstFile = Join-Path $target ".claude\context\$($f.Name)"
            $relPath = ".claude/context/$($f.Name)"
            if ((Test-Path $dstFile) -and ($relPath -notin $script:manifest)) {
                Add-ToManifest $relPath
                $script:nRepaired++
            }
        }
    }

    if ($script:nRepaired -gt 0) {
        Write-Warn2 "Manifest repair: registered $($script:nRepaired) pre-existing bootstrap file(s)."
        Write-Host "       These will now be updatable via -Force." -ForegroundColor DarkGray
        Write-Host ""
    }
}

# ---------------------------------------------------------------------------
# Install-File: decision matrix
#   File absent              -> copy (add to manifest)
#   In manifest + Force      -> update
#   In manifest + !Force     -> skip with hint
#   Not in manifest          -> skip (service-specific)
# ---------------------------------------------------------------------------
function Install-File ([string]$Source, [string]$Destination) {
    $relDst = Rel $Destination
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (-not (Test-Path $Destination)) {
        Copy-Item $Source $Destination
        Add-ToManifest $relDst
        Write-Ok "Installed    : $relDst"
        $script:nCopied++
    }
    elseif ($relDst -in $script:manifest) {
        if ($Force) {
            Copy-Item $Source $Destination -Force
            Write-Ok "Updated      : $relDst  (bootstrap origin, -Force)"
            $script:nUpdated++
        } else {
            Write-Skip "Exists (bootstrap): $relDst  -- rerun with -Force to update"
            $script:nSkipped++
        }
    }
    else {
        Write-Skip "Kept (service-specific): $relDst"
        $script:nSkipped++
    }
}

# ---------------------------------------------------------------------------
# Step 1: Agents
# ---------------------------------------------------------------------------
Write-Step "Agents"
$null = New-Item -ItemType Directory -Force -Path "$target\.claude\agents"
$agents = @(
    'architecture-reviewer.md', 'code-reviewer.md',
    'doc-generator.md', 'pr-reviewer.md',
    'test-writer.md', 'migration-writer.md', 'refactoring-agent.md',
    'lesson-curator.md'
)
foreach ($a in $agents) {
    Install-File "$source\Personas\$a" "$target\.claude\agents\$a"
}

# ---------------------------------------------------------------------------
# Step 2: Skills
# ---------------------------------------------------------------------------
Write-Step "Skills"
$srcSkills = Join-Path $source ".claude\skills"
if (Test-Path $srcSkills) {
    foreach ($skillDir in Get-ChildItem -Path $srcSkills -Directory) {
        $srcFile = Join-Path $skillDir.FullName "SKILL.md"
        if (Test-Path $srcFile) {
            Install-File $srcFile "$target\.claude\skills\$($skillDir.Name)\SKILL.md"
        }
    }
}

# ---------------------------------------------------------------------------
# Step 3: Rules
# ---------------------------------------------------------------------------
Write-Step "Rules"
$srcRules = Join-Path $source ".claude\rules"
if (Test-Path $srcRules) {
    foreach ($f in Get-ChildItem -Path $srcRules -Filter "*.md") {
        Install-File $f.FullName "$target\.claude\rules\$($f.Name)"
    }
}

# ---------------------------------------------------------------------------
# Step 4: Output styles
# ---------------------------------------------------------------------------
Write-Step "Output styles"
$srcStyles = Join-Path $source ".claude\output-styles"
if (Test-Path $srcStyles) {
    foreach ($f in Get-ChildItem -Path $srcStyles -Filter "*.md") {
        Install-File $f.FullName "$target\.claude\output-styles\$($f.Name)"
    }
}

# ---------------------------------------------------------------------------
# Step 5: Context files (template-based, from setup/templates/context/)
# ---------------------------------------------------------------------------
Write-Step "Context files (architecture.md, tech-stack.md, coding-standards.md)"
$srcContext = Join-Path $source "setup\templates\context"
if (Test-Path $srcContext) {
    $null = New-Item -ItemType Directory -Force -Path "$target\.claude\context"
    foreach ($f in Get-ChildItem -Path $srcContext -Filter "*.md") {
        Install-File $f.FullName "$target\.claude\context\$($f.Name)"
    }
}

# ---------------------------------------------------------------------------
# Step 5b: Skeletons (created only if missing - NOT manifest-tracked)
# ---------------------------------------------------------------------------
Write-Step "Skeletons (lessons.md, session-log.md)"

function New-SkeletonFile {
    param([string]$Path, [string]$Content)
    if (-not (Test-Path $Path)) {
        Set-Content -Path $Path -Value $Content -Encoding UTF8
        Write-Ok "Installed    : $(Rel $Path) (skeleton)"
    }
}

New-SkeletonFile "$target\.claude\lessons.md" @'
# Project-Specific Lessons

Capture rules that override or extend the generic agent guidance. Curated by `@lesson-curator`.

**RULE: Cap of 20 bullets total.** The Stop hook trims this file at end of every session.
The curator MUST insert new lessons at the TOP of their matching section so recent ones survive.

## Build Errors

## Naming Constraints

## DI Quirks

## Test Setup

## Architecture Deltas

## Stack Deltas

## Compliance Posture
'@

New-SkeletonFile "$target\.claude\session-log.md" @'
# Session Log

Reverse-chronological. Latest session at top. One block per session.

**RULE: Keep only the last 10 sessions.** A Stop hook trims this file automatically.

**Dynamic dates only.** Get today's date by running `date -u +%F` (bash) or `(Get-Date -Format 'yyyy-MM-dd')` (PowerShell).

## YYYY-MM-DD
- {what was worked on}
- {decisions made}
- {open threads carried into next session}
'@


# ---------------------------------------------------------------------------
# Step 6: Hook scripts
# ---------------------------------------------------------------------------
Write-Step "Hook scripts"
$null = New-Item -ItemType Directory -Force -Path "$target\.claude\scripts"
Install-File "$source\setup\templates\session-end.sh"    "$target\.claude\scripts\session-end.sh"
Install-File "$source\setup\templates\session-end.ps1"   "$target\.claude\scripts\session-end.ps1"
Install-File "$source\setup\templates\session-start.sh"  "$target\.claude\scripts\session-start.sh"
Install-File "$source\setup\templates\session-start.ps1" "$target\.claude\scripts\session-start.ps1"

# ---------------------------------------------------------------------------
# Step 7: Prompts
# ---------------------------------------------------------------------------
Write-Step "Prompts"
$null = New-Item -ItemType Directory -Force -Path "$target\.claude\prompts"
Install-File "$source\setup\templates\system-design.md"    "$target\.claude\prompts\system-design.md"

$srcPrompts = Join-Path $source "setup\templates\prompts"
if (Test-Path $srcPrompts) {
    foreach ($f in Get-ChildItem -Path $srcPrompts -Filter "*.md") {
        Install-File $f.FullName "$target\.claude\prompts\$($f.Name)"
    }
}

# ---------------------------------------------------------------------------
# Step 8: Example files (.gitignore only)
# ---------------------------------------------------------------------------
Write-Step "Example files"
$srcExamples = Join-Path $source "setup\templates\examples"
if (Test-Path $srcExamples) {
    foreach ($f in Get-ChildItem -Path $srcExamples -Force) {
        if ($f.PSIsContainer) { continue }
        Install-File $f.FullName "$target\$($f.Name)"
    }
}

# ---------------------------------------------------------------------------
# Step 9: CLAUDE.md - NEVER overwrite
# ---------------------------------------------------------------------------
$claudeTarget = "$target\CLAUDE.md"
if (Test-Path $claudeTarget) {
    Copy-Item -Path "$source\CLAUDE.md" -Destination "$target\CLAUDE.md.agents-template" -Force
    $claudeMsg = "[!]  CLAUDE.md already existed - agents template copied to CLAUDE.md.agents-template for manual merge"
} else {
    Copy-Item -Path "$source\CLAUDE.md" -Destination $claudeTarget -Force
    $claudeMsg = "[OK] CLAUDE.md installed at project root"
}

# ---------------------------------------------------------------------------
# Step 10: settings.json - install from template (idempotent merge if exists)
# ---------------------------------------------------------------------------
$settingsPath     = "$target\.claude\settings.json"
$settingsTemplate = Join-Path $source "setup\templates\settings.json"

if (-not (Test-Path $settingsPath)) {
    if (Test-Path $settingsTemplate) {
        Copy-Item $settingsTemplate $settingsPath
        $settingsMsg = "[OK] settings.json installed (permissions + hooks + defaultMode: acceptEdits)"
    } else {
        # Fallback: minimal hooks-only
        $fallback = @{ hooks = @{
            SessionStart = @(@{ matcher = ""; hooks = @(@{ type = "command"; command = "bash .claude/scripts/session-start.sh 2>/dev/null || pwsh -NoProfile -File .claude/scripts/session-start.ps1" }) })
            Stop         = @(@{ matcher = ""; hooks = @(@{ type = "command"; command = "bash .claude/scripts/session-end.sh 2>/dev/null || pwsh -NoProfile -File .claude/scripts/session-end.ps1" }) })
        }}
        $fallback | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
        $settingsMsg = "[OK] settings.json installed with hooks wired (template not found -- minimal fallback)"
    }
} else {
    $existing = Get-Content $settingsPath -Raw
    $hasHooks       = $existing -match 'session-end'
    $hasPermissions = $existing -match '"permissions"'

    if ($hasHooks -and $hasPermissions) {
        $settingsMsg = "[OK] settings.json already has hooks + permissions block (no change)"
    } elseif ($hasHooks -and -not $hasPermissions) {
        # Has hooks, missing permissions -- merge from template if possible
        if ((Test-Path $settingsTemplate)) {
            try {
                $existingObj  = $existing | ConvertFrom-Json
                $templateObj  = Get-Content $settingsTemplate -Raw | ConvertFrom-Json
                # Add permissions and env blocks from template
                foreach ($prop in @('permissions', 'env', 'model', 'effortLevel', 'autoMemoryEnabled', 'showThinkingSummaries', 'cleanupPeriodDays')) {
                    if ((Get-Member -InputObject $templateObj -Name $prop -MemberType NoteProperty -ErrorAction SilentlyContinue) -and
                        -not (Get-Member -InputObject $existingObj -Name $prop -MemberType NoteProperty -ErrorAction SilentlyContinue)) {
                        $existingObj | Add-Member -MemberType NoteProperty -Name $prop -Value $templateObj.$prop
                    }
                }
                $existingObj | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                $settingsMsg = "[OK] settings.json merged -- permissions + model settings added"
                $script:nMerged++
            } catch {
                Copy-Item $settingsTemplate "$settingsPath.agents-template" -ErrorAction SilentlyContinue
                $settingsMsg = "[!]  settings.json has hooks but no permissions. Template saved to settings.json.agents-template -- merge manually."
            }
        } else {
            $settingsMsg = "[!]  settings.json has hooks but no permissions and template not found -- manual update needed."
        }
    } else {
        # No hooks at all -- install fresh from template
        if (Test-Path $settingsTemplate) {
            Copy-Item $settingsTemplate $settingsPath -Force
            $settingsMsg = "[OK] settings.json replaced with full template (permissions + hooks)"
            $script:nMerged++
        } else {
            $settingsMsg = "[!]  settings.json exists without hooks and template not found -- manual update needed"
        }
    }
}

# ---------------------------------------------------------------------------
# Step 11: BOOTSTRAP_PENDING.md
# ---------------------------------------------------------------------------
$pendingPath = Join-Path $target ".claude\BOOTSTRAP_PENDING.md"
if (-not $SkipAnalysis -and -not (Test-Path $pendingPath)) {
    if ($Force -and $script:nUpdated -gt 0) {
        $pendingContent = @'
# Bootstrap Updated -- Re-customisation Required

The Claude Code agent library has been updated (one or more bootstrap-origin
files refreshed via -Force).

Bootstrap skill files are refreshed to their latest generic versions, which
means any service-specific sections that /onboard-project Phase 6 appended
to them have been overwritten:
  - ## Service-Specific Context sections (Phase 6a -- added to bootstrap
    utility/workflow skills to cross-reference dedicated service skills)
  - ## Service-Specific Routing sections (Phase 6b -- added to persona skills
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
'@
    } else {
        $pendingContent = @'
# Bootstrap Customization Pending

The generic Claude Code agent library has been installed. Run the
customization skill to let Claude analyse this service and tailor everything:

```
/onboard-project
```

The skill is a single main-session execution covering 12 phases (0-11):
  Phase 0  - Branch / state check (WAIT if non-default branch or dirty tree)
  Phase 1  - Service Discovery (csproj scan, Program.cs, appsettings)
  Phase 2  - Codebase Deep Dive (entities, services, hosted services, tests,
             skill inventory - Phase 2g)
  Phase 3  - Populate CLAUDE.md (Project Facts + scaffold sections)
  Phase 4  - Populate context/ files (architecture.md, tech-stack.md,
             coding-standards.md) - WAIT for Current Phase question
  Phase 5  - Emit Lesson Candidates across all 9 lessons.md headings
  Phase 6  - Skill Alignment:
             6a: add ## Service-Specific Context to overlapping bootstrap skills
             6b: persona routing analysis (agent-developer / agent-architect)
                 - WAIT for A/B/C/D choice (only if service-specific skills exist)
             6c: suggest missing skills
  Phase 7  - Delete this BOOTSTRAP_PENDING.md (with verify)
  Phase 8  - Run @lesson-curator to write lessons.md - WAIT for diff approval
  Phase 9  - Auto-write today's session-log entry
  Phase 10 - Mechanical verification - disk checks + subagent context smoke test
  Phase 11 - Final output report

Total: ~8-12 min. Three WAIT gates on fresh install (Phase 0 if non-default,
Phase 4 Current Phase question, Phase 8 curator diff approval). A fourth WAIT
gate fires at Phase 6b only if service-specific skills are found.

Delete this file manually to skip customization and use the generic library as-is.
'@
    }
    Set-Content -Path $pendingPath -Value $pendingContent -Encoding UTF8
    Write-Ok "Installed    : .claude/BOOTSTRAP_PENDING.md"
}

# ---------------------------------------------------------------------------
# Persist manifest
# ---------------------------------------------------------------------------
Save-Manifest $script:manifest

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ----------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Installed : $($script:nCopied) new file(s)" -ForegroundColor Green
if ($Force) {
    Write-Host "  Updated   : $($script:nUpdated) bootstrap-origin file(s) refreshed" -ForegroundColor Cyan
}
Write-Host "  Merged    : $($script:nMerged) settings.json" -ForegroundColor Cyan
Write-Host "  Skipped   : $($script:nSkipped) file(s) (kept existing)" -ForegroundColor DarkGray
if ($script:nRepaired -gt 0) {
    Write-Host "  Repaired  : $($script:nRepaired) manifest entries" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  $claudeMsg"
Write-Host "  $settingsMsg"
Write-Host ""
Write-Host "Next steps (recommended - takes ~8-12 min total):" -ForegroundColor Cyan
Write-Host "  1. cd `"$target`""
Write-Host "  2. Launch Claude Code:           claude"
Write-Host "  3. Inside Claude, paste:         /onboard-project"
Write-Host "     The skill scans the codebase and populates: Project Facts in CLAUDE.md,"
Write-Host "     context/architecture.md + tech-stack.md + coding-standards.md,"
Write-Host "     Lesson Candidates -> lessons.md (via curator, with diff approval),"
Write-Host "     and session-log entry. Three WAIT gates."
Write-Host "  4. Optional:                     Use prompts/system-design.md"
Write-Host "     If you want a docs/system-design.md artefact (mermaid diagrams)."
Write-Host "     Independent of onboarding; adds 5-10 min."
Write-Host ""
Write-Host "Re-running the installer:" -ForegroundColor DarkGray
Write-Host "  Default  : preserves all existing files (only adds new bootstrap files)." -ForegroundColor DarkGray
Write-Host "  -Force   : also updates files in BOOTSTRAP_MANIFEST.json (CLAUDE.md always preserved)." -ForegroundColor DarkGray
Write-Host "             NOTE: -Force overwrites Phase 6 skill customisations -- re-run /onboard-project to restore." -ForegroundColor Yellow
Write-Host "  -SkipAnalysis : skip BOOTSTRAP_PENDING.md (useful for CI/CD)." -ForegroundColor DarkGray
Write-Host ""
