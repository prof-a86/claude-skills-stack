---
name: artifact-version-control
description: >
  Use this skill whenever files are being updated across multiple rounds in a session,
  when the user asks to "pull the latest," "get the clean version," "update this,"
  or references a specific version of a file (v1, v2, FINAL, etc.). Also triggers when
  multiple versions of the same document exist in outputs (e.g. memo_v1.docx, memo_v2.docx),
  when the user says "that was the wrong version," or when a session involves iterative
  edits to docx, pptx, jsx, pdf, md, or code files. Activate automatically on any session
  where the same file will be touched more than once.
---

# Artifact Version Control

Enforces consistent versioning across all file outputs in a session. Prevents version
confusion, audit-clean state loss, and the "which one is the latest?" problem.

---

## Session Open

**Run before any file operation in the session.**

If the session was started from a pasted HANDOFF.md:
- Check for a Version State section in the handoff
- If present — restore it as the active Version Registry immediately
- Confirm to the user: *"Restored version registry from handoff — [list files and versions]. Continuing from there."*
- Do not reinitialize — never overwrite restored registry state with fresh v1.0 entries

If no handoff was pasted — before creating the first file, check if any versioned file already exists in `/mnt/user-data/outputs/` matching the project name:
- If versioned file found (e.g. `Madoff_Memo_v2.1_FINAL.docx`) — read the highest existing version and initialize the registry from that, not from v1.0
- Confirm: *"Found existing version [X.X] for [file] — picking up from there."*
- If no existing file found — initialize a fresh registry when the first file is created

---

## Versioning Standard

Use semantic versioning adapted for documents:

| Change Type | Version Bump | Example |
|---|---|---|
| Minor wording, formatting, small fix | Patch: x.x.y → x.x.y+1 | v1.0 → v1.0.1 → v1.0.2 |
| Section rewrite, new content, structural change | Minor: x.y → x.y+1 | v1.0 → v1.1 |
| Full overhaul, format change, scope change | Major: x.0 → x+1.0 | v1.2 → v2.0 |

**Status flags** (append to filename):
- `_DRAFT` — working version, not ready for submission
- `_REVIEW` — ready for review, not yet confirmed clean
- `_FINAL` — confirmed clean, submission-ready

**Full filename format:** `[ProjectName]_v[X.X]_[STATUS].ext`
Examples: `Madoff_Memo_v1.0_DRAFT.docx`, `Madoff_Memo_v1.0.1_DRAFT.docx`, `Madoff_Memo_v2.1_FINAL.docx`

---

## Declaration-First Rule

**Claude never decides the version bump alone.** Before writing any updated file, Claude must state:

*"This looks like a [patch / minor / major] change — bumping from [current] to [proposed]. Does that match what you intended?"*

Wait for confirmation before saving the new version. If the user disagrees, apply the bump they specify — no debate.

**Why this rule exists:** "Fix this" and "overhaul this" are both vague. Without declaration, Claude guesses the bump category and version drift becomes invisible. The user should always know what version they're on and why.

---

## Session Rules

### On First File Creation
- **Only applies if Session Open found no existing version for this file.** If Session Open already initialized the registry for this file from a handoff or existing output, skip this step — do not overwrite with v1.0
- If no prior version exists — assign v1.0 automatically
- Set status to `_DRAFT` unless the user says it's final
- Log the file in the Session Version Registry

### On Every Update
1. Read the current file state before touching it
2. Determine change type (patch / minor / major — see table above)
3. Bump the version accordingly
4. Update the status flag if the user confirms clean
5. Save as a new file — never overwrite the previous version
6. Update the Session Version Registry

### On "Pull the Latest" or "Get the Clean Version"
- Check the Session Version Registry
- Return the highest version with `_FINAL` status
- If no FINAL exists, return the highest version with `_REVIEW`
- If only DRAFT exists, return it and say so: *"Latest is still DRAFT — no confirmed clean version yet."*

### Never Overwrite
Old versions stay in `/mnt/user-data/outputs/`. New version gets a new filename.
If storage is a concern, ask before deleting any prior version.

---

## Session Version Registry

Maintain this block in working memory throughout the session. Update after every file operation.

```
## Version Registry — [Session Date]

| File | Current Version | Status | Path |
|---|---|---|---|
| [filename] | v[X.X] | DRAFT/REVIEW/FINAL | /mnt/user-data/outputs/[full filename] |
```

Surface the registry when:
- User asks "what versions do I have"
- User asks to pull the latest
- A handoff file is being created
- More than 3 versions of the same file exist

### Registry Self-Check

