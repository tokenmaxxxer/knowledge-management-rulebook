---
proposal: issue-7/knowledge-management
loop_state: open
upstream: docs/issue-7/reports/knowledge-management/survey.md
---

# Enforcement-gate design proposal — knowledge-management directive deepening (phase 1)

**Scope note: this document is a phase-1 design proposal only.** No gate
script, hook wiring change, agent, or test file is implemented by this
document. Everything below is a specification for phase-2 to build after
an approver records Approve per `docs/specs/approvers.md` (contract v3
§19). No approval is issued by this document; the author of this document
holds no approval authority for it.

## Context

Issue-1 (merged) adopted a methodology for this role — ADR-shaped
phase-1 proposals, and three phase-2 artifact kinds (pattern-library
entry, cross-issue index, supersession note) each with required
front-matter/section shape — and recorded it in
`docs/handbooks/knowledge-management.md`. That handbook already states,
in its own words, that the phase-2 self-check is "a manual checklist
item, not a code gate." `knowledge-management/hooks/directive.sh` carries
only a one-line `PRODUCES` summary. Issue-7 asks that this methodology be
turned into the same class of mechanical enforcement that
`implementation-rulebook` has for its own role
(`coding/hooks/coding-progress-gate.sh`, ~180 lines, state-tracked
ordering enforcement) and that `pricing-rulebook` has for its own methodology
(`pricing/hooks/methodology-gate.sh`, ~230 lines, required-element
detection on the Write/Edit surface) — both read directly at
`/home/jwjung/tokenmaxxxer/rulebooks/{implementation,pricing}-rulebook`
during the phase-1 survey (see
`docs/issue-7/reports/knowledge-management/survey.md`).

## Options considered

### For the directive deepening

**A. Keep `directive.sh` as a one-line summary; put all stage/criteria/
prohibition detail only in the handbook.**
Rejected: the handbook is not read at `SessionStart` the way
`directive.sh` is (per `knowledge-management/hooks/hooks.json`), so a
session could act without ever seeing the deepened norm. This is exactly
the "directive 한 줄 요약" state issue-7 was opened to fix.

