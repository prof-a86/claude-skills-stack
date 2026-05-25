# Security

## Overview

This repository was audited against two threat models before public release:

1. **SOC Stress Test** — 7 scenarios testing behavioral edge cases and hook reliability
2. **Penetration Test** — 15 attack vectors across 5 surfaces targeting the specific threat model for skill files operating in an agentic context

All findings were patched before the first public commit. The patch record is documented below.

---

## Threat Model

Skill files are not traditional software — they don't execute code directly. Their attack surface is the agent's own instruction-following behavior. The relevant threat categories for this stack are:

| Surface | Threat |
|---|---|
| Prompt Injection | Malicious content in pasted files (PROJECT_STATE.md, HANDOFF.md) manipulates skill instructions |
| Skill Poisoning | Malformed state files cause Claude to act on false state or execute injected commands |
| Hook Exploitation | Malicious hook payload data escapes sanitization and affects the filesystem |
| MCP Gate Bypass | Write operations execute without explicit user confirmation |
| Credential Reconstruction | Stack is manipulated into surfacing secrets it was instructed to protect |

These categories map directly to the attack classes documented in Snyk's ToxicSkills research (February 2026), which found prompt injection in 36% of audited skills and 1,467 malicious payloads across the ecosystem.

---

## SOC Stress Test — 7 Scenarios

| # | Scenario | Severity | Finding | Status |
|---|---|---|---|---|
| 1 | `session_id` path traversal in hook temp file | HIGH | Unquoted SESSION_ID allowed path traversal outside `/tmp` | ✅ Patched |
| 2 | Non-numeric `TOKEN_PCT` crash | MEDIUM | Empty/non-numeric output from python3 caused integer comparison crash | ✅ Patched |
| 3 | Concurrent Stop events race condition | LOW | Simultaneous hook invocations could conflict on COMPACT_FLAG write | ✅ Patched |
| 4 | task-auditor + expert-auditor double intake | LOW | Expected behavior — documented in INSTALL_GUIDE.md troubleshooting | ✅ Documented |
| 5 | mcp-router gate bypass via context-ambiguous "yeah" | MEDIUM | Prior "yeah" in unrelated exchange could confirm pending write operation | ✅ Patched |
| 6 | PROJECT_STATE.md missing required sections | MEDIUM | Skill silently proceeded with partial state as fully confirmed | ✅ Patched |
| 7 | Hook scripts invoked outside Claude Code | LOW | Would fail non-gracefully without environment guard | ✅ Patched |

---

## Penetration Test — 15 Attack Vectors

### Attack Surface 1 — Prompt Injection

| # | Vector | Severity | Finding | Status |
|---|---|---|---|---|
| 1A | PROJECT_STATE.md field value injection | CRITICAL | No data/instruction boundary — imperative language in field values could be executed | ✅ Patched |
| 1B | HANDOFF.md Next Steps injection | CRITICAL | Next Steps parsed as executable commands without gate | ✅ Patched |
| 1C | Session Continuity Rules override | CRITICAL | Malicious rules section could override skill gate protocols | ✅ Patched |

**Fix:** Data boundary rule enforced across all pasted file parsing. Field values, Next Steps, and Session Continuity Rules are categorized as state data. Imperative language in any field triggers a flag and requires user confirmation. Session Continuity Rules explicitly cannot override installed skill instructions.

### Attack Surface 2 — Skill Poisoning

| # | Vector | Severity | Finding | Status |
|---|---|---|---|---|
| 2A | Poisoned component description executed as instruction | MEDIUM | ✅ status tagged content as confirmed — malicious descriptions could be acted on | ✅ Patched |
| 2B | Credential injection in Deployment State field | MEDIUM | No warning if actual values placed in names-only fields | ✅ Patched |
| 2C | Open Decisions action injection | CRITICAL | Resolved decisions with action values could be auto-executed | ✅ Patched |

**Fix:** 2A/2C covered by data boundary rule. 2B covered by dual warning in PROJECT_STATE_SCHEMA.md — flag and refuse actual credential values in names-only fields.

