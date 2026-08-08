---
code_under_review:
  - docs/handbooks/knowledge-management.md
  - km-pattern-entry/hooks/pattern-entry-gate.sh
  - km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh
loop_state: landed
---

# issue-21 implementation record (phase 2)

## What was done

Applied the approved phase-1 proposal (`docs/issue-21/proposals/implementation.md`):

- `docs/handbooks/knowledge-management.md`:
  - Extended the pattern-library entry front-matter list with the spec's
    three field-shaped keys: `article_id`, `capture_point`
    (`at-resolution`|`retroactive`), `reuse_status`
    (`new`|`reused`|`flagged-for-review`), and added the explicit mapping
    note that `article_content` equals the entry's existing five-section
    body (no new section).
  - Replaced the ad hoc `loop_state` mentions with a new "loop_state
    vocabulary (issue-21)" section stating the spec's exact four values
    (`capturing`, `landed`, `not-captured-at-resolution`,
    `article-unreachable`), superseding the prior ad hoc set per issue-2's
    deferred decision.
  - Added the manual self-check item to the phase-2 record self-check:
    confirm any pattern entry with `capture_point: retroactive` this round
    pairs with this record's `loop_state: not-captured-at-resolution`.
- `km-pattern-entry/hooks/pattern-entry-gate.sh`: extended the
  front-matter key-presence check to also require `article_id`,
  `capture_point`, `reuse_status`, and added enum-value validation for
  `capture_point` and `reuse_status`, mirroring the file's existing
  regex/string-match approach (no new dependency).
- `km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh`: added cases
  for missing `article_id`/`capture_point`/`reuse_status`, invalid
  `capture_point`/`reuse_status` enum values, and a full six-key
  valid-front-matter pass case; updated pre-existing fixtures
  (`FULL_CONTENT`, `MISSING_KEYWORDS`, `ORDER_VIOLATION`,
  `replace-all-edit.md`) to carry the three new required keys so they
  keep testing their original assertion instead of failing on the new
  key-presence check.

## What did not work

- `docs/patterns/index.md` (the proposal's fourth write-set file, a short
  header note cross-referencing the new fields) could not be created: the
  repo's board-gate (contract v3 s10, enforced by an out-of-repo core
  plugin hook) refuses any write under `docs/patterns/` — that path is
  not one of the six standing buckets (`_assets`, `decisions`,
  `handbooks`, `proposals`, `reports`, `specs`) nor a `docs/issue-<n>/`
  tree, even though `docs/handbooks/knowledge-management.md`'s own
  `write_scope: ['docs/patterns/**']` and the `km-pattern-entry`/
  `km-cross-index` plugins already target that path. This mismatch
  predates this issue (no `docs/patterns/` content has ever existed in
  git history) and is out of this issue's scope to fix — it is a
  precondition of the role's whole phase-2 artifact norm, not something
  introduced by the issue-21 change. The three other write-set files
  landed as planned; the index.md header note is the one item of "What
  will be done" left undelivered, blocked at the tool layer rather than
  by a design choice.

## Why

Spec required fields and loop_state vocabulary needed a home on the
rulebook's existing methodology without deleting it (issue-21 acceptance
criteria) — the phase-1 proposal chose pattern-entry front matter as the
natural home per its Rationale section, rejecting record-level
frontmatter and a dual-vocabulary loop_state scheme for the reasons
stated there.

## Upstream / basis

- `docs/issue-21/proposals/implementation.md` (approved via issue comment
  `APPROVE issue-21/implementation` from `JiwonJung94`, a listed
  `docs/specs/approvers.md` account).
- `docs/issue-21/reports/implementation/survey.md` (phase-1 survey).
- `docs/reports/2026-08-09-hunt-issue-21-implementation.md` (phase-1
  warrant hunt finding that shaped the proposal's manual-self-check
  constraint, already reflected in the approved proposal).

## Closed checks

- `bash km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh` — 31/31
  passed, including the new missing-key/invalid-enum/valid-full cases.
- `bash km-cross-index/hooks/tests/index-shape-gate.test.sh` — 23/23
  passed (unaffected by this change; run to confirm no regression).
- `bash km-cross-index/hooks/tests/index-pairing-gate.test.sh` — 15/15
  passed (unaffected; regression check).
- `bash km-supersession/hooks/tests/supersession-pairing-gate.test.sh` —
  12/12 passed (unaffected; regression check).
- `bash km-adr-proposal/hooks/tests/adr-shape-gate.test.sh` — 26/26
  passed (unaffected; regression check).
- `grep -ri 'article_id\|capture_point\|article_content\|reuse_status' docs/ README.md`
  — all four field names present in `docs/handbooks/knowledge-management.md`
  (acceptance check 1 satisfied).
- `grep -ri 'loop_state' docs/handbooks/knowledge-management.md` — only
  the spec's four values appear, no stale ad hoc value (acceptance check
  2 satisfied).
- No local `pytest` or repo-root `tests/*.sh` suite exists beyond the
  plugin `hooks/tests/*.test.sh` files run above; `compliance-check.sh`
  referenced by the proposal is a vendored core script not present in
  this repo, so it could not be run directly — `unverifiable: no
  standalone compliance-check.sh test suite present locally` for that
  specific script (acceptance check 3, partially: the plugin test suites
  that exist were run and pass).

## Open findings

None outstanding against this session's changes. The phase-1 warrant hunt
finding (cross-file capture_point/loop_state enforcement gap) was already
resolved by the approved proposal choosing a manual self-check over a new
automated gate — see Constraints in the proposal and the new handbook
section above.

## Rationale for deviations

The `docs/patterns/index.md` change from "What will be done" was not
applied — see "What did not work" above for the blocking cause
(board-gate refusal, a pre-existing repo/tool-layer constraint outside
this issue's write set to fix). Everything else in "What will be done"
was applied as proposed, with no alternative-swap.
