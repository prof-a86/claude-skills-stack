# PROJECT_STATE_SCHEMA.md
**Version:** v1.2
**Used by:** agentic-session-manager at session open
**Purpose:** Defines the minimum state a session manager needs to govern a multi-session agentic project

---

## What This Schema Is — And What It Isn't

`PROJECT_STATE.md` is a **session continuity file**, not a project blueprint.

It answers one question: *"What does Claude need to know to pick up this project cleanly without reconstructing state from memory?"*

It does not define how a project should be built, what architecture to use, or what components to create. Those are builder concerns. This schema is a governor concern — it captures the current state of what exists so the next session doesn't start blind.

---

## Why Each Field Exists

Every field was derived from a real session management failure mode:

| Field | Failure Mode |
|---|---|
| Component Status | Claude assumed a component was built when it wasn't |
| Deployment State | Claude used stale access codes or the wrong environment |
| Sensitive File Notes | Claude tried to read files that couldn't be shared |
| Open Decisions | Claude re-asked questions already answered in prior sessions |
| Known Issues | Claude assumed bugs were resolved when they weren't |
| Continuity Rules | Claude re-confirmed established facts — wasted tokens and context |

---

## Empirical Grounding — How This Schema Was Derived

This schema was not designed from theory. Every field maps to a specific observed failure mode from production multi-session agentic work. The failure modes below were catalogued across real sessions and used to define what the schema must capture.

### Failure Mode 1 — Acting on Components That Don't Exist

**What happened:** Claude reconstructed project state from memory across sessions and treated a pipeline stage as built when it wasn't — because a prior session had discussed its design in detail. Claude referenced the stage's behavior, attempted to wire it to other stages, and produced code that assumed its existence.

**Root cause:** Memory of a *planned* component is indistinguishable from memory of a *built* component without an explicit status field.

**Field this created:** `Component Status` with ✅/🔵/❌/⚠️ values. ❌ explicitly means "do not assume this exists" — not "unknown" but "confirmed absent."

---

### Failure Mode 2 — Stale Deployment State

**What happened:** Claude carried deployment configuration from memory — platform, environment, start command, access codes — across multiple sessions. When the deployment changed between sessions (environment switched from mock to live, access codes rotated), Claude acted on the stale values without flagging the discrepancy.

**Root cause:** Deployment state lives in session memory with no staleness signal. There's no way to distinguish "I remember this from last session" from "I confirmed this this session."

**Field this created:** `Deployment State` as a required section with an explicit warning: *"Never reconstruct credentials from memory — use only what's listed here."* This moves deployment state from implicit memory to explicit file, making staleness visible via the Last Updated date.

---

### Failure Mode 3 — Sensitive File Requests

**What happened:** Claude, attempting to follow the read-before-touching protocol, requested files that contained sensitive information — API keys, environment variables, private configuration. The user had to repeatedly decline and explain why the files couldn't be shared, consuming tokens and interrupting flow.

**Root cause:** No persistent signal that specific files are off-limits. Every session, Claude rediscovered the constraint the hard way.

**Field this created:** `Sensitive?` column in Key Files table. Yes means Claude will not request the full file — minimum paste excerpt protocol activates automatically.

---

### Failure Mode 4 — Re-asking Resolved Questions

**What happened:** Decisions made in prior sessions — build order, architecture choices, design tradeoffs — were re-raised in subsequent sessions because Claude had no reliable way to know they'd been resolved. The user had to re-answer questions already answered, sometimes multiple sessions in a row.

**Root cause:** Resolved decisions exist only in session memory. Memory is unreliable across sessions and gives no signal about whether a decision was made or is still open.

**Field this created:** `Open Decisions` table with explicit ✅ Resolved / ❓ Open status. Resolved decisions carry their outcome so Claude never re-raises them. Open decisions are surfaced proactively so the human knows what's still pending.

---

### Failure Mode 5 — Bug Status Confusion

**What happened:** A known bug was referenced as resolved in one session because Claude remembered a fix being discussed. In a subsequent session, Claude proceeded as though the bug was gone — until the behavior reappeared. The session then had to re-diagnose something already diagnosed.

**Root cause:** Bug resolution exists in session memory with no persistent record. Memory of "we talked about fixing this" is indistinguishable from "we confirmed this was fixed."

**Field this created:** `Known Issues` table with ✅ Resolved / ⚠️ Open status. Only ✅ means the issue is gone — ⚠️ means it's active and Claude should not assume normal behavior in the affected area.

---

### Failure Mode 6 — Token Waste on Re-confirmation

**What happened:** At the start of sessions, Claude would spend multiple exchanges re-confirming facts already established — project name, which LMS was in use, what the pipeline modes were, which files were sensitive. Each confirmation consumed tokens and delayed actual work.

**Root cause:** Without a confirmed state baseline, every session starts from zero. Claude asks to be safe; the human answers; tokens burn before any work happens.

**Field this created:** `Session Continuity Rules` — an explicit instruction set telling the session manager how to interpret the file. Rule 1: treat ✅ fields as confirmed, do not re-ask. This converts the file from reference material into a behavioral directive.

---

### The Confidence Tag System

The ✅ / 🔵 / ❓ tagging system used throughout the schema was derived from a specific observed gap: memory-sourced facts and session-confirmed facts look identical to the session manager without an explicit label.

