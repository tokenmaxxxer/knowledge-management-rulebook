---
proposal: issue-7/knowledge-management
loop_state: open
upstream: docs/issue-7/reports/knowledge-management/survey.md
revision: 2 (rewritten per approver FEEDBACK on PR #8, plugin-set structure)
---

# Plugin-set design proposal — knowledge-management methodology enforcement (phase 1)

**Scope note: this document is a phase-1 design proposal only.** No
plugin directory, marketplace entry, gate script, agent, or test file is
created by this document. Everything below is a specification for
phase-2 to build after an approver records Approve per
`docs/specs/approvers.md` (contract v3 §19). No approval is issued by
this document; the author holds no approval authority for it.

## Revision note (why this version differs from PR #8's original)

The approver's FEEDBACK comment on issue #7 rejects the original design
(one deepened handbook + two combined gate scripts vendored directly
under `knowledge-management/hooks/`) and requires this structure
instead: the adopted methodologies become a **plugin set**, mirroring
`core`'s own marketplace — one independent, self-contained plugin per
methodology (directive/gate/agent/test as needed), each registered in
`.claude-plugin/marketplace.json`, with the phase-1 and phase-2 norms
each expressed as which plugins compose to produce that norm. This
revision restructures the Decision section accordingly; the underlying
factual survey (`docs/issue-7/reports/knowledge-management/survey.md`)
and the field precedents it read
(`implementation-rulebook/coding/hooks/coding-progress-gate.sh`,
`pricing-rulebook/pricing/hooks/methodology-gate.sh`) are unchanged and
still ground the per-plugin gate logic below — reading `core`'s own
plugin layout (`tokenmaxxxer-core/.claude-plugin/marketplace.json`:
`core`, `terse`, `freelunch`, `scout`, `warrant` as five sibling
plugins, each with its own `.claude-plugin/plugin.json`) is the added
reference for *this* revision, cited in Sources below.

## Context

Issue-1 (merged) adopted four methodologies for this role, recorded in
`docs/issue-1/proposals/2026-07-31-km-methodology-norms.md` (c) and
absorbed into `docs/handbooks/knowledge-management.md`:

1. **ADR** (Architecture Decision Record shape) — for phase-1 proposals.
2. **Alexander pattern language** (Context → Problem → Solution →
   Consequences), combined with **NASA AAR's "why" causal question** —
   for the pattern-library entry artifact.
3. **PMI's keyword-based searchability principle** — for the
   cross-issue index artifact.
4. **ADR's `status: superseded` convention**, applied to pattern
   entries — for the supersession-note artifact.

None of the four is enforced today beyond prose in the handbook and a
one-line `PRODUCES` summary in `knowledge-management/hooks/directive.sh`.
Issue-7 asks for `implementation-rulebook`-grade mechanical enforcement.
The approver's structural correction: don't fold four methodologies into
shared scripts — give each its own plugin, the way `core`'s marketplace
already keeps `freelunch`, `scout`, and `warrant` as independent plugins
rather than one monolith.

## Options considered

### For plugin granularity

**A. One `knowledge-management-enforcement` plugin covering all four
methodologies, internally dispatching by path/target (the PR #8
structure, rewritten as a single plugin instead of loose vendored
scripts).**
Rejected. This is the shape the approver's FEEDBACK explicitly rejects
("단일 게이트/디렉티브 심화가 아니라 플러그인 세트로"). A single plugin
with four internal dispatch branches is functionally the combined-script
design from PR #8 wearing a `.claude-plugin/plugin.json` wrapper — it
does not give each methodology independent versioning, independent
enable/disable, or a self-contained test surface, which is what "1
방법론 = 1 독립 플러그인" requires.

**B. Four independent plugins, one per adopted methodology (`km-adr-proposal`,
`km-pattern-entry`, `km-cross-index`, `km-supersession`), each owning its
own directive fragment, gate script, and tests; each registered as its
own entry in `.claude-plugin/marketplace.json`, mirroring `core`'s
`core`/`terse`/`freelunch`/`scout`/`warrant` sibling layout.**
Adopted. Matches the approver's explicit structure requirement
line-for-line: independent plugin per methodology, freelunch-level
self-containment, marketplace registration, single methodology per
plugin.

**C. Four plugins as in B, but also collapse the existing
`knowledge-management` role plugin (identity/directive/write_scope) into
one of the four.**
Rejected. The role-identity plugin (`SessionStart` directive, role
`hooks.json`, `write_scope`) is not itself a methodology — it's the
container the methodology plugins attach enforcement to, same relation
`core`'s `core` plugin has to `freelunch`/`scout`/`warrant` (core owns
role/contract machinery; the others are optional capability plugins
layered on top). Folding a methodology into the role plugin would
special-case that one methodology's enforcement path differently from
the other three for no reason grounded in the methodology itself.