### Attack Surface 3 — Hook Exploitation

| # | Vector | Severity | Finding | Status |
|---|---|---|---|---|
| 3A | `session_id` path traversal | HIGH | Unquoted path in temp file construction | ✅ Patched |
| 3B | Message content code injection | LOW | String comparison only — no eval/exec | ✅ Safe |
| 3C | ZeroDivision via `context_window=0` | LOW | Division by zero not caught | ✅ Patched |

**Fix:** `SESSION_ID` sanitized with regex (`[^a-zA-Z0-9_-]` stripped). Numeric validation on `TOKEN_PCT` with default 0. `context_window > 0` guard before division. `flock` exclusive lock on all flag reads and writes.

### Attack Surface 4 — MCP Gate Bypass

| # | Vector | Severity | Finding | Status |
|---|---|---|---|---|
| 4A | Chained confirmation bypass | MEDIUM | Prior "yes" carrying into new operation | ✅ Patched |
| 4B | Compound read/write classification | MEDIUM | Write piggybacks on read in one message | ✅ Patched |
| 4C | Gate abandonment exploit | MEDIUM | Pending write lost when user sends unrelated message | ✅ Patched |

**Fix:** Per-operation gate rule — prior confirmations never carry over. Pending gate rule — unrelated messages cancel pending write operations; gate must be re-presented from scratch.

### Attack Surface 5 — Credential Reconstruction

| # | Vector | Severity | Finding | Status |
|---|---|---|---|---|
| 5A | Social engineering via handoff | CRITICAL | Pasted handoff content tagged ✅ — fake credentials treated as confirmed | ✅ Patched |
| 5B | Memory pressure extraction | LOW | Never-reconstruct rule already present | ✅ Mitigated |
| 5C | Credential field inflation | MEDIUM | No enforcement if actual values placed in names-only file | ✅ Patched |

**Fix:** Credential detection added to sensitive file protocol — actual credential values in pasted files are flagged and refused, not tagged ✅.

---

## Hook Security

All three hooks (`degradation-monitor.sh`, `compact-tracker.sh`, `session-close.sh`) implement:

- `set -euo pipefail` — fail fast on any error
- `CLAUDE_CODE_HOOKS` environment guard — exit cleanly if invoked outside Claude Code
- `SESSION_ID` sanitization — `re.sub(r'[^a-zA-Z0-9_-]', '', raw)` before any path construction
- `TOKEN_PCT` numeric validation — `[[ "$TOKEN_PCT" =~ ^[0-9]+$ ]]` with default 0
- `flock` exclusive locks on all flag and file writes — prevents race conditions on concurrent events
- Atomic writes via temp file + `mv` — prevents partial writes on process interruption

---

## Self-Validation

The stack implements a Comprehension Gate on all handoff-continuation sessions. Before any work begins, Claude must demonstrate comprehension of the three areas that cause real damage if wrong:

1. **Inherited Decisions** — lists all binding decisions from the chain
2. **Dead Ends** — lists all approaches that must not be retried
3. **Deployment State** — confirms platform, environment, and access code names

The gate is generated from handoff content — Claude is not permitted to ask the user to re-explain. If any section cannot be reconstructed accurately, Claude flags the gap and requests clarification before proceeding. The gate cannot be skipped.

---

## Reporting Security Issues

If you find a vulnerability in this repository, please open a GitHub issue with the label `security`. Do not include actual exploit payloads in public issues — describe the attack surface and contact the maintainer directly for coordination.

---

## Scope Notes

This audit covers the skill files and hook scripts in this repository. It does not cover:

- The Claude model itself or Anthropic's infrastructure
- MCP servers connected by the user (GitHub, Gmail, Google Drive) — those are governed by their respective security policies
- Third-party skills installed alongside this stack
- User-maintained PROJECT_STATE.md files — the schema warns against actual credential values, but enforcement depends on the user following the instructions
