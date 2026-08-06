# Survey — issue-19: remove temp-file dependency from km-cross-index gates

Scout-directive skip: this is a pure bugfix with a fully specified fix
direction and acceptance criteria in the issue text (adopt an existing,
already-landed house pattern; no open design decision). Scouting is
skipped under the "pure bugfix" condition. Survey-order-directive skip:
same condition — the write set below is what the issue itself names.

## Write set (what will change)

- `km-cross-index/hooks/index-pairing-gate.sh` — two bare `mktemp` calls
  (lines 62-63, `status_file`/`only_file`) writing `git diff --cached -z`
  output to scratch files so NUL bytes survive.
- `km-cross-index/hooks/index-shape-gate.sh` — one `mktemp
  "${TMPDIR:-/tmp}/km-cross-index-shape.XXXXXX.py"` call (line 25) writing
  the inline python payload to a scratch file.
- `km-cross-index/hooks/tests/index-pairing-gate.test.sh` — add a
  mktemp-shadowing regression case.
- `km-cross-index/hooks/tests/index-shape-gate.test.sh` — add a
  mktemp-shadowing regression case.

No other files are touched: no schema/env-var/dependency change, no
migration.

## Current state

Both target scripts already source the shared `core/hooks/lib/gate-lib.sh`
and use `gate_trap_fail_closed` / `gate_deny` / `gate_kill_switch_active`.
Two sibling gates in this same repo (`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-pattern-entry/hooks/pattern-entry-gate.sh`) already implement the
target pattern the issue asks for: pass the PreToolUse JSON payload (and
any other needed data) into `python3` via a `KM_*_PAYLOAD`/`KM_*_B64` env
var, feed the python program itself to `python3 <<'PYEOF' ... PYEOF` on
stdin, and communicate results back as `print()`'d lines captured via
`$(...)`. Neither of those two sibling gates writes to any scratch file.
This confirms the fix direction is not a new pattern to invent — it is an
already-proven, already-tested pattern already in this codebase, applied
to the two remaining gates that still use `mktemp`.

### `index-pairing-gate.sh` specifics

The gate needs `git diff --cached -z --name-status` and `--name-only`
output, both NUL-delimited (because staged paths can contain spaces —
covered by test case 6/7 in the existing test file). The two `mktemp`
files exist only because a NUL byte cannot survive a bash `"$(...)"`
command substitution (NUL truncates the C string). The house pattern's
env-var channel has the same problem: env vars are also NUL-terminated
C strings, so raw NUL-delimited git output cannot go through
`KM_..._PAYLOAD=` either.

Fix: don't carry NUL-delimited output through any channel that can't hold
NUL bytes. `git diff -z` is only needed so spaces in a path aren't
ambiguous with the field separator; the pairing check only needs to
know (a) which `docs/patterns/*.md` files were newly added, and (b)
whether `docs/patterns/index.md` is among all staged paths. Piping
`git diff --cached -z --name-status`/`--name-only` directly into
`python3`'s stdin (one process each, buffered in memory, not through an
intermediate bash variable) avoids the NUL-in-env-var problem entirely
without needing a scratch file — python3 reads `sys.stdin.buffer.read()`
as raw bytes, decodes, and splits on `\x00` exactly as the current
in-file logic does. The original PreToolUse JSON payload is small text
(no embedded NULs) and can go through the existing `KM_GATE_PAYLOAD` env
var like the sibling gates.

### `index-shape-gate.sh` specifics

This one is more direct: the python payload text and the JSON payload are
both ordinary UTF-8 text with no NUL-byte concern. This is a straight
swap onto the same `python3 <<'PYEOF' ... PYEOF` + env-var pattern
`adr-shape-gate.sh` already uses — no scratch file, no `TMPDIR` fallback.

## Existing test harness conventions (from index-pairing-gate.test.sh /
index-shape-gate.test.sh)

- Bash script, `set -uo pipefail`, hand-rolled `run_case`/`record`
  pass/fail counters, exits 1 if any case failed.
- Cases run the gate as a subprocess via `CLAUDE_PROJECT_DIR=... "$gate"`
  with JSON piped on stdin.
- `mktemp -d` is already used inside the *test* harnesses themselves (to
  build scratch git repos) — that is unrelated to the gate's own runtime
  path and is not in scope to change (the issue only asks to remove
  mktemp from "gate hook runtime paths").
- Neither test file currently has a PATH-shadowing case. The #54-style
  regression test (per the issue's acceptance criteria) needs: a fake
  `mktemp` binary placed earlier on `PATH` that always exits non-zero
  (simulating the sandbox-denied write), run the gate with that PATH, and
  assert the gate still allows/denies correctly (i.e., does not depend on
  `mktemp` succeeding). This must fail against the pre-fix scripts and
  pass after.

## Unknowns / risks

- None outstanding — the fix direction, target files, and test shape are
  all fully determined by the issue text plus the two already-landed
  sibling gates in this same repo.
