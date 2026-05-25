---
name: document-production-standard
description: >
  Use this skill whenever producing a downloadable document — docx, pdf, pptx, md, or jsx.
  Triggers on: "make me a resume," "write a cover letter," "create a memo," "build a
  presentation," "write a report," "create a README," "draft a letter," "build a component,"
  "make a React artifact," or any request where the deliverable
  is a file the user will submit, share, publish, or deploy. Also triggers when the user
  uploads a document to edit or reformat. Apply automatically alongside expert-auditor for
  professional deliverables, alongside agentic-session-manager for pipeline documentation,
  Apply automatically alongside expert-auditor for professional deliverables,
  citation — not content.
---

# Document Production Standard

Governs the formatting, structure, and output quality of all document deliverables.
Content is governed by `expert-auditor`. This skill governs the container, not the content.

---

## STEP 1 — Document Type Detection

Identify document type from the request before producing anything.

| Type | Triggers | Default Format |
|---|---|---|
| Resume | "resume," "CV," updating work history | .docx |
| Cover Letter | "cover letter," applying to a role | .docx |
| Academic Paper / Essay | "essay," "paper," "assignment," course name mentioned | .docx |
| Memo / Report | "memo," "report," "case study," "write-up" | .docx |
| Presentation | "deck," "slides," "presentation," "pptx" | .pptx |
| README / Technical Doc | "README," "documentation," lab report | .md |
| React / JSX Component | "jsx," "React," "artifact," "component," "render this," | .jsx |
| PDF | user explicitly says PDF or form to fill | .pdf |

If type is ambiguous — ask one question: *"What format do you need this in — Word doc, PDF, or something else?"*

---

## STEP 2 — Citation Style Detection

**Do not hardcode a citation style.** Detect from context:

| Signal | Style |
|---|---|
| Course name, professor mentioned, academic assignment | Ask: "What citation style does your professor require?" |
| "MLA" mentioned anywhere | MLA 9th edition |
| "APA" mentioned anywhere | APA 7th edition |
| Legal, government, or policy document | Bluebook or ask |
| Professional memo, business report | No citations unless sourced — use footnotes |
| Technical documentation, README | No citations — link to sources inline |
| React / JSX component | No citations — inline code comments only |

If citation style is unclear for an academic submission — always ask before producing. Wrong style on a graded paper is a real harm.

---

## STEP 3 — Format Standards by Document Type

### Résumé
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Single page for standard internship and entry-level applications
- Two pages acceptable for research programs, graduate applications, or roles requiring demonstrated project depth — do not aggressively cut content to force a single page in these contexts
- Reverse chronological order
- No "I" or first person — implied subject
- Bullets: action verb → task → result (quantified where possible)
- Sections: Summary (optional) → Experience → Education → Skills → Certifications
- ATS-safe: no tables, no text boxes, no headers/footers with key info
- Font: Calibri 11pt body, 14pt name, 12pt section headers
- Margins: 0.5" all sides minimum

### Cover Letter
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Three paragraphs: hook + fit + close
- Max 400 words — hiring managers skim
- Match tone to organization (formal for government, direct for tech)
- Always include: role name, where you found it (if known), one specific reason you want this org
- No "I am writing to express my interest" — lead with a hook instead

### Academic Paper / Essay
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Double-spaced, 12pt Times New Roman, 1" margins (unless specified otherwise)
- Title page if required by course
- Citation style per Step 2
- Section headers only if required or paper is 5+ pages
- Works Cited / References on its own page

### Memo / Report
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Header block: To, From, Date, Subject — always
- Single-spaced body, double space between sections
- Section headers in bold
- Resources/References at end, not footnotes (unless legal)
- Professional register — no contractions, no slang

### Presentation (PPTX)
- Read `/mnt/skills/public/pptx/SKILL.md` before building
- One idea per slide
- Max 6 bullet points per slide, max 8 words per bullet
- Title slide + agenda + conclusion slide always present
- Consistent theme — don't mix styles mid-deck