### For where the phase-1/phase-2 norms live, given B

**A. State the norms only implicitly, as "whichever plugins happen to be
enabled."**
Rejected. The approver's requirement is explicit: "기획서(phase 1)
규범과 산출물(phase 2) 규범도 각각을 플러그인 조합으로 풀어낸다 — 어떤
플러그인들이 조합되어 그 규범이 성립하는지가 설계의 본체." The
composition itself has to be a stated, checkable fact, not an emergent
property of whatever's installed.

**B. A short composition table in the role's `plugin.json`/handbook
stating: phase-1 norm = {km-adr-proposal}; phase-2 norm =
{km-pattern-entry, km-cross-index, km-supersession}, each row naming
which plugin(s) a given phase norm requires enabled.**
Adopted. This is the "plugin 목록(이름·담당 방법론·구성요소·조합 관계)"
the approver requires the proposal to carry (see Plugin set table
below) — carried forward into the handbook in phase 2 as the norm's
canonical statement, not left implicit.

## Decision & rationale — the plugin set

Four new sibling plugins, at repo root next to the existing
`knowledge-management` role plugin, each with its own
`<name>/.claude-plugin/plugin.json`, each registered as its own entry in
`.claude-plugin/marketplace.json` (five entries total after phase 2: the
existing `knowledge-management` role plugin unchanged, plus these four).

