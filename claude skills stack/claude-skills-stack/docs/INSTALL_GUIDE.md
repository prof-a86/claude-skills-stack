# Install Guide

## Which Version Should I Use?

**Use the integrated version** if you're installing the full stack and want the most token-efficient setup. Skills cross-reference each other — install all seven and they work as a unit.

**Use the standalone version** if you want to install one or two skills without the rest. Each skill is fully self-sufficient. Any combination works.

---

## Installing on Claude.ai

1. Go to **claude.ai → Settings → Skills → New Skill**
2. Copy the contents of the relevant `SKILL.md` file
3. Paste into the skill editor and save
4. Repeat for each skill

**Integrated install order (follow this exactly):**
```
1. task-auditor
2. expert-auditor
3. agentic-session-manager
4. artifact-version-control
5. document-production-standard
```

Order matters for the integrated version — governors must be installed before specialists.

**Standalone install:** Any order. Any subset.

---

## Recommended Combinations

If you don't want all seven, here are the most useful subsets:

### Minimum viable stack
```
task-auditor + expert-auditor
```
Covers session governance, ask-first protocol, degradation handling, and professional SME work. Everything else builds on top of these two.

### For agentic / dev work
```
task-auditor + agentic-session-manager + artifact-version-control
```
Multi-session project state, memory reconstruction, deployment tracking, file versioning.

### For document-heavy work
```
task-auditor + expert-auditor + document-production-standard + artifact-version-control
```
Professional deliverables with format standards, version control, and SME-quality output.

### Full stack
All five core skills + mcp-router. Governors first, specialists second, mcp-router last.

### For developers / Claude Code users
```
task-auditor + agentic-session-manager + artifact-version-control + mcp-router
```
Full agentic project management with GitHub integration, file versioning, and MCP governance.

**Add hooks for automatic degradation monitoring:**
```bash
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```
Then merge `hooks/settings.example.json` into `.claude/settings.json`. See `hooks/README.md` for full setup.

---

## Customizing Skills

### Personalizing for your context

Skills ship generic but are designed to be personalized. Things worth adding to your installed versions:

**`agentic-session-manager`:** Add your specific projects to memory context. The skill will surface them during multi-project disambiguation.

**`document-production-standard`:** Add your institution's specific citation requirements if you work with a recurring professor or organization that has non-standard formatting rules.

### How to edit an installed skill

1. Open the skill in **Settings → Skills**
2. Make your edits
3. Save

Skills are stored as text — they're just instructions. Editing is safe.

### Following the skill creator loop

If you want to build new skills or significantly modify existing ones, follow the loop in `task-auditor` Layer 4:

```
Capture intent → Interview → Write SKILL.md → Test → Evaluate → Improve → Repeat → Package
```

Write the skill, test it in conversation, note where it fires incorrectly or fails to fire, revise the description, repeat.

---

## Updating Skills

When a new version of a skill is released:

1. Open the skill in **Settings → Skills**
2. Replace the content with the new version
3. Save

The changelog at the bottom of each skill tells you what changed and why.

---

## Troubleshooting

### The skill isn't firing when it should

The description is the trigger mechanism. Claude reads it to decide whether to activate the skill. If a skill isn't firing:
- Check the description for the specific phrases that should trigger it
- If your use case doesn't match any of the trigger phrases, the description needs to be updated
- Claude undertriggers by default — descriptions should be slightly pushy

### Two skills seem to be conflicting

This usually means both skills are trying to handle the same behavior. Check which skill should own the behavior and which should defer. In the integrated version, the dependency chain is documented in `ARCHITECTURE.md`.

### I'm seeing two rounds of intake questions on professional requests

This is expected behavior when `task-auditor` and `expert-auditor` are both active on a high-stakes professional request (cover letters, resumes, cybersecurity advice, interview prep). `task-auditor` governs session scope — it asks about format, audience, and constraints. `expert-auditor` governs SME quality — it asks about goal, existing content, and domain-specific context. Both rounds are necessary because they serve different purposes. The governor asks to prevent wasted work. The specialist asks to produce quality output. If you find the double intake too heavy for a specific use case, you can install the standalone versions of each skill — standalone skills carry their own intake logic without cross-skill coordination overhead.

### The handoff is firing too early / too late

The 30%/50% thresholds are empirically derived, not precise. If they're wrong for your session patterns, edit `task-auditor` Layer 3 to adjust the zone boundaries. The behavioral signals are more reliable than the percentage thresholds — consider lowering the red threshold if you're seeing stale artifacts or instruction skips before 50%.

### Skills are referencing each other but one isn't installed

In the integrated version, each cross-reference has a fallback: "if [skill] is not installed, do [X] instead." The fallbacks are designed to degrade gracefully rather than fail. If you're seeing broken behavior from a missing skill, check the relevant section for its fallback rule and verify it's sufficient for your use case.

---

## FAQ

**Do these work with Claude API?**
The skills are designed for Claude.ai's skill system. The behavioral patterns can be adapted as system prompts for API use, but they weren't built or tested for that context.

**Do these work with other AI models?**
The architecture is model-agnostic in principle but Claude-specific in implementation. The skill file format, the memory system references, and the tool names (`bash_tool`, `present_files`, etc.) are Claude-specific. Porting to other models requires replacing the implementation layer while preserving the behavioral logic.

**Can I fork and publish my own version?**
Yes — MIT license. Attribution appreciated but not required.

**How do I contribute?**
Open an issue for bugs or behavioral gaps. PRs welcome — follow the skill creator loop in `task-auditor` Layer 4 before submitting.
