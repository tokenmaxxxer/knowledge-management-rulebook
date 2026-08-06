---
record: docs/issue-19/reports/implementation.md
subject: issue-19
loop_state: landed
upstream: [docs/issue-19/proposals/implementation.md]
code_under_review: [km-cross-index/hooks/index-pairing-gate.sh, km-cross-index/hooks/index-shape-gate.sh, km-cross-index/hooks/tests/index-pairing-gate.test.sh, km-cross-index/hooks/tests/index-shape-gate.test.sh]
---

# Record — remove mktemp from km-cross-index gates (issue #19)

Subject: issue-19. Phase 2 output — proposal (PR #20) approved via issue
comment `APPROVE issue-19/implementation`.

## Why

`tokenmaxxxer/product-discovery-rulebook#54` established that a gate
hook writing its inline python payload to a `mktemp` scratch file fails
closed on every write under a Claude Code sandboxed role session (a
templateless `mktemp` resolves outside the sandbox's writable set).
`index-pairing-gate.sh` has the exact bare-`mktemp` bug;
`index-shape-gate.sh` has the weaker `TMPDIR`-templated variant that only
survives when `$TMPDIR` happens to be sandbox-writable. Removing both
closes this repo's instance of the defect class and matches the
already-proven no-scratch-file pattern this repo's other gates use.

## What was done

1. `index-pairing-gate.sh`: replaced the two `mktemp` scratch files
   (`status_file`, `only_file`) with a `python3 <<'PYEOF' … PYEOF`
   heredoc. The two NUL-delimited `git diff --cached -z` streams
   (`--name-status`, `--name-only`) are piped directly into `base64`
   (never captured raw into a bash variable, which would silently strip
   embedded NUL bytes) and the resulting NUL-free base64 text is passed
   in via `KM_PAIRING_STATUS_B64` / `KM_PAIRING_ONLY_B64` env vars; the
   python payload decodes and NUL-splits them. `git diff` failures are
   now checked via `PIPESTATUS[0]` (the exit status of `git`, not
   `base64`) so a failed diff still fails closed.
2. `index-shape-gate.sh`: replaced the `mktemp "${TMPDIR:-/tmp}/…".py` +
   `cat > file` + `python3 file` + `rm -f file` sequence with the direct
   `python3 <<'PYEOF' … PYEOF` form `adr-shape-gate.sh` already uses; the
   PreToolUse JSON payload travels via a base64 `KM_SHAPE_PAYLOAD_B64`
   env var and project root via `KM_SHAPE_ROOT`, matching the sibling
   gate's pattern.
3. Added one mktemp-shadowing regression case to each test file
   (`index-pairing-gate.test.sh` case 14, `index-shape-gate.test.sh`'s
   new case): a fake `mktemp` binary that always exits 1 is prepended to
   `PATH` around a gate invocation that should otherwise pass; both
   assert the gate still allows. Verified manually against the pre-fix
   scripts (via `git show HEAD:…` copies pointed at by a redirected test
   file) that both new cases fail there (`rc=2`, "mktemp: shadowed...")
   and pass against the post-fix scripts.
4. Ran both modified test files individually, then the full existing
   gate suite across the repo (`km-supersession`, `km-adr-proposal`,
   `km-cross-index` x2, `km-pattern-entry`) for cross-gate regression.

## Upstream basis

- `docs/issue-19/proposals/implementation.md` (this repo, approved
  proposal, PR #20)
- `tokenmaxxxer/product-discovery-rulebook#54` (prior art for the
  no-scratch-file pattern)
- `km-adr-proposal/hooks/adr-shape-gate.sh` (in-repo sibling pattern
  followed verbatim)

## Verification

```
$ grep -n mktemp km-cross-index/hooks/index-pairing-gate.sh km-cross-index/hooks/index-shape-gate.sh
(no output)

$ bash km-cross-index/hooks/tests/index-pairing-gate.test.sh
index-pairing-gate.test.sh: 15 passed, 0 failed   (rc=0)

$ bash km-cross-index/hooks/tests/index-shape-gate.test.sh
index-shape-gate.test.sh: 23 passed, 0 failed      (rc=0)

$ bash km-supersession/hooks/tests/supersession-pairing-gate.test.sh
summary: 12 passed, 0 failed                       (rc=0)

$ bash km-adr-proposal/hooks/tests/adr-shape-gate.test.sh
26/26 passed                                        (rc=0)

$ bash km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh
SUMMARY: 25 passed, 0 failed                        (rc=0)
```

Pre-fix check (manual, per proposal's "Verify each new case fails
against the pre-fix script and passes after the fix"): running the same
two new shadow-mktemp cases against `git show HEAD:…` copies of the
pre-fix gate scripts produced `FAIL (rc=2)` with output `mktemp: shadowed
for regression test, always fails` for both — confirming the tests
actually exercise the fixed defect.

## What did not work

None.

## Doc placement ladder

- No new env var, dependency, migration, or public-signature/wire-format
  change — mechanism swap only (mktemp scratch file → stdin heredoc +
  base64 env var), matching the pattern already in place at
  `km-adr-proposal/hooks/adr-shape-gate.sh`. No handbook/decisions/reports
  entry required beyond this record.

## loop_state

`landed` (this record, terminal — see frontmatter). No role-specific
terminal-state override in effect.

## Open findings

None. All items in the approved proposal's "What will be done" were
executed as specified; no scope was exceeded and no alternative was
swapped mid-build.

## Closed checks

- `no-mktemp-in-runtime-path` — `grep -n mktemp` on both modified gate
  scripts returns nothing.
- `shadow-regression-fails-pre-fix-passes-post-fix` — manually verified
  both new test cases against pre-fix (`git show HEAD:…`) copies: FAIL
  (rc=2); against post-fix scripts: PASS.
- `full-gate-suite-green` — all 5 gate test files in the repo (101 total
  cases across pairing/shape/supersession/adr/pattern-entry gates) exit
  0.
