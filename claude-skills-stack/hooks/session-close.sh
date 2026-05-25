#!/bin/bash
# session-close.sh
# Claude Skills Stack — Session Close Hook
# Fires on Stop events when Claude produces a handoff or PROJECT_STATE update
# Handles:
#   1. Auto-write PROJECT_STATE.md updates to disk
#   2. Chain-link handoff file routing — creates chain folder, saves to correct seq file
#   3. CHAIN_INDEX.md creation and append
#
# Path resolution:
#   Default: ./PROJECT_STATE.md in working directory
#   Override: CLAUDE_PROJECT_STATE_PATH environment variable
#
# Install: .claude/hooks/session-close.sh
# Register: settings.json → hooks → Stop

set -euo pipefail

# ── Claude.ai safety guard ────────────────────────────────────────────────────
if [ -z "${CLAUDE_CODE_HOOKS:-}" ]; then
    exit 0
fi

# ── Read hook context ─────────────────────────────────────────────────────────
INPUT=$(cat)

# ── Extract Claude's output from hook payload ─────────────────────────────────
CLAUDE_OUTPUT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('output', '') or data.get('assistant_message', '') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

if [ -z "$CLAUDE_OUTPUT" ]; then
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# PART 1 — PROJECT_STATE.md auto-update
# ══════════════════════════════════════════════════════════════════════════════

