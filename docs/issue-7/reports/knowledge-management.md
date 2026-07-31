---
record: issue-7/knowledge-management
loop_state: landed
upstream: docs/issue-7/proposals/knowledge-management/proposal.md
---

# Phase-2 record — knowledge-management methodology enforcement plugin set (issue-7)

## What was done

Built the four sibling plugins specified in
`docs/issue-7/proposals/knowledge-management/proposal.md` (revision 2, the
plugin-set structure the approver's FEEDBACK required), each self-contained
(`.claude-plugin/plugin.json`, `hooks/hooks.json`, gate script(s),
`hooks/tests/`, `README.md`) and registered in
`.claude-plugin/marketplace.json` alongside the existing `knowledge-management`
role plugin:

- `km-adr-proposal` — `hooks/adr-shape-gate.sh` (`PreToolUse`
  `Write|Edit|MultiEdit` on `docs/issue-*/proposals/knowledge-management/*.md`)
  checks Context / Options considered (>=2 reasoned) / Decision /
  Consequences (easier+harder) / Sources. Kill switch
  `KM_ADR_PROPOSAL_GATE_OFF`. Test: `hooks/tests/adr-shape-gate.test.sh`,
  7/7 passing (PASS-all, FAIL-missing-Consequences, FAIL-only-1-option,
  PASS-unrelated-path, PASS-kill-switch, FAIL-malformed-JSON,
  FAIL-stale-Edit-old_string).
- `km-pattern-entry` — `hooks/pattern-entry-gate.sh` (`PreToolUse`
  `Write|Edit|MultiEdit` on `docs/patterns/<slug>.md`, excluding
  `index.md`) checks front matter (`title`/`keywords`/`source_issues`) and
  body headings Context/Problem/Why/Solution/Consequences in order. Kill
  switch `KM_PATTERN_ENTRY_GATE_OFF`. Test:
  `hooks/tests/pattern-entry-gate.test.sh`, 7/7 passing.
- `km-cross-index` — `hooks/index-shape-gate.sh` (`PreToolUse`
  `Write|Edit|MultiEdit` on `docs/patterns/index.md`, checks a
  keyword/status-bearing table header row) plus
  `hooks/index-pairing-gate.sh` (`PreToolUse` `Bash` matched on
  `git commit`, denies a staged new pattern entry with no same-commit
  `index.md` row). Shared kill switch `KM_CROSS_INDEX_GATE_OFF`. Tests:
  `hooks/tests/index-shape-gate.test.sh` (5/5) and
  `hooks/tests/index-pairing-gate.test.sh` (5/5, real temp-git-repo cases).
- `km-supersession` — `hooks/supersession-pairing-gate.sh` (`PreToolUse`
  `Bash` matched on `git commit`, reads staged pattern-entry content via
  `git show :<path>`, denies a `supersedes`/`superseded_by` declaration
  with no reciprocal staged field on the counterpart entry). Kill switch
  `KM_SUPERSESSION_GATE_OFF`. Test:
  `hooks/tests/supersession-pairing-gate.test.sh`, 5/5 passing (real
  temp-git-repo cases).

All ten `.sh` files parse clean under `bash -n`. Each plugin's gate script
follows the fail-closed trap-at-top / kill-switch / python3-JSON-parse /
`has_any()` / single-combined-`deny()` shape read structurally (not copied)
from `pricing-rulebook/pricing/hooks/methodology-gate.sh` (write-time shape
gates) and `implementation-rulebook/coding/hooks/coding-progress-gate.sh`
(commit-time staged-file pairing gates) — no file from either external
rulebook was read or vendored during the build, per
`docs/handbooks/canon-scripts.md`.

Registration: `.claude-plugin/marketplace.json` gained four new entries
(`km-adr-proposal`, `km-pattern-entry`, `km-cross-index`, `km-supersession`),
each `source` pointing at its own top-level directory. The role plugin's
`knowledge-management/hooks/directive.sh` `PRODUCES` line now names the four
plugins and points to the handbook's composition table.
`docs/handbooks/knowledge-management.md` gained an "Enforcement plugin
composition" section stating the phase-1-norm = {`km-adr-proposal`} and
phase-2-norm = {`km-pattern-entry` ∧ `km-cross-index` ∧ `km-supersession`}
table, and its "Phase-2 record self-check" section now states that the
three phase-2 checks are machine-enforced (previously it said this role
"adds no new gate script").

## Why

Issue-1 (merged) adopted four methodologies (ADR shape, Alexander pattern
language + AAR "why", PMI keyword searchability, ADR
`status: superseded`) but left them enforced only as prose in the handbook
and a one-line `PRODUCES` summary. Issue-7 asked for
`implementation-rulebook`-grade mechanical enforcement; the approver's
FEEDBACK on the first PR (#8) rejected a combined-script design and
required an independent plugin per methodology, mirroring `core`'s own
`core`/`freelunch`/`scout`/`warrant` sibling-plugin marketplace layout, with
the phase-1/phase-2 norms stated as explicit plugin compositions rather
than left implicit. This record implements that plugin-set design exactly
as specified in the approved phase-1 proposal, with no scope drift.

## Upstream basis

`docs/issue-7/proposals/knowledge-management/proposal.md` (revision 2,
approved via `APPROVE issue-7/knowledge-management` issue comment, single-
account mode per contract v3 §19) and its upstream survey
`docs/issue-7/reports/knowledge-management/survey.md`. Underlying
methodology adoption: `docs/issue-1/proposals/2026-07-31-km-methodology-norms.md`.

## Open findings

None. All four plugins built to the proposal's exact specification (gate
targets, kill-switch names, test case sets); all gate/test scripts verified
independently after the build (parse-check + full test-suite re-run) rather
than trusting build-time self-report alone.
