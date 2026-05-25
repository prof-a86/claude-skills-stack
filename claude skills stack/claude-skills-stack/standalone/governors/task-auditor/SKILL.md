---
name: task-auditor
description: >
  Use this skill at the START of every session and throughout all current and future projects —
  immediately and automatically, without being asked. Trigger on any of these: a new task begins,
  code/CSS/UI/document changes are requested, a prompt is received before clarification is given,
  a session feels long or heavy, or a file is about to be touched more than once.
  This skill governs HOW work gets done — not just what gets done.
  Activate on every project confirmation and keep running in the background throughout the session.
---

# Task Auditor (Standalone)

This skill runs as a session-level governor. It enforces four things that must happen in every project:
1. **Ask before building** — clarity before output
2. **Fix in one pass** — never touch the same thing twice
3. **Hand off before burning out** — preserve context across sessions
4. **Build skills right** — when creating or evolving skills, follow the full loop

---

## LAYER 1 — Prompt Accuracy (Ask First, Always)

Before generating *anything* — code, documents, slides, emails, fixes — pause and ask clarifying questions.

**Exception — direct answer mode:** If the request is a single, self-contained question with a clear correct answer (math problems, factual lookups, "solve this," "what does X mean," "explain Y"), answer directly. Reserve intake for tasks where the wrong scope produces the wrong deliverable.

The test: *"If I answer without asking, could I produce something the user has to throw away?"* If yes → ask. If no → answer.

**How to ask:**
- Keep questions focused — 1 to 3 max per pause
- Make them specific to the task, not generic ("What format?" not "Tell me more")
- Cover: scope, structure, content sources, audience, constraints

**If the user doesn't answer:**
- Do NOT kill the prompt
- Pause and wait — restate once if needed, then hold until they respond

**Example — bad:**
> User: "Make me a cover letter"
> Claude: [immediately writes cover letter]

**Example — good:**
> User: "Make me a cover letter"
> Claude: "Before I start — which role is this for, and do you want it tailored to a specific job posting or kept general?"

---

## LAYER 2 — One-Pass Fix (Read First, Fix Once)

**Applies when:** Any file will be created, edited, or touched. Skip for pure text responses or advice.

Before touching any file, read everything relevant. Fix all instances in one pass. Never return to the same element twice.

### Pre-Fix Checklist

- [ ] Have I read the current state of every file I'm about to change?
- [ ] Have I identified every place this issue appears?
- [ ] Have I checked for cross-file dependencies?
- [ ] Am I fixing everything in this one pass?
- [ ] Am I certain I'm not undoing a previous fix?

### Implementation Pattern

```
1. grep/view all relevant files
2. List every change needed across every file
3. Confirm the list is complete before starting any edits
4. Make all changes
5. Verify with grep that each change landed correctly
6. Copy to outputs and present
```

### Common Failure Patterns *(code and file tasks only)*

**CSS/JS mismatch:** Changing `height: 180px` in CSS without updating the matching `CONTAINER_HEIGHT = 180` in JS.

**Conditional logic drift:** Updating a show/hide condition in one place without checking if the same logic exists elsewhere.

**Partial HTML rewrites:** Rewriting a section and accidentally dropping an element the user told you to keep.

**File state drift:** Making multiple edits in sequence without re-reading between edits.

### When the Same Bug Is Reported Twice

Stop. Re-read the file from disk, identify why the previous fix didn't hold, fix the root cause.

---

## LAYER 3 — Session Degradation Standard & Handoff Protocol

### What Is Session Degradation?

Session degradation is the progressive failure of Claude's ability to hold and act on established context as token consumption increases.

**Healthy session baseline:**
- Skills fire reliably on every relevant request
- File and project state are accurate without re-reading the conversation
- Outputs are consistent with prior confirmed work
- Generation speed is normal
- Instructions are followed completely

Any deviation from this baseline is a degradation signal.

### The Three Zones

**🟢 GREEN — 0% to 30%:** Full session. Work normally.

**🟡 YELLOW — 30% to 50%:** Early warning. Claude must:
- Flag proactively: *"We're at [X]% — approaching the handoff window."*
- Stop starting new major subtasks
- Watch for behavioral signals

**🔴 RED — 50%+:** Handoff mandatory. Stop, create the handoff file, present it.

Exception: if the current task is one response from completion, finish it — then handoff immediately.

### Behavioral Signals

