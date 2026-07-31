# Current-state survey — issue #1 (phase 1)

Subject: issue-1. Survey precedes scout per scout-directive's survey-first
order.

## Write surfaces this role already has

- `knowledge-management/hooks/directive.sh` — YOU DECIDE / USE_WHEN /
  PRODUCES / HAND-OFF text, sourced from core's `role-directive.sh`
  (already core-canon reference per issue #2, landed).
- `docs/handbooks/knowledge-management.md` — `write_scope:
  ['docs/patterns/**']` + boundary-case text. No template or format
  guidance for what goes under `docs/patterns/**` — a gap.
- `docs/issue-<n>/reports/knowledge-management.md` — phase-2 record file.
  Gated generically by core's `record-fields-gate.sh` (contract §20
  fields: what-was-done, why, upstream-basis, loop_state, open-findings) —
  not by this role's own `produces` list (issue #2 proposal, item 2, flag
  accepted as intended effect).
- `docs/issue-<n>/proposals/*.md` — phase-1 proposal files. No fixed
  template exists yet; issue-2's proposal is the only precedent in this
  repo, front-mattered `proposal / loop_state / upstream`, freeform body.

## Gaps this issue is meant to close

1. `directive.sh`'s `PRODUCES` line names three artifact kinds ("curated
   pattern-library entry, cross-issue index, supersession note") but no
   file in this repo defines what fields or structure each kind must
   have. `docs/patterns/**` (the write scope) is currently empty.
2. No methodology is specified for *how* a pattern-library entry gets
   curated from raw issue retrospectives (extraction method), nor how the
   cross-issue index is kept navigable, nor what a supersession note must
   contain to be traceable.
3. No fixed methodology or required-section list exists for this role's
   own phase-1 proposals — each proposal currently free-forms its
   structure from the issue text alone.

## Constraint carried from issue-2 (landed)

`warrant-hunter` and generic gates are core-canon references now, not
vendored copies — issue #1's plugin reflection plan must not reintroduce
local copies of anything core already provides generically. Any new
gate/check this issue's phase-2 wants must either extend the handbook
(non-code, unenforced-but-documented) or be justified against core's
existing generic `record-fields-gate.sh`, not a new custom script.
