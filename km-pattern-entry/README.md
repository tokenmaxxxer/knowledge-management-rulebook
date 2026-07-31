# km-pattern-entry

Enforces the pattern-entry authoring methodology for files under
`docs/patterns/*.md` (excluding `index.md`): a Christopher Alexander-style
pattern-language front matter (`title:`, `keywords:`, `source_issues:`) plus a
NASA-AAR-derived "why" narrative arc — headings for Context, Problem, Why,
Solution, and Consequences, in that exact order. A `Write`/`Edit`/`MultiEdit`
that would leave a pattern entry missing any of these elements is refused.

This plugin is **member 1 of 3** composing the knowledge-management role's
phase-2 norm, jointly with `km-cross-index` (cross-issue indexing, owns
`index.md`) and `km-supersession` (reciprocal supersession linking). The
three are jointly necessary — none of them alone is sufficient to satisfy the
phase-2 norm.

Kill switch: set `KM_PATTERN_ENTRY_GATE_OFF=1` (or any truthy value other
than `0`/`false`/`no`/`off`) to bypass the gate.

Canon reference: the gate script structurally follows the shape of
pricing-rulebook's `methodology-gate.sh` (fail-closed trap, kill switch,
additive missing-element reporting) — no code was copied from that or any
other external repo; only the pattern was reused.
