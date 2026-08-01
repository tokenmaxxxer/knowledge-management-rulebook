---
subject: issue-13
role: knowledge-management
loop_state: proposed
---

# Survey — re-audit residuals on gate A+ closure (issue-13)

Phase 1, per contract v3 s19. This document verifies each item in the
2026-08-01 re-audit (issue #13) against the actual files in this repo on
branch `issue-13/knowledge-management` (forked from `main` at
`29d4156`), rather than restating the issue text. All five
enforcement plugins (`km-adr-proposal`, `km-cross-index`,
`km-pattern-entry`, `km-supersession`) and the `knowledge-management`
role-directive plugin exist in full on disk in this checkout
(confirmed via `find knowledge-management km-adr-proposal
km-cross-index km-pattern-entry km-supersession -maxdepth 4 -type f`);
none of this survey's findings depend on any of them being absent.

## Prerequisite landing check

Issue #13 lists two "already landed" preconditions.

- **on-the-record #182** (`CLAUDE_PLUGIN_ROOT_CORE` injection in
  `spawn.py`): `gh issue view 182 --repo tokenmaxxxer/on-the-record`
  returns `state: CLOSED`, body confirms the ask (spawn.py must inject
  `CLAUDE_PLUGIN_ROOT_CORE` when spawning a role session). Not
  independently re-verified against `spawn.py` source — no local
  checkout of `on-the-record` at its closing commit was found under
  `/home/jwjung/.tokenmaxxxer/work`. Treated as landed on the strength
  of the closed-issue state; this is a noted limitation, not a
  file-level verification.
