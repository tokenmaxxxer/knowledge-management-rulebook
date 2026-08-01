---
subject: issue-10
role: knowledge-management
loop_state: landed
---

# Report — gate A+ remediation via gate-house standard adoption (issue-10)

Phase 2 delivery per the approved
`docs/issue-10/proposals/knowledge-management/proposal.md` (Option A),
opened by the `APPROVE issue-10/knowledge-management` issue comment
(single-account mode).

## What was done

All five gates (`km-pattern-entry/hooks/pattern-entry-gate.sh`,
`km-adr-proposal/hooks/adr-shape-gate.sh`,
`km-cross-index/hooks/index-shape-gate.sh`,
`km-cross-index/hooks/index-pairing-gate.sh`,
`km-supersession/hooks/supersession-pairing-gate.sh`) were migrated onto
core issue #72's landed `core/hooks/lib/gate-lib.sh`/`gate-lib.py`
(reference-only, sourced via the `CLAUDE_PLUGIN_ROOT_CORE`/`../../core`
pattern already used by `knowledge-management/hooks/directive.sh`), and
each gate's semantic checks were upgraded from whole-text substring
matching to section/adjacency/structure parsing, per the proposal's four
work items.

1. **gate-lib migration** — every gate now calls `gate_trap_fail_closed`,
   `gate_kill_switch_active` (closes the fail-open-on-unrecognized-value
   bug the audit named), `gate_deny`/`gate_allow`,
   `gate_parse_json_or_deny` (malformed/non-object/empty JSON all deny),
   and, for the three shape gates, `gate_normalize_path` +
   `gate_reconstruct_write` (closes the `replace_all`-ignored bug and adds
   `NotebookEdit` coverage — each shape gate either added `NotebookEdit`
   handling or documents in-code why it stays out of scope).
   - The two pairing gates (`index-pairing-gate.sh`,
     `supersession-pairing-gate.sh`) do not reconstruct file content and
     are not Write/Edit/MultiEdit path-scoped, so `gate_reconstruct_write`/
     `gate_normalize_path` do not apply to them — documented in each
     script and in their test files.
2. **Multiline git-commit bypass fixed** in both pairing gates: the
   audit-named `grep -Eq '\bgit\b[^\n]*\bcommit\b'` (stops at any
   embedded newline) was replaced with a newline-tolerant match done
   inside each gate's Python payload, with a regression test in each
   suite proving a `git`/`commit` command split across an embedded
   newline is still caught.
3. **Unquoted for-loop word-split fixed** in
   `supersession-pairing-gate.sh:106` (now line ~138): the bare
   `for entry in $pattern_entries` was replaced with a real bash array
   built via `while read -r`, iterated quoted, plus a
   `get_field()` regex fix (`\S+` → `.+?`) so a staged pattern-entry path
   containing a space is recognized as one entry both as the subject and
   as a `supersedes`/`superseded_by` target value — the original `\S+`
   silently truncated any spaced path at its first space, a related
   defect the audit didn't separately name but that the mandated
   spaced-path regression test surfaced.
   - `index-pairing-gate.sh`'s equivalent spaced-path case was verified
     NOT to be a live bug (git's plain-space paths were never quoted in
     porcelain output); it was still switched to NUL-terminated
     (`git diff --cached -z`) parsing as the more defensive baseline, with
     a regression test.
4. **Semantic check upgrade** (substring → section/adjacency/structure),
   applied to the three gates that had a `has_any()`-style check:
   - `pattern-entry-gate.sh`: front-matter keys now require an actual
     `^key:` line inside the `---`/`---` block (not substring-anywhere);
     headings require an actual `^#{1,6}\s+.*word` heading line; the
     existing Context→Problem→Why→Solution→Consequences order check now
     also requires adjacency (no unrelated heading between two mandated
     ones).
   - `adr-shape-gate.sh`: same heading-line-match tightening; added
     adjacency to the existing order requirement for
     Context→Options considered→Decision→Consequences→Sources; the
     "≥2 options" count and the "easier"/"harder" check are now scoped to
     their own section only (closes a cross-section-leak the proposal
     named).
   - `index-shape-gate.sh`: the table-header `keyword`/`status` check
     moved from whole-line substring to exact per-cell match after
     splitting the header row on `|` (closes a column-name substring-leak,
     e.g. a `Keywords_Extra` column no longer falsely satisfies the
     `keyword` requirement).
   - The two pairing gates have no `has_any()`-style content check
     (their existing front-matter field parser in `get_field()` already
     line-anchors correctly); not in scope for this upgrade beyond the
     `.+?` fix in item 3.
