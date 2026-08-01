---
subject: issue-13
role: knowledge-management
loop_state: proposed
---

# Proposal — gate A+ remediation for re-audit residuals (issue-13)

## Context

Built on `docs/issue-13/reports/knowledge-management/survey.md` and
`scout-brief.md`. The 2026-08-01 re-audit (issue #13) named residual
defects left in `km-adr-proposal` after `docs/issue-10`'s gate-house-
standard adoption: `hooks.json` advertises and tests a `Bash` branch in
`adr-shape-gate.sh` that is unreachable in production (matcher omits
`Bash`), that branch hand-rolls a token scan instead of calling core
issue #75's `gate_bash_write_targets`, a dangling `(see below)`
reference in the top-level README, a general require that hooks.json
matcher/code coverage stay aligned, a missing-core test case with a
green suite and recorded compliance-check pass, and zero old-role-name/
ghost-file references in README/manifest. Core issue #75 (confirmed
landed at `tokenmaxxxer/tokenmaxxxer-core` commit `52bdc15`, PR #77 —
see survey.md's prerequisite section for the correction of an earlier
wrong-repo-slug lookup in this same session) has since landed the
mandatory `||`-guarded source convention, `compliance-check.sh`'s
same-line detection rule, a missing-core test case pattern, and
`gate_bash_write_targets` ported to `gate-lib.py`. On-the-record issue
#182 (closed) separately fixed `spawn.py`'s `CLAUDE_PLUGIN_ROOT_CORE`
injection. This proposal is this repo's per-repo remediation against
those two landed references, plus the repo-local defects (matcher/
branch reachability, dangling reference) core does not itself cover.
This is a **phase-1 proposal only** — no code changes are made in this
PR; every fix below is described at file/line precision so phase-2 can
apply it mechanically once approved.

## Options considered

