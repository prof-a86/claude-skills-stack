---
name: mcp-router
description: >
  Use this skill at session start whenever any MCP server may be connected, or when the user
  asks to push files, commit code, open a PR, create an issue, send an email, save to Drive,
  check a calendar, or interact with any external service. Triggers on: "push this to GitHub,"
  "open a PR," "save this to Drive," "send this," "check my calendar," "create an issue,"
  "what MCP servers do I have," or any task where Claude would benefit from reaching an
  external system. Also triggers automatically when agentic-session-manager, artifact-version-control,
  or document-production-standard detect a connected MCP server could improve their output.
  Governs all MCP interactions for the entire skill stack — no other skill calls MCP directly.
---

# MCP Router

Central MCP governance layer for the Claude Skills Stack. All MCP interactions in the
stack route through this skill — no other skill calls an MCP server directly. This keeps
tool use auditable, prevents redundant calls, and enforces declaration-first on destructive operations.

---

## STEP 1 — Session Open (Run Once)

At session start, discover what MCP servers are connected and build the Session MCP Registry.

### Platform Detection

**Claude.ai:** MCP servers appear as connected apps. Available servers are listed in the user's
connected integrations. Claude cannot enumerate them programmatically — surface from context
or ask: *"Which MCP servers do you have connected for this session?"*

**Claude Code:** MCP servers are configured via `claude mcp add`. Run discovery:
```bash
claude mcp list
```
Parse output to build the registry. Do not ask the user — discover programmatically.

### Session MCP Registry

Build and maintain this in working memory. Update after every MCP interaction.

```
## MCP Registry — [Session Date]

| Server | Type | Status | Last Called | Calls This Session |
|---|---|---|---|---|
| github | read+write | ✅ Connected | — | 0 |
| gmail | read+write | ✅ Connected | — | 0 |
| gdrive | read+write | ✅ Connected | — | 0 |
| gcalendar | read+write | ✅ Connected | — | 0 |
| [other] | [type] | ✅/❌ | — | 0 |
```

**Status values:**
- ✅ Connected — available for use
- ❌ Not connected — task requiring this server must fall back to manual
- ⚠️ Rate limited — temporarily unavailable, note reset time if known
- 🔒 Auth error — re-authentication required, flag to user

Surface the registry when:
- User asks what's connected
- A skill needs an MCP server to complete a task
- A call fails — update status immediately

---

## STEP 2 — Call Classification

Before any MCP call, classify it. Classification determines whether a gate fires.

### Read Operations (no gate — execute directly)
- Fetch file contents
- List repo files, issues, PRs
- Check repo status, latest commit, branch state
- Read email, calendar events, Drive files
- Search within a connected service

### Write Operations (declaration-first gate — always)
- Push commits, create/update files in a repo
- Open, update, or close a PR
- Create, update, or close an issue
- Send email
- Create or modify calendar events
- Create, move, or delete Drive files

### Gate Format (write operations)

*"About to [action] on [target] via [server] — confirm?"*

Examples:
- *"About to push `task-auditor/SKILL.md` to `main` on [repo] via GitHub — confirm?"*
- *"About to open a PR: '[title]' → `main` — confirm?"*
- *"About to send email to [recipient] via Gmail — confirm?"*

**Confirmation rules:**
- "yes," "yeah," "go ahead," "do it," "confirm," "approved" → proceed
- Silence → do NOT proceed. Ask once more, then abandon the operation
- Response to a **different question** in the same exchange → do NOT proceed. Re-present the gate explicitly before executing
- Ambiguous response → *"Just to confirm — you want me to [action]?"*

The gate is per-operation. A prior confirmation from earlier in the conversation does not carry over to a new write operation.

**Pending gate rule:** If a gate has been presented and the user sends an unrelated message before confirming, the gate is considered abandoned — not silently approved. The write operation is cancelled. If the user returns to the write operation later, re-present the gate from scratch before executing.

---

## STEP 3 — Cache-First Protocol

Before making any MCP call, check the Session MCP Registry.

**Cache hit:** If the requested data was fetched this session and no significant changes have
occurred since — use the cached result. Tag it 🔵 (from session cache — may have changed).
Do not make a redundant call.

**Cache miss:** Make the call, log it in the registry, tag the result ✅ (confirmed this call).

**Force refresh:** If the user says "check again," "pull latest," "refresh" — bypass cache,
make the call, update registry.

