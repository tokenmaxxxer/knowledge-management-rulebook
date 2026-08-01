---
subject: issue-10
role: knowledge-management
loop_state: phase-1
---

# Survey — current-state audit trace (issue-10)

## Scope

Gates under audit: `km-pattern-entry/hooks/pattern-entry-gate.sh`,
`km-supersession/hooks/supersession-pairing-gate.sh`,
`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-cross-index/hooks/index-shape-gate.sh`,
`km-cross-index/hooks/index-pairing-gate.sh`. Precondition: core issue #72
("gate-house standard") is landed — `core/hooks/lib/gate-lib.sh` +
`gate-lib.py` + `core/hooks/tests/run-gate-lib-tests.sh` +
`core/hooks/tests/compliance-check.sh` + `docs/handbooks/gate-house-standard.md`
exist and are the mandated reference (`docs/handbooks/canon-scripts.md`
reference-not-copy rule; a vendored copy is caught by `stub-check.sh` via
`canon-manifest.txt`).

## Confirmed defect instances (traced to source lines)

1. **git-commit multiline bypass** — both
   `supersession-pairing-gate.sh:52` and `index-pairing-gate.sh:48` gate
   Bash-tool commit detection on
   `grep -Eq '\bgit\b[^\n]*\bcommit\b'`. `[^\n]*` cannot cross a newline,
   so a multi-line Bash command with `git` on one line and `commit` on a
   later line (a heredoc, `&&`-chained script, or literal embedded
   newline in `tool_input.command`) never matches — the pairing gate
   silently no-ops on exactly the kind of command it exists to catch.

2. **Unquoted for-loop word-split** —
   `supersession-pairing-gate.sh:106`: `for entry in $pattern_entries; do`.
   `$pattern_entries` is an unquoted expansion of a newline/space-joined
   list of staged paths; any path containing a space (or a glob
   metacharacter) is word-split/glob-expanded rather than treated as one
   token, so `git show ":$entry"` is called against a wrong,
   attacker-or-accident-controllable path.

3. **YAML-quoted-value false reject** — the shape gates
   (`adr-shape-gate.sh`, `pattern-entry-gate.sh`, `index-shape-gate.sh`)
   detect required front-matter/heading keys with a whole-text
   case-insensitive substring search (`has_any()` at
   `adr-shape-gate.sh:182-190`, same shape at
   `pattern-entry-gate.sh:124-126`), not a per-line `key:` parse. A
   quoted YAML value that happens to contain a required key token as
   plain text (e.g. `keywords: "not a title: placeholder"`) satisfies the
   substring check for an unrelated key, and — more importantly per the
   issue's semantic-upgrade ask — the same mechanism means any key can be
   satisfied by the word merely appearing anywhere in prose, not
   specifically as a front-matter key or section heading.

4. **README ghost-file / missing-plugin drift** — top-level `README.md`
   layout section (lines ~25-30) enumerates only
   `knowledge-management/hooks/directive.sh`, `docs/handbooks/*`,
   `docs/specs/approvers.md`; it does not mention any of the four real
   plugins (`km-pattern-entry`, `km-supersession`, `km-adr-proposal`,
   `km-cross-index`) or their gate scripts, kill switches, or test files
   that actually exist in this repo.

## Semantic-check pattern (the thing requirement #2 targets)

All four shape/pairing gates share one weak idiom: reconstruct the
resulting text (via each gate's own hand-rolled `Write`/`Edit`/`MultiEdit`
reconstruction — itself a second axis of drift from
`gate_reconstruct_write`), then run a flat case-insensitive substring scan
against the whole text or whole front-matter blob
(`has_any()`/`in front_matter.lower()`). None of them parse: (a) front
matter as `key: value` lines scoped to the `---`...`---` block only, (b) a
markdown heading as a heading (`^#+\s`) rather than "word appears anywhere
including in body prose or inside a code fence", or (c) section adjacency/
order via actual heading boundaries rather than raw line-index comparison
of first-occurrence indices of a bare word.
`pattern-entry-gate.sh:141-165`'s heading-order check is the closest
existing approximation (it does restrict to lines starting with `#`) but
still matches on `word in lower(heading_line)` (substring within the
heading line, not the heading's own text run) and has no adjacency
requirement — two headings with three off-topic headings between them
still "pass" as long as index order holds.

## What's already correct (do not re-flag)

- Kill-switch idiom (`case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac`)
  is present in all five gates and is the exact bug `gate-lib.sh`'s
  `gate_kill_switch_active` was written to fix (unrecognized value
  currently disables; should stay active). This is defect class #1 from
  the issue text's "fail-closed(... 킬스위치 비인식 값=활성)" line, not a
  new finding — already fully specified by the landed core fix.
- `gate_trap_fail_closed`-equivalent trap-at-top pattern already exists in
  all five gates (`trap __fc EXIT` before `set -uo pipefail`) — matches
  the canon shape; migration is a reference swap, not new logic.
- `index-pairing-gate.sh` iterates staged files via a Python list
  (`for line in name_status.splitlines()`), not an unquoted bash
  word-split — the bash-side word-split bug is confined to
  `supersession-pairing-gate.sh:106`, not systemic to both pairing gates.

## Gaps this proposal must close

- No repo-local adoption of `gate-lib.sh`/`gate-lib.py` yet (all five
  gates hand-roll trap/kill-switch/reconstruct/path-normalize).
- No `compliance-check.sh` run against this repo's hooks dir yet.
- No section/adjacency-aware semantic check anywhere in the four
  content-shape gates.
- No test cases for Edit/MultiEdit/`replace_all`/malformed-JSON/
  kill-switch/absolute-path per gate (some gates have partial test files
  under `km-*/hooks/tests/`, none cover the full six-case-group set).
- README plugin inventory not regenerated from actual `.claude-plugin/`
  manifests.

## Skip record

Scouting (external web sweep) is not fully run: the design's central
decision — adopt `core/hooks/lib/gate-lib.sh` verbatim, no reimplementation
— is fixed by the issue's own precondition and by
`docs/handbooks/canon-scripts.md`'s reference-not-copy rule, leaving no
open "which vendor/pattern to adopt" question for an external sweep to
resolve. The remaining open design surface (section/adjacency markdown
parsing shape) is covered by direct inspection of the five gates' own
existing code plus the landed core standard, which is the authoritative
and only in-scope reference per the issue's stated precondition — not a
comparison-shopping decision. See `scout-brief.md` for the one-round
internal-reference synthesis this produced.
