---
name: artifact-version-control
description: >
  Use this skill whenever files are being updated across multiple rounds in a session,
  when the user asks to "pull the latest," "get the clean version," "update this,"
  or references a specific version of a file (v1, v2, FINAL, etc.). Also triggers when
  multiple versions of the same document exist in outputs, when the user says "that was
  the wrong version," or when a session involves iterative edits to docx, pptx, jsx,
  pdf, md, or code files. Activate automatically on any session where the same file
  will be touched more than once.
---

# Artifact Version Control (Standalone)

Enforces consistent versioning across all file outputs. Prevents version confusion,
audit-clean state loss, and the "which one is the latest?" problem.

---

## Session Open

**Run before any file operation in the session.**

**If a HANDOFF.md or checkpoint file was pasted:**
- Check for a Version State section
- If present — restore it as the active Version Registry immediately
- Confirm: *"Restored version registry from handoff — [list files and versions]. Continuing from there."*
- Never overwrite restored registry state with fresh v1.0 entries

**If no handoff was pasted:**
- Before creating the first file, check if any versioned file exists in `/mnt/user-data/outputs/` matching the project name
- If found (e.g. `Project_v2.1_FINAL.docx`) — read the highest existing version, initialize registry from that
- Confirm: *"Found existing version [X.X] for [file] — picking up from there."*
- If no existing file found — initialize a fresh registry on first file creation

---

## Versioning Standard

| Change Type | Version Bump | Example |
|---|---|---|
| Minor wording, formatting, small fix | Patch: x.x.y → x.x.y+1 | v1.0 → v1.0.1 → v1.0.2 |
| Section rewrite, new content, structural change | Minor: x.y → x.y+1 | v1.0 → v1.1 |
| Full overhaul, format change, scope change | Major: x.0 → x+1.0 | v1.2 → v2.0 |

**Status flags:**
- `_DRAFT` — working version, not ready for submission
- `_REVIEW` — ready for review, not yet confirmed clean
- `_FINAL` — confirmed clean, submission-ready

**Filename format:** `[ProjectName]_v[X.X]_[STATUS].ext`
Examples: `Report_v1.0_DRAFT.docx`, `Report_v1.0.1_DRAFT.docx`, `Report_v2.1_FINAL.docx`

---

## Declaration-First Rule

**Claude never decides the version bump alone.** Before writing any updated file:

*"This looks like a [patch / minor / major] change — bumping from [current] to [proposed]. Does that match what you intended?"*

Wait for confirmation. Apply whatever the user specifies — no debate.

**Why:** "Fix this" and "overhaul this" are both vague. Without declaration, Claude guesses and version drift becomes invisible.

---

## Session Rules

### On First File Creation
- **Only if Session Open found no existing version for this file** — assign v1.0 automatically
- If Session Open already initialized the registry for this file, skip — do not overwrite with v1.0
- Set status to `_DRAFT` unless the user says it's final
- Log in the Session Version Registry

### On Every Update
1. Read the current file state before touching it
2. Declare the bump — wait for confirmation
3. Bump version, update status flag if user confirms clean
4. Save as a new file — never overwrite
5. Update the Session Version Registry

### On "Pull the Latest" or "Get the Clean Version"
- Return highest version with `_FINAL` status
- If no FINAL → return highest `_REVIEW`
- If only DRAFT → return it and say: *"Latest is still DRAFT — no confirmed clean version yet."*

### Never Overwrite
Old versions stay in `/mnt/user-data/outputs/`. New version gets a new filename.

---

## Session Version Registry

Maintain in working memory throughout the session. Update after every file operation.

```
## Version Registry — [Session Date]

| File | Current Version | Status | Path |
|---|---|---|---|
| [filename] | v[X.X] | DRAFT/REVIEW/FINAL | /mnt/user-data/outputs/[full filename] |
```

Surface when: user asks what versions exist, user asks to pull latest, handoff fires, more than 3 versions of the same file exist.

### Registry Self-Check

Before creating or updating any versioned file — confirm the registry state is current. If unable to recall current version:
1. If `bash_tool` is available — list `/mnt/user-data/outputs/` and identify highest existing version
2. If `bash_tool` is not available — ask: *"What's the latest version of [file]?"*

Never proceed with a version bump until current version is confirmed.

---

## Status Promotion Rules

| Transition | Trigger |
|---|---|
| DRAFT → REVIEW | "looks good," "that's right," "ready to check," "bet," "aight," "yep," "solid," or any single-word positive after a DRAFT delivery |
| REVIEW → FINAL | "done," "submit this," "that's the one," "final," "ship it," "lock it" |
| FINAL → DRAFT | User requests changes — declare bump per declaration-first rule, reset to DRAFT |

**Casual affirmative rule:** Single-word positive after DRAFT delivery → confirm before promoting: *"Marking as REVIEW. Say 'ship it' when ready to lock."*

Confirm FINAL explicitly: *"Marking as FINAL — v[X.X]_FINAL. Nothing further written to this version unless you request changes."*

---

## Multi-File Sessions

Each document has its own version track — they don't share version numbers. "Pull all latest" returns highest FINAL (or REVIEW) for each document independently.

---

## Handoff Integration

When a handoff fires, append the Version Registry to the handoff file before presenting. The new session must know which versions are clean before doing anything.

### Delivery Sequence

On every file delivery:
```
1. Declare bump → wait for confirmation → save new version
2. Run pre-delivery quality check (font, format, checklist if applicable)
3. present_files
```

### If `present_files` Fails

1. Do not increment version again — file exists at declared version
2. Flag: *"File saved at [version] but download link failed — check `/mnt/user-data/outputs/[filename]`."*
3. Mark registry entry as ⚠️ UNCONFIRMED
4. On next successful delivery — update registry to correct status

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Standalone release | Self-sufficient version — delivery sequence inlined, no external skill dependencies, all rules self-contained |
