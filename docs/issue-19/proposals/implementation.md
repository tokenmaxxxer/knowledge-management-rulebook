files:
- km-cross-index/hooks/index-pairing-gate.sh
- km-cross-index/hooks/index-shape-gate.sh
- km-cross-index/hooks/tests/index-pairing-gate.test.sh
- km-cross-index/hooks/tests/index-shape-gate.test.sh

## Request

Remove the temp-file dependency from the two `km-cross-index` gate hooks
that still use `mktemp`: `index-pairing-gate.sh` (two bare `mktemp` calls,
the exact `product-discovery-rulebook#54` bug — fails closed under
sandboxed role sessions) and `index-shape-gate.sh` (a `TMPDIR`-templated
`mktemp` that survives only when `$TMPDIR` happens to be set to a
sandbox-writable dir). Adopt the pattern `#54` already landed elsewhere:
payload/data via env vars, python3 program fed on stdin via a
`<<'PYEOF' ... PYEOF` heredoc, no scratch files. Add a `#54`-style
mktemp-shadowing regression test per gate; keep the full existing gate
test suite green.

## Constraints

- No new dependency, no new env var beyond the gate-internal
  `KM_*_PAYLOAD`/`KM_*_B64` channel names already used by sibling gates.
- No behavior change for any currently-passing test case in either
  existing test file — this is a mechanism swap, not a logic change.
- `index-pairing-gate.sh` must keep handling staged paths containing
  spaces correctly (NUL-delimited `git diff -z` semantics), since the
  existing test suite already covers that case.
- Runtime path only: `mktemp` used inside the test harness itself (to
  build scratch git repos) is out of scope — the issue's acceptance
  criterion is "no mktemp ... remains in gate hook runtime paths."

## Rationale

Chosen approach: replace both gates' scratch-file usage with the
env-var + stdin-heredoc pattern already used by
`km-adr-proposal/hooks/adr-shape-gate.sh` and
`km-pattern-entry/hooks/pattern-entry-gate.sh` in this same repo, piping
`git diff --cached -z` output straight into a `python3` subprocess's
stdin (instead of through an intermediate file) for the pairing gate's
NUL-delimited data.

Alternative considered and rejected: harden the existing `mktemp
"${TMPDIR:-/tmp}/..."` calls instead of removing them — e.g. require
`TMPDIR` to be set and fail closed if it is unset, or always use
`CLAUDE_PROJECT_DIR` as the scratch directory. Rejected because it does
not fix `index-pairing-gate.sh`'s bare `mktemp` calls at all (those have
no template to harden — a templateless `mktemp` resolves outside the
sandbox's writable set regardless of `TMPDIR`), and it would leave this
repo with two different gate patterns (temp-file-based here vs. the
already-proven no-scratch-file pattern in `adr-shape-gate.sh` /
`pattern-entry-gate.sh`), increasing future maintenance divergence for
no benefit — the no-scratch-file pattern already exists, is already
tested, and already handles the payload-reconstruction cases these gates
need.

## What will be done

- `index-pairing-gate.sh`: replace the two `mktemp` + `git diff -z >file`
  + python-reads-two-files sequence with a single `python3 <<'PYEOF'`
  invocation. `git diff --cached -z --name-status` and `--name-only`
  output are piped directly into that python3 process's stdin (concatenated
  with a delimiter python can split on, since exactly two NUL-delimited
  streams are needed and stdin is a single channel) rather than captured
  into a bash variable or scratch file, preserving NUL-safe handling of
  spaced paths. The PreToolUse JSON payload continues through a
  `KM_*_PAYLOAD` env var as the sibling gates already do.
- `index-shape-gate.sh`: replace the `mktemp` + `cat > "$pyscript" <<'PYEOF'`
  + `python3 "$pyscript"` + `rm -f "$pyscript"` sequence with the direct
  `python3 <<'PYEOF' ... PYEOF` form `adr-shape-gate.sh` already uses,
  with the PreToolUse JSON payload passed via env var.
- `index-pairing-gate.test.sh` / `index-shape-gate.test.sh`: add one
  regression case each that shadows `mktemp` on `PATH` (a script earlier
  on `PATH` named `mktemp` that always exits non-zero) scoped to the gate
  subprocess invocation, and asserts the gate still produces the correct
  allow/deny verdict. Verify each new case fails against the pre-fix
  script and passes after the fix (manual `git stash`/toggle check during
  implementation, not a permanent dual-mode test).
- Run both test files (and the full existing gate suite, to catch any
  cross-gate regression) and confirm all cases pass before delivering.

## Out of scope

- Any other gate in this repo (`km-adr-proposal`, `km-pattern-entry`,
  `km-supersession`) — none of them use `mktemp` in their runtime path
  per the current-state survey.
- `mktemp` usage inside test harnesses themselves (building scratch git
  repos) — not a gate runtime path.
- Any change to `core/hooks/lib/gate-lib.sh` or `gate-lib.py` — this repo
  does not vendor the `core` plugin; both gates already source it via the
  existing `CLAUDE_PLUGIN_ROOT_CORE` fallback, and issue #19 does not ask
  for changes there.

## How you'll know it worked

- `grep -n mktemp km-cross-index/hooks/index-pairing-gate.sh
  km-cross-index/hooks/index-shape-gate.sh` returns nothing.
- The new mktemp-shadowing regression case in each test file fails when
  run against the pre-fix script and passes against the post-fix script.
- `km-cross-index/hooks/tests/index-pairing-gate.test.sh` and
  `km-cross-index/hooks/tests/index-shape-gate.test.sh` both exit 0 with
  zero failures, and running every other gate's existing test file in the
  repo still exits 0 (no cross-gate regression).
