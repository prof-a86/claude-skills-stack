#!/bin/bash
# compact-tracker.sh
# Claude Skills Stack — /compact Usage Tracker
# Fires on Notification events to detect when /compact is run
# Sets a session-scoped flag that degradation-monitor.sh reads
#
# Install: .claude/hooks/compact-tracker.sh
# Register: settings.json → hooks → Notification

set -euo pipefail

# ── Scenario 7 patch: Claude.ai safety guard ─────────────────────────────────
# Hooks only run in Claude Code. Exit cleanly if invoked outside that context.
if [ -z "${CLAUDE_CODE_HOOKS:-}" ]; then
    exit 0
fi

INPUT=$(cat)

# Check if this notification is a /compact event
IS_COMPACT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    msg = str(data.get('message', '')).lower()
    if 'compact' in msg or 'compacted' in msg or 'compression' in msg:
        print('yes')
    else:
        print('no')
except Exception:
    print('no')
" 2>/dev/null || echo "no")

if [ "$IS_COMPACT" = "yes" ]; then
    # Extract and sanitize SESSION_ID — alphanumeric, hyphens, underscores only
    # Prevents path traversal in COMPACT_FLAG temp file path
    SESSION_ID=$(echo "$INPUT" | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
    raw = data.get('session_id', 'unknown')
    safe = re.sub(r'[^a-zA-Z0-9_-]', '', str(raw))
    print(safe if safe else 'unknown')
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")

    COMPACT_FLAG="/tmp/claude-compact-run-${SESSION_ID}"
    LOCK_FILE="/tmp/claude-compact-lock-${SESSION_ID}"

    # ── Scenario 3 patch: atomic flag write with flock ────────────────────────
    # Prevents race condition if concurrent Notification events fire simultaneously
    (
        flock -x 200
        touch "$COMPACT_FLAG"
    ) 200>"$LOCK_FILE"
fi

exit 0