HAS_STATE_UPDATE=$(echo "$CLAUDE_OUTPUT" | python3 -c "
import sys
content = sys.stdin.read()
print('yes' if '<!-- PROJECT_STATE_UPDATE_START -->' in content else 'no')
" 2>/dev/null || echo "no")

if [ "$HAS_STATE_UPDATE" = "yes" ]; then
    STATE_CONTENT=$(echo "$CLAUDE_OUTPUT" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'<!-- PROJECT_STATE_UPDATE_START -->\n(.*?)\n<!-- PROJECT_STATE_UPDATE_END -->', content, re.DOTALL)
print(match.group(1) if match else '')
" 2>/dev/null || echo "")

    if [ -n "$STATE_CONTENT" ]; then
        # Resolve path
        if [ -n "${CLAUDE_PROJECT_STATE_PATH:-}" ]; then
            STATE_FILE="${CLAUDE_PROJECT_STATE_PATH}/PROJECT_STATE.md"
        else
            STATE_FILE="./PROJECT_STATE.md"
        fi

        # Only update if file exists — never create from scratch via hook
        if [ -f "$STATE_FILE" ]; then
            LOCK_FILE="${STATE_FILE}.lock"
            TEMP_FILE="${STATE_FILE}.tmp"
            (
                flock -x 200
                echo "$STATE_CONTENT" > "$TEMP_FILE"
                mv "$TEMP_FILE" "$STATE_FILE"
            ) 200>"$LOCK_FILE"
            rm -f "$LOCK_FILE"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# PART 2 — Chain-link handoff routing
# ══════════════════════════════════════════════════════════════════════════════

HAS_HANDOFF=$(echo "$CLAUDE_OUTPUT" | python3 -c "
import sys
content = sys.stdin.read()
print('yes' if '<!-- HANDOFF_START -->' in content else 'no')
" 2>/dev/null || echo "no")

if [ "$HAS_HANDOFF" = "yes" ]; then
    # Extract handoff content
    HANDOFF_CONTENT=$(echo "$CLAUDE_OUTPUT" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'<!-- HANDOFF_START -->\n(.*?)\n<!-- HANDOFF_END -->', content, re.DOTALL)
print(match.group(1) if match else '')
" 2>/dev/null || echo "")

    if [ -n "$HANDOFF_CONTENT" ]; then
        # Extract chain metadata from handoff content
        CHAIN_ID=$(echo "$HANDOFF_CONTENT" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'\*\*Chain ID:\*\*\s*(.+)', content)
print(match.group(1).strip() if match else 'unknown-chain')
" 2>/dev/null || echo "unknown-chain")

        # Sanitize chain ID — alphanumeric, hyphens, underscores only
        CHAIN_ID=$(echo "$CHAIN_ID" | python3 -c "
import sys, re
raw = sys.stdin.read().strip()
safe = re.sub(r'[^a-zA-Z0-9_-]', '-', raw)
print(safe if safe else 'unknown-chain')
" 2>/dev/null || echo "unknown-chain")

        SEQ=$(echo "$HANDOFF_CONTENT" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'\*\*Sequence:\*\*\s*(\d+)', content)
print(match.group(1).strip() if match else '1')
" 2>/dev/null || echo "1")

        # Pad sequence number to 3 digits
        SEQ_PADDED=$(printf '%03d' "$SEQ")

        # Create chain folder
        CHAIN_DIR=".claude/chains/${CHAIN_ID}"
        mkdir -p "$CHAIN_DIR"

        # Write handoff file
        HANDOFF_FILE="${CHAIN_DIR}/HANDOFF_${CHAIN_ID}_seq${SEQ_PADDED}.md"
        LOCK_FILE="${HANDOFF_FILE}.lock"
        TEMP_FILE="${HANDOFF_FILE}.tmp"
        (
            flock -x 200
            echo "$HANDOFF_CONTENT" > "$TEMP_FILE"
            mv "$TEMP_FILE" "$HANDOFF_FILE"
        ) 200>"$LOCK_FILE"
        rm -f "$LOCK_FILE"

        # ── CHAIN_INDEX.md update ────────────────────────────────────────────
        INDEX_FILE="${CHAIN_DIR}/CHAIN_INDEX.md"
        TODAY=$(date '+%Y-%m-%d')

        # Extract summary fields for index row
        KEY_WORK=$(echo "$HANDOFF_CONTENT" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'## What Was Worked On This Session\n(.+?)(\n##|\Z)', content, re.DOTALL)
if not match:
    match = re.search(r'## What Was Being Worked On\n(.+?)(\n##|\Z)', content, re.DOTALL)
if match:
    text = match.group(1).strip().split('\n')[0][:60]
    print(text)
else:
    print('—')
" 2>/dev/null || echo "—")

        DECISION_COUNT=$(echo "$HANDOFF_CONTENT" | python3 -c "
import sys, re
content = sys.stdin.read()
rows = re.findall(r'^\| [^|]+\| [^|]+\| seq', content, re.MULTILINE)
print(len(rows))
" 2>/dev/null || echo "0")

        DEAD_END_COUNT=$(echo "$HANDOFF_CONTENT" | python3 -c "
import sys, re
content = sys.stdin.read()
rows = re.findall(r'^\| [^|]+\| [^|]+\| [^|]+\| seq', content, re.MULTILINE)
print(len(rows))
" 2>/dev/null || echo "0")

        TOKEN_PCT=$(echo "$HANDOFF_CONTENT" | python3 -c "
import sys, re
content = sys.stdin.read()
match = re.search(r'Session Handoff.*?(\d+)%', content)
print(match.group(1) + '%' if match else '—')
" 2>/dev/null || echo "—")

        if [ ! -f "$INDEX_FILE" ]; then
            # Create new CHAIN_INDEX.md
            PROJECT_NAME=$(echo "$CHAIN_ID" | sed 's/-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$//' | tr '-' ' ')
            cat > "$INDEX_FILE" << INDEXEOF
# Chain Index — ${CHAIN_ID}
**Project:** ${PROJECT_NAME}
**Started:** ${TODAY}
**Last Updated:** ${TODAY}

## Sessions

| Seq | Date | Token % | Key Work | Decisions | Dead Ends |
|---|---|---|---|---|---|
| ${SEQ_PADDED} | ${TODAY} | ${TOKEN_PCT} | ${KEY_WORK} | ${DECISION_COUNT} | ${DEAD_END_COUNT} |

## Cumulative Decision Count: ${DECISION_COUNT}
## Cumulative Dead End Count: ${DEAD_END_COUNT}
## Latest Handoff: HANDOFF_${CHAIN_ID}_seq${SEQ_PADDED}.md
INDEXEOF
        else
            # Append row to existing CHAIN_INDEX.md
            LOCK_INDEX="${INDEX_FILE}.lock"
            (
                flock -x 200
                # Update Last Updated date
                sed -i "s/^\*\*Last Updated:\*\*.*/\*\*Last Updated:\*\* ${TODAY}/" "$INDEX_FILE"
                # Append session row before the cumulative count line
                sed -i "/^## Cumulative Decision Count/i | ${SEQ_PADDED} | ${TODAY} | ${TOKEN_PCT} | ${KEY_WORK} | ${DECISION_COUNT} | ${DEAD_END_COUNT} |" "$INDEX_FILE"
                # Update cumulative counts and latest handoff
                TOTAL_DECISIONS=$(grep -c "^| [0-9]" "$INDEX_FILE" || echo "0")
                sed -i "s/^## Cumulative Decision Count:.*/## Cumulative Decision Count: ${TOTAL_DECISIONS}/" "$INDEX_FILE"
                sed -i "s/^## Cumulative Dead End Count:.*/## Cumulative Dead End Count: ${DEAD_END_COUNT}/" "$INDEX_FILE"
                sed -i "s/^## Latest Handoff:.*/## Latest Handoff: HANDOFF_${CHAIN_ID}_seq${SEQ_PADDED}.md/" "$INDEX_FILE"
            ) 200>"$LOCK_INDEX"
            rm -f "$LOCK_INDEX"
        fi
    fi
fi

exit 0
