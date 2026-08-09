# Survey — issue #24: adopt test-env resolution convention

## Convention source
Fetched verbatim from `tokenmaxxxer/on-the-record`
`docs/specs/test-env-resolution.md` (issue #551). Key points:

- Resolution order: `$CLAUDE_PLUGIN_ROOT_CORE` (if it contains
  `hooks/lib/gate-lib.sh`) -> first caller-supplied sibling candidate
  containing `hooks/lib/gate-lib.sh` -> SKIP.
- SKIP contract: print `SKIP: core plugin unreachable — unverifiable
  outside spawn env` to stderr, exit `75` (`EX_TEMPFAIL`), distinct from
  a gate's own 0/1/2.
- Reference implementation is a Python module
  (`gates/test_env_resolve.py`) living in the on-the-record repo itself.
  Adoption guidance names two consumer shapes: a bash test runner
  invokes it as a CLI subprocess; a pytest suite imports it directly.
  Neither shape matches this repo directly — see below.
- Explicitly out of scope in the spec doc: "Adopting this convention
  inside the 23 rulebook repos' own gate-test scripts — that is separate
  work per repo, tracked in each repo's own issue/PR." This issue (#24)
  is that per-repo adoption work for this rulebook.

## This repo's actual test shape
No Python, no pytest, no existing dependency on the on-the-record repo.
All 5 test scripts are plain bash, found at:

- `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh`
- `km-cross-index/hooks/tests/index-shape-gate.test.sh`
- `km-cross-index/hooks/tests/index-pairing-gate.test.sh`
- `km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh`
- `km-supersession/hooks/tests/supersession-pairing-gate.test.sh`

Each spawns its own gate script as a subprocess (`bash "$GATE"` /
`run_gate`/`run_case` helpers) and asserts on exit codes + stdout/stderr.
Each gate script (`*-gate.sh`, one per test file, all under
`km-*/hooks/`) opens with the same one-line pattern:

```sh
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate>: cannot source gate-lib.sh" >&2; exit 2; }
```

`knowledge-management/hooks/directive.sh` uses the identical fallback
pattern but is a runtime hook, not a test script — out of the issue's
acceptance scope (which names "gate-test scripts").

## Confirmed failure mode (reproduced)
With `CLAUDE_PLUGIN_ROOT_CORE` set (spawn env, current session):
`adr-shape-gate.test.sh` -> 26/26 passed.

With `CLAUDE_PLUGIN_ROOT_CORE` unset and no sibling `../../core` checkout
(`env -u CLAUDE_PLUGIN_ROOT_CORE bash ...test.sh`): 17/26 passed, 9
FAILs, all of the shape `FAIL - <case> (expected rc=0/1, got rc=2)` with
stderr `adr-shape-gate.sh: cannot source gate-lib.sh` — i.e. every case
that actually needs `gate-lib.sh` sourced reports as a false gate-shape
failure instead of "environment unreachable". One case in each file
("missing-core: ... denies") deliberately points
`CLAUDE_PLUGIN_ROOT_CORE` at a nonexistent path and asserts the gate's
own fail-closed exit(2) — that assertion is about the gate's own
defensive code, not about the ambient spawn env, and holds regardless of
whether real core is reachable.

## Existing SKIP precedent in this ecosystem
The spec doc names `gates/skip_gate.py` (on-the-record repo) as
precedent for making skip a distinct, non-green signal, and separately
carves out an "empty state" exception: a test suite with no core
dependency at all is out of scope for the convention. None of this
repo's 5 test files fall into that exception — all 5 depend on sourcing
`gate-lib.sh` through their gate script.

## Write-set implications
- No Python is introduced — vendoring/depending on the on-the-record
  repo's `gates` package would add a cross-repo dependency this repo has
  never had; the spec doc itself frames per-repo adoption as separate
  work, not literal package reuse. The right adoption for a bash-only
  consumer is a small bash re-implementation of the same order + SKIP
  contract (env var -> sibling candidate `../../core` relative to repo
  root, matching the gate scripts' own existing fallback -> SKIP exit
  75), referenced back to the spec doc so `grep test-env-resolution`
  finds it (acceptance check #3).
- Candidate shared code location: a new
  `knowledge-management/hooks/tests/lib/test-env-resolve.sh` (sourced by
  all 5 test files) is the natural single point, since all 5 already
  live under differing `km-*/hooks/tests/` dirs with no shared lib today
  — a copy-pasted resolver in each of the 5 files would violate DRY for
  no reason. This new shared file is in-scope for the write set even
  though the issue's acceptance criteria enumerate only the 5 test
  files, because the 5 files need something to source.
- Each of the 5 test files needs a small edit at its top: source the
  shared resolver, resolve core, and if unreachable, print the SKIP
  message and `exit 75` before running any gate-lib-dependent case. The
  "missing-core denies" case in each file does not depend on real core
  and is unaffected either way.

## Alternatives considered (for the proposal's Rationale)
1. Reimplement the SKIP resolution logic separately inside each of the 5
   test files (no shared lib).
2. Shell out to `python3 -m gates.test_env_resolve` from the
   on-the-record repo, added as a fetched/vendored dependency.
3. A single shared bash resolver sourced by all 5 test files (chosen —
   see proposal).