- **core #75** (gate-lib source guard mandate, compliance-check
  detection of an unguarded source line, mandatory missing-core test,
  `gate_bash_write_targets` Python port): `gh issue view 75 --repo
  tokenmaxxxer/core` and `gh repo view tokenmaxxxer/core` both fail
  with "Could not resolve to a Repository" — there is no reachable
  `core` remote from this sandbox to query directly, and no local
  checkout of `on-the-record`/`core` at a post-#75 commit was found
  either. The two local core caches this survey could inspect,
  `/tmp/tokenmaxxxer-core-canon-cache/core` and
  `/tmp/tokenmaxxxer-core-test-fixture/core`, both sit at `git log -1`
  = `22a7cad deliver(implementation): gate-house standard canonization
  (issue-72) (#74)` — issue #72's landing, not #75's. `grep -rn
  gate_bash_write_targets` against `hooks/lib/*.sh` and `hooks/lib/*.py`
  in both caches finds the function **only in `gate-lib.sh` (bash)**,
  not in `gate-lib.py`; no source-guard convention, compliance-check
  rule for it, or missing-core test case beyond issue #72's own content
  was found in either cache.
  **Correction (later in this same session): the repo slug above was
  wrong.** `tokenmaxxxer/core` does not exist; the org's core repo is
  `tokenmaxxxer/tokenmaxxxer-core` (confirmed via `gh repo list
  tokenmaxxxer`). Re-run against the correct slug:
  `gh issue view 75 -R tokenmaxxxer/tokenmaxxxer-core` returns `state:
  CLOSED`, title "gate-lib 하우스 표준 결함 2건: source 무가드 fail-open +
  gate_bash_write_targets py 부재", confirming both the source-guard
  mandate and the Python port were the two asks. A fresh
  `git clone --depth 1 https://github.com/tokenmaxxxer/tokenmaxxxer-core.git`
  (bypassing the two stale local caches above, which are both pinned at
  `22a7cad`/#74, i.e. issue #72's close, not #75's) lands at commit
  `52bdc15 deliver(implementation): gate-lib source guard +
  gate_bash_write_targets py parity (issue-75) (#77)` on `main`, and
  directly contains all three landed pieces: (a)
  `core/hooks/lib/gate-lib.sh`'s usage-contract comment now states the
  guard literally — `. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }`;
  (b) `core/hooks/tests/compliance-check.sh` contains the rule
  `grep -q 'gate-lib\.sh"$' "$f" && ! grep -qE 'gate-lib\.sh"[[:space:]]*\|\|' "$f"`
  (same-line guard detection); (c) `core/hooks/lib/gate-lib.py` now
  defines `gate_bash_write_targets(command)` (`_BASH_WRITE_TARGET_RE`,
  a mirror of the sh version's `[[:alnum:]_./~$-]+` class); (d)
  `core/hooks/tests/run-gate-lib-tests.sh` has a "group 7: missing-core
  -> guarded source must deny, not allow" case. **Core #75 is confirmed
  landed** — the "not confirmed from this sandbox" finding above was an
  artifact of querying the wrong repo slug, not an actual gap in core's
  state. This correction is also independently cross-checked by a
  sibling role's own issue-13 survey,
  `/home/jwjung/.tokenmaxxxer/work/api-design-rulebook-issue-13-api-design/docs/issue-13/reports/api-design/current-state.md`,
  which names the same commit `52bdc15`/PR #77.

## Item-by-item verification

### 1. adr-shape-gate's Bash branch is unreachable in production

Confirmed. `km-adr-proposal/hooks/hooks.json:5` sets
`"matcher": "Write|Edit|MultiEdit"` for the sole `PreToolUse` hook
entry, which runs `adr-shape-gate.sh`. But `adr-shape-gate.sh:111-126`
contains an `elif tool_name == "Bash":` branch (denies when a Bash
command's tokens resolve to an ADR-proposal target path), and
`km-adr-proposal/hooks/tests/adr-shape-gate.test.sh:288-305`
("Mandatory case group 6") invokes the script directly with a
`tool_name: "Bash"` payload and asserts both a deny and a pass case.
Both pass today because the test harness calls the script directly,
bypassing `hooks.json`'s matcher entirely — in a real Claude Code
session, a `Bash` tool call never triggers this hook process at all
(Claude Code only launches a `PreToolUse` hook when the tool name
matches the `hooks.json` matcher regex), so the advertised/tested
Bash-write protection is dead code in production.

**Same defect, additional instance not named in the issue's six
items:** `adr-shape-gate.sh:85` also branches on `tool_name in
("Write", "Edit", "MultiEdit", "NotebookEdit")`, and the test file has
a dedicated NotebookEdit coverage block
(`adr-shape-gate.test.sh:307-320`, 3 cases: replace-mode pass,
replace-mode bad-shape fail, unsupported edit_mode fail). `NotebookEdit`
is equally absent from the `hooks.json` matcher — this branch is
likewise unreachable in production today. Called out separately
because item 4's "matcher/code coverage must be fully aligned"
requirement is written generally, and a fix scoped narrowly to `Bash`
only would leave this second dead branch behind.

### 2. Hand-rolled Bash token scan vs. `gate_bash_write_targets`

Confirmed. `adr-shape-gate.sh:111-119`, inside the `elif tool_name ==
"Bash":` branch, reimplements a path-token scan inline:

```python
for token in re.findall(r"[\w./~$-]+", command):
    rel = gate_lib.gate_normalize_path(project_root, token)
```

Line 113, `targets = gate_lib.__dict__  # no-op reference to keep
import used`, shows the author was aware `gate_lib` was imported for
this purpose but did not call the intended function.
`core/hooks/lib/gate-lib.sh:81-90` already defines
`gate_bash_write_targets()` (`grep -oE '[[:alnum:]_./~$-]+'`),
documented as "the token-scan technique already used by
approval-gate.sh/board-gate.sh." `adr-shape-gate.sh:17` already sources
`gate-lib.sh` at the top of the bash script (for
`gate_trap_fail_closed`), so the shell function is already in scope at
the point the `Bash` case is handled — it is simply never invoked; the
scan is re-derived independently inside the Python heredoc instead.
Character-class note: the hand-rolled `[\w./~$-]+` (i.e.
`[A-Za-z0-9_./~$-]+` under Python `\w`) is close to but not identical
to the bash function's `[[:alnum:]_./~$-]+` (locale-dependent
alphanumeric vs. ASCII `\w`) — functionally near-equivalent for ASCII
tokens, but the fix is to delegate to the shared function regardless,
per the issue's explicit ask and the "reference only, never copy" rule
stated in `gate-lib.sh`'s own header comment.

### 3. Dangling "(see below)" reference in README

Confirmed, single instance. `README.md:27`:

```
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)
```

`README.md` has no subsequent section, heading, or bullet elaborating
on `approvers.md` or an approve-authority allowlist — the "Layout"
list item is immediately followed by "### Enforcement plugins"
(`README.md:29`), which covers the five gate scripts, not approvers.
`docs/specs/approvers.md` does exist on disk (read in full: a one-line
per-login allowlist file with its own inline HTML comment explaining
its purpose) — this is purely a stale forward-reference, not also a
ghost-file case.

### 4. hooks.json matcher vs. code coverage, across all five plugins

Checked every plugin's `hooks/hooks.json` against its gate script(s)'
`tool_name` branches:

| Plugin | hooks.json matcher(s) | Script's tool_name branches | Gap |
|---|---|---|---|
| km-adr-proposal | `Write\|Edit\|MultiEdit` | Write/Edit/MultiEdit/NotebookEdit/**Bash** | NotebookEdit + Bash both unreachable (item 1) |
| km-cross-index — index-shape-gate.sh | `Write\|Edit\|MultiEdit` (separate hooks.json entry) | includes a `Bash` branch too (`index-shape-gate.sh:50: if tool_name == "Bash":`) | **also a dead branch**: this entry's own matcher is `Write\|Edit\|MultiEdit`, no `Bash` — same defect class as item 1, on a different plugin, not named in the issue's six items. Flagged here for the record; out of scope to fix in this phase-1 proposal (issue #13's precondition section names only `adr-shape-gate`), but the pattern is now visibly repo-wide, not a one-off. |
| km-cross-index — index-pairing-gate.sh | separate hooks.json entry: `Bash` | Bash-only (pairing check runs at commit time) | none — this is the one gate in the repo that already registers a Bash-only script correctly, and is the closest in-repo precedent for item 1's fix |
| km-pattern-entry | `Write\|Edit\|MultiEdit` | not independently re-verified for a Bash/NotebookEdit branch in this pass (out of scope: issue names only adr-shape-gate) | not assessed |
| km-supersession | `Bash` | Bash-only | none found |
| knowledge-management (role-directive plugin) | `PreToolUse` matcher `Bash` → command `${CLAUDE_PLUGIN_ROOT}/hooks/knowledge-management-progress-gate.sh` | **no such file exists**: `find knowledge-management -type f` lists only `.claude-plugin/plugin.json`, `hooks/directive.sh`, `hooks/hooks.json` | **new finding, not in the issue's six items**: a `PreToolUse`/`Bash` stanza referencing a nonexistent script. Any `Bash` tool call in a knowledge-management-role session would hit a missing-command hook execution error. `README.md:23` states "SessionStart wiring (role-agnostic gates now fire from core's own `hooks.json`)" for this same file, implying it should carry only the `SessionStart` entry — inconsistent with the `PreToolUse` stanza's presence, which reads as stale wiring. |

### 5. missing-core test case, full suite green, compliance-check recorded

Not run in phase 1 (no code changes made this phase; proposal-only per
issue #13's ask). `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh`
has no case simulating an unresolvable `gate-lib.sh` source (no group
parallel to what core #75 is said to add). No compliance-check run or
record exists anywhere under `docs/issue-13/` or `docs/issue-10/`
evidencing a `compliance-check.sh` pass for `km-adr-proposal/hooks`.

Additionally — found while checking this item —
`adr-shape-gate.sh:17`'s own source line has **no `||` guard**:

```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
```

with no trailing `|| { ... ; exit 2; }`. If core #75's compliance-check
rule (source-guard detection) is in fact landed as issue #13 states, this
line would fail that check today. The same unguarded pattern is present
in the other four gate scripts checked
(`km-pattern-entry/hooks/pattern-entry-gate.sh:2`-equivalent source
line, `km-cross-index/hooks/index-shape-gate.sh`,
`km-cross-index/hooks/index-pairing-gate.sh`,
`km-supersession/hooks/supersession-pairing-gate.sh`, all sourcing
`gate-lib.sh` the same unguarded way per their file headers) — noted
for completeness since it directly affects whether "full suite green +
compliance-check passing" (item 5) is achievable at all without the
guard fix, but a repo-wide guard rollout across all five gates is
scoped to phase 2 for `km-adr-proposal` only per issue #13's stated
precondition scope; the other four are flagged as a likely follow-up,
not silently folded into this issue's phase 2.

### 6. README/manifest zero leftover old-role-name or ghost-file references

Checked `README.md`, all five `.claude-plugin/plugin.json` manifests,
and `docs/handbooks/knowledge-management.md` for old role names or
nonexistent-file references:

- No old (pre-43-taxonomy-split) role names found — every manifest
  `name` field and every README/handbook mention consistently uses
  `knowledge-management`, `km-adr-proposal`, `km-cross-index`,
  `km-pattern-entry`, `km-supersession`.
- The item-3 `(see below)` dangler and the item-4
  `knowledge-management-progress-gate.sh` ghost reference are this
  repo's actual instances of "ghost/nonexistent file" content under
  item 6's umbrella (the dangler is a stale prose reference, not a
  path reference; the `hooks.json` entry is a genuine nonexistent-path
  reference).
- `README.md`'s "Layout" (`README.md:20-27`) and "Enforcement plugins"
  (`README.md:29-61`) lists were cross-checked path-by-path against
  `find` output for all five plugin directories; every listed path
  exists on disk except the item-3 dangler text.

## Sources

- `gh issue view 13` (this repo, run directly).
- `gh issue view 182 --repo tokenmaxxxer/on-the-record` (state: CLOSED).
- `gh issue view 75 --repo tokenmaxxxer/core` / `gh repo view
  tokenmaxxxer/core` (both fail: repository not resolvable from this
  sandbox — verbatim error "Could not resolve to a Repository with the
  name 'tokenmaxxxer/core'").
- `/tmp/tokenmaxxxer-core-canon-cache/core` and
  `/tmp/tokenmaxxxer-core-test-fixture/core`: `git log --oneline -1`
  on the canon cache (`22a7cad ... (#74)`); `grep -rn
  gate_bash_write_targets` against `hooks/lib/*.sh` and `hooks/lib/*.py`
  in both.
- `km-adr-proposal/hooks/hooks.json`,
  `km-adr-proposal/hooks/adr-shape-gate.sh` (full read),
  `km-adr-proposal/hooks/tests/adr-shape-gate.test.sh` (full read).
- `km-cross-index/hooks/hooks.json`,
  `km-cross-index/hooks/index-shape-gate.sh` (Bash-branch line
  confirmed via targeted grep).
- `km-supersession/hooks/hooks.json`, `km-pattern-entry/hooks/hooks.json`.
- `knowledge-management/hooks/hooks.json`,
  `knowledge-management/hooks/directive.sh`, and `find
  knowledge-management -type f` (script-absence check).
- `README.md` (full read), `docs/specs/approvers.md` (full read),
  each `.claude-plugin/plugin.json` (full read).
- `core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py` (full
  read, canon-cache copy).