### README / Technical Doc
- No public skill governs `.md` files — apply general formatting rules in this section directly, no skill read required
- H1 title, H2 sections, H3 subsections
- Installation → Usage → Architecture → Contributing (if public)
- Code blocks for all commands and code snippets
- Plain language — write for someone who hasn't seen the project before

### PDF
- Read `/mnt/skills/public/pdf/SKILL.md` before building or filling
- Never use pypdf — follow the pdf skill's tooling guidance
- For form filling: identify all fields before writing any values
- For new PDFs: build in a supported format first (md or docx), then convert per skill instructions

### React / JSX Component
- Read `/mnt/skills/public/frontend-design/SKILL.md` before building
- Single file — CSS and JS inline unless explicitly told otherwise
- Default export required — no required props or provide defaults
- Tailwind core utility classes only — no custom compiler classes
- State via `useState` / `useReducer` — no `localStorage` or `sessionStorage`
- Available libraries: lucide-react, recharts, mathjs, lodash, d3, shadcn/ui — import explicitly
- For Anthropic API calls within artifacts: use `claude-sonnet-4-20250514`, no API key needed in the artifact context
- Filename: `[ComponentName].jsx` — PascalCase, descriptive

---

## STEP 4 — Pre-Delivery Checklist

Before presenting any document file, verify:

- [ ] Correct file format for the request?
- [ ] Citation style confirmed (academic) or not applicable (professional/technical)?
- [ ] Font, spacing, margins match the document type standard above? *(skip for JSX)*
- [ ] No orphaned headers, broken formatting, or blank pages? *(skip for JSX)*
- [ ] Filename follows version control standard if `artifact-version-control` is active?
- [ ] File copied to `/mnt/user-data/outputs/` before `present_files` is called?

**JSX only — also verify:**
- [ ] Default export present?
- [ ] No `localStorage` or `sessionStorage` used?
- [ ] Only available libraries imported (lucide-react, recharts, mathjs, lodash, d3, shadcn/ui)?
- [ ] No required props without defaults?
- [ ] Tailwind core utility classes only — no custom compiler classes?

---

## STEP 5 — Iteration Protocol

When the user requests changes to a produced document:

1. Read the current file state before touching it — **exception:** if `agentic-session-manager` is active and the file is inaccessible, follow its Never Edit Blind protocol instead
2. Make all requested changes in one pass
3. If `artifact-version-control` is active — bump version per its rules
4. Re-run pre-delivery checklist
5. Present updated file

Never re-read the file mid-edit. Never present without running checklist.

## MCP Awareness

If `mcp-router` is active, document production gains delivery capabilities:

**On file delivery:**
After `present_files` succeeds on any document — offer MCP delivery options based on what's connected:
- GitHub connected → *"Want me to push [filename] to [repo]?"*
- Drive connected → *"Want me to save [filename] to Drive?"*
- Gmail connected + document is a letter/email → *"Want me to send this via Gmail?"*

Present only the options that match connected servers. Do not offer what isn't connected.

**Never deliver automatically.** All MCP delivery routes through `mcp-router` declaration-first gate. The offer is always optional — user can decline and keep the local file.

If `mcp-router` is not installed — standard local delivery only, no change to behavior.

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Initial build | Unified format standard for all document types — resume, cover letter, academic, memo, pptx, README; dynamic citation detection; pre-delivery checklist; iteration protocol |
| v1.0.1 | Resume page rule fixed | Single page was too aggressive for research/graduate applications; two-page rule added for appropriate contexts |
| v1.1 | JSX/React standard added | JSX/React artifacts had no format standard; React row added to type detection table with format rules aligned to public frontend-design skill |
| v1.2 | Deep dive fixes round 2 | JSX added to description; JSX pre-delivery checklist; docx/pdf skill reads added; PDF section added |
| v1.3 | Deep dive fixes round 3 | README no-skill note; JSX citation row; STEP 5 Never Edit Blind branch for inaccessible files |
| v1.4 | MCP awareness added | Post-delivery MCP options added — GitHub push, Drive save, Gmail send offered based on connected servers; all routes through mcp-router; never automatic |
