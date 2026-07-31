---
record: docs/issue-2/reports/implementation.md
subject: issue-2
loop_state: landed
upstream: [docs/issue-2/proposals/2026-07-31-core-canon-reference-conversion.md]
---

# Record — core canon reference conversion (issue #2)

Subject: issue-2. Phase 2 output — proposal approved via issue comment
`APPROVE issue-2/implementation`.

## Why

core issue #63 (warrant plugin) and core issue #66 (role-agnostic gates +
`role-directive.sh` boilerplate) landed a single canon for content this
rulebook had vendored independently. Converting to references removes
drift risk (issue-66's survey found 38/40 unique hashes across vendored
copies) and must land before this repo's own "rulebook 성숙화" phase 2, per
the issue's ordering constraint.

## What was done

Executed the approved proposal's 5-item list in one batch:

1. Deleted `knowledge-management/agents/warrant-hunter.md`. Core's
   `warrant` plugin (`tokenmaxxxer-core/warrant/agents/warrant-hunter.md`)
   is the canon replacement, installed alongside this rulebook rather than
   vendored. Added a Layout line in `README.md` pointing at it.
2. Deleted `knowledge-management/hooks/trailer-gate.sh`,
   `record-fields-gate.sh`, `handbook-trigger-gate.sh` and removed their
   `PreToolUse` entries from `knowledge-management/hooks/hooks.json`.
   Core's own `hooks.json` (installed with the `core` plugin) fires all
   three globally, parameterized on `CLAUDE_ROLE`. Left the pre-existing
   `knowledge-management-progress-gate.sh` entry (dangling reference to a
   file that does not exist in this repo) untouched — out of scope per the
   proposal.
3. Replaced `knowledge-management/hooks/directive.sh` with the stub form:
   sources `core/hooks/lib/role-directive.sh`, assigns the four role-unique
   values (`you_decide`, `use_when`, `produces`, `hand_off`) to variables,
   calls `core_role_directive` with them. `write_scope` and the BOUNDARY
   CASE text (not among `core_role_directive`'s four parameters) moved
   verbatim into new `docs/handbooks/knowledge-management.md`.
4. Did not set `RECORD_FIELDS_TERMINAL_STATES` — adopted core canon's
   default terminal state (`landed`), per the proposal's decision. No
   divergent `loop_state` vocabulary exists for this role to preserve.
5. Ran `core/hooks/tests/stub-check.sh` against
   `knowledge-management/hooks` (see Verification below).

## Upstream basis

- `docs/issue-2/proposals/2026-07-31-core-canon-reference-conversion.md`
  (this repo, approved proposal)
- core issue #63 → PR #65 (warrant plugin)
- core issue #66 → PR #68 (role-agnostic gates + role-directive.sh)

## Verification

```
$ bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh knowledge-management/hooks
stub-check: ok — no vendored 'trailer-gate.sh' under knowledge-management/hooks
stub-check: ok — no vendored 'record-fields-gate.sh' under knowledge-management/hooks
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under knowledge-management/hooks
stub-check: ok — no vendored 'parse-check.sh' under knowledge-management/hooks
stub-check: ok — knowledge-management/hooks/directive.sh is a role-directive stub
```

Exit code 0. All five checks pass.

Note: the proposal's literal directive.sh form (one `core_role_directive`
call with backslash-continued string arguments) fails `stub-check.sh`'s
line-by-line structural scan, because each continuation line matches
neither the source-line, `core_role_directive`, nor bare-variable-assignment
patterns the check allow-lists. Rewrote as four `name="value"` variable
assignments followed by a single-line `core_role_directive "$a" "$b" "$c"
"$d"` call — same four values, same function, form the check recognizes.

## loop_state

`landed` (this record, terminal — see frontmatter). Adopting core canon's
default terminal state per item 4 above; no role-specific
`RECORD_FIELDS_TERMINAL_STATES` set.

## Open findings

None beyond the two the proposal already flagged and decided (item 2's
required-field semantics change from role-specific `produces` fields to
generic contract §20 fields; item 4's terminal-state default) — both
carried through unchanged in execution.
