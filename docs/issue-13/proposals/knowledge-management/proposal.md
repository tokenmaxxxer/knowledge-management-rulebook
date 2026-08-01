---
subject: issue-13
role: knowledge-management
loop_state: proposed
---

# Proposal — gate A+ remediation for re-audit residuals (issue-13)

## Context

Built on `docs/issue-13/reports/knowledge-management/survey.md` and
`scout-brief.md`. The 2026-08-01 re-audit (issue #13) graded this
repo's gates B+ and named six residual defects on top of issue #10's
already-merged gate-house-standard adoption: (1) `km-adr-proposal`'s
`hooks.json` Bash matcher is not registered, making the gate's own
`elif tool_name == "Bash":` branch dead code in production despite
being advertised and tested; (2) that same branch hand-rolls a
path-token scan instead of calling `gate_lib`'s
`gate_bash_write_targets`; (3) a dangling `(see below)` reference in
the top-level `README.md`; (4) a general requirement that every
`hooks.json` matcher and its script's code coverage be fully aligned;
(5) a missing-core test case plus a green full suite and a recorded
`compliance-check` pass; (6) zero leftover old-role-name or
ghost/nonexistent-file references in README/manifests.

The survey additionally found, while verifying items 4 and 6, that
`adr-shape-gate.sh`'s `NotebookEdit` branch is equally unreachable
(same defect class as item 1, not separately named in the issue), and
that `knowledge-management/hooks/hooks.json` carries a `PreToolUse`
`Bash` entry pointing at `knowledge-management-progress-gate.sh`, a
file that does not exist anywhere in this checkout — a ghost-file
reference the issue's item 6 language covers even though it lives in a
`hooks.json` rather than the README or a `plugin.json`.

Core #75 (gate-lib source-guard mandate, compliance-check detection of
an unguarded source line, mandatory missing-core test,
`gate_bash_write_targets` Python port) is confirmed landed: commit
`52bdc15` ("gate-lib source guard + gate_bash_write_targets py parity
(issue-75) (#77)") on `tokenmaxxxer/tokenmaxxxer-core`'s `main` (the
survey's first pass queried the wrong repo slug and two stale local
caches pinned at issue #72's close; both are corrected in
survey.md/scout-brief.md, cross-checked against a sibling role's own
issue-13 survey naming the same commit/PR). This proposal applies that
landed pattern directly rather than inventing a variant of it.

## Options considered

**A. Fix `km-adr-proposal` in place: extend its existing
`hooks.json` matcher, delegate its Bash-branch token scan to the
landed `gate_lib.gate_bash_write_targets` (Python, core #75), add the
landed same-line `||`-guard plus its landed missing-core test pattern,
and fix the README/manifest fixes as targeted diffs, scoped strictly
to the issue's named items plus the two adjacent findings
(NotebookEdit matcher gap, the role-directive plugin's ghost-file
reference).** No architectural change; every fix is a same-shape
extension of a pattern already correct elsewhere in this repo
(`km-supersession`/`km-cross-index`'s Bash-matcher registration) or
already landed verbatim in core (#75's guard/test/Python-port).

**B. Roll the fix into a repo-wide sweep now — also fix
`km-cross-index/hooks/index-shape-gate.sh`'s identical dead-Bash-branch
defect (found during scouting, item 4's general form) and add the
same-line `||`-guard to all five gate scripts' `gate-lib.sh` source
line (found during the item-5 check) in this same phase-2, since they
are the same defect classes on sibling files.** Closes more of the
repo's actual gate risk in one pass and avoids re-opening the same
investigation later. But issue #13's precondition section names only
`adr-shape-gate`, and its acceptance criteria are all `km-adr-proposal`
-scoped; folding in un-requested fixes to four other plugins expands
this issue's phase-2 diff surface and review burden beyond what was
asked, and risks conflating two audits' findings if the human reviewer
is grading strictly against issue #13's stated scope.

**C. Wait for explicit re-confirmation that core #75 has landed before
proposing anything, since items 2 and 5 are phrased as "use the
landed core #75 pattern" and the survey's first pass could not
confirm it.** Maximally conservative about the precondition-
verification gap the survey initially hit. But the gap was a
wrong-repo-slug/stale-cache artifact, not an actual landing gap — a
fresh clone of the correctly named core repo confirms all three #75
pieces exist at commit `52bdc15`, cross-checked by a sibling role's
own issue-13 documents. Re-blocking phase-1 on a precondition that is
now directly confirmed would stall a fix for a live defect (item 1's
dead Bash branch is a real coverage gap right now) for no remaining
verification benefit.

## Decision

Option A. It fixes every one of the six named items plus the two
adjacent findings discovered while verifying them, applying core #75's
now-confirmed landed pattern verbatim (the same-line `||` guard, the
`gate_lib.py` `gate_bash_write_targets`, the missing-core test shape)
rather than inventing a substitute, and it does not expand scope into
the other four plugins' matching-but-unrequested defects (option B) —
those are recorded in survey.md/scout-brief.md as a follow-up
candidate instead. It does not re-block on the precondition (option C
rejected) because the corrected verification already confirms core
#75 landed.

## Consequences

**Easier**: `km-adr-proposal`'s Bash-write and NotebookEdit protections
become real in production instead of advertised-only, closing the
exact gap a re-audit would otherwise keep finding every cycle; the
Bash-branch token scan collapses from a hand-maintained regex to one
call into `gate_lib.gate_bash_write_targets` (core #75's landed Python
port), so a future fix to that function reaches this gate
automatically without a repeat migration; a reviewer checking item 6
has one less ghost path to chase, in either the README or
`knowledge-management/hooks/hooks.json`; `compliance-check.sh`'s
landed same-line-guard rule gives a mechanical pass/fail for item 5
instead of a manual re-audit.

**Harder**: because no `compliance-check.sh` rule (landed or otherwise,
confirmed by reading the corrected fresh-clone copy) cross-checks
`hooks.json` matcher strings against script `tool_name` branches, the
item-1/item-4 defect class itself is not mechanically preventable
today; the fix instead relies on a human-authored test case plus
manual review to keep matcher and code coverage aligned, and the same
defect could recur in `km-pattern-entry` or a future gate unless a
compliance-check rule for this specific class is proposed as separate
follow-up work (not in scope here, since issue #13 does not ask for a
compliance-check rule change, only a per-plugin fix and a recorded
pass).

## Sources

- `gh issue view 13` (this repo).
- `docs/issue-13/reports/knowledge-management/survey.md`,
  `docs/issue-13/reports/knowledge-management/scout-brief.md` (this
  proposal's own phase-1 companions, full detail, line citations, and
  the core-#75 slug correction there).
- `km-adr-proposal/hooks/hooks.json`,
  `km-adr-proposal/hooks/adr-shape-gate.sh`,
  `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh`.
- `km-supersession/hooks/hooks.json`, `km-cross-index/hooks/hooks.json`
  (Bash-matcher precedent).
- `knowledge-management/hooks/hooks.json`, `README.md`,
  `docs/specs/approvers.md`.
- core commit `52bdc15` (PR #77, `tokenmaxxxer/tokenmaxxxer-core`):
  `core/hooks/lib/gate-lib.sh`'s guarded-source usage contract,
  `core/hooks/lib/gate-lib.py`'s `gate_bash_write_targets`,
  `core/hooks/tests/compliance-check.sh`'s same-line-guard rule,
  `core/hooks/tests/run-gate-lib-tests.sh`'s missing-core case group.
- `docs/issue-10/proposals/knowledge-management/proposal.md` (this
  repo's prior phase-1 proposal, PR #12 tone/structure precedent).

## Proposed remediation detail (phase 2, on Approve)

### 1 + 4. Register the full matcher for `km-adr-proposal`

`km-adr-proposal/hooks/hooks.json:5`: change

```
"matcher": "Write|Edit|MultiEdit"
```

to

```
"matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash"
```

so every `tool_name` branch `adr-shape-gate.sh` already has code for
and already has tests for (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`
via `gate_reconstruct_write`, `Bash` via the token-scan deny) is
actually reachable in a live session. This is the single-line fix for
item 1 and the `km-adr-proposal`-scoped instance of item 4; the
identical defect on `km-cross-index/index-shape-gate.sh` (found in
scouting) is recorded as a follow-up, not fixed in this diff (see
Decision).

### 2. Delegate the Bash branch to `gate_bash_write_targets`

`adr-shape-gate.sh:111-119` currently does:

```python
elif tool_name == "Bash":
    command = tool_input.get("command", "")
    targets = gate_lib.__dict__  # no-op reference to keep import used
    matched = False
    for token in re.findall(r"[\w./~$-]+", command):
        rel = gate_lib.gate_normalize_path(project_root, token)
        if check_target(rel) is not None:
            matched = True
            break
```

Since core #75 landed a Python port of `gate_bash_write_targets` in
`core/hooks/lib/gate-lib.py` (mirroring the sh version's
`[[:alnum:]_./~$-]+` class), the fix replaces the hand-rolled loop with
a direct call into it:

```python
elif tool_name == "Bash":
    command = tool_input.get("command", "")
    matched = False
    for token in gate_lib.gate_bash_write_targets(command):
        rel = gate_lib.gate_normalize_path(project_root, token)
        if check_target(rel) is not None:
            matched = True
            break
```

removing both the duplicated regex and the no-op `gate_lib.__dict__`
placeholder line, so the gate delegates to the one canonical
implementation instead of maintaining a parallel one.

### 3. Fix the README dangler

`README.md:27`: remove the trailing `(see below)` —

```
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)
```

becomes

```
- `docs/specs/approvers.md` — Approve-authority allowlist
```

`docs/specs/approvers.md` already carries its own explanatory comment
(read in full during the survey), so no replacement forward-reference
is needed; the file is self-describing.

### 4 (continued). Fix the role-directive plugin's ghost-file reference

`knowledge-management/hooks/hooks.json:10-17` currently declares a
`PreToolUse`/`Bash` entry pointing at
`${CLAUDE_PLUGIN_ROOT}/hooks/knowledge-management-progress-gate.sh`,
which does not exist on disk. `README.md:23` states this plugin's
`hooks.json` now carries only `SessionStart` wiring since
"role-agnostic gates now fire from core's own `hooks.json`." Proposed
fix: remove the `PreToolUse` stanza from
`knowledge-management/hooks/hooks.json` entirely, leaving only the
`SessionStart` → `directive.sh` entry, bringing the file in line with
what the README already claims about it. (Restoring the referenced
script instead was considered and rejected: nothing in this repo's
docs, tests, or the issue text describes what
`knowledge-management-progress-gate.sh` was supposed to check, and
inventing new gate behavior is out of scope for a residual-defect
remediation issue.)

### 5. Missing-core test case, source guard, full suite, compliance-check record

Apply core #75's landed pattern verbatim to `adr-shape-gate.sh:17`:

- Change the unguarded source line

  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
  ```

  to the landed same-line-guard form:

  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "adr-shape-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
  ```

  (the exact idiom `core/hooks/lib/gate-lib.sh`'s own usage-contract
  comment documents and `compliance-check.sh`'s landed same-line-guard
  rule checks for — `gate-lib\.sh"$` with no trailing `||` on the same
  line is a fail).
- Add a "missing-core" test case group to `adr-shape-gate.test.sh`,
  mirroring core's own `run-gate-lib-tests.sh` "group 7": invoke the
  gate with `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent
  directory (e.g. `$TMP_ROOT/no-such-core`) and assert the gate denies
  (exit 2) rather than silently no-op-passing.
- Run `bash km-adr-proposal/hooks/tests/adr-shape-gate.test.sh` to
  green (all existing + new cases) and
  `core/hooks/tests/compliance-check.sh km-adr-proposal/hooks` (against
  the landed core #75 checkout) to a clean pass, recording both
  outputs verbatim in `docs/issue-13/reports/knowledge-management.md`
  (the phase-2 record file, gated behind human APPROVE — not created
  in this phase-1 proposal).

### 6. Confirm zero leftover references after 3 and 4 land

After items 3 and 4's diffs land, re-grep `README.md` and every
`.claude-plugin/plugin.json` for `(see below)` and for
`knowledge-management-progress-gate.sh` to confirm both are gone, and
re-run the item-4 matcher/code table from survey.md against the
post-fix files to confirm `km-adr-proposal` and the role-directive
plugin now show zero gaps. Recorded in the phase-2 record file
alongside the test/compliance-check output.

## Scope note

Phase 1 only. No implementation lands in this PR; phase 2 (the
`hooks.json` matcher fix, the `gate_bash_write_targets` delegation,
the README/hooks.json ghost-reference fixes, the missing-core test and
source guard, the full-suite/compliance-check run and record) opens on
Approve per contract v3 s19.
