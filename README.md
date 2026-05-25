# Claude Skills Stack

LLMs don't fail because they lack knowledge. They fail because they skip steps, lose context under pressure, and present stale work as new work.

This is a behavioral governance stack for Claude — six skills and three Claude Code hooks that fix those failure modes structurally. Every rule in every skill traces back to a specific observed failure. Nothing is theoretical.

---

## Why This Exists

Standard Claude skills tell Claude what to know. This stack tells Claude how to behave — when to ask before building, when to hand off before degrading, how to carry decisions and dead ends across sessions, and how to reconstruct project state from memory when files can't be shared.

The session continuity system is the most developed part. After observing real multi-session agentic work break down in specific, repeatable ways, the failure modes were catalogued, named, and turned into structural rules. The result is a handoff chain system, a zone-based degradation model with empirical observations from real sessions, and a typed session state schema — all derived from production use, not theory.

The security posture matches. Before this repo went public, it was audited against the threat model specific to Claude skill files — prompt injection via pasted state files, skill poisoning, hook exploitation, MCP gate bypass, and credential reconstruction. All findings were patched. See [`SECURITY.md`](SECURITY.md) for the full report.

---

## Two Versions

| Version | Best For | Location |
|---|---|---|
| **Integrated** | Installing the full stack — skills cross-reference each other, token-efficient | `/integrated` |
| **Standalone** | Dropping in one or two skills — fully self-sufficient, no dependencies | `/standalone` |

Integrated requires all six installed together. Standalone works in any combination.

---

## The Skills

### Governors — install first

| Skill | What It Governs |
|---|---|
| `task-auditor` | How every session runs. Ask-first protocol, one-pass fix standard, zone-based degradation model, chain-link handoff system, comprehension gate. |
| `expert-auditor` | How professional outputs get produced. Crisis protocol, domain ceiling, research-before-advising standard, self-audit scorecard for high-stakes outputs. |

### Specialists — install after governors

| Skill | What It Governs |
|---|---|
| `agentic-session-manager` | Multi-session projects with sensitive or remote files. Memory reconstruction with confidence tagging, deployment state tracking, PROJECT_STATE.md integration. |
| `artifact-version-control` | Versioning for all file outputs. Semantic bumps, declaration-first rule, session registry, handoff integration. |
| `document-production-standard` | Format standards for every document type — resume, cover letter, memo, PPTX, README, PDF, JSX. Pre-delivery checklist. |

### MCP Layer — install last (optional)

| Skill | What It Governs |
|---|---|
| `mcp-router` | All MCP server interactions. Session registry, cache-first reads, declaration-first gate on every write. GitHub, Gmail, Drive, Calendar. Claude.ai and Claude Code platform detection. |

---

## Chain-Link Handoff System

The handoff system is the core of what makes this stack different from standard session continuity tools.

Every handoff file is part of a named chain. Chains carry two things forward that standard handoffs don't:

**Inherited Decisions** — architectural and irreversible decisions that remain binding across all sessions. The filter is specific: a decision belongs here if a future session reversing it without knowing it was made would cause real damage. Everything else stays out.

**Dead Ends** — approaches that were tried and explicitly failed. Carried forward forever, never pruned. Prevents context poisoning — the failure mode where a new session retries an already-failed approach because the failure isn't visible from the outside.

At continuation session open, a **Comprehension Gate** fires before any work begins. Claude must demonstrate it correctly reconstructed Inherited Decisions, Dead Ends, and Deployment State from the handoff — generated from the file content, not re-explained by the user. If any section can't be reconstructed, Claude flags the gap and waits for clarification.

A **CHAIN_INDEX.md** tracks every session in the chain — token percentage at handoff, key work summary, cumulative decision and dead-end counts — so a new session can orient in one read without loading all prior handoff files.

On Claude Code, `session-close.sh` handles all of this automatically — chain file routing, CHAIN_INDEX creation and appending, and PROJECT_STATE.md auto-updates on session close.

---

## Claude Code Hooks

Three hooks extend the stack for Claude Code environments. They enforce the same behavioral standards defined in the skills, but deterministically — firing on every response regardless of what Claude decides.

| Hook | Fires On | What It Does |
|---|---|---|
| `degradation-monitor.sh` | Every response | Checks token percentage, enforces GREEN/YELLOW/RED zones, suggests `/compact` at yellow, escalates to handoff at red |
| `compact-tracker.sh` | Notifications | Records when `/compact` runs so the monitor knows ladder position |
| `session-close.sh` | Handoff/checkpoint responses | Routes chain files to `.claude/chains/`, creates/updates CHAIN_INDEX.md, writes PROJECT_STATE.md updates to disk |

The `/compact` → handoff ladder: yellow zone suggests `/compact` first. Red zone offers `/compact` as a last resort if it hasn't run yet. If `/compact` has already run and the session is still in red — handoff mandatory.

See [`hooks/README.md`](hooks/README.md) for install instructions, settings configuration, and known behaviors.

---

## Install

### Claude.ai

```
1. task-auditor
2. expert-auditor
3. agentic-session-manager
4. artifact-version-control
5. document-production-standard
6. mcp-router  (optional — install last)
```

Settings → Skills → New Skill → paste the relevant `SKILL.md` → save. Repeat in order.

### Claude Code Hooks (optional)

```bash
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

Merge `hooks/settings.example.json` into `.claude/settings.json`. Full setup in [`hooks/README.md`](hooks/README.md).

---

## Docs

| Doc | What It Covers |
|---|---|
| [`docs/SESSION_DEGRADATION.md`](docs/SESSION_DEGRADATION.md) | Zone-based degradation model, two-pattern matrix (Gradual Fill vs Artifact Spike), behavioral signal catalog, empirical observations from real sessions, threshold calibration |
| [`docs/PROJECT_STATE_SCHEMA.md`](docs/PROJECT_STATE_SCHEMA.md) | Typed session state schema — required fields, optional fields, failure-mode rationale for every field, how `agentic-session-manager` uses it |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Dependency chain, integrated vs standalone tradeoffs, why each skill exists |
| [`docs/INSTALL_GUIDE.md`](docs/INSTALL_GUIDE.md) | Recommended combinations, customization guidance, troubleshooting |
| [`SECURITY.md`](SECURITY.md) | Full audit report — threat model, 7 SOC scenarios, 15 penetration test vectors, all findings and patches |

---

## Design Principles

**Behavior only.** No domain facts hardcoded. Everything perishable is researched live. Skills define how Claude acts, not what Claude knows.

**One source of truth per concept.** In the integrated version, each rule lives in exactly one skill. Others defer. Change a rule once — it propagates.

**The 2-year test.** Before adding anything to a skill: "Will this still be true in 2 years?" If no — it belongs in a search query, not a skill file.

**Empirical, not theoretical.** Every rule in the degradation model, every field in the schema, every gate in the handoff system traces back to a specific observed failure from real sessions. Nothing is added because it seemed like a good idea.

**Governor / specialist separation.** Skills that govern how sessions run are separate from skills that govern specific output domains. A builder or scaffolding skill is deliberately out of scope.

---

## Contributing

Open an issue for bugs, gaps, or behavior you think should be different. PRs welcome for new skills or improvements to existing ones — follow the skill creator loop in `task-auditor` Layer 4.

---

## License

MIT
