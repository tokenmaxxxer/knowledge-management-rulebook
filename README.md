# knowledge-management-rulebook

Rulebook for the `knowledge-management` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-4 promotion and
generated as skeleton scaffolding by issue-167.

- **decides**: 개별 이슈의 교훈이 조직 차원에서 재사용 가능한 형태로 축적·색인되는가
- **use_when**: 여러 이슈의 회고가 쌓여 지식 큐레이션이 필요할 때
- **produces**: curated pattern-library entry, cross-issue index, supersession note (if replacing an older pattern)
- **write_scope**: ['docs/patterns/**']
- **hand-off**: 단일 이슈 회고 자체는 → issue-retrospective

## Install

```
claude plugin marketplace add tokenmaxxxer/knowledge-management-rulebook
claude plugin install knowledge-management
```

## Layout

- `knowledge-management/.claude-plugin/plugin.json` — plugin manifest
- `knowledge-management/hooks/hooks.json` — SessionStart wiring (role-agnostic gates now fire from core's own `hooks.json`)
- `knowledge-management/hooks/directive.sh` — SessionStart role directive stub (sources `core/hooks/lib/role-directive.sh`)
- `docs/handbooks/knowledge-management.md` — this role's write_scope and boundary-case doctrine
- core `warrant` plugin — rotating-stance hunt agent (installed alongside this rulebook, per core issue #63)
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

### Enforcement plugins

Four plugins compose the role's methodology gates. All five gate scripts
below source `core/hooks/lib/gate-lib.sh`/`gate-lib.py` (issue #72's
gate-house standard) instead of hand-rolling the fail-closed trap,
kill-switch, path-normalize, and Write/Edit/MultiEdit/NotebookEdit
reconstruction logic; `core/hooks/tests/compliance-check.sh` runs clean
against every plugin below.

- **`km-adr-proposal`** (phase-1 norm, sole plugin) — ADR-shape gate on
  `docs/issue-<n>/proposals/knowledge-management/*.md`.
  - `km-adr-proposal/hooks/adr-shape-gate.sh`
  - `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh`
  - kill switch: `KM_ADR_PROPOSAL_GATE_OFF`
- **`km-pattern-entry`** (phase-2 norm, member 1 of 3) — pattern-language
  front-matter + heading-order/adjacency gate on `docs/patterns/*.md`
  (excludes `index.md`).
  - `km-pattern-entry/hooks/pattern-entry-gate.sh`
  - `km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh`
  - kill switch: `KM_PATTERN_ENTRY_GATE_OFF`
- **`km-cross-index`** (phase-2 norm, member 2 of 3) — two gates on
  `docs/patterns/index.md`: table-shape (keyword/status columns) and
  same-commit pairing with any newly staged pattern entry.
  - `km-cross-index/hooks/index-shape-gate.sh`
  - `km-cross-index/hooks/index-pairing-gate.sh`
  - `km-cross-index/hooks/tests/index-shape-gate.test.sh`
  - `km-cross-index/hooks/tests/index-pairing-gate.test.sh`
  - kill switch (shared by both gates): `KM_CROSS_INDEX_GATE_OFF`
- **`km-supersession`** (phase-2 norm, member 3 of 3) — reciprocal
  `supersedes`/`superseded_by` pairing gate at git-commit time.
  - `km-supersession/hooks/supersession-pairing-gate.sh`
  - `km-supersession/hooks/tests/supersession-pairing-gate.test.sh`
  - kill switch: `KM_SUPERSESSION_GATE_OFF`

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
