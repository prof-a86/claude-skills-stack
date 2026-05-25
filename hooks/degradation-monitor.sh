#!/bin/bash
# degradation-monitor.sh
# Claude Skills Stack — Session Degradation Monitor Hook
# Fires on every Stop event (after each Claude response)
# Implements the three-zone degradation model from task-auditor Layer 3
#
# Zone thresholds (match task-auditor Layer 3):
#   GREEN:  0-30%   — work normally
#   YELLOW: 30-50%  — suggest /compact, stop new subtasks
#   RED:    50%+    — handoff mandatory
#
# /compact ladder:
#   YELLOW → suggest /compact first
#   RED    → if /compact already run this session, handoff immediately
#           → if /compact not yet run, suggest /compact as last resort before handoff
#
# Install: .claude/hooks/degradation-monitor.sh
# Register: settings.json → hooks → Stop

set -euo pipefail

# ── Scenario 7 patch: Claude.ai safety guard ─────────────────────────────────
# Hooks only run in Claude Code. If CLAUDE_CODE_HOOKS is not set,
# this script was invoked outside Claude Code — exit cleanly, no output.
if [ -z "${CLAUDE_CODE_HOOKS:-}" ]; then
    exit 0
fi

# ── Read Claude Code hook context from stdin ──────────────────────────────────
INPUT=$(cat)

# Extract token usage percentage from hook context
TOKEN_PCT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    usage = data.get('usage', {})
    input_tokens = usage.get('input_tokens', 0)
    context_window = usage.get('context_window', 200000)
    if context_window > 0:
        pct = round((input_tokens / context_window) * 100)
        print(pct)
    else:
        print(0)
except Exception:
    print(0)
" 2>/dev/null || echo "0")

# Ensure TOKEN_PCT is numeric — default to 0 if empty or non-numeric
if ! [[ "$TOKEN_PCT" =~ ^[0-9]+$ ]]; then
    TOKEN_PCT=0
fi

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

# ── Zone detection ─────────────────────────────────────────────────────────────
if [ "$TOKEN_PCT" -ge 50 ]; then
    ZONE="RED"
elif [ "$TOKEN_PCT" -ge 30 ]; then
    ZONE="YELLOW"
else
    ZONE="GREEN"
fi

# ── Scenario 3 patch: atomic flag check with flock ────────────────────────────
# Prevents race condition when concurrent Stop events check/write COMPACT_FLAG
# flock acquires exclusive lock before flag read/write, releases on exit
check_compact_flag() {
    (
        flock -x 200
        if [ -f "$COMPACT_FLAG" ]; then
            echo "yes"
        else
            echo "no"
        fi
    ) 200>"$LOCK_FILE"
}

COMPACT_ALREADY_RUN=$(check_compact_flag)

# ── Output instructions to Claude based on zone ───────────────────────────────
case "$ZONE" in

    "GREEN")
        exit 0
        ;;

    "YELLOW")
        if [ "$COMPACT_ALREADY_RUN" = "yes" ]; then
            cat <<MSG
[DEGRADATION MONITOR] 🟡 YELLOW zone — ${TOKEN_PCT}% token usage.
/compact was already run this session. Continue current task to completion, then prepare for handoff. Do not start new subtasks. Flag to user: "We're at ${TOKEN_PCT}% — finishing current task then creating a handoff file."
MSG
        else
            cat <<MSG
[DEGRADATION MONITOR] 🟡 YELLOW zone — ${TOKEN_PCT}% token usage.
Suggest /compact to the user before starting any new subtask. Say: "We're at ${TOKEN_PCT}% — want to run /compact to compress the session and extend our working window before we continue?"
Do not run /compact automatically. Wait for user confirmation.
MSG
        fi
        ;;

    "RED")
        if [ "$COMPACT_ALREADY_RUN" = "yes" ]; then
            cat <<MSG
[DEGRADATION MONITOR] 🔴 RED zone — ${TOKEN_PCT}% token usage. /compact already run this session.
HANDOFF MANDATORY. Stop current task. Create HANDOFF.md using task-auditor Layer 3 handoff protocol. Do not start any new work. Tell user: "We're at ${TOKEN_PCT}% and /compact has already run — creating handoff file now."
MSG
        else
            cat <<MSG
[DEGRADATION MONITOR] 🔴 RED zone — ${TOKEN_PCT}% token usage.
Offer /compact as a last resort before handoff. Say: "We're at ${TOKEN_PCT}% — I can run /compact to compress the session, or create a handoff file to continue in a fresh session. Which do you prefer?"
If user chooses /compact: note it was run (this is the last /compact opportunity). If user chooses handoff or doesn't respond: create HANDOFF.md using task-auditor Layer 3 protocol immediately.
MSG
        fi
        ;;
esac

exit 0
