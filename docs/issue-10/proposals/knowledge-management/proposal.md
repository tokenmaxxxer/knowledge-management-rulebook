---
subject: issue-10
role: knowledge-management
loop_state: proposed
---

# Proposal — gate A+ remediation via gate-house standard adoption (issue-10)

## Context

Built on `docs/issue-10/reports/knowledge-management/survey.md` and
`scout-brief.md`. The 2026-08-01 audit graded this repo's five gates B
and named four defect classes: absolute-path/fail-closed/Edit-MultiEdit-
replace_all gaps, substring-level semantic checks, missing mandatory test
cases, and a README that has drifted from the real plugin set. Core
issue #72 has since landed `core/hooks/lib/gate-lib.sh`/`gate-lib.py` +
`run-gate-lib-tests.sh` + `compliance-check.sh` +
`docs/handbooks/gate-house-standard.md` as the mandated, reference-only-
never-copy fix for the first defect class; this proposal is this repo's
per-repo A+ remediation against that standard, plus the semantic-depth
upgrade the standard does not itself cover.

## Options considered

**A. Adopt `core/hooks/lib/gate-lib.sh`/`gate-lib.py` wholesale, add a
bounded structural (non-AST) semantic-check rewrite on top.** Migrate all
five gates' trap/kill-switch/reconstruct/path-normalize/Bash-write-scan
logic to source/load the core library per the handbook's five-step
checklist, and separately rewrite each shape gate's `has_any()` substring
check into a front-matter-block-scoped key parse and heading-line-scoped
section/adjacency parse, implemented as plain stdlib regex/line-scan
additions to each gate's existing Python payload.

**B. Re-derive each gate's own fixes independently** (fix the multiline
regex, quote the for-loop, tighten substring checks, per gate, without
touching the shared library). Faster to land per-gate in isolation, but
reproduces exactly the drift issue #72 exists to stop — six weeks from
now a sixth defect class surfaces in core canon and this repo silently
misses the fix again, because nothing here traces back to the shared
source.

**C. Adopt `gate-lib.sh`/`gate-lib.py` for the four already-covered
defect classes, but solve the semantic-check gap with a full markdown-AST
parser dependency** (e.g. a Python markdown library) for section/heading
extraction instead of a stdlib line-scan. More general, but adds a new
runtime dependency for a bounded problem (flat front-matter block plus
`^#{1,6}` heading lines) that a ~30-line stdlib scan already solves, and
none of the five gates currently have any non-stdlib Python dependency.

## Decision

Option A. It is the only option that satisfies the issue's explicit
precondition (adopt the landed core standard, no reimplementation) while
also closing the gap that standard does not cover (semantic-check depth),
without importing new dependency surface option C would add for no
corresponding requirement.

## Consequences

**Easier**: every future core-canon fix to trap/kill-switch/reconstruct/
path-normalize logic (like the two bugs issue #72 itself found and fixed
in core's own seven gates) now reaches these five gates automatically by
re-sourcing the same library, instead of requiring a sixth repo-specific
remediation issue later; `compliance-check.sh` gives a mechanical,
repeatable pass/fail instead of a manual re-audit next time grading comes
up.

**Harder**: the semantic-check rewrite (front-matter-block scoping,
heading-line-scoped section/adjacency parsing) is not covered by the
core library at all — it is net-new logic this repo must design, test,
and maintain itself, and it must not regress the existing heading-order
check in `pattern-entry-gate.sh` that already partially works.

## What will be done

### 1. Migrate all five gates onto `core/hooks/lib/gate-lib.sh`/`gate-lib.py`

For each of `km-pattern-entry/hooks/pattern-entry-gate.sh`,
`km-supersession/hooks/supersession-pairing-gate.sh`,
`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-cross-index/hooks/index-shape-gate.sh`,
`km-cross-index/hooks/index-pairing-gate.sh`, following the handbook's
five-step checklist:

- Replace the hand-rolled `trap __fc EXIT; ...; set -uo pipefail` block
  with `. "${CORE_PLUGIN_ROOT:-...}/hooks/lib/gate-lib.sh"` +
  `gate_trap_fail_closed`.
- Replace each `case "${..._OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;;
  esac` with `gate_kill_switch_active "${..._OFF:-}" || { trap - EXIT;
  exit 0; }` — closes defect class #1 (kill-switch default-on-unrecognized
  fixed at the library, not re-derived per gate).
