#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../adr-shape-gate.sh"

# Test-env resolution convention (docs/specs/test-env-resolution.md, issue #551).
. "$SCRIPT_DIR/../../../knowledge-management/hooks/tests/lib/test-env-resolve.sh"
resolve_core_or_skip "$SCRIPT_DIR/../../../core"

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0

check() {
  local name="$1" expected_rc="$2" actual_rc="$3"
  if [ "$actual_rc" = "$expected_rc" ]; then
    echo "ok - $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL - $name (expected rc=$expected_rc, got rc=$actual_rc)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_gate() {
  # run_gate <json-payload> [env assignments...]
  local json="$1"; shift
  printf '%s' "$json" | env CLAUDE_PROJECT_DIR="$TMP_ROOT" "$@" bash "$GATE"
}

json_write() {
  local path="$1" content="$2"
  python3 - "$path" "$content" <<'PYEOF'
import json, sys
path, content = sys.argv[1], sys.argv[2]
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": path, "content": content},
}))
PYEOF
}

json_edit() {
  local path="$1" old="$2" new="$3" replace_all="${4:-false}"
  python3 - "$path" "$old" "$new" "$replace_all" <<'PYEOF'
import json, sys
path, old, new, replace_all = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": path, "old_string": old, "new_string": new,
        "replace_all": replace_all == "true",
    },
}))
PYEOF
}

json_multiedit() {
  # json_multiedit <path> <edits-json>
  local path="$1" edits_json="$2"
  python3 - "$path" "$edits_json" <<'PYEOF'
import json, sys
path, edits_json = sys.argv[1], sys.argv[2]
edits = json.loads(edits_json)
print(json.dumps({
    "tool_name": "MultiEdit",
    "tool_input": {"file_path": path, "edits": edits},
}))
PYEOF
}

json_notebookedit() {
  local path="$1" new_source="$2" edit_mode="${3:-replace}"
  python3 - "$path" "$new_source" "$edit_mode" <<'PYEOF'
import json, sys
path, new_source, edit_mode = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "tool_name": "NotebookEdit",
    "tool_input": {"file_path": path, "new_source": new_source, "edit_mode": edit_mode},
}))
PYEOF
}

json_bash() {
  local command="$1"
  python3 - "$command" <<'PYEOF'
import json, sys
command = sys.argv[1]
print(json.dumps({
    "tool_name": "Bash",
    "tool_input": {"command": command},
}))
PYEOF
}

GOOD_BODY='## Context

We need to decide how proposals are shaped.

## Options considered

**A. Do nothing**
Keep the status quo.

**B. Adopt ADR shape**
Require a fixed structure.

## Decision

We adopt option B.

## Consequences

This makes review easier but makes drafting harder.

## Sources

- team discussion 2026-07-31
'

TARGET_REL="docs/issue-7/proposals/knowledge-management/proposal.md"

# --- Case 1: PASS full ADR shape on a matching target path ---------------
PAYLOAD="$(json_write "$TARGET_REL" "$GOOD_BODY")"
run_gate "$PAYLOAD"
check "case1 pass: full ADR shape" 0 "$?"

# --- Case 2: FAIL missing Consequences heading ----------------------------
BAD_NO_CONSEQUENCES='## Context

Body.

## Options considered

**A. One**
First.

**B. Two**
Second.

## Decision

Chosen.

## Sources

- src
'
PAYLOAD="$(json_write "$TARGET_REL" "$BAD_NO_CONSEQUENCES")"
run_gate "$PAYLOAD"
check "case2 fail: missing consequences" 2 "$?"

# --- Case 3: FAIL only 1 option under Options considered ------------------
BAD_ONE_OPTION='## Context

Body.

## Options considered

**A. Only one**
Just this.

## Decision

Chosen.

## Consequences

Easier here, harder there.

## Sources

- src
'
PAYLOAD="$(json_write "$TARGET_REL" "$BAD_ONE_OPTION")"
run_gate "$PAYLOAD"
check "case3 fail: only one option" 2 "$?"

# --- Case 4: PASS path outside target regex, even with garbage content ----
PAYLOAD="$(json_write "docs/issue-7/notes/scratch.md" "garbage garbage garbage")"
run_gate "$PAYLOAD"
check "case4 pass: outside target regex" 0 "$?"

