---
subject: issue-10
role: knowledge-management
loop_state: phase-1
---

# Scout brief (issue-10)

Mode: batched-sequential (single session, no parallel subagent/WebSearch
fan-out — the open design surface here is narrow enough per the survey's
skip-record that a comparison sweep across external exemplars would not
change the build decision; see survey.md's "Skip record"). One stage run:
direct read of the landed core reference implementation.

## Must-bes (from the mandated reference, not negotiable)
- Reference-not-copy: source `gate-lib.sh`/load `gate-lib.py`, never
  vendor a copy (`canon-manifest.txt` + `stub-check.sh` enforce this).
- Six mandatory test-case groups per `run-gate-lib-tests.sh`'s model:
  replace_all-Edit, replace_all-mix MultiEdit, malformed JSON, kill-switch
  unrecognized-value-stays-active, absolute + `./`-prefixed path, Bash-tool
  write-target coverage.
- `compliance-check.sh` clean run is the stated acceptance evidence for
  each of the 43 downstream repos' A+ issue (per the handbook's five-step
  migration checklist).

## Performance axes this repo's gates should compete on
1. Semantic-check precision — front matter parsed as scoped `key:` lines,
   headings matched as heading lines with adjacency/order over actual
   heading boundaries, not flat substring search (this repo's specific
   gap; `gate-lib.sh` itself is agnostic to this axis, it only fixes
   trap/kill-switch/reconstruct/path).
2. Coverage of the Bash-write path (`gate_bash_write_targets`) — currently
   used ad hoc (`grep -Eq` custom patterns) in the two pairing gates
   instead of the canon token-scanner.
3. Test-suite honesty — existing `km-*/hooks/tests/*.test.sh` files are
   partial; the six-group harness is the bar, not "some tests exist."

## Adopt / skip
- Adopt: `gate-lib.sh`'s `gate_trap_fail_closed`, `gate_kill_switch_active`,
  `gate_deny`/`gate_allow`, `gate_bash_write_targets`; `gate-lib.py`'s
  `gate_parse_json_or_deny`, `gate_normalize_path`, `gate_reconstruct_write`
  wholesale, per the handbook's per-repo migration checklist (five steps).
- Skip: writing a bespoke markdown-AST parser dependency. The section/
  adjacency upgrade needed here is small enough (heading-line regex +
  ordered index list, front-matter scoped to the `---` block already
  isolated by each gate) to do in the same stdlib-only Python payload
  style `gate-lib.py` itself uses — pulling in a markdown library would
  be new-dependency scope the issue never asked for.

## Segment fit
This repo is exactly one of the 43 downstream rulebooks the core handbook
was written for; it is not a novel design problem, it is the checklist's
"per-repo migration" case applied to five gates plus one semantic-depth
upgrade requirement 2 adds on top.

## Gap line
Core's standard already fully covers: fail-closed trap, kill-switch
fix, Edit/MultiEdit/NotebookEdit reconstruction, absolute-path
normalization, Bash-write-target scanning, and the compliance detector.
It does NOT cover: content-semantic depth (section/adjacency/structure
vs. substring) — that axis is this repo's own gap to close, on top of the
migration, exactly as the issue's requirement #2 names it.

Sources: `core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`docs/handbooks/gate-house-standard.md`, `docs/issue-72/reports/implementation.md`
(all read from the landed core worktree at
`tokenmaxxxer-core-issue-72-implementation`); this repo's own
`km-pattern-entry/hooks/pattern-entry-gate.sh`,
`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-supersession/hooks/supersession-pairing-gate.sh`,
`km-cross-index/hooks/index-pairing-gate.sh`.