**B. Expand `directive.sh`'s inline strings to carry the full stage/
criteria/prohibition text.**
Rejected: `directive.sh` sources `core`'s `role-directive.sh` and calls
`core_role_directive` with four short positional strings (`you_decide`,
`use_when`, `produces`, `hand_off`) — this is core canon's shape, shared
by every role's `directive.sh` (confirmed in both `pricing/hooks/
directive.sh` and this role's own file). Stuffing full stage detail into
one of those four positional strings breaks the canon shape's uniformity
and readability across roles, and it's not this role's canon script to
redesign.

**C. Deepen the handbook (`docs/handbooks/knowledge-management.md`) with
an explicit stage/criteria/prohibition structure per facet, and have
`directive.sh` keep its four canon lines but point its `PRODUCES` line at
the handbook section by name — session-start still sees a compact
signal, the deepened detail is one hop away in the file the gate itself
will also reference.**
Adopted. Matches core canon's existing directive shape (no redesign of
`role-directive.sh`), keeps the handbook as the single normative source
the gate checks against (survey finding: handbook is already this role's
methodology source of record), and avoids duplicating handbook content
into the directive script.

### For the methodology gate

**A. A single generic "required sections present" gate reused verbatim
from `pricing/hooks/methodology-gate.sh`.**
Rejected: that script's checks (method-named, conjoint-family-name,
inputs-needed, gate-check-result, labeled-numbers, residual-list) are
pricing-specific vocabulary. Reusing the file would either vendor a copy
of role-specific logic that isn't this role's canon script, or produce a
gate that checks for the wrong words. The issue's own constraint text
("캐논 스크립트는 참조만·복사 금지") targets *core* canon scripts
specifically, but the same discipline applies here: don't copy another
role's role-scoped script either — write a role-scoped script for this
role's own required elements, following the same *pattern*, not the same
*bytes*.

**B. One combined gate script covering all three artifact kinds
(pattern entry, index, supersession) plus the phase-1 ADR-shape check,
in one PreToolUse hook.**
Considered. Simpler wiring (`hooks.json` needs only one new entry). But
mixes four independent "required-elements-present" questions — phase-1
ADR shape, pattern-entry front matter + 5 sections, index row-added rule,
supersession both-sides rule — into one script's control flow, which
`pricing/hooks/methodology-gate.sh`'s own single-purpose-per-target-regex
structure argues against (it dispatches by path regex to distinct checks
already; a combined script here would do the same internally, so the
simplification is mostly cosmetic).

**C. One PreToolUse gate script, `knowledge-management-methodology-gate.sh`,
matched on `Write|Edit|MultiEdit`, internally dispatching by target-path
regex to four checks (phase-1 proposal shape; pattern-entry shape;
index-row-presence; supersession-linking), each independently
pass/fail, each `deny()` naming every missing element at once — same
external shape as B, but written and documented as four named checks
inside one file for auditability, matching
`methodology-gate.sh`'s existing internal structure (it already
dispatches on `PROPOSAL_RE` vs `RECORD_RE`).**
Adopted — same wiring simplicity as B, same auditability as A without A's
copy-paste risk.

### For the ordering constraint (index-row-added-in-same-change,
supersession-linked-both-sides)

**A. Persisted state file (mirrors `coding-progress-gate.sh`'s read of
`docs/issue-<n>/reports/verify.md`'s `loop_state` field across separate
tool calls/commits).**
Considered, but this role's ordering constraint is same-commit-set, not
cross-role/cross-record — the handbook's own words are "in the same
change," not "in a later, gated change." A persisted state file would be
solving a harder problem (crash recovery across sessions) than the
methodology actually demands.

**B. Check the git staging area / working tree at commit time for the
paired file(s), by extending the same-shape check the gate already does
per-write, checked again at the `git commit` Bash PreToolUse boundary
(mirrors `coding-progress-gate.sh`'s own hook point: a Bash matcher on
`git commit`, not a Write/Edit matcher).**
Adopted. When a `Write|Edit|MultiEdit` targets `docs/patterns/<slug>.md`
with new/changed `supersedes` or `superseded_by` front matter, or when it
creates a new pattern entry, the gate cannot yet know whether the
paired file (`docs/patterns/index.md` row, or the other side's
front-matter link) will land in the same commit — so per-write checking
alone cannot enforce "in the same change." A second, commit-time check
(new `Bash` `git commit`-matched hook, structurally the same pattern as
`coding-progress-gate.sh`) inspects `git diff --cached --name-only` and
denies if a staged new/changed pattern entry's required pairing (index
row; both-sides supersession link) is not also staged in the same
commit. This needs no persisted state — everything it needs is in the
current staging area at commit time.

## Decision & rationale

1. **Directive deepening** lands in
   `docs/handbooks/knowledge-management.md` (this role's existing
   normative source, per issue-1), restructured into four explicit
   subsections per the issue's ask — Stages, Judgment criteria,
   Prohibitions, and Per-facet executable checklists — replacing the
   current prose-only sections while keeping every existing normative
   fact untouched (front-matter fields, section lists, ordering rules
   already specified there are the source of truth; the gate below reads
   *file structure*, not this handbook's prose, so re-wording the
   handbook for stage/criteria/prohibition clarity does not require
   re-deriving what the required elements are). `directive.sh`'s
   `produces` string is updated to point at the handbook's per-facet
   checklist section by name (one line, still core-canon-shaped),
   *not* expanded inline. See "Directive deepening spec" below for the
   exact structure phase-2 must produce.

2. **Methodology gate**: a new role-scoped script
   `knowledge-management/hooks/knowledge-management-methodology-gate.sh`,
   `PreToolUse` matched on `Write|Edit|MultiEdit`, layered on top of core's
   generic `record-fields-gate.sh` (never replacing it), following the
   structural pattern read from `pricing/hooks/methodology-gate.sh`
   line-for-line (fail-closed trap-at-top, kill-switch env var, JSON
   payload parse with fail-closed on any parse/shape error, target-path
   regex scoping, resulting-text reconstruction for Write/Edit/MultiEdit,
   substring-based required-element detection, one combined `deny()`
   naming every missing element, outer try/except mapping internal
   errors to exit 2). See "Methodology gate spec" below.

3. **Ordering constraint**: a second new script,
   `knowledge-management/hooks/knowledge-management-pairing-gate.sh`,
   `PreToolUse` matched on `Bash` (`git commit`), following the
   structural pattern read from `coding/hooks/coding-progress-gate.sh`
   (fail-closed trap-at-top, root resolution, staged-file inspection via
   `git diff --cached --name-only`, one combined `deny()`). No persisted
   state file — same-commit-set is fully checkable from the staging area
   at commit time (Option B above).

4. `hooks.json`'s existing dangling `PreToolUse` → `Bash` entry
   (currently pointing at a nonexistent
   `knowledge-management-progress-gate.sh`) is corrected in phase-2 to
   point at the new `knowledge-management-pairing-gate.sh`, and a new
   `PreToolUse` → `Write|Edit|MultiEdit` entry is added pointing at
   `knowledge-management-methodology-gate.sh`. (Wiring change only;
   still phase-2, not executed here.)

## Directive deepening spec (what phase-2 writes into the handbook)

Target file: `docs/handbooks/knowledge-management.md` (existing file,
restructured — not a new file, no canon content duplicated in). Four
subsections, replacing/absorbing the current "Phase-1 proposal norm" /
"Phase-2 artifact templates" / "Phase-2 record self-check" sections:

- **Stages** — name the two phases explicitly as stages with entry/exit
  conditions already implied by contract v3 (survey → scout → proposal
  for phase 1; artifact-writing → self-check → record for phase 2), each
  stage naming which of the three existing template sections
  (unchanged, referenced not restated) applies.
- **Judgment criteria** — decision rules already implicit in the
  existing text made explicit as testable predicates, e.g.: "an entry
  supersedes another iff both `supersedes` and `superseded_by` resolve to
  an existing path in `docs/patterns/`"; "a proposal's Options considered
  section satisfies the norm iff it lists >= 2 options each with a
  stated rejection or acceptance reason" (mirrors the ADR shape already
  in the handbook, phrased as a criterion instead of a description).
- **Prohibitions** — explicit negative rules currently only implied:
  no pattern entry without all five body sections; no index entry
  addition split across commits from the entry it indexes; no
  one-sided supersession link; no new methodology gate script that
  duplicates core's `record-fields-gate.sh` checks instead of adding to
  them.
- **Per-facet executable checklists** — one checklist each for: phase-1
  survey, phase-1 proposal, phase-2 pattern-entry write, phase-2 index
  update, phase-2 supersession note — each item phrased as a yes/no the
  author can self-check before writing, matching the granularity of the
  gate's own checks below (so the human checklist and the machine gate
  check the same list, one manual and one mechanical, never diverging
  sources of truth).

## Methodology gate spec

File: `knowledge-management/hooks/knowledge-management-methodology-gate.sh`
(new, phase-2). `PreToolUse`, matcher `Write|Edit|MultiEdit`.

Target-path dispatch (four independent checks; a write outside all four
patterns exits 0 immediately, same as `methodology-gate.sh`'s
"not this gate's business" pattern):

1. **Phase-1 proposal check** — path matches
   `^docs/issue-[0-9]+/proposals/knowledge-management/.*\.md$`.
   Required elements (from handbook's ADR shape, referenced not
   restated): a `Context` heading, an `Options considered` (or
   equivalent) heading with >= 2 distinctly-headed options each
   containing rejection/acceptance language, a `Decision` heading, a
   `Consequences` heading, and a `Sources` heading. Detection mirrors
   `methodology-gate.sh`'s `has_any()` substring approach over
   lower-cased heading text — no full Markdown-AST parse (same
   simplicity/robustness trade-off, noted in the survey's scout notes).

2. **Pattern-entry check** — path matches
   `^docs/patterns/(?!index\.md$)[^/]+\.md$`. Required: front-matter
   keys `title`, `keywords`, `source_issues` present and non-empty
   (`supersedes`/`superseded_by` optional, checked only when the
   pairing gate's supersession case applies); body headings `Context`,
   `Problem`, `Why`, `Solution`, `Consequences` present, in that order
   (order check: each heading's line number strictly increasing —
   `methodology-gate.sh` doesn't need an order check since its elements
   aren't sequential, but the handbook's "in order" language for this
   facet is load-bearing per issue-1, so this check adds an
   order predicate `pricing`'s gate didn't need).

3. **Index check** — path matches `^docs/patterns/index\.md$`. Required:
   the file is a Markdown table (a header row containing `pattern name`
   or `keywords` or `status`, case-insensitive) — this check only
   confirms *shape*; the *pairing* (row added in the same commit as its
   entry) is the pairing gate's job (Bash/`git commit`-matched), not
   this Write-time gate's, since a single Write to `index.md` can't see
   whether a sibling entry file is staged in the same change.

4. **Phase-2 record check** — path matches
   `^docs/issue-[0-9]+/reports/knowledge-management\.md$` — out of
   scope for this gate per issue-7's explicit instruction not to create
   this file in phase 1, but the gate spec still names it for phase-2
   completeness: required elements here are core's generic §20 fields
   (unchanged, enforced already by core's `record-fields-gate.sh` —
   this role's gate adds nothing on this surface, confirming "layered on
   top of, never instead of").

Kill switch: `KM_METHODOLOGY_GATE_OFF=1` env var (mirrors
`PRICING_METHODOLOGY_GATE_OFF`).

## Pairing-gate spec

File: `knowledge-management/hooks/knowledge-management-pairing-gate.sh`
(new, phase-2). `PreToolUse`, matcher `Bash` (`git commit`).

Logic: read `git diff --cached --name-only`. If any staged path matches
the pattern-entry regex (facet 2 above) and is new or has changed
front-matter `supersedes`/`superseded_by`/`source_issues` implying a new
entry:
- if the entry is new (not previously tracked by git, i.e. `git diff
  --cached --diff-filter=A` includes it): require
  `docs/patterns/index.md` is also staged in the same commit (deny
  naming the missing pairing if not).
- if the entry's front matter (staged version) sets `supersedes: X` or
  `superseded_by: Y`: require the referenced path `X`/`Y` is also
  staged in the same commit with the reciprocal field set (deny naming
  which side is missing if not).

Fail-closed on any unreadable staged file, any git command failure, any
unresolved project root — same pattern as `coding-progress-gate.sh`.

## Gate test design

New root-level `tests/` directory (none exists yet in this repo — a gap
noted in the survey). Test harness shape follows
implementation-rulebook's `tests/run-gate-tests.sh` convention (feed a
constructed PreToolUse JSON payload on stdin, assert exit code and
stderr substring).

Methodology-gate test cases:
- PASS: a phase-1 proposal `Write` with all five ADR headings and >= 2
  options each with a reason → exit 0.
- FAIL: a phase-1 proposal `Write` missing `Consequences` → exit 2,
  stderr names `Consequences` (or the missing-element list including it).
- FAIL: a phase-1 proposal with only 1 option under "Options
  considered" → exit 2.
- PASS: a pattern-entry `Write` with full front matter and all five
  body headings in order → exit 0.
- FAIL: a pattern-entry missing `keywords` front-matter key → exit 2.
- FAIL: a pattern-entry with `Solution` before `Problem` (order
  violated) → exit 2.
- PASS: an `index.md` `Write` containing a header row with `pattern
  name` → exit 0.
- FAIL: an `index.md` `Write` with no recognizable table header → exit 2.
- PASS: a `Write` to an unrelated path (e.g. `README.md`) → exit 0
  (not this gate's business).
- PASS: `KM_METHODOLOGY_GATE_OFF=1` set, otherwise-failing payload →
  exit 0 (kill switch honored).
- FAIL (fail-closed): malformed JSON on stdin → exit 2.
- FAIL (fail-closed): `Edit` whose `old_string` doesn't match current
  file content (resulting text undeterminable) → exit 2.

Pairing-gate test cases:
- PASS: staged new pattern entry + staged `index.md` in the same commit
  → exit 0.
- FAIL: staged new pattern entry, `index.md` not staged → exit 2, stderr
  names the missing index pairing.
- PASS: staged entry with `supersedes: docs/patterns/old.md`, `old.md`
  also staged with matching `superseded_by` → exit 0.
- FAIL: staged entry with `supersedes: ...`, the referenced old entry
  not staged (or staged without the reciprocal field) → exit 2.
- PASS: a `git commit` with no pattern-entry files staged at all → exit
  0 (not this gate's business — mirrors
  `coding-progress-gate.sh`'s early `sys.exit(0)` when no subject is
  attributable).
- FAIL (fail-closed): `git diff --cached` fails/errors → exit 2.

## Agents/checklists

No standing agent is proposed. The methodology here (curate → check five
elements/three artifact kinds → pair-check at commit) is a single-role,
single-session mechanical check, not a multi-step repeated procedure
across sessions the way e.g. implementation's hunt-guard state machine
is — a gate script plus the per-facet handbook checklist (already
specified above, machine-checked and human-checked against the same
list) is proportionate. If a future issue finds this role repeatedly
needs multi-pattern batch curation across many source issues in one
sitting, a checklist-driving agent could be reconsidered then; not
warranted by anything in issue-1's adopted methodology or this survey.

## Consequences

**Easier**: a pattern entry, index update, or supersession missing a
required element is caught at write time instead of surviving to
review; the phase-1 proposal ADR shape is enforced the same way
pricing's is, closing the "directive 한 줄 요약" gap issue-7 names;
the dangling `hooks.json` reference to a nonexistent script is fixed as
a byproduct.

**Harder**: two new scripts to maintain in step with any future handbook
change (a handbook edit that adds/removes a required section must be
mirrored in the gate's detection list, since the gate is regex/substring-
based and does not read the handbook programmatically — same coupling
`pricing`'s gate already accepts against its own methodology-norms doc);
substring-based detection (not a real Markdown-AST parse) can in
principle be fooled by a heading word appearing in prose rather than as
an actual heading, a known trade-off already accepted by
`methodology-gate.sh` and inherited here for consistency rather than
re-litigated.

## Sources

- `docs/handbooks/knowledge-management.md` (this repo, landed issue-1
  phase 2) — normative methodology text referenced throughout, not
  restated.
- `docs/issue-1/reports/knowledge-management/survey.md`,
  `docs/issue-1/reports/knowledge-management/scout-brief.md` — issue-1's
  adoption rationale (cited by the handbook's own header).
- `knowledge-management/hooks/directive.sh`,
  `knowledge-management/hooks/hooks.json` (this repo) — current
  directive/wiring state.
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/coding-progress-gate.sh`
  — read in full during phase-1 survey; structural pattern for the
  pairing gate.
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`
  — read in full during phase-1 survey; structural pattern for the
  methodology gate (the exact reference issue-7 names).
- `docs/issue-7/reports/knowledge-management/survey.md` (this issue,
  phase-1) — full survey this proposal is built on.
- `assumption`: root-level `tests/` directory naming/harness convention
  is inferred from implementation-rulebook's `tests/run-gate-tests.sh`,
  `parse-check.sh`, `deny-only-check.sh` file names only (contents not
  read); phase-2 should read these in full before implementing rather
  than relying on this inference.
