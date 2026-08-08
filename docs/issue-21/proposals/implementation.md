files:
- docs/handbooks/knowledge-management.md
- km-pattern-entry/hooks/pattern-entry-gate.sh
- km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh
- docs/patterns/index.md

## Request

Align this rulebook with the realized marketplace spec
`roles/specs/knowledge-management.spec.json` (on-the-record repo, fetched
in the phase-1 survey). Layer the spec's four required deliverable fields
(`article_id`, `capture_point`, `article_content`, `reuse_status`) and its
`loop_state` vocabulary (`article-unreachable`, `capturing`, `landed`,
`not-captured-at-resolution`) onto existing rulebook docs/hooks,
strengthening current methodology rather than replacing it. Phase 1 only:
propose the mapping; apply it in phase 2 after approval.

## Constraints

- Never delete existing methodology (Context/Problem/Why/Solution/
  Consequences body, ADR-shape phase-1 norm, supersession pairing) — spec
  fields layer on top.
- No new plugin, no new gate script file — extend the existing
  `km-pattern-entry` gate/handbook, matching issue-1's precedent of not
  vendoring a role-specific gate where an existing enforcement point can
  carry the check.
- `article_id` must resolve to a real KB article file per the spec's
  `reference_resolution` rule; that resolution check itself is enforced
  by `on-the-record/hooks/role-spec-reference-guard.sh`, which lives
  outside this repo — out of scope here, only the field's presence and
  shape are this rulebook's concern.
- `capture_point: retroactive` must surface as a refusal `loop_state`
  (`not-captured-at-resolution`), never a silent pass — per the spec's
  own `recomputation` rule.
- `RECORD_FIELDS_TERMINAL_STATES` stays unset: the spec's terminal set
  (`{landed}`) already equals core's default: no env override needed.

## Rationale

Chosen approach: add the four spec fields as **pattern-entry front-matter
keys** (`article_id`, `capture_point`, `reuse_status`) plus an explicit
mapping note for `article_content` (already satisfied by the existing
five-section body — no structural change needed there), and replace the
loop_state vocabulary section with the spec's exact four values.

Alternative considered and rejected: model the four spec fields as new
**record-level** frontmatter on `docs/issue-<n>/reports/knowledge-management.md`
instead of pattern-entry frontmatter. Rejected because the spec's
`write_scope` is exactly that record path, and the KCS "article" the spec
is modeling is the pattern-library entry's *content*, not the record
that reports on producing it — putting `article_id`/`article_content` on
the record instead of the article itself would make `article_id` point
at nothing resolvable (violating `reference_resolution`) and would
duplicate `article_content` as a copy of the entry body rather than a
reference to it. Pattern-entry frontmatter is the field's natural home;
the record instead gains a short mapping note (not new fields) pointing
at which pattern entry satisfies which spec field for that issue.

Second alternative considered and rejected for `loop_state` specifically:
keep the current ad hoc vocabulary (`proposed`/`open`/`phase-1`/
`delivered`/`landed`) and treat the spec's four values as an *additional*
vocabulary used only when the marketplace integration is active.
Rejected because issue-2 already flagged this exact ambiguity as
unresolved ("no evidence exists of this role needing a terminal state
other than `landed`... if phase-2 execution surfaces a genuine
divergence, set the env var explicitly, with the reason recorded") — a
realized spec from the marketplace program is that divergence evidence,
and running two vocabularies in parallel would make every future record
ambiguous about which set applies. One vocabulary, replacing the ad hoc
set, is simpler and matches the spec exactly.

## What will be done

- `docs/handbooks/knowledge-management.md`:
  - Extend the pattern-library entry template's front matter list with
    `article_id` (ref — this entry's own resolvable identifier, e.g. its
    own path), `capture_point` (enum `at-resolution` | `retroactive`),
    `reuse_status` (enum `new` | `reused` | `flagged-for-review`).
  - Add one line mapping `article_content` explicitly to the existing
    five-section body (Context..Consequences) — no new section, a named
    equivalence.
  - Replace the ad hoc `loop_state` mentions in this handbook's
    phase-2 self-check with the spec's four-value vocabulary
    (`capturing` = progress / `landed` = terminal /
    `not-captured-at-resolution` = refusal, used when `capture_point:
    retroactive` / `article-unreachable` = error, used when a pattern
    entry's `article_id` fails to resolve) and state this is now the
    role's fixed vocabulary, superseding the prior ad hoc set per
    issue-2's deferred decision.
- `km-pattern-entry/hooks/pattern-entry-gate.sh`: extend the front-matter
  key check from `("title", "keywords", "source_issues")` to also
  require `article_id`, `capture_point`, `reuse_status`; add enum-value
  validation for `capture_point` (`at-resolution`|`retroactive`) and
  `reuse_status` (`new`|`reused`|`flagged-for-review`) mirroring the
  existing key-presence pattern (no new dependency, same regex/string
  approach already in the file).
- `km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh`: add cases —
  missing each new key denied; invalid enum value denied; valid full
  front matter (all six keys, both enums valid) allowed.
- `docs/patterns/index.md`: add a short header note cross-referencing
  that each row's pattern entry now also carries the four spec fields,
  so the index and entry stay in sync without duplicating the fields
  into the index table itself (index stays name/keywords/source_issues/
  status per `km-cross-index`'s existing shape gate, untouched).

## Out of scope

- `on-the-record/hooks/role-spec-reference-guard.sh` and any
  `reference_resolution`/`recomputation` enforcement code — both live
  outside this repo per the spec's own `checked_by` fields (the second
  is explicitly `TBD`, a stated follow-up in the spec itself).
- `km-cross-index` and `km-supersession` plugin logic — the spec's four
  fields and loop_state vocabulary land on the pattern-entry gate and
  handbook only; the index-shape/pairing and supersession-pairing gates
  check unrelated shape and are not spec targets.
- `core/contract/role-handoff-contract.md` §2's kind table — adding this
  role's kind there belongs to core's own repo, restated from issue-2's
  own out-of-scope note; this proposal only fixes this repo's own
  documented vocabulary.
- Rewriting or migrating existing pattern entries under `docs/patterns/`
  to backfill the three new fields — none exist yet in this repo
  (`docs/patterns/` currently holds no entries beyond scaffolding), so
  there is nothing to migrate; the gate applies going forward.

## How you'll know it worked

- `grep -ri 'article_id\|capture_point\|article_content\|reuse_status' docs/ README.md`
  returns hits in `docs/handbooks/knowledge-management.md` (all four
  field names present per the issue's acceptance check).
- `grep -ri 'loop_state' docs/handbooks/knowledge-management.md` shows
  only the spec's four values (`article-unreachable`, `capturing`,
  `landed`, `not-captured-at-resolution`), no stale ad hoc value
  reintroduced.
- `bash km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh` passes,
  including the new missing-key/invalid-enum/valid-full-frontmatter
  cases.
- `bash core/hooks/tests/compliance-check.sh` (if present via installed
  core plugin) still passes against the modified gate, matching the
  handbook's existing claim that all gate scripts run clean against it.
