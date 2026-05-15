# session-end.ps1 - runs at Claude Code Stop. Three jobs:
#   1. Trim session-log.md to the last 3 entries (prevents context bloat).
#   2. Trim lessons.md to the most recent 20 bullets across all sections
#      (curator inserts at top of each section, so first 20 = newest).
#      Section headers, prose, and blank lines preserved.
#   3. Auto-discard .pending-lesson-candidates entries older than 60 days
#      (prevents unbounded accumulation when reminders are repeatedly ignored).
# Always returns 0 so it never blocks session shutdown.

$ErrorActionPreference = 'SilentlyContinue'
$claudeDir = Split-Path $PSScriptRoot -Parent

# Job 1: trim session-log.md to last 3 entries
$log = Join-Path $claudeDir 'session-log.md'
if (Test-Path $log) {
    $keep = 3
    $count = 0
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content $log) {
        if ($line -match '^## ') {
            $count++
            if ($count -gt $keep) { break }
        }
        $out.Add($line)
    }
    Set-Content -Path $log -Value $out -Encoding UTF8
}

# Job 2: trim lessons.md to first 20 bullets in file order.
# Curator MUST insert new lessons at the TOP of each section (file-order =
# recency). Bullets beyond #20 are dropped. Section headers, prose, and
# blank lines pass through unchanged.
$lessons = Join-Path $claudeDir 'lessons.md'
if (Test-Path $lessons) {
    $total = (Get-Content $lessons | Where-Object { $_ -match '^- ' }).Count
    if ($total -gt 20) {
        $max = 20
        $bullets = 0
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($line in Get-Content $lessons) {
            if ($line -match '^- ') {
                $bullets++
                if ($bullets -gt $max) { continue }
            }
            $out.Add($line)
        }
        Set-Content -Path $lessons -Value $out -Encoding UTF8
    }
}

# Auto-discard pending lesson candidate entries older than 60 days.
# Lossy by design: 60-day-old un-curated candidates are clearly being ignored;
# better to bound the file than let it accumulate forever. The user is warned
# at every SessionStart for that 60 days before silent removal.
$marker = Join-Path $claudeDir '.pending-lesson-candidates'
if (Test-Path $marker) {
    $cutoff = (Get-Date).ToUniversalTime().AddDays(-60).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $kept = Get-Content $marker | Where-Object {
        $ts = ($_ -split '\s+')[0]
        $ts -ge $cutoff
    }
    if ($kept) {
        Set-Content -Path $marker -Value $kept -Encoding UTF8
    } else {
        Remove-Item $marker -Force
    }
}

exit 0
