---
subject: issue-13
role: knowledge-management
loop_state: proposed
---

# Scout brief — prior art for matcher/dead-branch parity closure (issue-13)

Scope per the scout-directive: how do other well-audited gate/hook
systems in this same core lineage structure matcher-code coverage
parity checks and dead-branch elimination. Capped at 5 stages / ~3
minutes; stopped early once the in-repo precedent and the core #72
lineage document were both found to answer the question directly.

## Stage 1 — core #72's own survey (the best comparable "strong audit
of this change-class")

`docs/issue-10/proposals/knowledge-management/proposal.md:115-117`
(this repo's own prior phase-1 proposal, already merged per PR #12)
already states the general rule this issue's item 4 restates:

> Any gate currently matching only `Write`/`Edit`/`MultiEdit` file-path
> tools gains `gate_bash_write_targets` coverage for the Bash-tool
> write path, per the standard's stated Bash-write test-case group.

This is direct prior art from within this same role/repo: the
gate-house standard (core #72) was already understood, at proposal
time, to require Bash-write coverage as part of "compliance," but the
2026-08-01 re-audit found that `km-adr-proposal`'s implementation of
that requirement (delivered under issue #10/PR #12) added the Bash
*code branch* and its *tests* without also adding the Bash *matcher
entry* — i.e. the phase-2 delivery satisfied the code-coverage half of
the requirement and missed the deployment-reachability half. This is
the precise gap issue #13 exists to close, and the prior proposal did
not have a step for it: its "What will be done" section (read in
full) describes gate-lib migration, semantic-check upgrade, and test-
case additions, but never states "and register the Bash matcher in
hooks.json."

## Stage 2 — in-repo precedent for a correctly wired Bash matcher

`km-supersession/hooks/hooks.json:5` and
`km-cross-index/hooks/hooks.json:13-21` both register a dedicated
`"matcher": "Bash"` `PreToolUse` entry pointing at a Bash-only gate
script (`supersession-pairing-gate.sh`, `index-pairing-gate.sh`
respectively). These are the two gates in this repo whose entire
purpose is Bash-tool-triggered (git-commit-time pairing checks), so
Bash-matcher registration was load-bearing for them from the start and
was gotten right. This is the closest structural precedent for the
fix: `km-adr-proposal` is different in that Bash is a secondary,
defense-in-depth branch alongside a primary Write/Edit/MultiEdit path,
so the fix is "add `Bash` (and `NotebookEdit`) to the existing
`Write|Edit|MultiEdit` matcher string," not "add a new matcher entry"
— but the underlying rule ("the matcher regex must literally contain
every tool_name the script branches on") is the same in both cases.
`km-cross-index/hooks/index-shape-gate.sh:50` was also found, during
this same check, to branch on `tool_name == "Bash"` while its own
`hooks.json` entry (`km-cross-index/hooks/hooks.json:3-12`) matches
only `Write|Edit|MultiEdit` — the identical defect class on a second
plugin, not named in issue #13's six items and out of this proposal's
scope (the issue's precondition section names only `adr-shape-gate`),
but recorded in survey.md as evidence the pattern is repo-wide rather
than a one-off in `km-adr-proposal`.

## Stage 3 — core canon caches for a general parity-checking mechanism

Checked whether `core/hooks/tests/compliance-check.sh` (issue #72's
mechanical compliance checker, confirmed landed in both reachable core
caches — see survey.md's prerequisite section) itself contains any
rule that cross-checks a plugin's `hooks.json` matcher string against
its script's `tool_name` branches. A full read of
`/tmp/tokenmaxxxer-core-canon-cache/core/hooks/tests/compliance-check.sh`
found no such rule — as landed at issue #72's state, it checks for
hand-rolled trap/kill-switch/reconstruct patterns inside gate scripts,
not `hooks.json` matcher-vs-code alignment at all. This is a real gap
in the current tooling, not something this repo failed to use: nothing
in the reachable core lineage would mechanically have caught issue
#13's item 1/item 4 defects. Recorded as a limitation of the current
standard and carried into the proposal's Consequences section (a
"harder" item), since this repo's fix must be verified by test-level
inspection rather than an automated `compliance-check.sh` rule.

## Stage 4 — other role repos under `/home/jwjung/.tokenmaxxxer/work`
referencing core #75 or `CLAUDE_PLUGIN_ROOT_CORE`

A full filesystem sweep for other role repos was not run (out of the
scout-directive's time budget, and this sandbox restricts writes/reads
of some sibling paths outside this checkout). The already-known
sibling directories under
`/tmp/claude-1000/-home-jwjung--tokenmaxxxer-work-tokenmaxxxer-core-issue-75-implementation/`
were checked (per the survey's prerequisite section) and found to
contain only agent scratchpad/task metadata, no actual repo checkout
at a post-#75 commit. No other role repo's `docs/issue-*` tree was
independently scouted for a prior remediation of this same
matcher/dead-branch defect class within this budget — this repo's own
issue #10 proposal (stage 1) is the only concretely available prior
art found, and it speaks directly to the same gap.

## Stage 5 — stop condition reached

Stopped after stage 4: the question ("how do others structure
matcher/code parity checks and dead-branch elimination") has a direct,
sourced answer from stages 1-2 (the rule was already known in this
repo's own prior proposal; the fix pattern already exists correctly in
2 of 5 plugins in this same repo) and a direct negative finding from
stage 3 (no mechanical upstream check exists), which is itself useful
for the proposal (the fix must be test-verified, not tool-verified).
Continuing to a broader cross-repo sweep was judged low marginal value
against the ~3-minute budget once both a positive precedent and the
negative "no upstream mechanical check" finding were confirmed.

## Correction to Stage 3/survey.md's core-lineage read

Stage 3 above (and survey.md's original prerequisite section) queried
the wrong core repo slug (`tokenmaxxxer/core`, nonexistent) and read
only the two stale local caches pinned at issue #72's close (`22a7cad`).
Re-run against the correct slug, `tokenmaxxxer/tokenmaxxxer-core`
(confirmed via `gh repo list tokenmaxxxer`), and a fresh
`git clone --depth 1` of it: core #75 (commit `52bdc15`, PR #77) is
landed and does add exactly the source-guard/compliance-check/missing-
core-test/`gate_bash_write_targets`-py pieces issue #13's precondition
section describes — see survey.md's correction note in its prerequisite
section for the full citation. This does not change Stage 3's
substantive finding (no `hooks.json` matcher-vs-`tool_name` parity rule
exists in `compliance-check.sh`, confirmed present in the fresh clone
too) — only the earlier claim that core #75 itself could not be
confirmed, which is now retracted.

## Sources

- `docs/issue-10/proposals/knowledge-management/proposal.md` (this
  repo, full read, lines 115-117 quoted above).
- `km-supersession/hooks/hooks.json`, `km-cross-index/hooks/hooks.json`
  (full read).
- `km-cross-index/hooks/index-shape-gate.sh` (targeted read around
  line 50).
- `/tmp/tokenmaxxxer-core-canon-cache/core/hooks/tests/compliance-check.sh`
  (full read).
- `/tmp/claude-1000/-home-jwjung--tokenmaxxxer-work-tokenmaxxxer-core-issue-75-implementation/`
  (directory listing only — scratchpad/task metadata, no repo checkout).
