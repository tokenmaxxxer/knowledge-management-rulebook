# Issue #2 — current-state survey

Subject: issue-2. Phase 1 only — research and proposal, no execution.

## What this rulebook currently vendors

- `knowledge-management/agents/warrant-hunter.md` — full copy of the hunt
  agent, header-adapted only ("adapted from implementation-rulebook's
  agents/warrant-hunter.md"), no hunt-cadence dispatch wiring found anywhere
  else in this repo (no `hooks/hunt-guard.sh`, `hunt-state.sh`, `state.sh`,
  or `scope-gate.sh` — those live only in core's separate `warrant/` plugin).
- `knowledge-management/hooks/trailer-gate.sh`,
  `record-fields-gate.sh`, `handbook-trigger-gate.sh` — three files, each
  header-annotated "adapted from implementation-rulebook's X.sh, role name
  substituted only" (trailer-gate, handbook-trigger-gate) or independently
  role-specific in payload only (record-fields-gate's `REQUIRED_FIELDS`,
  `RECORD_SUFFIX`). All three are registered a second time in
  `hooks/hooks.json`.
- `knowledge-management/hooks/directive.sh` — hand-written SessionStart
  script: shebang, `trap ... EXIT`, `set -uo pipefail`, kill-switch case,
  `CLAUDE_ROLE` guard, then a `cat <<'DIRECTIVE'` heredoc with this role's
  four values (YOU DECIDE / USE_WHEN / PRODUCES / HAND-OFF) plus the
  boilerplate opening/closing lines and RECORD line.
- `knowledge-management/hooks/hooks.json` also registers a fifth hook,
  `knowledge-management-progress-gate.sh`, under the same `Bash` matcher as
  `handbook-trigger-gate.sh` / `trailer-gate.sh` — **that file does not
  exist in this repo.** Not one of the issue's 5 items and out of scope
  here; flagged as a pre-existing dangling reference for a follow-up issue,
  not touched by this proposal.

## What core now ships (verified by reading core canon directly, not its docs)

- `core/hooks/lib/role-directive.sh` (tokenmaxxxer-core@main, commit
  2fd1fcb) — exports `core_role_directive(you_decide, use_when, produces,
  hand_off)`. Reads `CLAUDE_ROLE`, no-ops if unset; kill switch via
  `<ROLE_UPPER>_CYCLE_OFF` (role name uppercased with `tr`, matching this
  role's existing `KNOWLEDGE_MANAGEMENT_CYCLE_OFF`); prints the same
  `[<role>] Role directive ...` header and `RECORD: docs/issue-<n>/...`
  footer this rulebook's own directive.sh hand-rolls today.
- `core/hooks/tests/stub-check.sh` — distributed test, run against a
  rulebook's own `hooks/` tree (`stub-check.sh [hooks-dir]`). Two checks:
  1. **Absence check** for `trailer-gate.sh`, `record-fields-gate.sh`,
     `handbook-trigger-gate.sh`, `parse-check.sh` — any vendored copy under
     the rulebook's own `hooks/` (depth ≤3) is a FAIL, because core now
     fires these globally via its own `hooks.json` (`PreToolUse` /
     matcher `.*`, parameterized on `CLAUDE_ROLE`).
  2. **Structural check** for `directive.sh` — every non-blank,
     non-comment line must be the `role-directive.sh` source line, a
     plain `VAR=value` assignment, or the `core_role_directive` call.
     Anything else (trap, case, guard, raw heredoc) fails as "regrown
     boilerplate."
- `core/warrant/agents/warrant-hunter.md` — the canonical hunt-agent
  definition now lives in core's own `warrant` plugin (separate
  `.claude-plugin`, not under `core/`), installed alongside `core` per the
  marketplace. It is role-agnostic already — no role name baked into its
  text (the "one stance, one finding" mandate reads the same regardless of
  which rulebook installs it). This repo's copy predates that promotion.
- Core's own `hooks.json` fires `board-gate.sh`, `approval-gate.sh`,
  `gh-guard.sh`, `trailer-gate.sh`, `record-fields-gate.sh`,
  `handbook-trigger-gate.sh` for every plugin install, matcher `.*`,
  parameterized on `CLAUDE_ROLE` — so `record-fields-gate.sh`'s
  role-specific `REQUIRED_FIELDS` payload must resolve per-role somehow on
  the core side (not verified from inside this repo's checkout; core's own
  copy was not read in depth since this survey scopes to what this repo
  needs to remove, not core's internals — noted as an open question for
  item 4 below).

## Gaps against the issue's 5 items

1. Remove `agents/warrant-hunter.md` + hunt-cadence dispatch text → replace
   with a core-canon reference. No dispatch text exists outside the file
   itself, so item 1 is a delete + one-line pointer, nothing else to touch.
2. Remove the three gate copies and their `hooks.json` entries → core
   already fires the role-agnostic three. Confirmed core's `hooks.json`
   covers all three by matcher `.*` (broader than this repo's split
   `Write|Edit|MultiEdit` / `Bash` matchers, but a superset, not a gap).
3. Replace `directive.sh` with the stub form stub-check.sh requires:
   source `role-directive.sh`, then exactly one `core_role_directive` call
   with this role's four already-known values. No case/trap/guard may
   remain (stub-check.sh's structural check fails a file that keeps any).
4. `RECORD_FIELDS_TERMINAL_STATES` — **open question, not resolved by this
   survey**: this repo's own `record-fields-gate.sh` checks `REQUIRED_FIELDS`
   substring-presence in the target markdown, not any `loop_state`
   machinery — no `TERMINAL_STATES` concept exists in this repo's current
   gate at all. Whether this role needs an explicit
   `RECORD_FIELDS_TERMINAL_STATES` override depends on core's
   `record-fields-gate.sh` internals (which loop states it treats as
   terminal by default, and whether knowledge-management's set differs).
   The proposal below states this as the item to verify against core's
   actual gate source before writing the override, rather than guessing at
   a difference that may not exist.
5. `core/hooks/tests/stub-check.sh` exists and is runnable
   (`bash core/hooks/tests/stub-check.sh <dir>` pattern, confirmed by
   reading the script directly) — running it against this repo's
   `knowledge-management/hooks/` post-change and recording the result is
   phase-2 work (the record file itself is phase-2 output per contract
   v3 s19); this survey only confirms the tool exists and how to invoke it.

## Scout

Skipped. `core/hooks/lib/role-directive.sh` and `core/hooks/tests/stub-check.sh`
are read directly (verbatim, not from core's own docs/decisions) and they
prescribe the exact required shape of the replacement stub and the exact
absence-check for the three gates — there is no external design space left
to survey; the only open question (item 4) is an internal fact about core's
own gate source, not a best-in-class product question. Per scout-directive's
skip conditions ("spec literally leaves no design decision open"), no
scout-brief.md is written.
