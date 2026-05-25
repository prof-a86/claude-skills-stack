# Session Degradation Model

## What Is Session Degradation?

Session degradation is the progressive failure of a Claude session's ability to hold and act on established context as token consumption increases. It is not a single event — it is a zone-based decline with observable behavioral symptoms at each stage.

This model was derived from real observed failure modes in production Claude sessions, not from theoretical LLM behavior. The failure modes catalogued here were observed directly and used to build the trigger system that governs the entire skill stack.

---

## Why Token Percentage, Not Round Count

The original handoff trigger in this stack was round count (15 rounds). Round count was replaced by token percentage as the primary signal for a specific reason:

**Round count does not account for response length.** A session with five long technical responses (detailed code reviews, multi-file edits, extensive explanations) can consume more context than a session with twenty short exchanges. Round count treats both sessions identically. Token percentage does not.

Claude.ai displays token consumption as a percentage of the context window. This percentage is the most reliable available signal for session health — it measures what actually matters (context capacity consumed) rather than a proxy (exchanges made).

**Limitation:** The percentage is relative to the context window size, which varies by model and plan. The same percentage means different things on different models. A raw token count would be more precise, but is not exposed in the current Claude.ai interface.

---

## The Two Degradation Patterns — A Clarification

The term "context rot" appears frequently in the Claude community but conflates two fundamentally different degradation patterns. This model distinguishes them explicitly because they have different causes, different behavioral signatures, and different mitigations.

### Pattern 1 — Gradual Context Fill (Long Sessions, Short Outputs)

Many short exchanges accumulate over a long session. Each response adds a small amount to the context window. Degradation is gradual — the session technically still works, it just works worse over time. Answers get vaguer, Claude re-reads sections already processed, responses slow down.

**Primary mitigation:** `/compact` — compresses conversation history in place, keeps the session alive, extends the working window. Usually sufficient.

**Behavioral signature:** Yellow signals dominate. Red signals appear only at high token percentages.

**Token curve:** Gradual slope. 30% threshold reached after many exchanges.

### Pattern 2 — Artifact Spike (Any Session Length, Large Outputs)

A single large artifact — a JSX component, a PPTX executor, a multi-file pipeline edit, a detailed technical document — burns massive context in a handful of exchanges. The session doesn't have to be long. A fresh session can hit the 30% threshold in three or four responses if those responses involve large artifact generation.

**Primary mitigation:** `/compact` first if available, but handoff is often necessary because the artifact that caused the spike needs to carry into the new session — compressing history doesn't remove the artifact from context.

**Behavioral signature:** Red signals appear early and fast. Stale artifact re-presentation is the dominant failure mode — not vague answers. The session looks healthy until it suddenly isn't.

**Token curve:** Spike shape. 30% or 50% threshold reached in a small number of exchanges regardless of session age.

### The Degradation Matrix

```
                    SHORT OUTPUTS        LARGE ARTIFACTS
                   ┌─────────────────┬───────────────────────┐
  LONG SESSION     │  Gradual Fill   │  Compound Spike       │
                   │  /compact       │  /compact + handoff   │
                   │  sufficient     │  likely both needed   │
                   ├─────────────────┼───────────────────────┤
  SHORT SESSION    │  Low risk       │  Single Spike         │
                   │  No action      │  /compact first,      │
                   │  needed         │  handoff if RED       │
                   └─────────────────┴───────────────────────┘
```

### Why This Matters for Mitigation

The degradation ladder (YELLOW → suggest `/compact`, RED → `/compact` as last resort, RED + `/compact` already run → handoff mandatory) was designed with both patterns in mind:

- For Pattern 1 sessions, `/compact` is usually sufficient and handoff is avoidable
- For Pattern 2 sessions, `/compact` buys time but doesn't solve the underlying issue — the large artifact is still in context and will be regenerated stale on the next response. Handoff is more likely to be necessary even after `/compact` runs

**The signal that distinguishes Pattern 2 from Pattern 1 mid-session:** stale artifact re-presentation. This red signal is almost exclusively a Pattern 2 failure mode. When it appears, escalate to handoff regardless of token percentage — `/compact` alone will not resolve it.

### Implications for the Behavioral Signal Catalog

The behavioral signals map cleanly onto the two patterns:

| Signal | Pattern | Notes |
|---|---|---|
| Answers getting vaguer | Pattern 1 | Gradual attention dilution |
| Re-reading already-processed content | Pattern 1 | Working memory saturating |
| Generation slower | Both | Earlier in Pattern 2 |
| Stale artifact re-presentation | Pattern 2 | Dominant failure mode |
| Wrong file state / version | Pattern 2 | Artifact context corrupted |
| Instruction skip | Pattern 2 | Skill instructions crowded out by artifact context |
| Context re-scanning | Both | Late-stage signal in Pattern 1, earlier in Pattern 2 |
| Repeated question | Pattern 1 | Answer fell out of working context |

---

| Zone | Token Range | Behavior |
|---|---|---|
| 🟢 GREEN | 0% – 30% | Full session. All skills active. Work normally. |
| 🟡 YELLOW | 30% – 50% | Early warning. Flag proactively. Stop starting new major subtasks. Monitor for behavioral signals. |
| 🔴 RED | 50%+ | Handoff mandatory. Stop. Create handoff file. Present it. |

**Exception:** If the current task is one response from completion at RED entry, finish it — then handoff immediately after.

**Handoff-continuation sessions** (sessions starting from a pasted HANDOFF.md or checkpoint file) start in YELLOW by default, not GREEN. Context density is immediately high even at 0% token usage because the handoff file carries substantial established state. Flag at **40%** for these sessions, not 50%.

---

## Behavioral Signals

Behavioral signals override zone assignment. A session showing red behavioral signals at 35% token usage is treated as RED, not YELLOW.

### 🟡 Yellow Signals (flag to user — do not handoff yet)
- Generation noticeably slower than earlier in the session
- Having to re-read files or conversation sections already processed this session
- Answers getting vaguer or less specific than earlier responses

### 🔴 Red Signals (handoff immediately — regardless of token percentage)

| Signal | Description |
|---|---|
| Context re-scanning | Re-scanning the full conversation history instead of working from established state |
| Stale artifact re-presentation | Presenting a previously created artifact as new or fixed work when it hasn't changed |
| Instruction skip | Skipping or overlooking skill instructions that were followed correctly earlier in the session |
| Wrong file state | Citing wrong file state, wrong version, or contradicting a confirmed decision |
| Repeated question | Repeating a question already answered in this session |
| Incorrect reference | Referencing earlier parts of the conversation incorrectly |

**The stale artifact rule** deserves specific attention: if Claude presents an old artifact as new fixed work, stop immediately. Do not continue. Flag it explicitly. Re-read the actual current file state before producing anything further. If token level is 40%+, handoff after the correction.

---

## The Handoff Trigger Rule

Handoff fires at whichever comes first:
- Token counter reaches **50%**, OR
- Any **red behavioral signal** appears at any token percentage

Round count is a secondary indicator only. 15+ rounds at low token usage does not trigger handoff. 15+ rounds at 40%+ combined with any yellow signal does.

---

## Healthy Session Baseline

A session is healthy when:
- Skills fire reliably on every relevant request
- File state, project state, and open decisions are accurate without re-reading the conversation
- Outputs are consistent with prior confirmed work — no re-presenting old artifacts as new
- Generation speed is consistent throughout the session
- Instructions are followed completely, not partially

Any deviation from this baseline is a degradation signal.

---

## Observed Failure Mode Catalog

These failure modes were observed in real sessions and used to build the behavioral signal catalog above.

**Context re-scanning:** At high token usage, Claude re-reads the full conversation instead of working from established working state. This is the most common early signal — observable as increased response latency combined with outputs that re-establish facts already confirmed.

**Stale artifact re-presentation:** Claude serves a file version created earlier in the session (or a prior session) as if it were a newly fixed version. This is the most dangerous failure mode because it actively misleads the user into thinking work is done when it isn't. The user receives an old file, doesn't compare it to the prior version, and discovers the issue only after closing the session.

**Instruction skip:** Skills stop firing reliably. Claude omits steps it was following correctly 10 exchanges earlier. This happens without announcement — Claude does not report that it has stopped following a rule.

**Wrong file state:** Claude cites a file version, a decision, or a confirmed fact from earlier in the session incorrectly. Often appears as reverting to a pre-fix state or attributing a decision to the wrong exchange.

**Repeated question:** Claude asks a clarifying question already answered by the user earlier in the same session. Indicates the earlier answer has fallen out of effective working context.

---

## Implications for Multi-Session Work

The session degradation model has specific implications for projects that span multiple sessions:

1. **Handoff files are not optional.** Without a structured handoff, the new session reconstructs state from memory — which is always potentially stale and never complete. Every forced handoff (degradation-triggered) and every voluntary close should produce a state artifact.

2. **Continuation sessions start degraded.** A session that opens with a handoff file immediately loads substantial context. The effective GREEN zone is shorter. Flag earlier.

3. **Memory confidence tags are required.** In continuation sessions, facts sourced from memory (🔵) and facts confirmed this session (✅) must be distinguished explicitly. Blending them silently produces invisible errors.

4. **The 40% flag threshold for continuation sessions** exists because the handoff file itself consumes token budget before any new work begins. At 40% in a continuation session, the remaining capacity is roughly equivalent to 50% in a fresh session.

---

## Empirical Observations — Session Sample

The following observations were recorded across real production sessions. Token percentages are approximations based on the Claude.ai token indicator at the time behavioral signals were first observed. Session types and content are described generically — no session-specific content is included.

| Session | Type | Output Size | Pattern | First Signal | Signal Type | Mitigation |
|---|---|---|---|---|---|---|
| Multi-agent pipeline dev | Agentic / sensitive files | Large (JSX + multi-file edits) | Pattern 2 | ~40% | Wrong file state (CSS/JS mismatch) | Handoff — file paste required |
| Skills stack development | Multi-file governance system | Very large (23 files, hooks, docs) | Compound Spike | No signal observed | — | Session still active |
| Academic tutoring (math) | Short text, many exchanges | Small (solutions, explanations) | Pattern 1 | ~55%+ | Vague answers | None needed |
| Document production (4 memos + deck) | Sequential large file generation | Large (4 docx + 13-slide pptx) | Pattern 2 | ~35% | Stale artifact re-presented as updated | Version tracking + re-generation |
| Code generation (10 scripts) | Single session, sequential output | Very large (~285KB across files) | Pattern 2 | Not recorded | — | Session completed without handoff |
| Cover letters + interview prep | Mixed doc + coaching | Medium (3 docx + long text) | Mixed | No signal observed | — | Clean session |

### What the Data Shows

**Pattern 1 sessions** (academic tutoring, interview coaching) accumulated tokens slowly across many exchanges. First degradation signals appeared at 50%+ and were mild — vague answers, re-reading already-processed content. `/compact` would have been sufficient mitigation in all observed cases.

**Pattern 2 sessions** (pipeline development, document production, code generation) hit first degradation signals significantly earlier — as low as 35-40% — despite shorter session lengths. The dominant signal was stale artifact re-presentation or wrong file state, not vague answers. These sessions required either handoff or explicit re-reading of current file state before continuing.

**The Compound Spike case** (skills stack development — this session) is the most severe pattern: a long session producing many large artifacts in sequence. No degradation signal was observed because the session is still active — but the token curve is consistent with Pattern 2 behavior accelerated by session length.

### Threshold Calibration Implication

The 30%-50% zone thresholds appear well-calibrated for Pattern 1. For Pattern 2, the effective YELLOW threshold based on these observations are closer to **25-35%** — significantly earlier than the current model predicts. This suggests the zone model may need pattern-specific thresholds in a future revision:

- Pattern 1: 30% YELLOW / 50% RED (current thresholds — well calibrated)
- Pattern 2: 25% YELLOW / 40% RED (empirically indicated — not yet implemented)

This is a specific, testable hypothesis that follows from the two-pattern distinction.

---

**Why 30% and 50% specifically?** These thresholds were derived from observation patterns across Pattern 1 sessions (gradual fill). The empirical observations above suggest they are well-calibrated for Pattern 1 but too conservative for Pattern 2 — Pattern 2 sessions showed first signals at 35-40%, significantly earlier than the 50% RED threshold.

**Pattern-specific thresholds:** Based on observations above, Pattern 2 may require 25% YELLOW / 40% RED instead of the current 30%-50% threshold. This is a specific testable hypothesis — validating it requires a larger sample of Pattern 2 sessions with token percentage recorded at signal onset.

**What happens between models?** Claude Sonnet and Claude Opus have different context window sizes. The same percentage represents different absolute token counts. Pattern-specific thresholds may also differ between models — a future version of this model would ideally be calibrated per model and per degradation pattern.

**Is the matrix exhaustive?** The two-pattern model covers the dominant observed cases. Mixed sessions appear to behave closer to Pattern 1 unless a single large artifact dominates — in which case they shift toward Pattern 2. This suggests single-artifact output size may be a stronger predictor than total session output size.