5. **README realignment** — `README.md`'s Layout section now lists all
   four real plugins, their gate/test file paths, and their kill-switch
   env vars, generated from the actual `.claude-plugin/` manifests and
   `hooks/` trees (root `.claude-plugin/marketplace.json` was already
   accurate — no drift found there).

## Upstream basis

Built on the approved
`docs/issue-10/proposals/knowledge-management/proposal.md` (Option A),
which is itself built on core issue #72's landed
`core/hooks/lib/gate-lib.sh`/`gate-lib.py` +
`core/hooks/tests/compliance-check.sh` +
`docs/handbooks/gate-house-standard.md` (read from the landed core
checkout at commit `5550961`/PR #74, confirmed merged to
`tokenmaxxxer/tokenmaxxxer-core` main via `gh api
repos/.../git/refs/heads/main`).

## How you know it worked

- `core/hooks/tests/compliance-check.sh <plugin>/hooks` run against all
  four plugins, clean:

  ```
  === km-pattern-entry ===
  compliance-check: ok — km-pattern-entry/hooks/pattern-entry-gate.sh
  === km-adr-proposal ===
  compliance-check: ok — km-adr-proposal/hooks/adr-shape-gate.sh
  === km-supersession ===
  compliance-check: ok — km-supersession/hooks/supersession-pairing-gate.sh
  === km-cross-index ===
  compliance-check: ok — km-cross-index/hooks/index-shape-gate.sh
  compliance-check: ok — km-cross-index/hooks/index-pairing-gate.sh
  ```

- Full suite green, all five gates, run with `CLAUDE_PLUGIN_ROOT_CORE`
  pointed at the landed core checkout (this repo carries no local
  `core/` copy — reference-only per the gate-house standard):

  ```
  pattern-entry-gate.test.sh:        SUMMARY: 24 passed, 0 failed
  adr-shape-gate.test.sh:            25/25 passed
  index-shape-gate.test.sh:          21 passed, 0 failed
  index-pairing-gate.test.sh:        13 passed, 0 failed
  supersession-pairing-gate.test.sh: 11 passed, 0 failed
  ```

  All six mandatory case groups (replace_all-multi-occurrence, MultiEdit
  mixed replace_all, malformed-JSON trio, kill-switch-unrecognized-value,
  absolute/`./`-path equivalence, Bash-write-same-target) are present in
  the three shape gates' suites; the two pairing gates carry the subset
  applicable to their trigger shape (malformed JSON, kill-switch,
  multiline git/commit regression, spaced staged-path regression) plus a
  documented note on the inapplicable groups.
- Quoted-YAML-value / heading-in-prose / cross-section-leak /
  adjacency-violation negative fixtures added per gate, alongside a
  positive well-formed-document fixture — all passing.

## Process note

Migration for the five gates ran as five parallel background workers
(freelunch fan-out; the Workflow tool was unavailable in this session
and degraded to direct Agent-tool dispatch per the fallback order). Two
workers (`index-shape`, `supersession-pairing`) hit an environment-level
Bash denial in their sandbox and could not run their own test suites;
their code changes were completed but untested. The orchestrating
session ran both suites directly afterward, found and fixed two real
defects the untested code had introduced (`gate_bash_write_targets`
called from Python — it is bash-only in `gate-lib.sh`, not exposed to
`gate-lib.py`; and the pre-existing `get_field()` regex truncating
spaced paths at the first space), then reconfirmed all five suites and
the compliance detector green before this record was written.

## Open findings

None outstanding. The two Bash-denial-related defects discovered mid-run
(process note above) were both fixed and reverified before delivery; no
known gap remains against the proposal's four work items or its "how
you'll know it worked" criteria.