| Plugin | Methodology owned | Components (phase-2 build) | Composes into |
|---|---|---|---|
| `km-adr-proposal` | ADR shape (issue-1 (a)) | `hooks/adr-shape-gate.sh` (`PreToolUse`/`Write\|Edit\|MultiEdit` on `docs/issue-*/proposals/knowledge-management/**`, checks Context/Options considered (>=2, reasoned)/Decision/Consequences/Sources headings, `has_any()` substring detection per `pricing`'s `methodology-gate.sh` pattern); `hooks/tests/adr-shape-gate.test.sh` | **Phase-1 norm** (sole member) |
| `km-pattern-entry` | Alexander pattern language + AAR "why" (issue-1 (b).1) | `hooks/pattern-entry-gate.sh` (`PreToolUse`/`Write\|Edit\|MultiEdit` on `docs/patterns/<slug>.md`, checks front-matter `title`/`keywords`/`source_issues` + body headings Context/Problem/Why/Solution/Consequences present **in order**); `hooks/tests/pattern-entry-gate.test.sh` | **Phase-2 norm** (member 1 of 3) |
| `km-cross-index` | PMI keyword searchability (issue-1 (b).2) | `hooks/index-shape-gate.sh` (`PreToolUse`/`Write\|Edit\|MultiEdit` on `docs/patterns/index.md`, checks table header row); `hooks/index-pairing-gate.sh` (`PreToolUse`/`Bash` matched on `git commit`, denies if a new pattern entry is staged without a same-commit `index.md` row, via `git diff --cached --name-only`); `hooks/tests/*.test.sh` | **Phase-2 norm** (member 2 of 3) |
| `km-supersession` | ADR `status: superseded` convention applied to patterns (issue-1 (b).3) | `hooks/supersession-pairing-gate.sh` (`PreToolUse`/`Bash` matched on `git commit`, denies if a staged entry sets `supersedes`/`superseded_by` without the reciprocal field staged on the referenced entry in the same commit); `hooks/tests/supersession-pairing-gate.test.sh` | **Phase-2 norm** (member 3 of 3) |

Each gate script follows the structural pattern read from
`pricing/hooks/methodology-gate.sh` (fail-closed trap-at-top, kill-switch
env var scoped to that plugin — e.g. `KM_ADR_PROPOSAL_GATE_OFF=1` —
JSON payload parse fail-closed, target-path regex scoping, resulting-text
reconstruction for Write/Edit/MultiEdit, one combined `deny()` naming
every missing element) or from
`implementation-rulebook/coding/hooks/coding-progress-gate.sh` for the
two commit-time pairing gates (fail-closed, `git diff --cached
--name-only` staged-file inspection). No script is copied byte-for-byte
from either rulebook (both are role-scoped canon outside this repo, not
this role's to vendor) — only the pattern is reused, same discipline PR
#8's version already applied and the approver's FEEDBACK does not
revisit.

**Phase-1 norm** = `km-adr-proposal` enabled. A single-methodology norm
composes from exactly one plugin — the composition table still states it
explicitly rather than leaving "just this one plugin" implicit, per the
approver's requirement that composition always be a stated fact.

**Phase-2 norm** = `km-pattern-entry` ∧ `km-cross-index` ∧
`km-supersession`, all three enabled together. None alone enforces the
full norm: `km-pattern-entry` alone would let an entry land with no
index row or no supersession link; `km-cross-index` alone would not
check the entry's own shape; `km-supersession` fires only on commits
that touch `supersedes`/`superseded_by` and is silent on entries that
carry neither field. The three are independent (each has its own
directive/gate/test surface, each can be disabled independently via its
own kill switch) but jointly necessary for the phase-2 norm to hold —
this joint-necessity relation is what "조합 관계" in the approver's
requirement names.

**Role plugin (`knowledge-management`, existing, unchanged in kind)**:
keeps identity, `SessionStart` directive, `write_scope`. Its
`directive.sh` `PRODUCES` line is updated (still a single core-canon-
shaped line, not expanded inline — same constraint PR #8's version
already established and the approver's FEEDBACK does not revisit) to
name the four plugins by reference instead of only the three artifact
kinds, so a session reading the directive at `SessionStart` knows
enforcement exists and which plugins carry it.

**Marketplace registration**: `.claude-plugin/marketplace.json` gains
four new entries (`km-adr-proposal`, `km-pattern-entry`, `km-cross-index`,
`km-supersession`), each `source` pointing at its own top-level
directory, each `description` naming the one methodology it owns —
mirroring `core`'s marketplace, which lists `freelunch`/`scout`/`warrant`
as siblings of `core` with one-methodology-per-entry descriptions (read
in full at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/.claude-plugin/marketplace.json`
during this revision's re-scout).

## Gate test design (per plugin, phase-2)

Each plugin's own `hooks/tests/` carries its cases (no shared root-level
`tests/` directory this time — that would recreate a shared-surface
coupling across plugins the approver's split is designed to avoid).
Per-plugin cases, same PASS/FAIL/fail-closed/kill-switch shape as PR #8's
original design (unchanged in substance, only relocated):

- `km-adr-proposal`: PASS all 5 headings + >=2 reasoned options; FAIL
  missing `Consequences`; FAIL only 1 option; PASS unrelated path
  (not-this-gate's-business exit 0); PASS kill switch set on an
  otherwise-failing payload; FAIL malformed JSON (fail-closed); FAIL
  `Edit` with stale `old_string` (fail-closed).
- `km-pattern-entry`: PASS full front matter + 5 headings in order; FAIL
  missing `keywords`; FAIL `Solution` before `Problem` (order); PASS
  unrelated path; PASS kill switch; FAIL malformed JSON.
- `km-cross-index`: PASS `index.md` write with recognizable header row;
  FAIL no recognizable header; PASS staged new entry + staged index row
  same commit; FAIL staged new entry, index.md not staged; PASS no
  pattern-entry files staged (not this gate's business); FAIL
  `git diff --cached` failure (fail-closed).
- `km-supersession`: PASS staged entry with `supersedes: old.md` +
  `old.md` staged with matching `superseded_by`; FAIL referenced old
  entry not staged or missing the reciprocal field; PASS commit with no
  `supersedes`/`superseded_by` touched (not this gate's business); FAIL
  `git diff --cached` failure (fail-closed).

## Agents/checklists

No standing agent for any of the four plugins. Same rationale as PR #8's
version, now per-plugin: each methodology's check is a single-session
mechanical shape/pairing check, not a multi-step repeated procedure
across sessions — a gate script plus a human checklist line in the
handbook (one line per plugin, listing what its gate checks) is
proportionate for all four. If a future issue finds one of these
methodologies needs batch/repeated procedure across a sitting, that
plugin alone can grow an agent later without touching the other three —
exactly the independence the plugin split is for.

## Consequences

**Easier**: each methodology's enforcement can be read, tested, enabled,
or disabled independently — a change to the pattern-entry shape rule
touches only `km-pattern-entry`, not a shared script also carrying index
and supersession logic; the phase-1/phase-2 norm statement is now an
explicit, auditable plugin list instead of an implicit "whatever's
wired in `hooks.json`"; the plugin-set shape matches `core`'s own
marketplace convention, so a reader already familiar with `core`,
`freelunch`, `scout` recognizes the pattern immediately.

**Harder**: four `plugin.json` + four `hooks.json` + four kill-switch env
vars to keep straight instead of one or two files (more registration
surface than PR #8's combined-script design); the two commit-time
pairing gates (`km-cross-index`'s index-pairing check,
`km-supersession`'s link check) both hook `Bash`/`git commit` and both
must independently fail-closed and independently report — two separate
`deny()` messages on one `git commit` call that touches both an
unindexed new entry and a one-sided supersession is a slightly noisier
failure mode than PR #8's single combined pairing gate would have
produced, accepted as the cost of the two methodologies staying
independently owned and testable.

## Sources

- `docs/issue-7/reports/knowledge-management/survey.md` — full phase-1
  survey (unchanged by this revision), citing the two external gate
  precedents read in full.
- `docs/issue-1/proposals/2026-07-31-km-methodology-norms.md` — the four
  adopted methodologies and their per-artifact rationale ((a)/(b)/(c)),
  restated in this document's Context section.
- `docs/handbooks/knowledge-management.md` — current normative text,
  updated in phase 2 to state the composition table.
- Issue #7, approver FEEDBACK comment (JiwonJung94, on PR #8) — the
  plugin-set structural requirement this revision implements verbatim
  (four bullet points: independent-plugin-per-methodology,
  freelunch-grade self-containment, phase-1/phase-2 norms as plugin
  compositions, mandatory plugin list in the proposal).
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/.claude-plugin/marketplace.json`,
  `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/freelunch/.claude-plugin/plugin.json` —
  read in full during this revision's re-scout; reference for
  sibling-plugin marketplace layout and per-plugin `plugin.json` shape.
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/coding-progress-gate.sh` —
  read in full during the original phase-1 survey; structural pattern
  for the two commit-time pairing gates.
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh` —
  read in full during the original phase-1 survey; structural pattern
  for the three write-time shape gates (the exact reference issue-7
  names).
- `knowledge-management/hooks/directive.sh`,
  `knowledge-management/hooks/hooks.json`,
  `.claude-plugin/marketplace.json` (this repo) — current role-plugin
  wiring state, updated per this revision's plan.
- `assumption`: per-plugin `hooks/tests/` file naming
  (`<gate-name>.test.sh`) is this revision's own choice, not read from
  any external convention — phase-2 should confirm it doesn't collide
  with any harness convention `core`'s own plugins use before
  implementing.
