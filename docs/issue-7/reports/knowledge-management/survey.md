# Current-state survey — issue #7 (phase 1)

Subject: issue-7. Scout folded into this survey (this is an internal
engineering-design task, not a market question — see "Scout notes" below
per this session's scout-directive).

## What issue #1 established (the norm source this issue must enforce)

- `docs/issue-1/proposals/knowledge-management/2026-07-31-km-methodology-norms.md`
  (referenced from the handbook below) — adoption rationale for this
  role's methodology; ADR-shaped.
- `docs/handbooks/knowledge-management.md` (issue-1, phase 2, landed) —
  the actual normative text. Key load-bearing sections:
  - **Phase-1 proposal norm** (handbook, "Phase-1 proposal norm" section):
    every proposal must be ADR-shaped — Context, Options considered
    (>= 2, with rejection reasons), Decision & rationale, Consequences
    (both easier and harder), Sources (URL or `path:line`, unsourced
    claims labeled `assumption`).
  - **Phase-2 artifact templates** (handbook, "Phase-2 artifact
    templates" section) — three required kinds, matching
    `knowledge-management/hooks/directive.sh`'s `PRODUCES` line:
    1. Pattern-library entry (`docs/patterns/<slug>.md`): front matter
       `title`, `keywords`, `source_issues`, `supersedes`/
       `superseded_by`; body sections in fixed order Context / Problem /
       Why / Solution / Consequences.
    2. Cross-issue index (`docs/patterns/index.md`): one table row per
       pattern entry added in the same change.
    3. Supersession note: both-direction front-matter linking
       (`superseded_by` on the old entry, `supersedes` on the new one)
       in the same change.
  - **Phase-2 record self-check** (handbook, same file) — explicitly
    states this is "a manual checklist item, not a code gate" today;
    core's `record-fields-gate.sh` enforces only the generic §20 fields,
    not this role's own `produces` list. This is the exact gap issue-7
    is opened to close.
- `knowledge-management/hooks/directive.sh` — `PRODUCES (required record
  fields): curated pattern-library entry, cross-issue index, supersession
  note (if replacing an older pattern)` — one summary line, no stage
  detail, no judgment criteria, no prohibitions. This is the "directive
  一 줄 요약" the issue calls out as insufficient.
- `knowledge-management/hooks/hooks.json` — currently wires
  `SessionStart` → `directive.sh` and `PreToolUse` (Bash matcher) →
  `knowledge-management-progress-gate.sh`, but **that progress-gate
  script does not exist in this repo** (`find` confirms only
  `directive.sh` and `hooks.json` under `knowledge-management/hooks/`).
  The hooks.json entry is a stub pointing at nothing — a second,
  independent gap from the one issue-7 names (no methodology gate on
  the Write/Edit surface at all), worth flagging in the proposal.

## What the reference bar (implementation-rulebook) looks like

Read directly from the sibling checkout at
`/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook` (not part of
this repo; cited by absolute path for traceability, not copied in).

- `coding/hooks/coding-progress-gate.sh` (~180 lines) — PreToolUse gate
  matched on `Bash` (`git commit`). Shape, in order:
  1. **Fail-closed trap at top**: `trap __fc EXIT` remaps any abnormal
     exit code to `2` (deny) before any gate logic runs — installed as
     the literal first executable statement, above `set`/`source`.
  2. Tool binary preconditions checked explicitly (`python3`, `git` on
     PATH) with `deny` on absence, never silent fallback.
  3. Project-root resolution via `CLAUDE_PROJECT_DIR` with a
     `_plausible()` sanity check, falling back to `git rev-parse
     --show-toplevel`, denying if neither resolves.
  4. Payload parsed as JSON from stdin inside an embedded `python3`
     heredoc; every parse/shape failure denies with a stated reason
     (never silently allows).
  5. Business logic: derive the subject issue from staged files /
     commit-message trailer, read a state file scoped to that subject
     (`docs/issue-<n>/reports/verify.md`), parse structured `finding`
     blocks by regex, and refuse the commit if a `blocking`
     `addressed_to: coding` finding exists without a matching
     `resolved_findings` entry AND the finder's own `loop_state:
     cleared`.
  6. Outer `try/except` around the whole python body maps *any*
     unhandled internal error to exit 2 with a labeled
     `fail-closed: internal error` message, never exit 0.
  - This gate enforces an **ordering constraint** (verify's finding must
    be resolved before coding's next commit) via a **state field**
    (`loop_state`) read from another role's record — this is the
    "상태 추적으로 강제" instance the issue points at for
    order-dependent methodologies.

- `pricing/hooks/methodology-gate.sh` (~230 lines, explicitly the
  pattern issue-7 names as the reference: "pricing-rulebook의
  methodology-gate.sh 참조") — PreToolUse gate matched on
  `Write|Edit|MultiEdit`. Shape:
  1. Same fail-closed trap-at-top pattern.
  2. Kill switch via env var (`PRICING_METHODOLOGY_GATE_OFF`) — an
     explicit, documented escape hatch, not a silent bypass.
  3. Target-path extraction from `tool_input.file_path` /
     `notebook_path`, resolved against project root, restricted to two
     named write surfaces via regex:
     `^docs/issue-[0-9]+/proposals/.*pricing.*\.md$` and
     `^docs/issue-[0-9]+/reports/pricing\.md$`. Anything else exits 0
     immediately ("not this gate's business") — the gate is scoped
     exactly to this role's own write surface, layered **on top of**
     (comment: "never instead of") core's generic
     `record-fields-gate.sh`.
  4. Reconstructs the **resulting** document text for `Write` (use
     `content` directly), `Edit` (apply `old_string`→`new_string` if it
     matches current content), and `MultiEdit` (apply the edit chain in
     order); denies if the resulting text can't be determined (e.g. an
     `Edit` whose `old_string` doesn't match) rather than guessing.
  5. Checks six required elements are present in the resulting text via
     keyword/phrase detection (`has_any(...)` substring checks over
     lower-cased text) — method named (or an explicit early-exit
     phrase), family named when a superset term appears, inputs-needed
     stated, a gate-check result phrase present, verdict numbers carry
     a label when digits are present, and a residual/"cannot answer"
     list. Each missing element is collected into a list and reported
     together in one `deny()` call naming every gap and citing the
     methodology-norms doc it derives from.
  6. Same internal-error-catches-to-exit-2 wrapper as the coding gate.

- `tests/run-gate-tests.sh`, `tests/parse-check.sh`,
  `tests/deny-only-check.sh` at implementation-rulebook's repo root —
  a shared test harness pattern (not read in full; names alone confirm
  a root-level `tests/` convention exists and is where issue-7's ask
  "레포 루트 tests에 게이트 통과/거부 케이스" points).

## Gap: what this role is missing to reach that bar

1. **Directive**: `directive.sh`'s single `PRODUCES` line has no stage
   breakdown, no judgment criteria, no prohibitions, no per-facet
   (phase-1 survey / phase-1 proposal / phase-2 pattern-entry / phase-2
   index / phase-2 supersession) executable checklist. The handbook
   carries some of this in prose but is not read at session start the
   way `directive.sh` is (`SessionStart` hook), and is not phrased as
   stage/criteria/prohibition.
2. **Methodology gate**: none exists. `hooks.json` references a
   `knowledge-management-progress-gate.sh` file that is absent, and no
   `Write|Edit|MultiEdit`-matched hook exists at all, so nothing
   mechanically checks a pattern-entry's five body sections + front
   matter, the index-row-added-in-same-change rule, or the
   both-sides-linked supersession rule the handbook already specifies
   in prose ("Phase-2 record self-check" explicitly says today this is
   manual).
3. **Ordering constraint**: the handbook's cross-issue-index rule
   ("Adding an entry requires adding its row here in the same change")
   and the supersession both-sides rule are exactly the kind of
   sequencing constraint implementation-rulebook enforces with a state
   field (`loop_state` in `coding-progress-gate.sh`). Nothing here
   tracks that today; a same-commit-set check (rather than a persisted
   state file) may be sufficient since index-row and pattern-entry
   normally land together, but this needs an explicit design decision
   (see proposal, Options considered).
4. **Tests**: no `tests/` directory exists at this repo's root at all.
5. **hooks.json bug**: the stub reference to a nonexistent
   `knowledge-management-progress-gate.sh` should be corrected/replaced
   by whatever phase-2 actually implements, not left dangling.

## Scout notes (prior art for "artifact must contain X" mechanical gates)

Primary sweep was in-repo (above) per this session's scout-directive:
survey prior art within this repo/its sibling rulebooks first. Two
general external engineering patterns are worth naming briefly, both
already implicitly used by the sibling gates read above, so no separate
web sweep was run:

- **Front-matter/schema validation** — treat the front matter of a
  Markdown file as a small schema (required keys, types) and validate on
  write; this is the shape the pattern-entry's `title`/`keywords`/
  `source_issues` front matter maps onto directly.
- **Required-section linting** (the docs-as-code convention behind tools
  like `markdownlint`'s heading-structure rules, and behind
  `methodology-gate.sh`'s own approach) — verify a fixed, ordered set of
  section headers/keyword-markers exists in the body; this is the shape
  the pattern-entry's five body sections (Context/Problem/Why/Solution/
  Consequences) map onto, and is exactly what `methodology-gate.sh`
  already does via `has_any()` substring checks rather than a full
  Markdown-AST parse (a deliberate simplicity/robustness trade-off worth
  carrying forward — see proposal).

## Constraint carried forward from issue-1 / issue-2

- Canon scripts (`role-directive.sh`, `record-fields-gate.sh`, any core
  hook lib) are referenced only, never vendored — per `core
  canon-scripts.md` and issue-2's landed reference-conversion precedent.
  The new methodology gate must be additive, role-scoped, layered on top
  of core's generic gate (mirroring `methodology-gate.sh`'s own comment:
  "on top of (never instead of)"), not a replacement or a copy of core
  logic.
- Role boundary / `write_scope: ['docs/patterns/**']` is unchanged by
  this issue; the gate only adds enforcement over surfaces this role
  already owns (`docs/patterns/**`, this role's own phase-1 proposals,
  this role's own phase-2 record).
