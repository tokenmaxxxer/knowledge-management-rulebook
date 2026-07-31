#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../adr-shape-gate.sh"

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
  local path="$1" old="$2" new="$3"
  python3 - "$path" "$old" "$new" <<'PYEOF'
import json, sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {"file_path": path, "old_string": old, "new_string": new},
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

echo ""
echo "$PASS_COUNT/$((PASS_COUNT + FAIL_COUNT)) passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
