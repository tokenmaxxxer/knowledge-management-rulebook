---
code_under_review:
  - knowledge-management/hooks/tests/lib/test-env-resolve.sh
  - km-adr-proposal/hooks/tests/adr-shape-gate.test.sh
  - km-cross-index/hooks/tests/index-shape-gate.test.sh
  - km-cross-index/hooks/tests/index-pairing-gate.test.sh
  - km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh
  - km-supersession/hooks/tests/supersession-pairing-gate.test.sh
type: fix
breaking: false
verdict: pass
loop_state: landed
---

# Implementation record — issue #24

## Summary of work
Added a shared bash resolver
`knowledge-management/hooks/tests/lib/test-env-resolve.sh` implementing
the canonical test-env resolution convention
(`docs/specs/test-env-resolution.md`, issue #551): check
`$CLAUDE_PLUGIN_ROOT_CORE`, then a caller-supplied sibling `../core`
candidate, else print the SKIP message to stderr and exit 75
(`EX_TEMPFAIL`). Wired it into all 5 gate-test scripts (each of the
issue's frozen write set) right after their existing `SCRIPT_DIR`/`here`
variable is computed, passing that variable's own `../../../core`
sibling-candidate path explicitly into `resolve_core_or_skip`.

## Why
Per the approved proposal (`docs/issue-24/proposals/implementation.md`):
outside the spawn environment, all 5 test files previously reported
misleading per-case `FAIL`s (each case needing `gate-lib.sh` sourced hit
the gate's own fail-closed `exit 2`) instead of an explicit
"unverifiable here" signal. This blurs a real gate-shape regression with
"you're not running in the spawn env," which the on-the-record
convention's SKIP contract exists to separate.

## Upstream basis
docs/issue-24/proposals/implementation.md (commit 13de008)

## What was done (doc-placement / acceptance cross-reference)
- [x] `knowledge-management/hooks/tests/lib/test-env-resolve.sh` added —
  header references `docs/specs/test-env-resolution.md` and issue #551.
- [x] `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh` — sources
  resolver, calls `resolve_core_or_skip "$SCRIPT_DIR/../../../core"`.
- [x] `km-cross-index/hooks/tests/index-shape-gate.test.sh` — sources
  resolver, calls `resolve_core_or_skip "$here/../../../core"`.
- [x] `km-cross-index/hooks/tests/index-pairing-gate.test.sh` — same.
- [x] `km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh` — sources
  resolver, calls `resolve_core_or_skip "$SCRIPT_DIR/../../../core"`.
- [x] `km-supersession/hooks/tests/supersession-pairing-gate.test.sh` —
  same.
- [x] Acceptance check "scripts reference the convention doc" —
  `grep -rl test-env-resolution` over all 6 files matches all 6
  (verified below).
- [x] Acceptance check "with core reachable, all previously-passing
  assertions still pass unchanged" — verified below (26/26, 23/23,
  15/15, 31/31, 12/12, matching the survey's captured baseline).
- [x] Acceptance check "on a plain checkout without
  CLAUDE_PLUGIN_ROOT_CORE, every test script exits with the convention's
  SKIP contract" — verified below (all 5, `SKIP: ...`, rc=75).
- [x] Hunt finding from the after-proposal hunt
  (`docs/issue-24/reports/implementation/hunt-issue-24-implementation.md`,
  stance 4, `design-error`) resolved: the resolver takes the
  sibling-core candidate as an explicit argument computed by each
  caller from its own `SCRIPT_DIR`/`here`, rather than deriving it from
  the shared lib file's own `BASH_SOURCE` location — this is exactly
  the fix the finding called for.

## Verification run (this turn, actually executed)
`bash <each>.test.sh` in the spawn env (CLAUDE_PLUGIN_ROOT_CORE set,
as inherited by this session):
```
adr-shape-gate.test.sh:            26/26 passed, rc=0
index-shape-gate.test.sh:          23 passed, 0 failed, rc=0
index-pairing-gate.test.sh:        15 passed, 0 failed, rc=0
pattern-entry-gate.test.sh:        31 passed, 0 failed, rc=0
supersession-pairing-gate.test.sh: 12 passed, 0 failed, rc=0
```
`env -u CLAUDE_PLUGIN_ROOT_CORE bash <each>.test.sh` (no sibling
`../core` present in this checkout):
```
all 5: "SKIP: core plugin unreachable — unverifiable outside spawn env" (stderr), rc=75
```
`grep -rl test-env-resolution knowledge-management/hooks/tests/lib/ <5 test files>`
matched all 6 changed/added files.

No real defect was found in any of the 5 gate scripts during this pass
— every FAIL observed pre-change was the env-unreachable misleading
failure the issue describes, not a gate-shape bug — so no finding is
recorded in place of a SKIP.

## What did not work
None.

## Open findings
None outstanding. The one hunt finding from the after-proposal pass
(sibling-candidate must be caller-anchored, not lib-anchored) is
resolved by this implementation's explicit-argument design, verified
above. Resolution path: none needed — no unresolved finding remains.

## Next steps
Commit this record and the code changes, push, and open the phase-2 PR
(`Closes #24`). No further build work remains inside this proposal's
frozen write set.

## Rationale for deviations
None — implementation matches the approved proposal's "What will be
done" section exactly, incorporating the after-proposal hunt finding as
the proposal's own text anticipated ("noted for phase-2 build").
