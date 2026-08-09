---
status: proposed
files:
  - knowledge-management/hooks/tests/lib/test-env-resolve.sh
  - km-adr-proposal/hooks/tests/adr-shape-gate.test.sh
  - km-cross-index/hooks/tests/index-shape-gate.test.sh
  - km-cross-index/hooks/tests/index-pairing-gate.test.sh
  - km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh
  - km-supersession/hooks/tests/supersession-pairing-gate.test.sh
---

## Request
Adopt the canonical test-env resolution convention
(on-the-record `docs/specs/test-env-resolution.md`, issue #551) in this
rulebook's 5 gate-test scripts, so that outside the spawn environment
(no `CLAUDE_PLUGIN_ROOT_CORE`, no sibling `core` checkout) each script
exits with the convention's SKIP contract — explicit message, distinct
exit code — instead of reporting misleading per-case FAILs. Assertions
that run when core is reachable must not weaken.

## Constraints
- Resolution order per the spec: `$CLAUDE_PLUGIN_ROOT_CORE` (if it
  contains `hooks/lib/gate-lib.sh`) -> caller-supplied sibling
  candidate(s) -> SKIP.
- SKIP contract: stderr message
  `SKIP: core plugin unreachable — unverifiable outside spawn env`, exit
  code `75` (`EX_TEMPFAIL`) — distinct from a gate's own 0/1/2.
- No network fetch fallback (spec explicitly excludes it from the
  canonical contract).
- Do not weaken any assertion that runs when core IS reachable.
- A script's real defect must still surface as a finding, never masked
  by SKIP.

## Rationale
The spec's reference implementation is a Python module
(`gates/test_env_resolve.py`) living in the on-the-record repo, with two
named adoption shapes: a bash runner invokes it as a CLI subprocess, a
pytest suite imports it. This repo has neither Python nor any existing
dependency on the on-the-record repo.

Considered shelling out to `python3 -m gates.test_env_resolve` by
vendoring or fetching that module into this repo. Rejected: it would
introduce a cross-repo runtime dependency (a Python interpreter
requirement, plus a copy of another repo's module to keep in sync) that
this all-bash rulebook has never had, for a resolution algorithm simple
enough to express directly in the language the 5 test files are already
written in. The spec doc itself frames per-repo adoption as separate
work ("Out of scope: Adopting this convention inside the 23 rulebook
repos' own gate-test scripts... tracked in each repo's own issue/PR"),
not literal package reuse — so a same-language reimplementation of the
same order + SKIP contract is the intended adoption path for a bash-only
consumer, not a deviation from the convention.

Considered reimplementing the SKIP logic separately, copy-pasted, inside
each of the 5 test files. Rejected: all 5 files need the identical
env-var -> sibling-candidate -> SKIP logic; a single shared resolver
sourced by all 5 avoids 5 copies drifting out of sync, at the cost of
one new small file outside the issue's literally-enumerated write set
(justified in the survey as something the 5 files need to source).

## What will be done
- Add `knowledge-management/hooks/tests/lib/test-env-resolve.sh`: a
  sourceable bash function implementing the spec's resolution order
  (env var check via file-exists-and-nonempty on
  `<candidate>/hooks/lib/gate-lib.sh`, then the sibling candidate
  `<script's repo root>/../core`, matching the existing gate scripts'
  own `../../core` fallback), printing the SKIP message to stderr and
  returning a SKIP status when neither resolves. The file's header
  comment references `docs/specs/test-env-resolution.md` and issue
  #551 by name (satisfies the `grep test-env-resolution` acceptance
  check).
- Edit each of the 5 `*.test.sh` files: source the shared resolver near
  the top, resolve core before running any case that depends on
  `gate-lib.sh` being sourced successfully. If resolution SKIPs, print
  the SKIP message and `exit 75` immediately, before executing the
  gate-dependent cases. The existing "missing-core: ... denies" case in
  each file (which points `CLAUDE_PLUGIN_ROOT_CORE` at a bogus path on
  purpose, to assert the gate's own fail-closed exit(2)) is unaffected —
  it does not depend on real core being reachable and keeps running and
  asserting exactly as it does today, in both the core-reachable and
  core-unreachable case.
- All other existing cases and their expected exit codes/messages are
  left byte-for-byte unchanged; only the SKIP guard is added above them.

## Out of scope
- `knowledge-management/hooks/directive.sh` (a runtime hook, not a test
  script — the issue's acceptance criteria name "gate-test scripts").
- Vendoring or depending on the on-the-record repo's Python `gates`
  package.
- Any change to the gate scripts themselves (`*-gate.sh`) or to
  `gate-lib.sh`'s own sourcing fallback — the issue targets the tests,
  not the gates' production sourcing behavior.
- A shared cross-rulebook resolver library published outside this repo
  — each of the 23 rulebook repos adopts independently per the spec
  doc's own "out of scope" note.

## How you'll know it worked
- `env -u CLAUDE_PLUGIN_ROOT_CORE bash <each>.test.sh` (run from a
  checkout with no sibling `../core`) prints the SKIP message to stderr
  and exits `75` for all 5 files — reproducing today's 9-FAIL breakage
  from the survey as a single SKIP instead.
- `CLAUDE_PLUGIN_ROOT_CORE=<real core path> bash <each>.test.sh` (spawn
  env, as today) still reports the same pass/fail counts and messages as
  the pre-change baseline captured in the survey (e.g. 26/26 for
  `adr-shape-gate.test.sh`).
- `grep -rl test-env-resolution knowledge-management/hooks/tests/lib/
  km-*/hooks/tests/*.test.sh` matches all 6 changed/added files.
