# km-cross-index

Enforces the cross-issue pattern index methodology at `docs/patterns/index.md`:

- **PMI keyword searchability** — `hooks/index-shape-gate.sh` blocks any Write/Edit/MultiEdit
  to `docs/patterns/index.md` unless the resulting content contains a markdown table with a
  header row (followed by a separator row) that includes both a `Keyword` and a `Status`
  column, so entries stay discoverable by keyword and lifecycle state rather than by memory.
- **Same-commit index pairing** — `hooks/index-pairing-gate.sh` blocks `git commit` when a new
  pattern entry file under `docs/patterns/*.md` is staged as newly added without
  `docs/patterns/index.md` also staged in the same commit, so the index can never drift behind
  the entries it is supposed to catalog.

This plugin is member 2 of 3 composing the `knowledge-management` role's phase-2 norm, jointly
with `km-pattern-entry` and `km-supersession`.

Both gates share one kill switch, `KM_CROSS_INDEX_GATE_OFF` (set to a truthy value other than
`""`, `0`, `false`, `no`, `off` to disable).

Canon reference: this plugin's gate scripts follow the structural pattern of
`pricing-rulebook`'s `methodology-gate.sh` and `implementation-rulebook`'s
`coding-progress-gate.sh` — canon scripts are referenced, never copied.