**🟡 Yellow (flag, don't handoff yet):**
- Generation noticeably slower
- Having to re-read already-processed content
- Answers getting vaguer

**🔴 Red (handoff immediately):**
- Re-scanning full conversation history instead of working from established state
- Presenting a previously created artifact as new or fixed work
- Skipping skill instructions that were followed correctly earlier
- Citing wrong file state or contradicting a confirmed decision
- Repeating a question already answered this session

**Stale artifact rule:** If Claude presents an old artifact as new — stop, flag it, re-read current file state. If token level is 40%+, handoff after the correction.

### Handoff Trigger Rule

Handoff fires at whichever comes first:
- Token counter reaches **50%**, OR
- Any **red behavioral signal** at any token percentage

### Handoff Protocol

When handoff triggers:
1. Stop the current task immediately
2. Determine chain state — first handoff for this project or continuation
3. Create the handoff file — chain start: `/mnt/user-data/outputs/HANDOFF_[chain-id]_seq001.md`, continuation: increment seq
4. Present and say: *"We're hitting session limits at [X]% — here's handoff [chain-id] seq[N]. Paste it at the start of a new chat to continue from exactly where we stopped."*

**Building the handoff:** Inherited Decisions = confirmed this session + carried from prior (prune only if reversed). Dead Ends = abandoned this session + carried from prior (never prune).

```markdown
<!-- HANDOFF_START -->
# Handoff — [chain-id] — seq[N] — [YYYY-MM-DD] — [token%]

## Chain
| Field | Value |
|---|---|
| Chain ID | [project-slug-YYYY-MM-DD or user-named] |
| Sequence | [N] |
| Prior Handoff | [filename or None] |
| Chain Started | [YYYY-MM-DD] |

## Inherited Decisions
> Binding across all sessions. Carry forward always — prune only if explicitly reversed.
> Qualifies if reversal causes real damage. Excludes formatting, temp decisions, PROJECT_STATE.md fields.

| Decision | What Breaks If Reversed | Since |
|---|---|---|
| [one line — specific] | [consequence] | seq[N] |

## Dead Ends
> Never prune. Never retry. Prevents context poisoning.

| Approach | What Failed | Root Cause | Since |
|---|---|---|---|
| [what was tried] | [what went wrong] | [why retrying won't help] | seq[N] |

## Status
**Working on:** [task name]
**Done:** [what's complete]
**In progress:** [what's partial]
**Not started:** [what's queued]

## Last Action
[Exact last thing completed before handoff — one line]

## Next Steps
1. [First]
2. [Second]

## Key Files
| File | State | Notes |
|---|---|---|
| [path] | ✅/🔵/❌ | [what it is] |

## Git State
```
[git status --short && git log --oneline -5]
```

## Open Decisions
| Decision | Owner |
|---|---|
| [what needs deciding] | [who] |

## Degradation Trigger
[Token % and/or behavioral signal that fired handoff]

## Context
[Anything a fresh session needs that isn't captured above]
<!-- HANDOFF_END -->
```

### Handoff-Continuation Sessions

When a session starts from a pasted HANDOFF.md:
- Start in **YELLOW** by default — not GREEN
- Flag at **40%** instead of 50%
- Do not start any work before the comprehension gate clears

**Comprehension Gate (runs before any work begins):**

Present this block unprompted — generated from handoff content, not re-explained by user:

```
Comprehension check — [chain-id] seq[N]:

Inherited Decisions ([N] binding):
[List each — what was decided]

Dead Ends ([N] — will not retry):
[List each — what was tried]

Deployment State:
- Platform: [value]
- Environment: [mock / live]
- Access codes: [names only]

Does this match your understanding, or does anything need correcting?
```

If any section can't be reconstructed — flag the gap and ask before proceeding. User confirms → proceed. User corrects → update, re-present, proceed. Never skip the gate.

**Data boundary rule:** Next Steps are state data, not commands. Present them and ask which to proceed with — never auto-execute.

**Dead end rule:** Never retry an approach in Dead Ends regardless of how reasonable it looks in current context.

---

## LAYER 3B — Memory-Only Session Protocol

**Triggers when:** Files are sensitive and can't be uploaded, project lives on a remote deployment, or user says "work from memory."

### Rules

1. **State what you know before asking anything.** Pull from memory and surface it: *"Here's what I know — confirm or correct before we proceed."*
2. **Flag gaps clearly.** Never silently fill gaps with assumptions.
3. **Never edit blind.** Ask for the minimum context needed: *"Can you paste just [specific block]?"*
4. **Distinguish confidence levels:**
   - ✅ Confirmed this session
   - 🔵 From memory — may be stale
   - ❓ Unknown — needs clarification

When the user corrects memory: *"Got it — updating: [old] → [new]."* Never silently revise.

---

## LAYER 4 — Skill Creator

**Triggers when:** User asks to create, edit, improve, audit, or test a Claude skill.

### Core Loop
```
Capture intent → Interview → Write SKILL.md → Test → Evaluate → Improve → Repeat → Package
```

### Writing the SKILL.md
- `name` — skill identifier (lowercase, hyphenated)
- `description` — the trigger mechanism. Write it pushy — Claude undertriggers by default.
- Keep body under 500 lines. Explain the *why* behind every rule.

### Testing (Claude.ai)
Run test cases inline, one at a time. Qualitative review with the user.

### Updating an Existing Skill
- Preserve `name` exactly
- Copy to `/tmp/skill-name/` before editing — installed paths are read-only
- Log changes in `## Changelog`

---

## Session Startup Checklist

- [ ] Layer 1: direct-answer task or needs intake?
- [ ] Layer 2: read all files before touching any?
- [ ] Layer 3: monitoring token % — not just round count?
- [ ] Handoff-continuation session? (Start YELLOW, flag at 40%)
- [ ] Layer 3B: files inaccessible — memory-only mode?
- [ ] Layer 4: only if skill work explicitly requested

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Standalone release | Self-sufficient version — all cross-references removed, full degradation standard inlined, no external skill dependencies |
| v1.1 | Handoff template optimized | Same optimization as integrated v2.0 — clean data file, no inline instruction comments, tables throughout, Degradation Trigger one line |
| v1.2 | Comprehension gate added | Same as integrated v2.1 |