- ✅ means "confirmed this session — act on this"
- 🔵 means "from memory — verify before acting"  
- ❓ means "unknown — ask before acting"

This three-state model prevents the most common failure pattern: treating memory as authoritative. In sensitive-file projects especially, acting on 🔵 memory as if it were ✅ confirmed caused real downstream errors — wrong environment, wrong file path, wrong stage status.

---

## Schema — Required Fields

### File Header

```markdown
# PROJECT_STATE.md — [Project Name]
**Last Updated:** [YYYY-MM-DD]
**Maintained by:** [Who updates this file]
**Read by:** agentic-session-manager at session open
```

---

### 1. Project Identity

Minimum context for the session manager to orient itself.

```markdown
## Project Identity

| Field | Value |
|---|---|
| Project Name | [Name] |
| Type | [e.g. web app, API service, data pipeline, AI agent] |
| Status | [Active development / Maintenance / Production / Paused] |
```

**Keep this short.** The session manager doesn't need a product brief — it needs enough to confirm it's working on the right project.

---

### 2. Component Status

The most critical section. Defines what exists and what doesn't so Claude never acts on a component that isn't built.

```markdown
## Component Status

| Component | Status | Notes |
|---|---|---|
| [Name] | ✅ Built | [Optional notes] |
| [Name] | 🔵 Built — verify | [May have changed since last session] |
| [Name] | ❌ Not built | [Do not assume this exists] |
| [Name] | ⚠️ Broken | [See Known Issues] |
```

**Status values:**
- ✅ Built and confirmed working — Claude can act on this
- 🔵 Built but potentially stale — verify before acting
- ❌ Not built — Claude must not assume this exists or reference it as working
- ⚠️ Known issue active — see Known Issues section before touching

**Key Files** (subset of Component Status — files specifically):

```markdown
### Key Files

| File | Purpose | Status | Sensitive? |
|---|---|---|---|
| [filename] | [what it does] | ✅/🔵/❌ | Yes / No |
```

If Sensitive: Yes — Claude will not request the full file. Minimum paste excerpt only.

---

### 3. Deployment State

Required even if the answer is "not deployed." Prevents Claude from guessing.

```markdown
## Deployment State

| Field | Value |
|---|---|
| Platform | [Railway / Vercel / local / none] |
| Environment | [Production / Staging / Mock / Development / N/A] |
| Live URL | [URL or N/A] |
| Start command | [command or N/A] |
| Access codes / key names | [names only — never actual values] |

> ⚠️ Never reconstruct credentials from memory. Use only what's listed here.
> ⚠️ Never put actual credential values in this file. Names only (e.g. "JJC_API_KEY" not the actual key). If actual values are present, agentic-session-manager will flag and refuse to use them.
```

---

### 4. Open Decisions

Prevents Claude from re-asking resolved questions or making decisions that belong to the human.

```markdown
## Open Decisions

| Decision | Status | Owner |
|---|---|---|
| [What needs to be decided] | ❓ Open | [Who decides] |
| [What needs to be decided] | ✅ Resolved — [outcome] | [Who decided] |
```

---

### 5. Known Issues

Prevents Claude from treating broken things as working or resolved things as still broken.

```markdown
## Known Issues

| Issue | Status |
|---|---|
| [Description] | ✅ Resolved / ⚠️ Open |
```

---

### 6. Session Continuity Rules

How the session manager should interpret this file. Customize per project — defaults below are the recommended baseline.

```markdown
## Session Continuity Rules

1. Treat all ✅ fields as confirmed — do not re-ask
2. Treat all 🔵 fields as potentially stale — verify before acting
3. Treat all ❌ fields as not built — do not assume they exist
4. Never reconstruct credentials from memory — use Deployment State only
5. Sensitive files cannot be read — ask for minimum paste excerpt only
6. Update this file at the end of any session where status changes
```

---

### 7. Changelog

```markdown
## Changelog

| Date | Change |
|---|---|
| [YYYY-MM-DD] | [What changed] |
```

---

## What This Schema Does Not Cover

These are builder concerns — they belong in a project scaffolding tool, not a session manager:

- How the project should be architected
- What components to build next
- Research or data collection state
- External service integration setup
- Version control strategy

If you need those, that's a different tool. This schema is only about what the session manager needs to govern continuity.

---

## How agentic-session-manager Uses This File

### At Session Open
1. Check if `PROJECT_STATE.md` is present in context
2. If present — read it, tag ✅/🔵/❌ fields accordingly, skip memory reconstruction for covered fields
3. Surface state: *"Read PROJECT_STATE.md — does anything need updating since [Last Updated]?"*
4. If absent — fall back to memory reconstruction, offer to create the file at session close

### During Session
- Note any status changes as they happen
- Flag when a decision gets resolved

### At Session Close
Offer to update `PROJECT_STATE.md` with any changes from this session. This is how the file stays current without requiring manual maintenance after every exchange.

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Initial release | Derived from multi-session agentic project failure modes |
| v1.1 | Scoped to session management only | Removed builder concerns — schema now answers exactly one question: what does the session manager need to govern continuity |
| v1.2 | Empirical grounding section added | Six failure modes documented with full context, root cause, and field mapping; confidence tag system rationale added — makes research basis explicit for each schema decision |
