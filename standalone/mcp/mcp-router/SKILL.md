---
name: mcp-router
description: >
  Use this skill at session start whenever any MCP server may be connected, or when the user
  asks to push files, commit code, open a PR, create an issue, send an email, save to Drive,
  check a calendar, or interact with any external service. Triggers on: "push this to GitHub,"
  "open a PR," "save this to Drive," "send this," "check my calendar," "create an issue,"
  "what MCP servers do I have," or any task where Claude would benefit from reaching an
  external system. Governs all MCP interactions — no other skill should call MCP servers directly.
---

# MCP Router (Standalone)

Central MCP governance layer. All MCP interactions route through this skill.
Keeps tool use auditable, prevents redundant calls, and enforces declaration-first
on all destructive operations.

---

## STEP 1 — Session Open (Run Once)

Discover what MCP servers are connected and build the Session MCP Registry.

### Platform Detection

**Claude.ai:** MCP servers are connected apps. Discovery is contextual — build registry
from what appears in context, or ask: *"Which MCP servers do you have connected?"*

**Claude Code:** Run discovery programmatically:
```bash
claude mcp list
```
Parse output to build registry. Do not ask the user.

### Session MCP Registry

```
## MCP Registry — [Session Date]

| Server | Type | Status | Last Called | Calls This Session |
|---|---|---|---|---|
| github | read+write | ✅ Connected | — | 0 |
| gmail | read+write | ✅ Connected | — | 0 |
| gdrive | read+write | ✅ Connected | — | 0 |
| gcalendar | read+write | ✅ Connected | — | 0 |
```

**Status values:**
- ✅ Connected
- ❌ Not connected — fall back to manual
- ⚠️ Rate limited — temporarily unavailable
- 🔒 Auth error — re-authentication needed

---

## STEP 2 — Call Classification & Gating

### Read Operations (no gate — execute directly)
Fetch files, list repos/issues/PRs, check status, read email/calendar/Drive, search.

### Write Operations (declaration-first gate — always)
Push commits, open/close PRs, create/close issues, send email, create/modify/delete
calendar events or Drive files.

### Gate Format

*"About to [action] on [target] via [server] — confirm?"*

**Confirmation rules:**
- "yes," "yeah," "go ahead," "do it," "confirm" → proceed
- Silence → do NOT proceed. Ask once more, then abandon
- Response to a different question → do NOT proceed. Re-present gate explicitly
- Ambiguous → *"Just to confirm — you want me to [action]?"*

The gate is per-operation. Prior confirmations do not carry over.

---

## STEP 3 — Cache-First Protocol

Before any MCP call:
1. Check registry — if data was fetched this session and nothing has changed, use cached result (tag 🔵)
2. If cache miss — make the call, log it, tag result ✅
3. If user says "refresh" or "pull latest" — bypass cache, re-fetch, update registry

**Degradation rule:** During high token usage (30%+) — skip non-critical read calls.
Only call MCP when essential to the immediate task.

---

## STEP 4 — GitHub Operations

**Read (no gate):** Fetch files, list repos/issues/PRs, check status, check branches.

**Write (gate always):**

Push / commit:
*"About to commit [files] to [branch] on [repo] — confirm?"*

Open PR:
*"About to open PR '[title]' from [branch] → [target] on [repo] — confirm?"*

Create issue:
*"About to open issue '[title]' on [repo] — confirm?"*

Close PR / issue:
*"About to close [PR/issue] #[number] on [repo] — confirm?"*

**Rate limit handling:** If GitHub returns 429 — mark ⚠️ in registry, tell user,
do not retry automatically.

---

## STEP 5 — Google MCP Operations

### Gmail
- Read (search, fetch, check threads): no gate
- Write (send, reply, draft): gate always
  *"About to send email to [recipient] — subject: '[subject]' — confirm?"*

### Google Drive
- Read (fetch, list, search): no gate
- Write (create, update, move, delete): gate always
  *"About to [action] '[filename]' in [folder] on Drive — confirm?"*

**On FINAL file:** When a file is confirmed final — offer Drive sync:
*"[filename] is marked FINAL — want me to save it to Drive?"* Never automatic.

### Google Calendar
- Read (fetch events, check availability): no gate
- Write (create, update, delete): gate always
  *"About to create '[event]' on [date] at [time] — confirm?"*

---

## STEP 6 — General MCP Server Protocol

For any server not explicitly listed:
1. Classify operation (read vs. write) using STEP 2 rules
2. Check cache (STEP 3)
3. Gate if write (STEP 2)
4. Execute, log in registry, tag result
5. Surface result: *"[Result] — via [server]"*

On failure: update registry status, tell user, fall back to manual. Never silently fail.

---

## STEP 7 — Handoff Integration

When a handoff fires, append MCP state to the handoff file:

```markdown
## MCP State
[MCP Registry table — servers, status, call counts]
[Active rate limits if any]
[Pending gated operations not yet confirmed]
```

New session should restore registry and re-verify connection status before
assuming any server is still available.

---

## Platform Notes

**Claude.ai:** Connected app discovery is contextual. Rate limits per underlying API.
No programmatic server enumeration available.

**Claude Code:** Full tool enumeration via `claude mcp list`. Token usage per call
visible with `claude --verbose`. MCP servers configured via `claude mcp add`.

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Standalone release | Self-sufficient version — all protocols inlined, no external skill dependencies, full GitHub + Google MCP coverage, platform detection for Claude.ai vs Claude Code |
