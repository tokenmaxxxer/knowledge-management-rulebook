---
role: knowledge-management
write_scope: ['docs/patterns/**']
---

# knowledge-management handbook

Methodology and required-artifact norms for this role (issue-1, phase 2).
Adoption rationale lives in
`docs/issue-1/proposals/2026-07-31-km-methodology-norms.md`; this section is
the reference these three artifacts must match when produced under
`write_scope`.

## Phase-1 proposal norm

Every phase-1 proposal for this role follows ADR shape: Context, Options
considered (>= 2, with rejection reasons), Decision & rationale, Consequences
(both easier and harder), Sources (URL for web evidence, `path:line` for
repo facts; unsourced claims labeled `assumption`).

## Phase-2 artifact templates

### 1. Pattern-library entry — `docs/patterns/<slug>.md`

Front matter: `title`, `keywords`, `source_issues` (issue numbers this
pattern was extracted from), `supersedes` / `superseded_by` (if applicable).

Body sections, in order:
1. **Context** — situation the pattern appears in
2. **Problem** — the recurring problem (what happened vs. what should have)
3. **Why** — root cause of the gap (AAR-style causal question)
4. **Solution** — the reusable fix
5. **Consequences** — trade-offs of applying it

### 2. Cross-issue index — `docs/patterns/index.md`

One table row per pattern entry: pattern name, keywords, source_issues,
status (active/superseded). Adding an entry requires adding its row here in
the same change.

### 3. Supersession note

When an entry replaces an older one: link both directions in the same
change — old entry's front matter gets `superseded_by: <new path>`, new
entry's front matter gets `supersedes: <old path>`. Linking only one side is
incomplete.

## Phase-2 record self-check

Before closing the phase-2 record (`docs/issue-<n>/reports/knowledge-management.md`),
the "what-was-done" section must confirm: every pattern entry added or
changed this round has all required front-matter fields and all five body
sections above, and any supersession is linked on both sides. This is a
manual checklist item, not a code gate — core's `record-fields-gate.sh`
already enforces the general §20 fields; this role adds no new gate script
(see proposal (d) for why).

BOUNDARY CASE: if the work in front of you drifts outside `decides` above,
stop and hand off per the arrow — do not silently absorb another role's
scope. Record the hand-off point in this role's record before opening the
next role's session.