# --- Case 5: PASS kill switch on otherwise-failing payload -----------------
PAYLOAD="$(json_write "$TARGET_REL" "garbage garbage garbage")"
run_gate "$PAYLOAD" KM_ADR_PROPOSAL_GATE_OFF=1
check "case5 pass: kill switch" 0 "$?"

# --- Case 6: FAIL malformed JSON on stdin (fail-closed) --------------------
run_gate "{not valid json"
check "case6 fail: malformed json" 2 "$?"

# --- Case 7: FAIL Edit old_string mismatch against real file on disk -------
mkdir -p "$TMP_ROOT/docs/issue-7/proposals/knowledge-management"
REAL_FILE="$TMP_ROOT/$TARGET_REL"
printf '%s' "$GOOD_BODY" > "$REAL_FILE"
PAYLOAD="$(json_edit "$TARGET_REL" "this string does not exist in the file" "replacement")"
run_gate "$PAYLOAD"
check "case7 fail: edit old_string mismatch" 2 "$?"

# ============================================================================
# Mandatory case group 1: Edit with replace_all:true against an old_string
# occurring multiple times — applies to ALL occurrences.
# ============================================================================
REPEATED_BODY='## Context

X marks the spot. X marks it again. X.

## Options considered

**A. One**
First.

**B. Two**
Second.

## Decision

Chosen.

## Consequences

Easier here, harder there.

## Sources

- src
'
printf '%s' "$REPEATED_BODY" > "$REAL_FILE"
# Replace all "X" with "Y" (still leaves shape intact) -> should PASS.
PAYLOAD="$(json_edit "$TARGET_REL" "X" "Y" "true")"
run_gate "$PAYLOAD"
check "group1 pass: replace_all true applies to all occurrences, shape intact" 0 "$?"

# Replace all "Decision" with "" (destroys the Decision heading in every
# occurrence, since replace_all is honored) -> should FAIL.
printf '%s' "$GOOD_BODY" > "$REAL_FILE"
PAYLOAD="$(json_edit "$TARGET_REL" "Decision" "Removed" "true")"
run_gate "$PAYLOAD"
check "group1 fail: replace_all true removes required heading text everywhere" 2 "$?"

# ============================================================================
# Mandatory case group 2: MultiEdit mixing replace_all true/false in one
# call — each edit's own flag honored independently.
# ============================================================================
printf '%s' "$REPEATED_BODY" > "$REAL_FILE"
EDITS='[
  {"old_string": "X", "new_string": "Y", "replace_all": true},
  {"old_string": "Chosen.", "new_string": "Chosen firmly.", "replace_all": false}
]'
PAYLOAD="$(json_multiedit "$TARGET_REL" "$EDITS")"
run_gate "$PAYLOAD"
check "group2 pass: multiedit mixed replace_all, shape intact" 0 "$?"

# ============================================================================
# Mandatory case group 3: Malformed JSON on stdin — truncated, non-object
# top level, empty stdin — all fail closed (deny, exit 2).
# ============================================================================
run_gate '{"tool_name": "Write", "tool_input": {'
check "group3 fail: truncated json" 2 "$?"

run_gate '["not", "an", "object"]'
check "group3 fail: non-object top level json" 2 "$?"

run_gate ''
check "group3 fail: empty stdin" 2 "$?"

# ============================================================================
# Mandatory case group 4: Kill switch set to unrecognized/garbage value —
# gate stays ACTIVE.
# ============================================================================
PAYLOAD="$(json_write "$TARGET_REL" "garbage garbage garbage")"
run_gate "$PAYLOAD" KM_ADR_PROPOSAL_GATE_OFF=banana
check "group4 fail: kill switch garbage value stays active" 2 "$?"

# ============================================================================
# Mandatory case group 5: Absolute file_path matching same target as
# relative-path fixture, plus "./"-prefixed variant — treated identically.
# ============================================================================
PAYLOAD="$(json_write "$TMP_ROOT/$TARGET_REL" "garbage garbage garbage")"
run_gate "$PAYLOAD"
check "group5 fail: absolute path treated same as relative" 2 "$?"

PAYLOAD="$(json_write "./$TARGET_REL" "$GOOD_BODY")"
run_gate "$PAYLOAD"
check "group5 pass: ./-prefixed relative path treated same as relative, good body" 0 "$?"

