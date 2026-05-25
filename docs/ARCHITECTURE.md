# Architecture

## Overview

The Claude Skills Stack is structured as a two-tier system: governors that control session behavior, and specialists that govern specific domains. Skills in the integrated version form a dependency chain — each skill owns one concept and borrows from others for everything outside that domain.

---

## The Dependency Chain (Integrated Version)

```
task-auditor
│   Owns: session degradation standard, handoff trigger rules,
│         ask-first protocol, one-pass fix, skill creator loop
│
├── expert-auditor
│   Owns: SME pipeline, crisis protocol, research standard, scorecard
│   Defers to: task-auditor for degradation triggers and handoff template base
│
├── agentic-session-manager
│   Owns: memory reconstruction, deployment state, sensitive file protocol,
│         voluntary checkpoints, multi-project disambiguation
│   Defers to: task-auditor for degradation triggers
│   References: expert-auditor § LAYER 7-HANDOFF for user/research context sections
│
├── artifact-version-control
│   Owns: semantic versioning, session registry, status promotion,
│         declaration-first rule, present_files failure handling
│   Integrates with: agentic-session-manager (Version State in handoff template)
│                    document-production-standard (delivery sequence)
│
├── document-production-standard
│   Owns: format standards for all document types, pre-delivery checklist,
│         citation detection, skill read requirements
│   Defers to: artifact-version-control for version bump on iteration
│   Branches to: agentic-session-manager Never Edit Blind for inaccessible files
│
└── mcp-router
    Owns: all MCP server interactions — session registry, cache-first protocol,
          declaration-first gate for write operations, GitHub + Google MCP protocols,
          platform detection (Claude.ai vs Claude Code)
    No skill calls MCP directly — all MCP routes through mcp-router
    Optional — stack works without it, adds external service capabilities when installed

**Hooks (Claude Code only — `/hooks` folder)**

| Hook | Event | Role |
|---|---|---|
| `degradation-monitor.sh` | Stop (every response) | Enforces the GREEN/YELLOW/RED zone model automatically — suggests /compact in yellow, escalates to handoff in red |
| `compact-tracker.sh` | Notification | Tracks when /compact is run so the monitor knows ladder position |

Hooks enforce the same degradation standard defined in `task-auditor` Layer 3 but deterministically — they fire on every response regardless of what Claude decides. On Claude.ai, `task-auditor` self-monitors through skill instructions. On Claude Code, hooks replace self-monitoring with automatic enforcement.
```

---

## Integrated vs. Standalone: The Tradeoff

### Integrated
- **Token efficiency:** Each rule lives in one skill. No duplication. Cross-references keep the total token footprint lower across the stack.
- **Maintainability:** Change a rule once — it propagates. No risk of one skill drifting from another.
- **Dependency risk:** A skill that references another only works correctly when both are installed. Missing skills require fallback paths.
- **Recommended for:** Users installing the full stack and keeping it updated together.

### Standalone
- **Portability:** Install any single skill and it works. No dependencies, no missing references.
- **Redundancy:** Each skill carries its own copy of degradation triggers, handoff templates, and delivery rules. Larger token footprint per skill.
- **Drift risk:** When updating a rule, it must be updated in every standalone skill that carries it. Easy to miss.
- **Recommended for:** Users who want to drop in one or two skills, or who are building on top of this stack and need predictable isolated behavior.

### The Philosophical Question

The integrated vs. standalone split reflects a fundamental design choice in any multi-agent system: **dependency chain vs. redundancy**. Dependency chains are leaner and easier to maintain but fragile when components are missing. Redundancy is robust but requires discipline to keep synchronized.

This stack ships both because the right answer depends on the use case, not on a universal principle.

---

## Why Each Skill Exists

### `task-auditor`
LLMs fail not from lack of knowledge but from skipping steps — building before scoping, editing files without reading them, continuing sessions past the point of coherent output. `task-auditor` is a structural fix for each of these. It enforces behavior, not knowledge.

### `expert-auditor`
Professional deliverables require a different protocol than casual conversation. The research-before-advising requirement, the scorecard for high-stakes outputs, and the crisis protocol exist because the cost of being wrong is higher when the user will act on the output.

### `agentic-session-manager`
Multi-session projects with sensitive files break the standard read-before-touching protocol. Memory reconstructed from prior sessions is always potentially stale. This skill introduces confidence tagging (✅ 🔵 ❓) as a first-class concept — making the uncertainty visible rather than papering over it.

### `artifact-version-control`
Iterative document work without versioning produces the "which one is the latest?" problem — solved manually and inconsistently every time. The declaration-first rule exists because "fix this" and "overhaul this" are both vague, and version drift becomes invisible without explicit confirmation.

### `document-production-standard`
Format decisions are reinvented from scratch every session without this skill. Inconsistent margins, wrong citation styles, ATS-unsafe resume formatting — these are preventable with a stored standard. The skill governs the container, not the content.

### `mcp-router`
MCP tool calls without governance produce redundant API calls, unpredictable write operations, and no audit trail. Every MCP interaction in the stack routes through this skill — it owns the session registry, the cache-first check that prevents redundant calls, and the declaration-first gate that ensures no write operation happens without explicit user confirmation. The separation of MCP governance from task governance (which lives in `task-auditor`) keeps each skill's scope clean.

---

## The Session Degradation Model

See [`SESSION_DEGRADATION.md`](SESSION_DEGRADATION.md) for the full model. The short version:

Session degradation was defined from observed LLM failure modes — not from theory. The token percentage threshold (30%-50%) was derived from real usage patterns. The behavioral signal catalog was built from actual observed failures: context re-scanning, stale artifact re-presentation, instruction skip, wrong file state citation. Round count was the original trigger mechanism and was replaced by token percentage because round count does not account for response length — a session with five long technical responses hits the context limit faster than one with twenty short ones.

---

## Versioning Convention

Skills in this stack use semantic versioning adapted for documents:
- **Patch (x.x.y):** Small fix, wording change, minor clarification
- **Minor (x.y):** New section, behavioral change, protocol addition
- **Major (x.0):** Full architectural change, scope shift

Every change is logged in the skill's `## Changelog` with the reason. This is enforced by `task-auditor` Layer 4 and `expert-auditor` § LAYER 6.
