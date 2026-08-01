---
subject: issue-16
role: knowledge-management
---

# Current-state survey — issue #16 (A+ gap closure)

## Scout record

Skipped. Skip condition: the spec (2026-08-01 audit finding) names the
exact gates, defect class, and fix shape to apply, and this repo already
carries the authoritative precedent for that exact defect class —
`docs/issue-13/reports/knowledge-management.md` fixed the identical
"unguarded gate-lib.sh source" defect on `km-adr-proposal/hooks/adr-shape-gate.sh`
and explicitly flagged the four sibling files (this issue's targets) as
"a follow-up candidate for a future issue" with "same diff shape, ... no
new design work needed." External scouting would not outrank in-repo
prior art for an internal shell/gate engineering pattern.

## Findings

### 1. Unguarded `gate-lib.sh` source (4 gates)

All four target gates source core's `gate-lib.sh` with a bare `.` and no
failure guard:

- `km-pattern-entry/hooks/pattern-entry-gate.sh:2`
- `km-cross-index/hooks/index-shape-gate.sh:2`
- `km-cross-index/hooks/index-pairing-gate.sh:2`
- `km-supersession/hooks/supersession-pairing-gate.sh:2`

If `CLAUDE_PLUGIN_ROOT_CORE`/git-toplevel resolution ever points at a
missing/broken core checkout, the `.` fails silently and the script
continues past `gate_trap_fail_closed`/`set -uo pipefail` with gate
helper functions undefined — later calls (`gate_kill_switch_active`,
`gate_deny`, etc.) then blow up with an unclear error rather than a
clean fail-closed deny.

`km-adr-proposal/hooks/adr-shape-gate.sh:17` already carries the fixed
shape (landed in issue-13):

```
. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh" || { echo "adr-shape-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
```

None of the four target gates' test suites have a "missing-core" case
(`grep -n missing-core` on all four test files: no hits). `adr-shape-gate.test.sh:431`
has the reference case: point `CLAUDE_PLUGIN_ROOT_CORE` at a nonexistent
directory, assert exit 2.

### 2. `index-shape-gate.sh`'s dead Bash branch

`km-cross-index/hooks/hooks.json` routes only `Write|Edit|MultiEdit` to
`index-shape-gate.sh`; `Bash` is routed to `index-pairing-gate.sh`
instead (`hooks.json:13-21`). But `index-shape-gate.sh`'s embedded
Python (`index-shape-gate.sh:50-69`) contains a full `tool_name ==
"Bash"` branch that scans for writes to `docs/patterns/index.md` and
denies them fail-closed — this branch is coded, tested
(`index-shape-gate.test.sh` presumably exercises it directly by piping
a Bash payload to the script, bypassing hooks.json), but unreachable in
production because hooks.json never dispatches a real `Bash` tool call
to this gate.

This is the same defect class issue-13 fixed on `adr-shape-gate.sh`
(matcher didn't include `Bash`/`NotebookEdit`, so already-coded branches
were unreachable) — issue-13's fix was to extend the matcher, not delete
the branch, since the branch was correct and tested.

### 3. Test suites lacking coverage

Confirmed via grep across all four target test files: zero
`missing-core`/`CLAUDE_PLUGIN_ROOT_CORE`-failure cases in
`pattern-entry-gate.test.sh`, `index-shape-gate.test.sh`,
`index-pairing-gate.test.sh`, `supersession-pairing-gate.test.sh`.

The issue text says "missing-core 테스트 3개 스위트" (3 suites) against 4
gates getting the source guard. No in-repo reason found for an
asymmetric 3-of-4 split — see proposal Decision for how this survey
resolves that.
