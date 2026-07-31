# km-supersession

Enforces reciprocal supersession linking for pattern entries under
`docs/patterns/` — the ADR `status:superseded` convention applied to
patterns. When a staged pattern entry declares `supersedes: <path>` and/or
`superseded_by: <path>`, the counterpart entry must also be staged in the
same commit and must declare the matching field back. A one-sided
supersession claim is refused.

This plugin is member 3 of 3 composing the `knowledge-management` role's
phase-2 norm, jointly with `km-pattern-entry` (pattern-language authoring)
and `km-cross-index` (cross-issue indexing) — the three are jointly
necessary and no single one is sufficient on its own.

The gate runs as a `PreToolUse` hook on `Bash` commands that look like a
`git ... commit`, and inspects only staged (`git show :<path>`) content —
not the working tree — so it sees exactly what would be committed.

Kill switch: set `KM_SUPERSESSION_GATE_OFF=1` (or `true`/`yes`/`on`) to
disable the gate.

Canon reference: this gate's shape (fail-closed trap, kill switch, staged
git-diff inspection) follows the same structural pattern as
implementation-rulebook's `coding-progress-gate.sh`. No script is vendored
or copied from that repo — this is an independent implementation of the
shared pattern.
