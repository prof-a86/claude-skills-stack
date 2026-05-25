# Hooks

Claude Code hooks are shell scripts that fire automatically on session events — before a response, after a tool call, on session end. Unlike skills (which Claude decides to trigger), hooks fire deterministically regardless of what Claude does.

This folder contains hooks that extend the Claude Skills Stack for Claude Code environments. They are **not required** — the stack works without them on Claude.ai. But on Claude Code, hooks make session degradation monitoring proactive rather than reactive.

---

## How Hooks Work in Claude Code

Hooks are configured in your Claude Code settings (`.claude/settings.json`) and map to lifecycle events:

| Event | When It Fires |
|---|---|
| `PreToolUse` | Before any tool call |
| `PostToolUse` | After any tool call |
| `Notification` | When Claude sends a notification |
| `Stop` | When Claude finishes a response |

Each hook is a shell script that receives context via stdin (JSON) and can output instructions back to Claude via stdout.

---

## Hooks in This Stack

| Hook | File | Fires On | Purpose |
|---|---|---|---|
| Degradation Monitor | `degradation-monitor.sh` | `Stop` (every response) | Checks token usage — suggests `/compact` in yellow zone, triggers handoff in red zone |
| Compact Tracker | `compact-tracker.sh` | `Notification` | Records when `/compact` is run so the monitor knows the ladder position |
| Session Close | `session-close.sh` | `Stop` (on handoff/checkpoint) | Detects PROJECT_STATE.md update blocks in Claude's output and writes them to disk automatically |

### The Degradation Ladder

```
🟢 GREEN  (0-30%)   → work normally
🟡 YELLOW (30-50%)  → suggest /compact to extend session
🔴 RED    (50%+)    → if /compact not run: offer /compact as last resort
                    → if /compact already run: handoff mandatory, no exceptions
```

### Auto PROJECT_STATE.md Updates

`session-close.sh` listens for a structured update block in Claude's output at session close. When `agentic-session-manager` detects a voluntary close and a PROJECT_STATE.md exists, it outputs the updated file content wrapped in delimiters. The hook extracts the content and overwrites the file in place — atomic write via temp file and `flock` to prevent corruption.

**Path resolution (default with override):**
- Default: `./PROJECT_STATE.md` in the Claude Code working directory
- Override: set `CLAUDE_PROJECT_STATE_PATH` in your environment or `settings.json` env block

**The hook never creates PROJECT_STATE.md from scratch.** If the file doesn't exist, it exits cleanly and Claude offers to create it.

**On Claude.ai:** The update block still appears in Claude's output — copy the content between the delimiters and paste it into your PROJECT_STATE.md manually.

---

## Installation

### 1. Copy hooks to your project

```bash
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

### 2. Register in Claude Code settings

Copy `hooks/settings.example.json` to `.claude/settings.json`, or merge the hooks block into your existing settings file. The `env` block is optional — only needed if your PROJECT_STATE.md lives outside the working directory:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/degradation-monitor.sh" },
          { "type": "command", "command": ".claude/hooks/session-close.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": ".claude/hooks/compact-tracker.sh" }]
      }
    ]
  },
  "env": {
    "CLAUDE_PROJECT_STATE_PATH": ""
  }
}
```

Leave `CLAUDE_PROJECT_STATE_PATH` empty to use the default (`./PROJECT_STATE.md`). Set it to a directory path to override — e.g. `"/Users/you/projects/my-agent"`.

### 3. Verify

Start a session and watch for degradation warnings after responses. At session close, if you have a PROJECT_STATE.md, Claude will output an update block and the hook will write it to disk automatically.

---

## Relationship to Skills

Hooks and skills are complementary, not redundant:

- **Skills** (task-auditor Layer 3) define the degradation standard, zone model, and handoff protocol — the *what* and *why*
- **Hooks** enforce the monitoring automatically — the *when* and *how*

The hook reads the same zone thresholds defined in `task-auditor` Layer 3. If you change the thresholds in the skill, update the hook to match.

---

## Claude.ai Users

Hooks are Claude Code only. On Claude.ai, `task-auditor` Layer 3 governs degradation through skill instructions — Claude self-monitors based on the degradation standard. No hook setup needed. Running the hook scripts manually outside Claude Code will exit cleanly due to `set -euo pipefail` but produce no useful output.

---

## Known Behaviors

**Concurrent Stop events:** If Claude Code fires two `Stop` events in rapid succession (parallel tool calls), both instances of `degradation-monitor.sh` may run simultaneously. The `COMPACT_FLAG` temp file is session-scoped and `touch` is atomic on standard filesystems — concurrent writes are safe. In the rare case of a race on the flag read, the worst outcome is one extra `/compact` suggestion before the flag is detected. Not harmful.

**Hook errors surface to Claude:** If either hook exits non-zero, Claude Code may surface the error message. Both hooks use `set -euo pipefail` and validate all inputs with numeric checks and string sanitization — the most common failure causes (empty JSON, non-numeric token percentage, malformed session ID) are handled gracefully with safe defaults.