# ============================================================================
# Mandatory case group 6: A Bash-tool tool_input.command writing to the
# same target a Write-tool call would hit.
#
# Decision: this gate cannot reconstruct resulting file content for a
# Bash-tool write (no generic way to know what a shell command will write),
# so per the standard's "decide/justify Bash-write coverage" clause it
# fails CLOSED (deny) whenever a Bash command's tokens resolve to a
# docs/issue-<n>/proposals/knowledge-management/*.md target, rather than
# silently passing an un-vetted ADR write through.
# ============================================================================
PAYLOAD="$(json_bash "printf 'stuff' > $TARGET_REL")"
run_gate "$PAYLOAD"
check "group6 fail: bash command writing to target path is denied" 2 "$?"

PAYLOAD="$(json_bash "echo hello world")"
run_gate "$PAYLOAD"
check "group6 pass: bash command with no target-path token is skipped" 0 "$?"

# ============================================================================
# NotebookEdit coverage via gate_reconstruct_write.
# ============================================================================
PAYLOAD="$(json_notebookedit "$TARGET_REL" "$GOOD_BODY" "replace")"
run_gate "$PAYLOAD"
check "notebookedit pass: replace mode with good shape" 0 "$?"

PAYLOAD="$(json_notebookedit "$TARGET_REL" "garbage garbage garbage" "replace")"
run_gate "$PAYLOAD"
check "notebookedit fail: replace mode with bad shape" 2 "$?"

PAYLOAD="$(json_notebookedit "$TARGET_REL" "garbage" "delete")"
run_gate "$PAYLOAD"
check "notebookedit fail: unsupported edit_mode cannot be reconstructed" 2 "$?"

# ============================================================================
# Semantic-upgrade fixture (a): required word appears only in prose/an
# unrelated heading, not as its own heading — must NOT pass.
# ============================================================================
WORD_IN_PROSE_ONLY='## Context

Body.

## Options considered

**A. One**
First.

**B. Two**
Second. This is the decision we lean toward but have not written a
Decision heading for.

## Consequences

Easier here, harder there.

## Sources

- src
'
PAYLOAD="$(json_write "$TARGET_REL" "$WORD_IN_PROSE_ONLY")"
run_gate "$PAYLOAD"
check "semantic-a fail: required word only in prose, not a heading" 2 "$?"

# ============================================================================
# Semantic-upgrade fixture (b): an Options-considered-style bold marker
# appears in an unrelated LATER section, with the real Options section
# having only 1 option — must NOT pass (cross-section-leak check).
# ============================================================================
CROSS_SECTION_LEAK='## Context

Body.

## Options considered

**A. Only one**
Just this.

## Decision

Chosen.

## Consequences

Easier here, harder there.

## Sources

- src
- **B. This looks like a second option but is actually a source bullet**
'
PAYLOAD="$(json_write "$TARGET_REL" "$CROSS_SECTION_LEAK")"
run_gate "$PAYLOAD"
check "semantic-b fail: option-style marker leaking from later section not counted" 2 "$?"

# ============================================================================
# Semantic-upgrade fixture (c): unrelated heading between two mandated
# headings otherwise in order — must NOT pass (adjacency).
# ============================================================================
UNRELATED_HEADING_BETWEEN='## Context

Body.

## Options considered

**A. One**
First.

**B. Two**
Second.

## Appendix

Some unrelated interstitial heading.

## Decision

Chosen.

## Consequences

Easier here, harder there.

## Sources

- src
'
PAYLOAD="$(json_write "$TARGET_REL" "$UNRELATED_HEADING_BETWEEN")"
run_gate "$PAYLOAD"
check "semantic-c fail: unrelated heading breaks adjacency" 2 "$?"

# ============================================================================
# Semantic-upgrade fixture (d): correctly structured document — must pass.
# ============================================================================
PAYLOAD="$(json_write "$TARGET_REL" "$GOOD_BODY")"
run_gate "$PAYLOAD"
check "semantic-d pass: correctly structured document" 0 "$?"

# ============================================================================
# Missing-core fixture: CLAUDE_PLUGIN_ROOT_CORE points nowhere — the guarded
# source line must deny (exit 2), not silently no-op-pass (issue-75/issue-13).
# ============================================================================
PAYLOAD="$(json_write "$TARGET_REL" "$GOOD_BODY")"
run_gate "$PAYLOAD" CLAUDE_PLUGIN_ROOT_CORE="$TMP_ROOT/no-such-core"
check "missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies" 2 "$?"

echo ""
echo "$PASS_COUNT/$((PASS_COUNT + FAIL_COUNT)) passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