- In each gate's Python payload, load `gate-lib.py` via the
  `importlib`/`GATE_LIB_PY` pattern from the usage comment, and replace:
  - the ad hoc `json.loads(...)`/bare `try/except` with
    `gate_parse_json_or_deny`,
  - the ad hoc `os.path.relpath`/`os.path.isabs` handling with
    `gate_normalize_path` (root-relative tail or `None` outside root —
    closes the "경로 매칭 절대경로 정규화" ask uniformly instead of each
    gate's own variant),
  - each gate's own `Edit`/`MultiEdit`/`NotebookEdit` reconstruction
    (`current.replace(old, new, 1)` etc.) with `gate_reconstruct_write` —
    closes the replace_all-ignored bug class and adds `NotebookEdit`
    coverage none of the five gates currently have.
- In `supersession-pairing-gate.sh` and `index-pairing-gate.sh`: replace
  the custom `grep -Eq '\bgit\b[^\n]*\bcommit\b'` multiline-vulnerable
  match with a payload-string check that does not depend on `[^\n]*` (a
  `tr '\n' ' '` normalization before the same regex, or matching on the
  parsed `tool_input.command` in the Python payload instead of the bash
  layer) — closes the git-commit multiline-bypass defect.
- In `supersession-pairing-gate.sh:106`: quote the for-loop expansion
  (`for entry in "${pattern_entries[@]}"` backed by an actual bash array,
  not a bare unquoted string variable) or move the iteration into the
  existing Python payload (consistent with how `index-pairing-gate.sh`
  already does it) — closes the unquoted-word-split defect.
- Any gate currently matching only `Write`/`Edit`/`MultiEdit` file-path
  tools gains `gate_bash_write_targets` coverage for the Bash-tool write
  path, per the standard's stated Bash-write test-case group.
- Deny messages continue to go to stderr via `gate_deny` (already the
  house convention; formalized through the shared function instead of
  each gate's own `deny()`).

### 2. Semantic check upgrade: substring → section/adjacency/structure

Replace every `has_any()`/whole-text-substring check in the four
content-shape gates with a structural parse, implemented as small
additions to each gate's own Python payload (stdlib regex/line-scan,
no new dependency — see rejected option C):

- **Front matter**: parse only the text between the first `^---\s*$` and
  the next `^---\s*$` as a sequence of top-level `^key:` lines. A
  required key is present only if a line in that block matches
  `^key:\s`; a quoted scalar value on an unrelated key can no longer
  satisfy it, closing the YAML-quoted-value false-reject/false-accept
  defect.
- **Headings**: a required section is present only if some line matches
  `^#{1,6}\s+.*<word>` — the word must appear in an actual heading line's
  text, not merely anywhere in the document. Standardize the check that
  already partially exists in `pattern-entry-gate.sh` across all four
  gates, tightened so an unrelated word in the same heading line cannot
  satisfy a different requirement.
- **Adjacency/order**: derive each required section's heading line index
  from the heading list above (not first-occurrence-of-bare-word across
  the whole body), then require both order (indices strictly increasing
  in the mandated sequence) and, where the methodology specifies
  immediate sequence (e.g. ADR's Context→Options→Decision→Consequences),
  adjacency — no unrelated heading may sit between two mandated headings.
  A gate whose methodology only requires presence-and-order, not
  adjacency, states that explicitly in its own comment rather than
  silently downgrading the check.
- **Options-considered-style counts** (this gate's own ">=2 distinct
  options" heuristic): keep the existing marker-based line count but
  scope it to lines between the "Options considered" heading and the
  next top-level heading, not the whole document — closes a cross-section
  leak where a later, unrelated section's bullet could incidentally
  count.

### 3. Mandatory test cases

Add, per gate, the six-case-group set the standard requires
(`km-*/hooks/tests/*.test.sh`, extending existing partial files rather
than replacing cases that already exist):

1. `Edit` with `replace_all: true` against a multiply-occurring
   `old_string`.
2. `MultiEdit` mixing `replace_all: true`/`false` edits in one call.
3. Malformed JSON (truncated, non-object, empty stdin).
4. Kill switch set to an unrecognized value — assert gate stays active.
5. Absolute `file_path` matching the same scope a relative-path fixture
   matches, plus a `./`-prefixed variant.
6. A `Bash`-tool file write reaching the same target a `Write`-tool call
   would hit.

Plus gate-specific semantic-upgrade cases: a quoted-YAML-value fixture
that must NOT falsely satisfy an unrelated key; a heading-mentioned-in-
prose fixture that must NOT satisfy a section requirement; a correctly
structured document that must pass; and (pairing gates) a multiline Bash
`git`/`commit` command and a staged path containing a space, both of
which must still be caught.

Full suite green (`bash run-*.sh` per plugin) is the phase-2 delivery
gate, alongside a clean `core/hooks/tests/compliance-check.sh
km-<plugin>/hooks` run per plugin.

### 4. README realignment

Regenerate the "Layout" section from the actual `.claude-plugin/`
manifests and `hooks/` trees: list all four real plugins
(`km-pattern-entry`, `km-supersession`, `km-adr-proposal`,
`km-cross-index`), their gate scripts, their kill-switch env vars, and
their test files; remove any path that does not exist on disk. This is a
phase-2 (implementation) deliverable, not phase-1 — recorded here so the
acceptance criteria below are traceable to it.

## Sources

`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`docs/handbooks/gate-house-standard.md`,
`docs/issue-72/reports/implementation.md` (read from the landed core
worktree); this repo's `km-pattern-entry/hooks/pattern-entry-gate.sh`,
`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-supersession/hooks/supersession-pairing-gate.sh`,
`km-cross-index/hooks/index-pairing-gate.sh`,
`km-cross-index/hooks/index-shape-gate.sh`; full trace detail in
`docs/issue-10/reports/knowledge-management/survey.md` and
`scout-brief.md`.

## How you'll know it worked

- `core/hooks/tests/compliance-check.sh <plugin>/hooks` returns clean for
  all four plugins (no hand-rolled kill-switch/reconstruct flagged).
- Each plugin's own test suite is green and includes all six mandatory
  case groups plus the semantic-upgrade and multiline/word-split
  regression cases named above.
- A fixture where a required word appears only in prose/an unrelated
  YAML value is denied (semantic upgrade verified negative); a correctly
  structured fixture is allowed (verified positive).
- A multi-line `git ... commit` Bash command and a staged path with a
  space are both caught by the respective pairing gate.
- `README.md`'s Layout section lists exactly the plugins/files present in
  the tree — no ghost paths, no missing plugin.

## Scope note

Phase 1 only. No implementation lands in this PR; phase 2 (the migration,
the semantic-check rewrite, the tests, the README fix) opens on Approve
per contract v3 s19.