**Degradation zone rule:** During 🟡 YELLOW or 🔴 RED token zones — skip non-critical MCP
read calls entirely. The session is already under pressure; adding more context via MCP calls
accelerates degradation. Only make MCP calls that are essential to complete the immediate task.

---

## STEP 4 — GitHub Operations

Generic. No personal repo hardcoded — always confirm target repo with the user or read from
project context before any operation.

### Read Operations
```
# List repos
# Check repo status, latest commit, open PRs, open issues
# Fetch file contents from a specific path
# Check branch state
```

All read operations: execute directly, log in registry, tag result ✅.

### Write Operations (all require declaration-first gate)

**Push / commit:**
1. State what file(s) are being pushed, to which repo and branch
2. Gate: *"About to commit [files] to [branch] on [repo] — confirm?"*
3. On confirm: execute
4. Log result. If success → note commit hash. If fail → surface error, do not retry automatically.

**Open PR:**
1. State: source branch, target branch, title, body summary
2. Gate: *"About to open PR '[title]' from [branch] → [target] on [repo] — confirm?"*
3. On confirm: execute
4. Surface PR URL on success

**Create issue:**
1. State: title, body summary, labels if any
2. Gate: *"About to open issue '[title]' on [repo] — confirm?"*
3. On confirm: execute
4. Surface issue URL and number on success

**Close PR / issue:**
1. Gate always fires — closing is irreversible without reopening
2. *"About to close [PR/issue] #[number] on [repo] — confirm?"*

### Rate Limit Handling
If GitHub returns 429:
1. Note in registry: ⚠️ Rate limited — resets in [time if known]
2. Tell user: *"GitHub rate limit hit — calls will resume in [time]. Continuing with cached state."*
3. Do not retry automatically. Wait for user to trigger next call after reset.

---

## STEP 5 — Google MCP Operations (Gmail, Drive, Calendar)

### Gmail
**Read:** Fetch emails, search inbox, check threads — no gate.
**Write:** Send email, reply, create draft — gate always.

Gate: *"About to send email to [recipient] — subject: '[subject]' — confirm?"*

### Google Drive
**Read:** Fetch file contents, list folder, search — no gate.
**Write:** Create file, update file, move, delete — gate always.

Gate: *"About to [create/update/delete] '[filename]' in [folder] on Drive — confirm?"*

**Handoff integration:** When `artifact-version-control` marks a file as FINAL, offer to sync
to Drive: *"[filename] is marked FINAL — want me to save it to Drive?"* Do not sync automatically.

### Google Calendar
**Read:** Fetch events, check availability, list upcoming — no gate.
**Write:** Create event, update event, delete event — gate always.

Gate: *"About to create '[event name]' on [date] at [time] — confirm?"*

---

## STEP 6 — General MCP Server Protocol

For any MCP server not explicitly listed above:

1. Identify the server type from the registry
2. Classify the operation (read vs. write) using STEP 2 rules
3. Apply cache-first check (STEP 3)
4. Apply declaration-first gate if write operation (STEP 2)
5. Execute, log in registry, tag result
6. Surface result to user with server name noted: *"[Result] — via [server]"*

If a connected server fails:
1. Update registry status to ❌ or ⚠️
2. Tell user: *"[Server] isn't responding — falling back to [manual method]."*
3. Do not silently fail or silently retry

---

## STEP 7 — Handoff Integration

When `task-auditor` fires a handoff, append the MCP Registry to the handoff file:

```markdown
## MCP State
[Session MCP Registry table — servers, status, call counts, last called]
[Any rate limits active at handoff time]
[Any pending write operations that were gated but not confirmed]
```

The new session should restore the MCP Registry at open and re-verify connection status
before assuming any server is still available.

---

## Platform Notes

### Claude.ai
- MCP servers are connected apps — discovery is contextual, not programmatic
- Rate limits apply per connected app's underlying API
- No `claude mcp list` available — build registry from context or user confirmation

### Claude Code
- MCP servers configured via `claude mcp add [name] [command]`
- Discovery: `claude mcp list`
- Full tool enumeration available — Claude Code can inspect what each server exposes
- Verbose mode shows token usage per tool call: `claude --verbose`

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Initial build | Central MCP governance for the Claude Skills Stack — session registry, cache-first protocol, declaration-first gate for write operations, GitHub + Google MCP protocols, platform detection for Claude.ai vs Claude Code |
| v1.1 | Penetration test patches | Gate abandonment exploit closed — unrelated messages cancel pending write operations, gate must be re-presented from scratch; pending gate tracking added to handoff MCP State section |
