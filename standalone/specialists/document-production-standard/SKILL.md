---
name: document-production-standard
description: >
  Use this skill whenever producing a downloadable document — docx, pdf, pptx, md, or jsx.
  Triggers on: "make me a resume," "write a cover letter," "create a memo," "build a
  presentation," "write a report," "create a README," "draft a letter," "build a component,"
  "make a React artifact," or any request where the deliverable is a file the user will
  submit, share, publish, or deploy. Also triggers when the user uploads a document to
  edit or reformat. Governs formatting, structure, and citation — not content.
---

# Document Production Standard (Standalone)

Governs the formatting, structure, and output quality of all document deliverables.
This skill governs the container — content is determined by the user's instructions
and any active subject-matter skill.

---

## STEP 1 — Document Type Detection

| Type | Triggers | Default Format |
|---|---|---|
| Resume | "resume," "CV," updating work history | .docx |
| Cover Letter | "cover letter," applying to a role | .docx |
| Academic Paper / Essay | "essay," "paper," "assignment," course name mentioned | .docx |
| Memo / Report | "memo," "report," "case study," "write-up" | .docx |
| Presentation | "deck," "slides," "presentation," "pptx" | .pptx |
| README / Technical Doc | "README," "documentation," lab report | .md |
| React / JSX Component | "jsx," "React," "artifact," "component," "render this" | .jsx |
| PDF | user explicitly says PDF or form to fill | .pdf |

If type is ambiguous: *"What format do you need this in — Word doc, PDF, or something else?"*

---

## STEP 2 — Citation Style Detection

**Do not hardcode.** Detect from context:

| Signal | Style |
|---|---|
| Course name, professor mentioned, academic assignment | Ask: "What citation style does your professor require?" |
| "MLA" mentioned | MLA 9th edition |
| "APA" mentioned | APA 7th edition |
| Legal, government, policy document | Bluebook or ask |
| Professional memo, business report | No citations unless sourced — use footnotes |
| Technical documentation, README | No citations — link to sources inline |
| React / JSX component | No citations — inline code comments only |

If citation style is unclear for an academic submission — always ask. Wrong style on a graded paper is real harm.

---

## STEP 3 — Format Standards by Document Type

### Résumé
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Single page for standard internship and entry-level applications
- Two pages acceptable for research programs, graduate applications, or roles requiring demonstrated project depth
- Reverse chronological order. No first person — implied subject
- Bullets: action verb → task → result (quantified where possible)
- Sections: Summary (optional) → Experience → Education → Skills → Certifications
- ATS-safe: no tables, text boxes, or headers/footers with key info
- Font: Calibri 11pt body, 14pt name, 12pt section headers. Margins: 0.5" minimum

### Cover Letter
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Three paragraphs: hook + fit + close. Max 400 words
- Match tone to organization (formal for government, direct for tech)
- Always include: role name, one specific reason you want this org
- Never open with "I am writing to express my interest"

### Academic Paper / Essay
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Double-spaced, 12pt Times New Roman, 1" margins (unless specified)
- Title page if required. Citation style per Step 2
- Works Cited / References on its own page

### Memo / Report
- Read `/mnt/skills/public/docx/SKILL.md` before building
- Header block: To, From, Date, Subject — always
- Single-spaced body, double space between sections. Section headers in bold
- Resources/References at end. Professional register — no contractions

### Presentation (PPTX)
- Read `/mnt/skills/public/pptx/SKILL.md` before building
- One idea per slide. Max 6 bullets per slide, max 8 words per bullet
- Title slide + agenda + conclusion always present. Consistent theme

### README / Technical Doc
- No public skill governs .md — apply rules here directly
- H1 title, H2 sections, H3 subsections
- Installation → Usage → Architecture → Contributing (if public)
- Code blocks for all commands. Plain language throughout

### PDF
- Read `/mnt/skills/public/pdf/SKILL.md` before building or filling
- Never use pypdf. For form filling: identify all fields before writing any values
- For new PDFs: build in md or docx first, then convert per skill instructions

### React / JSX Component
- Read `/mnt/skills/public/frontend-design/SKILL.md` before building
- Single file — CSS and JS inline unless told otherwise
- Default export required — no required props without defaults
- Tailwind core utility classes only
- State via `useState` / `useReducer` — no `localStorage` or `sessionStorage`
- Available libraries: lucide-react, recharts, mathjs, lodash, d3, shadcn/ui
- Filename: `[ComponentName].jsx` — PascalCase

---

## STEP 4 — Pre-Delivery Checklist

- [ ] Correct file format?
- [ ] Citation style confirmed (academic) or not applicable?
- [ ] Font, spacing, margins match standard? *(skip for JSX)*
- [ ] No orphaned headers, broken formatting, blank pages? *(skip for JSX)*
- [ ] Filename versioned correctly if versioning is active?
- [ ] File copied to `/mnt/user-data/outputs/` before `present_files`?

**JSX only — also verify:**
- [ ] Default export present?
- [ ] No `localStorage` or `sessionStorage`?
- [ ] Only available libraries imported?
- [ ] No required props without defaults?
- [ ] Tailwind core utility classes only?

---

## STEP 5 — Iteration Protocol

When the user requests changes:

1. Read the current file state before touching it — **exception:** if files are inaccessible (sensitive/remote), ask for the minimum needed excerpt instead
2. Make all changes in one pass
3. Declare version bump if versioning is active — wait for confirmation before saving
4. Re-run pre-delivery checklist
5. Present updated file

Never re-read mid-edit. Never present without running checklist.

---

## Changelog

| Version | Change | Reason |
|---|---|---|
| v1.0 | Standalone release | Self-sufficient version — delivery sequence inlined, cross-skill references replaced with inline rules, no external skill dependencies |
