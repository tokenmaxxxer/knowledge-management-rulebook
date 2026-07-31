---
proposal: docs/issue-2/proposals/2026-07-31-core-canon-reference-conversion.md
loop_state: proposed
upstream: []
---

# Proposal — core canon 참조 전환 (issue #2)

Subject: issue-2. Phase 1 output — proposal only, no execution. Approve is
required before any of the changes below are made.

## Request

Convert this rulebook's three vendored copies (warrant-hunter agent, three
role-agnostic gates, directive.sh boilerplate) to references against the
canon core just landed (core issue #63 → PR #65, core issue #66 → PR #68),
per issue #2's 5-item list. Preserve everything that is genuinely
role-unique to `knowledge-management`.

## Constraints

- One batch, matching the issue's own framing ("작업 (한 배치)").
- Role-unique content survives: the four directive values (YOU DECIDE /
  USE_WHEN / PRODUCES / HAND-OFF), the record's required-field intent, and
  this role's own write_scope.
- Must pass `core/hooks/tests/stub-check.sh` against
  `knowledge-management/hooks/` once done (item 5) — verified in phase 2,
  not here.
- This conversion must land before this repo's own "rulebook 성숙화" phase 2
  (issue's 순서 제약).

## What will be done

### 1. Remove the warrant-hunter copy

Delete `knowledge-management/agents/warrant-hunter.md`. No hunt-cadence
dispatch instructions exist elsewhere in this repo to also strip — the
agent file is the entire vendored surface. Core's `warrant` plugin
(`tokenmaxxxer-core` repo, `warrant/agents/warrant-hunter.md`) is already
role-agnostic text; installing it alongside this rulebook's plugin (via the
marketplace, same pattern `core` itself uses) replaces it with zero local
content. Add one line to `README.md`'s Layout list pointing at the core
`warrant` plugin instead of a local file, so the layout doc doesn't dangle.

### 2. Remove the three gate copies + their hooks.json registrations

Delete `knowledge-management/hooks/trailer-gate.sh`,
`record-fields-gate.sh`, `handbook-trigger-gate.sh`. Remove their three
`PreToolUse` entries from `knowledge-management/hooks/hooks.json` (the
`Write|Edit|MultiEdit` matcher's `record-fields-gate.sh` entry and the
`Bash` matcher's `handbook-trigger-gate.sh` / `trailer-gate.sh` entries).
Core's own `hooks.json` (installed with the `core` plugin, matcher `.*`)
already fires all three, parameterized on `CLAUDE_ROLE` — confirmed by
reading `tokenmaxxxer-core/core/hooks/hooks.json` directly.

**Flag, not a blocker**: core's canon `record-fields-gate.sh` checks a
*different* set of required fields than this repo's copy. This repo's
version checks role `produces` fields (`pattern-library-entry`,
`cross-issue-index`, `supersession-note`); core's canon version checks
generic contract §20 fields (what-was-done, why, upstream-basis,
loop_state, open-findings — same check for every role). This is the
intended effect of core issue #66's approved promotion, not a defect this
proposal introduces — but it means this role's record will no longer be
gated on its own `produces` list, only on the shared §20 minimum. Worth the
approver's explicit sign-off since it changes what future `docs/issue-<n>/
reports/knowledge-management.md` writes are required to contain.

### 3. Replace directive.sh with the stub form

Replace `knowledge-management/hooks/directive.sh` with:

```sh
#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive \
  "YOU DECIDE: 개별 이슈의 교훈이 조직 차원에서 재사용 가능한 형태로 축적·색인되는가" \
  "USE WHEN: 여러 이슈의 회고가 쌓여 지식 큐레이션이 필요할 때" \
  "PRODUCES (required record fields): curated pattern-library entry, cross-issue index, supersession note (if replacing an older pattern)" \
  "HAND-OFF: 단일 이슈 회고 자체는 → issue-retrospective"
```

This is the exact form `core/hooks/tests/stub-check.sh` requires
structurally (source line + var assignments only + one
`core_role_directive` call, nothing else) — no trap, no case, no guard, no
raw heredoc may remain. `write_scope` and the `BOUNDARY CASE` paragraph
currently in this role's directive text are not among
`core_role_directive`'s four parameters (`you_decide`, `use_when`,
`produces`, `hand_off`) and core's function does not print them — they are
genuinely role-unique content the stub form has no slot for. Move them
into `docs/handbooks/` (this role has none yet; create
`docs/handbooks/knowledge-management.md` carrying `write_scope: ['docs/patterns/**']`
and the boundary-case text verbatim) rather than dropping them, since
`handbook-trigger-gate.sh` (core canon, item 2) already expects a
handbook to exist per role.

### 4. `RECORD_FIELDS_TERMINAL_STATES`

Read core's canon `record-fields-gate.sh` directly
(`tokenmaxxxer-core/core/hooks/record-fields-gate.sh`): default terminal
set is `{"landed"}` (`RF_TERMINAL="${RECORD_FIELDS_TERMINAL_STATES:-landed}"`).
This role has no `loop_state` vocabulary defined anywhere yet (it is not
one of the kinds enumerated in `core/contract/role-handoff-contract.md`
§2's table — a round-4 addition not yet reflected there). No evidence
exists of this role needing a terminal state other than `landed`
(no divergent vocabulary to preserve). Proposed decision: **do not set
`RECORD_FIELDS_TERMINAL_STATES`** — adopt the default (`landed`) as this
role's own terminal state, consistent with the closest listed kind
(`coding-record`'s `proposed,approved,landed`). If phase-2 execution
surfaces a genuine divergence (e.g. this role needing its own
`scope-approved`-style state), set the env var explicitly in
`knowledge-management/hooks/hooks.json`'s `env` block at that point, with
the reason recorded — not guessed here.

### 5. `stub-check.sh` pass, recorded

`core/hooks/tests/stub-check.sh [hooks-dir]` is invoked as
`bash <path-to-core>/hooks/tests/stub-check.sh knowledge-management/hooks`.
Running it and recording the pass/fail output is phase-2 work (the record
file `docs/issue-2/reports/implementation.md` is itself phase-2 output per
contract v3 s19) — this proposal only confirms the invocation form, since
the script takes an optional single directory argument and defaults to its
own parent otherwise.

## Out of scope

- `knowledge-management/hooks/hooks.json`'s dangling reference to
  `knowledge-management-progress-gate.sh` (a file that does not exist in
  this repo) — pre-existing, not one of the issue's 5 items, not touched.
- Defining this role's actual `loop_state` vocabulary in
  `core/contract/role-handoff-contract.md` §2's table — that edit belongs
  to core's own repo/issue tracker, not this rulebook.
- Any change to `docs/handbooks/` content beyond the mechanical move
  described in item 3 (no new doctrine authored here).

## Open findings

None from this phase-1 survey beyond the two flagged above (item 2's
required-field semantics change, item 4's terminal-state default) — both
carried into "What will be done" as explicit decisions with rationale,
not left as unresolved questions.
