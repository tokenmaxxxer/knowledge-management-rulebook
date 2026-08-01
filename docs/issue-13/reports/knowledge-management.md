---
subject: issue-13
role: knowledge-management
loop_state: delivered
---

# Record — gate A+ remediation for re-audit residuals (issue-13)

## Why

The 2026-08-01 re-audit (issue #13) graded this repo's gates B+ on six
residual defects plus two adjacent findings surfaced while verifying
them (see `docs/issue-13/proposals/knowledge-management/proposal.md`,
approved via issue-comment `APPROVE issue-13/knowledge-management` by
`JiwonJung94`, an `approvers.md` account, single-account mode). This
record applies Option A of that proposal verbatim: `km-adr-proposal`'s
dead-branch/hand-rolled-scan/ghost-reference/unguarded-source defects,
scoped strictly to the issue's named items.

## What was done

1. `km-adr-proposal/hooks/hooks.json:5` matcher extended from
   `Write|Edit|MultiEdit` to `Write|Edit|MultiEdit|NotebookEdit|Bash`,
   making `adr-shape-gate.sh`'s already-coded/already-tested
   `NotebookEdit` and `Bash` branches reachable in production.
2. `adr-shape-gate.sh`'s `Bash` branch now calls
   `gate_lib.gate_bash_write_targets(command)` (core #75's landed
   Python port) instead of a hand-rolled `re.findall` token scan; the
   no-op `gate_lib.__dict__` placeholder line is removed.
3. `README.md:27` dangling `(see below)` removed —
   `docs/specs/approvers.md` line is now self-contained.
4. `knowledge-management/hooks/hooks.json`'s `PreToolUse`/`Bash` stanza
   pointing at the nonexistent `knowledge-management-progress-gate.sh`
   removed; the file now carries only the `SessionStart` →
   `directive.sh` wiring the README already claimed.
5. `adr-shape-gate.sh:17` source line given the landed same-line `||`
   guard (`|| { echo "adr-shape-gate.sh: cannot source gate-lib.sh"
   >&2; exit 2; }`); a "missing-core" test case added to
   `adr-shape-gate.test.sh` (env `CLAUDE_PLUGIN_ROOT_CORE` pointed at a
   nonexistent directory) asserting deny (exit 2), mirroring core's own
   `run-gate-lib-tests.sh` group 7.
6. Re-grepped `README.md` and every `.claude-plugin/plugin.json` for
   `(see below)` and `knowledge-management-progress-gate.sh` post-fix:
   zero hits outside historical `docs/issue-*` report/proposal records
   (which document the audit itself and are correctly left as-is).
   Also checked all five `plugin.json` manifests for stale role names:
   none found — all five already match the current plugin set.

### Test / compliance-check output

`bash km-adr-proposal/hooks/tests/adr-shape-gate.test.sh`:

```
26/26 passed
```

(includes the new "missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed
nowhere denies" case, `ok`, exit 2 as expected.)

`bash core/hooks/tests/compliance-check.sh km-adr-proposal/hooks`
(against the landed core #75 checkout):

```
compliance-check: ok — km-adr-proposal/hooks/adr-shape-gate.sh
```

### Full-suite delivery status

All five gate test suites in this repo, run green:

```
km-supersession/hooks/tests/supersession-pairing-gate.test.sh   : 11 passed, 0 failed
km-adr-proposal/hooks/tests/adr-shape-gate.test.sh              : 26 passed, 0 failed
km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh         : 24 passed, 0 failed
km-cross-index/hooks/tests/index-shape-gate.test.sh             : 21 passed, 0 failed
km-cross-index/hooks/tests/index-pairing-gate.test.sh           : 13 passed, 0 failed
```

## Open findings

Running `compliance-check.sh` against the other four plugins' hooks
dirs (not requested by issue #13, checked only to confirm this fix
does not mask a wider regression) shows `km-supersession`,
`km-cross-index` (both gates), and `km-pattern-entry` still source
`gate-lib.sh` without the same-line `||` guard — the identical defect
class as item 5, on sibling files. Per the proposal's Decision (Option
B rejected), issue #13's precondition section and acceptance criteria
are `km-adr-proposal`-scoped only; fixing the other four plugins is
recorded here as a follow-up candidate for a future issue, not fixed
in this diff.

## Next steps

None required to close issue #13: every named item plus the two
adjacent findings are fixed, tests and `compliance-check` are green,
and the record is complete.

## Open-finding resolution path

The sibling-plugin same-line-guard gap (open finding above) resolves
by filing a new issue scoped to `km-supersession`,
`km-cross-index` (both gates), and `km-pattern-entry`, applying the
identical same-line `||` guard fix already landed here for
`km-adr-proposal` — same diff shape, four more files, no new design
work needed.