Before creating or updating any versioned file, confirm the registry state is current. If Claude cannot recall the current version of a file — do not guess. Stop and:

1. If `bash_tool` is available — run it to list `/mnt/user-data/outputs/` and identify the highest existing version
2. If `bash_tool` is not available — ask the user directly: *"I've lost track of the version registry — what's the latest version of [file]?"*

Never proceed with a version bump until current version is confirmed by one of the two methods above.

---

## Status Promotion Rules

| Transition | Trigger |
|---|---|
| DRAFT → REVIEW | User says "looks good," "that's right," "ready to check," "bet," "aight," "yep," "that works," "solid," or any single-word positive affirmative after a DRAFT delivery |
| REVIEW → FINAL | User says "done," "submit this," "that's the one," "audit clean," "final," "ship it," "lock it" |
| FINAL → DRAFT | User requests changes after marking final — bump version per declaration-first rule, reset to DRAFT |

**Casual affirmative rule:** A single-word positive response immediately after a DRAFT delivery is treated as a DRAFT → REVIEW signal. Confirm before promoting: *"Marking as REVIEW — [filename]. Say 'final' or 'ship it' when you're ready to lock it."*

When promoting to FINAL, confirm explicitly:
*"Marking [filename] as FINAL — v[X.X]_FINAL. Nothing further will be written to this version unless you request changes."*

---

## Multi-File Sessions

When multiple distinct documents exist in the same session (e.g. four fraud memos):
- Each document has its own version track — they don't share version numbers
- The registry tracks all of them
- "Pull all latest" returns the highest FINAL (or highest REVIEW if no FINAL) for each document

---

## Handoff Integration

When `task-auditor` or `agentic-session-manager` fires a handoff, append the Version Registry to the handoff file automatically. The new session should know exactly which versions exist and which are clean before doing anything.

## MCP Awareness

If `mcp-router` is active, version control gains two capabilities:

**GitHub sync (on FINAL):**
When a file is promoted to `_FINAL` status, offer to push it to GitHub via `mcp-router`:
*"[filename] is marked FINAL — want me to push it to [repo]?"*
Do not push automatically. Always gate through `mcp-router` declaration-first protocol.
If `mcp-router` is not installed — skip this offer. Present the file locally only.

**Drive sync (on FINAL):**
When a file is promoted to `_FINAL` status, offer to save it to Drive via `mcp-router`:
*"[filename] is marked FINAL — want me to save it to Drive?"*
Do not sync automatically.
If `mcp-router` is not installed — skip this offer. Present the file locally only.

**Session open with GitHub:**
If a project repo is connected via `mcp-router`, check GitHub for existing versioned files matching the project name during Session Open — prefer this over local `/mnt/user-data/outputs/` scan when both are available.
If `mcp-router` is not installed — scan `/mnt/user-data/outputs/` directly using `bash_tool`.

Do not call MCP servers directly — always route through `mcp-router`.

## Cross-Skill Sequence

When `document-production-standard` is also active, the operation order on every file delivery is:

```
1. artifact-version-control: declare bump → wait for confirmation → save new version
2. document-production-standard: run pre-delivery checklist
3. present_files
```

Neither skill calls `present_files` until both steps above are complete. If `document-production-standard` is not installed, go directly from step 1 to step 3.

### If `present_files` Fails

If `present_files` errors after a file has been saved and versioned:
1. Do not increment the version again — the file exists at the declared version
2. Flag to the user: *"The file was saved at [version] but the download link failed — try presenting it again or check `/mnt/user-data/outputs/[filename]`."*
3. Mark the registry entry as ⚠️ UNCONFIRMED — version saved but delivery not confirmed
4. On next successful `present_files` — update registry entry to the correct status (DRAFT/REVIEW/FINAL)

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Initial build | Semantic versioning + status flags for iterative document sessions |
| v1.0.1 | Declaration-first rule + patch chaining fix | Version bump was subjective without user confirmation; patch chain example was incomplete (x.x.1 → x.x.2 not shown) |
| v1.1 | Deep dive fixes | Session open restore from handoff added — registry no longer reinitializes from scratch on continuation sessions; cross-skill delivery sequence defined explicitly with document-production-standard |
| v1.2 | Deep dive fixes round 2 | Existing file detection on first operation; registry self-check added; status promotion trigger language expanded |
| v1.3 | Deep dive fixes round 3 | On First File Creation guarded against session open conflict; bash_tool fallback added; present_files failure handling added |
| v1.4 | MCP awareness added | GitHub push and Drive sync offered on FINAL promotion via mcp-router; GitHub repo scan added to Session Open when mcp-router is active; all MCP calls route through mcp-router, never direct |