**A. Reference-apply core #75's confirmed guard shape verbatim, add
`Bash` (and `NotebookEdit`, per survey.md's additional finding) to
`km-adr-proposal/hooks/hooks.json`'s matcher so the already-implemented,
already-tested branches become reachable, delegate the hand-rolled
token scan to `gate_lib.gate_bash_write_targets`, and fix the dangling
README reference and the `knowledge-management/hooks/hooks.json`
ghost-file entry as small, targeted text edits.** Every piece traces to
either an already-landed, re-verified core reference (the `||` guard,
the missing-core test shape, `gate_bash_write_targets`) or a narrowly
scoped repo-local text/config fix. No new abstraction, no new
dependency, no rewrite of working logic.

**B. Remove the Bash (and NotebookEdit) branches from
`adr-shape-gate.sh` and their test cases instead of registering them in
`hooks.json`.** Also closes the matcher/code-coverage misalignment, and
is strictly less code than option A. Rejected: issue item 2 ("Bash 분기
수제 토큰 스캔 → gate_bash_write_targets 사용") presupposes the Bash
branch continues to exist and simply needs its token-scan
implementation swapped — deleting it would make item 2 moot rather than
resolved, and would silently drop Bash/NotebookEdit-tool coverage for a
`docs/issue-<n>/proposals/knowledge-management/*.md` write path the
shape gate exists to protect (an ADR proposal can, in principle, be
written by a Bash command like `cat > file.md <<EOF`, exactly the
coverage test group 6 already defends). Registering the branches, not
deleting them, is the conservative choice that keeps existing
protection instead of narrowing it.

**C. Migrate all five `km-*`/role-directive scripts found to share the
unguarded source-line pattern, or the same dead-Bash-branch pattern on
`km-cross-index/hooks/index-shape-gate.sh` (both noted in survey.md as
repo-wide, not `km-adr-proposal`-only), in this same PR.** Rejected as
over-scope for this proposal: issue #13's own precondition section
names only `adr-shape-gate`, and folding unscoped, only-partially-
verified work into a phase-1 proposal whose acceptance criteria are all
`km-adr-proposal`-scoped would make review and "done" ambiguous.
Recorded as a follow-up candidate instead (see Consequences).

## Decision

Option A. It resolves all six items the issue names, using the landed
core #75/#182 references verbatim wherever they apply (item 2, and the
guard-line defect survey.md found while verifying item 5) and precise
repo-local text edits where they do not (items 1, 3, 4, 6), without
deleting existing protective coverage (rejects B) and without absorbing
unscoped, unverified repo-wide work into this issue's acceptance
criteria (rejects C).

## Consequences

**Easier**: `km-adr-proposal`'s Bash/NotebookEdit-tool coverage becomes
real instead of advertised-but-dead — a future re-audit against this
gate will find the matcher and the tested code paths in agreement,
closing exactly the defect class issue #13 exists to fix. Delegating to
`gate_lib.gate_bash_write_targets` means any future core-side fix to
the token-scan character class reaches this gate automatically via
re-sourcing, the same benefit `docs/issue-10`'s proposal already
established as the point of the gate-house standard.

**Harder**: this proposal's scope boundary (option A vs. C) means the
same unguarded-source-line pattern confirmed present across the other
four gate scripts, and the same dead-Bash-branch pattern confirmed on
`km-cross-index/hooks/index-shape-gate.sh`, are *not* fixed by this PR
— a second remediation pass, plus a full audit of those gates' own
matcher/code alignment and test coverage (not independently verified in
this survey beyond the specific greps noted), is still owed and must be
tracked as its own follow-up rather than assumed closed once this issue
lands. Survey.md also found no mechanical `compliance-check.sh` rule
that would have caught the matcher/`tool_name`-branch misalignment in
the first place (scout-brief.md Stage 3) — until core grows that check,
this class of defect must keep being caught by manual/test-level
inspection, which is a standing maintenance cost this fix does not
remove.

## Sources

`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`core/hooks/tests/compliance-check.sh`,
`core/hooks/tests/run-gate-lib-tests.sh` (read from a fresh
`git clone --depth 1 https://github.com/tokenmaxxxer/tokenmaxxxer-core.git`
at commit `52bdc15`, PR #77, closing core issue #75); `gh issue view
13` (this repo); `gh issue view 75 -R tokenmaxxxer/tokenmaxxxer-core`;
`gh issue view 182 -R tokenmaxxxer/on-the-record`; this repo's own
`km-adr-proposal/hooks/hooks.json`,
`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-adr-proposal/hooks/tests/adr-shape-gate.test.sh`,
`km-adr-proposal/README.md`, `knowledge-management/hooks/hooks.json`,
`km-cross-index/hooks/hooks.json`,
`km-cross-index/hooks/index-shape-gate.sh`, top-level `README.md`; full
trace detail in `docs/issue-13/reports/knowledge-management/survey.md`
and `scout-brief.md`; cross-checked against
`/home/jwjung/.tokenmaxxxer/work/api-design-rulebook-issue-13-api-design/docs/issue-13/reports/api-design/current-state.md`
(sibling role, same issue number, independent confirmation of core
#75's landed commit and on-the-record #182's state).

## What will be done (phase 2, on Approve)

### 1. `km-adr-proposal/hooks/hooks.json` — register the dead matchers

Change line 5 from:

```
        "matcher": "Write|Edit|MultiEdit",
```

to:

```
        "matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash",
```

This is the fix for issue items 1 and 4: it makes both the
already-implemented, already-tested `elif tool_name == "Bash":` branch
(`adr-shape-gate.sh:111-126`) and the `NotebookEdit` handling folded
into the `Write`/`Edit`/`MultiEdit` branch (line 85, tested at
`adr-shape-gate.test.sh:307-320`) reachable in a real gated session,
bringing matcher coverage and code coverage into agreement.

### 2. `km-adr-proposal/hooks/adr-shape-gate.sh` — two fixes in the same
### file

- **Line 17** (source-guard, the defect survey.md found while verifying
  item 5, using core #75's confirmed shape verbatim): change

  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
  ```

  to

  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "adr-shape-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
  ```

  matching `gate-lib.sh`'s own usage-contract comment and satisfying
  `compliance-check.sh`'s same-line detection rule.

- **Lines 111-124** (issue item 2): replace the hand-rolled token scan
  (`for token in re.findall(r"[\w./~$-]+", command):` plus the
  `targets = gate_lib.__dict__  # no-op reference` line) with a direct
  call into the ported core helper:

  ```python
  matched = False
  for token in gate_lib.gate_bash_write_targets(command):
      rel = gate_lib.gate_normalize_path(project_root, token)
      if check_target(rel) is not None:
          matched = True
          break
  ```

  `gate_lib` is already imported at lines 47-49; no new import is
  needed. `import re` must stay for `TARGET_RE`/`HEADING_RE` elsewhere
  in the same payload.

### 3. `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh` —
### missing-core test case (issue item 5)

Add a test group mirroring core's own `run-gate-lib-tests.sh` group 7
shape: invoke the gate with `CLAUDE_PLUGIN_ROOT_CORE` pointed at a
nonexistent path (no `../../core` fallback resolvable from the
`$TMPDIR`-based fixture) and assert `exit 2` (deny), not `exit 0`. This
is the regression test for the guard added in fix 2 — without it, a
future edit could silently drop the `||` guard again with nothing
catching the regression.

### 4. Top-level `README.md` — dangling reference (issue item 3)

Line 27 currently reads:

```
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)
```

Per survey.md, `docs/specs/approvers.md` exists on disk but no later
README section elaborates on it — the `(see below)` is a stale
forward-reference with nothing to point to. Conservative fix: drop the
dangling parenthetical:

```
- `docs/specs/approvers.md` — Approve-authority allowlist
```

### 5. `knowledge-management/hooks/hooks.json` — ghost-file reference
### (issue item 6)

The `PreToolUse`/`Bash` entry pointing at
`${CLAUDE_PLUGIN_ROOT}/hooks/knowledge-management-progress-gate.sh` (a
file confirmed absent from `knowledge-management/hooks/` — only
`directive.sh` and `hooks.json` exist there) should be removed,
consistent with the top-level README's own statement that
"role-agnostic gates now fire from core's own `hooks.json`" for this
file. Conservative fix: delete the `PreToolUse` block, leaving only the
`SessionStart` entry that matches what actually exists. If a real
progress gate is wanted later, it should be introduced with its script
landing in the same commit, not referenced ahead of it.

## How you'll know it worked

- `km-adr-proposal/hooks/hooks.json`'s matcher includes `Bash` and
  `NotebookEdit`, and `adr-shape-gate.test.sh`'s existing Bash/
  NotebookEdit cases exercise a code path Claude Code would actually
  invoke in a real session.
- `adr-shape-gate.sh:111-124`'s Bash branch calls
  `gate_lib.gate_bash_write_targets` instead of a local `re.findall`.
- `adr-shape-gate.sh`'s `gate-lib.sh` source line carries the `||`
  guard in core #75's exact confirmed shape.
- A new missing-core test case asserts deny (exit 2) when
  `CLAUDE_PLUGIN_ROOT_CORE` is unreachable; the full
  `adr-shape-gate.test.sh` suite is green.
- `core/hooks/tests/compliance-check.sh km-adr-proposal/hooks` passes
  clean; the passing run is recorded (e.g. appended to a phase-2
  implementation report) rather than only run ad hoc.
- Top-level `README.md` no longer contains a dangling `(see below)`.
- `knowledge-management/hooks/hooks.json` contains no reference to a
  file that does not exist under `knowledge-management/hooks/`.

## Scope note

Phase 1 only. No implementation lands in this PR; phase 2 (the five
fixes above, the missing-core test, the compliance-check run and
record) opens on Approve per contract v3 s19, matching the phase split
`docs/issue-10/proposals/knowledge-management/proposal.md` already used
for this role. The repo-wide follow-up named in Consequences (the other
four gates' shared unguarded-source pattern, `km-cross-index`'s own
dead Bash-branch on `index-shape-gate.sh`, and their unverified
matcher/code/test coverage) is explicitly out of this proposal's scope
and should be tracked as its own issue rather than folded into this
one's phase-2.
