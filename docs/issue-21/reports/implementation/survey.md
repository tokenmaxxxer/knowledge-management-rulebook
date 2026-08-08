# Survey — issue #21 (phase 1)

Scout skip: pure vocabulary/schema-alignment task against an already-fixed
external spec (`roles/specs/knowledge-management.spec.json`, on-the-record
repo) — no product-shaped design decision is open; the field mapping is
dictated by the spec text itself. Scouting the KCS field is also
unnecessary: the spec's own `source_standard` already cites KCS Solve loop,
and issue-1's prior scout (`docs/issue-1/reports/knowledge-management/scout-brief.md`)
already grounded this role's methodology in that same standard.

## Spec fetched

`gh api repos/tokenmaxxxer/on-the-record/contents/roles/specs/knowledge-management.spec.json`:

- required_fields: `article_id` (ref), `capture_point` (enum:
  at-resolution/retroactive), `article_content` (string), `reuse_status`
  (enum: new/reused/flagged-for-review)
- reference_resolution: `article_id` must resolve to a real KB article
  file — checked by `on-the-record/hooks/role-spec-reference-guard.sh`
  (lives in the on-the-record repo, not here)
- recomputation: `capture_point` must equal `at-resolution`; a retroactive
  capture is a refusal state. `checked_by: TBD` (explicitly a follow-up,
  out of scope per the spec's own note)
- write_scope: `docs/issue-<n>/reports/knowledge-management.md`
- loop_state: progress=[capturing], terminal=[landed],
  refusal=[not-captured-at-resolution], error=[article-unreachable]
- use_when.board_condition: issue reaches resolution AND no KM record
  exists yet for that resolution

## Current rulebook state

- `docs/handbooks/knowledge-management.md`: defines phase-2 artifact
  templates — pattern-library entry (front matter: `title`, `keywords`,
  `source_issues`, `supersedes`/`superseded_by`; body: Context / Problem /
  Why / Solution / Consequences), cross-issue index row, supersession
  note. No `article_id`, `capture_point`, or `reuse_status` field exists
  anywhere in this template.
- `km-pattern-entry/hooks/pattern-entry-gate.sh`: mechanically requires
  front-matter keys `title`, `keywords`, `source_issues` and the five
  body headings in order/adjacent. Does not check any spec-required field
  name.
- `loop_state` vocabulary: **no fixed vocabulary exists for this role**
  (confirmed twice — issue-1's record uses `landed`; issue-2's proposal
  explicitly notes "this role has no loop_state vocabulary defined
  anywhere yet" and defers it). Observed ad hoc values across past
  records/proposals: `proposed`, `open`, `phase-1`, `delivered`,
  `landed`. `RECORD_FIELDS_TERMINAL_STATES` is unset — core's default
  terminal set `{"landed"}` applies, which already matches the spec's
  `terminal: [landed]`.
- `knowledge-management/hooks/directive.sh`: PRODUCES line lists the
  three phase-2 artifacts (pattern entry, cross-issue index, supersession
  note) but no field-level detail — field detail lives in the handbook
  per issue-1's design, not the directive stub.
- No local gate currently checks `loop_state` values against a fixed set;
  `core/hooks/record-fields-gate.sh` (vendored, not in this repo) reads
  `RECORD_FIELDS_TERMINAL_STATES` only for terminal-state matching, not a
  full progress/refusal/error vocabulary check.

## Gaps this proposal must close (spec field -> rulebook home)

- `article_id`: no current home. Needs a new pattern-entry front-matter
  field (or article_content record field) since KCS "article" = the
  pattern-library entry itself.
- `capture_point`: no current home. Needs a new field distinguishing
  at-resolution vs. retroactive capture, and the retroactive value must
  map onto a refusal loop_state, not a silent pass.
- `article_content`: already exists in substance (the five-section body,
  Context..Consequences already carries the article's substantive
  content) — only needs the mapping stated explicitly, not a new
  structure.
- `reuse_status`: no current home. Nearest existing mechanism
  (`supersedes`/`superseded_by`) is related but not equivalent —
  supersession tracks entry-to-entry replacement, `reuse_status` tracks
  whether *this* capture act reused/authored/needs-review.
- `loop_state` vocabulary: current ad hoc set must be replaced by the
  spec's exact four values, mapped to contract kinds
  (progress/terminal/refusal/error) — this is the one item with a
  genuine prior decision to revisit (issue-2 deferred it pending
  "phase-2 execution surfaces a genuine divergence"; this issue is that
  divergence).
