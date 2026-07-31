# km-adr-proposal

Enforces the ADR-shape methodology on phase-1 knowledge-management proposals
(`docs/issue-<n>/proposals/knowledge-management/*.md`): every such document
must carry a Context, at least two distinct reasoned Options considered, a
Decision, Consequences (naming something easier and something harder), and
Sources. It is the sole plugin composing the knowledge-management role's
phase-1 norm.

Kill switch: set `KM_ADR_PROPOSAL_GATE_OFF=1` (or `true`/`yes`/`on`) to
disable the gate.

Canon reference: the gate script (`hooks/adr-shape-gate.sh`) is modeled
structurally on the pricing-rulebook `methodology-gate.sh` pattern
(fail-closed trap, kill switch, `has_any` substring helper, additive
missing-element reporting) — no script text is copied or vendored from that
repo.
