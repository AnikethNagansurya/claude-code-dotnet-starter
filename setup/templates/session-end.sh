#!/usr/bin/env bash
# session-end.sh — runs at Claude Code Stop. Three jobs:
#   1. Trim session-log.md to the last 3 entries (prevents context bloat).
#   2. Trim lessons.md to the most recent 20 bullets across all sections
#      (curator inserts at top of each section, so first 20 = newest).
#      Section headers, prose, and blank lines preserved.
#   3. Auto-discard .pending-lesson-candidates entries older than 60 days
#      (prevents unbounded accumulation when reminders are repeatedly ignored).
# Always exits 0 so it never blocks session shutdown.

CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Job 1: trim session-log.md to last 3 entries
LOG="$CLAUDE_DIR/session-log.md"
if [[ -f "$LOG" ]]; then
    awk '
        BEGIN { keep = 3; count = 0 }
        /^## / { count++; if (count > keep) exit }
        { print }
    ' "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# Job 2: trim lessons.md to first 20 bullets in file order.
# Curator MUST insert new lessons at the TOP of each section (file-order =
# recency). Bullets beyond #20 are dropped. Section headers, prose, and
# blank lines pass through unchanged. Skipped if lessons.md absent.
LESSONS="$CLAUDE_DIR/lessons.md"
if [[ -f "$LESSONS" ]]; then
    TOTAL=$(grep -c '^- ' "$LESSONS" 2>/dev/null || echo 0)
    if [[ "$TOTAL" -gt 20 ]]; then
        awk '
            BEGIN { max = 20; bullets = 0 }
            /^- / {
                bullets++
                if (bullets > max) next
            }
            { print }
        ' "$LESSONS" > "$LESSONS.tmp" && mv "$LESSONS.tmp" "$LESSONS"
    fi
fi

# Auto-discard pending lesson candidate entries older than 60 days.
# Lossy by design: 60-day-old un-curated candidates are clearly being ignored;
# better to bound the file than let it accumulate forever. The user is warned
# at every SessionStart for that 60 days before silent removal.
MARKER="$CLAUDE_DIR/.pending-lesson-candidates"
if [[ -f "$MARKER" ]]; then
    # Compute cutoff timestamp 60 days ago (handles GNU date and BSD date)
    CUTOFF=$(date -u -d "60 days ago" +%FT%TZ 2>/dev/null)
    if [[ -z "$CUTOFF" ]]; then
        CUTOFF=$(date -u -v-60d +%FT%TZ 2>/dev/null)
    fi
    if [[ -n "$CUTOFF" ]]; then
        awk -v cutoff="$CUTOFF" '$1 >= cutoff' "$MARKER" > "$MARKER.tmp" 2>/dev/null
        if [[ -s "$MARKER.tmp" ]]; then
            mv "$MARKER.tmp" "$MARKER"
        else
            rm -f "$MARKER" "$MARKER.tmp"
        fi
    fi
fi

exit 0
