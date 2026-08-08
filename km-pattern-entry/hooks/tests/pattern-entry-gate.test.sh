#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/../pattern-entry-gate.sh"

export CLAUDE_PLUGIN_ROOT="$SCRIPT_DIR/.."
export CLAUDE_PROJECT_DIR
CLAUDE_PROJECT_DIR="$(mktemp -d)"
trap 'rm -rf "$CLAUDE_PROJECT_DIR"' EXIT

mkdir -p "$CLAUDE_PROJECT_DIR/docs/patterns"

pass_count=0
fail_count=0

run_case() {
  local name="$1"
  local expected_rc="$2"
  local payload="$3"
  local extra_env="${4:-}"

  local actual_rc
  local out_file
  out_file="$(mktemp)"
  if [ -n "$extra_env" ]; then
    printf '%s' "$payload" | env "$extra_env" "$GATE" >"$out_file" 2>&1
  else
    printf '%s' "$payload" | "$GATE" >"$out_file" 2>&1
  fi
  actual_rc=$?

  if [ "$actual_rc" = "$expected_rc" ]; then
    echo "ok - $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL - $name (expected rc=$expected_rc, got rc=$actual_rc): $(cat "$out_file")"
    fail_count=$((fail_count + 1))
  fi
  rm -f "$out_file"
}

FULL_CONTENT=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\ncapture_point: at-resolution\nreuse_status: new\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

MISSING_KEYWORDS=$'---\ntitle: Some Pattern\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\ncapture_point: at-resolution\nreuse_status: new\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

ORDER_VIOLATION=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\ncapture_point: at-resolution\nreuse_status: new\n---\n\n## Context\ntext\n\n## Solution\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Consequences\ntext\n'

MISSING_ARTICLE_ID=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\ncapture_point: at-resolution\nreuse_status: new\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

MISSING_CAPTURE_POINT=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\nreuse_status: new\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

MISSING_REUSE_STATUS=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\ncapture_point: at-resolution\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

INVALID_CAPTURE_POINT=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\ncapture_point: sometime\nreuse_status: new\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

INVALID_REUSE_STATUS=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\narticle_id: docs/patterns/some-pattern.md\ncapture_point: retroactive\nreuse_status: maybe\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

json_write_payload() {
  local path="$1"
  local content="$2"
  python3 -c '
import json, sys
path, content = sys.argv[1], sys.argv[2]
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": path, "content": content}
}))
' "$path" "$content"
}

json_edit_payload() {
  # args: path old_string new_string replace_all(true/false)
  python3 -c '
import json, sys
path, old, new, replace_all = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": path,
        "old_string": old,
        "new_string": new,
        "replace_all": replace_all == "true",
    }
}))
' "$1" "$2" "$3" "$4"
}

json_multiedit_payload() {
  # args: path edits_json(list of {old_string,new_string,replace_all})
  python3 -c '
import json, sys
path, edits_json = sys.argv[1], sys.argv[2]
edits = json.loads(edits_json)
print(json.dumps({
    "tool_name": "MultiEdit",
    "tool_input": {"file_path": path, "edits": edits}
}))
' "$1" "$2"
}

json_notebookedit_payload() {
  # args: path new_source edit_mode
  python3 -c '
import json, sys
path, new_source, edit_mode = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "tool_name": "NotebookEdit",
    "tool_input": {"notebook_path": path, "new_source": new_source, "edit_mode": edit_mode}
}))
' "$1" "$2" "$3"
}

json_bash_payload() {
  # args: command
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$1"
}

write_fixture() {
  # args: relpath content
  local rel="$1"
  local content="$2"
  mkdir -p "$CLAUDE_PROJECT_DIR/$(dirname "$rel")"
  printf '%s' "$content" > "$CLAUDE_PROJECT_DIR/$rel"
}

# Case 1: PASS full pattern entry
run_case "PASS: full pattern entry with front matter and ordered headings" 0 \
  "$(json_write_payload docs/patterns/some-pattern.md "$FULL_CONTENT")"

# Case 2: FAIL missing keywords
run_case "FAIL: missing keywords in front matter" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_KEYWORDS")"

# Case 3: FAIL heading order violation (Solution before Problem)
run_case "FAIL: Solution heading before Problem heading" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$ORDER_VIOLATION")"

# ---- issue-21: spec-required front-matter keys ----
run_case "FAIL: missing article_id in front matter" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_ARTICLE_ID")"

run_case "FAIL: missing capture_point in front matter" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_CAPTURE_POINT")"

run_case "FAIL: missing reuse_status in front matter" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_REUSE_STATUS")"

run_case "FAIL: invalid capture_point enum value" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$INVALID_CAPTURE_POINT")"

run_case "FAIL: invalid reuse_status enum value" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$INVALID_REUSE_STATUS")"

run_case "PASS: full pattern entry with all six front-matter keys and valid enums" 0 \
  "$(json_write_payload docs/patterns/some-pattern.md "$FULL_CONTENT")"

# Case 4a: PASS path is docs/patterns/index.md (sibling plugin's business)
run_case "PASS: docs/patterns/index.md excluded (km-cross-index territory)" 0 \
  "$(json_write_payload docs/patterns/index.md "$MISSING_KEYWORDS")"

# Case 4b: PASS unrelated path
run_case "PASS: unrelated path docs/other.md is not this gate's business" 0 \
  "$(json_write_payload docs/other.md "$MISSING_KEYWORDS")"

# Case 5: PASS kill switch on otherwise-failing payload
run_case "PASS: kill switch KM_PATTERN_ENTRY_GATE_OFF=1 bypasses gate" 0 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_KEYWORDS")" \
  "KM_PATTERN_ENTRY_GATE_OFF=1"

# Case 6: FAIL malformed JSON (fail-closed)
run_case "FAIL: malformed JSON on stdin fails closed" 2 \
  "{not valid json"

# ---- Group 1: Edit replace_all:true applies to ALL occurrences ----
# Body has a harmless earlier occurrence of PLACEHOLDER, and the required
# "Problem" heading is ALSO spelled PLACEHOLDER. Only when replace_all is
# honored do BOTH occurrences get replaced, turning "## PLACEHOLDER" into
# "## Problem" and making the doc pass. Under the old bug (always
# first-occurrence-only) only the harmless body occurrence would be
# replaced and the heading would stay wrong, so this must PASS.
write_fixture "docs/patterns/replace-all-edit.md" \
  $'---\ntitle: T\nkeywords: k\nsource_issues: [7]\narticle_id: docs/patterns/replace-all-edit.md\ncapture_point: at-resolution\nreuse_status: new\n---\n\n## Context\nThis is PLACEHOLDER prose, harmless.\n\n## PLACEHOLDER\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'
run_case "PASS: Edit replace_all:true replaces ALL occurrences of old_string" 0 \
  "$(json_edit_payload docs/patterns/replace-all-edit.md PLACEHOLDER Problem true)"

# ---- Group 2: MultiEdit mixing replace_all true/false, each independent ----
# edit1 (replace_all:true) touches an unrelated placeholder harmlessly.
# edit2 (replace_all:false) must touch ONLY the first "CCC" occurrence (in
# body prose, before the heading), leaving the "## CCC" heading untouched
# -> required "Consequences" heading stays missing -> gate must FAIL.
write_fixture "docs/patterns/multiedit-mixed.md" \
  $'---\ntitle: T\nkeywords: k\nsource_issues: [7]\n---\n\n## Context\nAAA prose AAA and CCC mention here.\n\n## Problem\nBBB text\n\n## Why\ntext\n\n## Solution\ntext\n\n## CCC\ntext\n'
run_case "FAIL: MultiEdit honors each edit's own replace_all independently" 2 \
  "$(json_multiedit_payload docs/patterns/multiedit-mixed.md '[{"old_string":"AAA","new_string":"ok","replace_all":true},{"old_string":"CCC","new_string":"Solved","replace_all":false}]')"

# ---- Group 3: malformed JSON variants all fail closed ----
run_case "FAIL: truncated JSON on stdin fails closed" 2 \
  '{"tool_name": "Write", "tool_input": {"file_path": "docs/patterns/x.md", "content": "abc"'

run_case "FAIL: top-level JSON array fails closed" 2 \
  '["not", "an", "object"]'

run_case "FAIL: top-level JSON string fails closed" 2 \
  '"just a string"'

run_case "FAIL: empty stdin fails closed" 2 \
  ""

# ---- Group 4: kill switch garbage value stays ACTIVE ----
run_case "FAIL: kill switch set to unrecognized value 'banana' stays active" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_KEYWORDS")" \
  "KM_PATTERN_ENTRY_GATE_OFF=banana"

# ---- Group 5: absolute path and "./"-prefixed path normalize the same as relative ----
run_case "PASS: absolute file_path normalizes same as relative (passing doc)" 0 \
  "$(json_write_payload "$CLAUDE_PROJECT_DIR/docs/patterns/abs-test.md" "$FULL_CONTENT")"

run_case "FAIL: absolute file_path normalizes same as relative (failing doc)" 2 \
  "$(json_write_payload "$CLAUDE_PROJECT_DIR/docs/patterns/abs-test2.md" "$MISSING_KEYWORDS")"

run_case "PASS: './'-prefixed relative file_path normalizes same as plain relative" 0 \
  "$(json_write_payload "./docs/patterns/dot-test.md" "$FULL_CONTENT")"

# ---- Group 6: Bash tool_input.command writing to a target path ----
# Deliberately NOT covered: this gate's checks (front-matter key presence,
# heading presence/order/adjacency) need the full resulting text of the
# file. gate_bash_write_targets only yields candidate path-shaped tokens
# from the command string, not the content a shell redirect/heredoc/sed -i
# would leave behind, so there is no reliable way to reconstruct "resulting
# text" for a Bash write the way there is for Write/Edit/MultiEdit/
# NotebookEdit. A Bash write to docs/patterns/*.md therefore falls through
# unintercepted (not_our_business) rather than being falsely allowed via a
# content guess or falsely denied via a syntactic heuristic. This test
# documents that deliberate scope boundary.
run_case "PASS (documented gap): Bash write to docs/patterns/*.md is not intercepted by this gate" 0 \
  "$(json_bash_payload "printf 'bad' > docs/patterns/via-bash.md")"

# ---- NotebookEdit support via gate_reconstruct_write ----
write_fixture "docs/patterns/notebook-fixture.md" "irrelevant prior content"
run_case "PASS: NotebookEdit reconstructs new_source and evaluates it" 0 \
  "$(json_notebookedit_payload docs/patterns/notebook-fixture.md "$FULL_CONTENT" replace)"

run_case "FAIL: NotebookEdit with insert mode missing required elements" 2 \
  "$(json_notebookedit_payload docs/patterns/notebook-fixture2.md "$MISSING_KEYWORDS" insert)"

# ---- Semantic upgrade fixture (a): required key's word only appears as a
# quoted VALUE on a DIFFERENT key; must NOT satisfy the "keywords:" key
# requirement (previously a has_any substring check would falsely pass).
SEMANTIC_A=$'---\ntitle: Some Pattern\nsource_issues: "see keywords: below"\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'
run_case "FAIL: required front-matter key only appears as a quoted value on another key" 2 \
  "$(json_write_payload docs/patterns/semantic-a.md "$SEMANTIC_A")"

# ---- Semantic upgrade fixture (b): required heading word only appears in
# prose body, never on an actual "#"-heading line; must NOT satisfy the
# heading requirement (previously a bare substring-in-stripped-line check
# would falsely pass).
SEMANTIC_B=$'---\ntitle: Some Pattern\nkeywords: [a]\nsource_issues: [7]\n---\n\n## Context\nThis section discusses the Problem informally, without a dedicated heading.\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'
run_case "FAIL: required heading word only appears in prose, never as a heading line" 2 \
  "$(json_write_payload docs/patterns/semantic-b.md "$SEMANTIC_B")"

# ---- Semantic upgrade fixture (c): correctly structured document must PASS.
run_case "PASS: correctly structured pattern entry (semantic fixture c)" 0 \
  "$(json_write_payload docs/patterns/semantic-c.md "$FULL_CONTENT")"

# ---- Semantic upgrade fixture (d): an unrelated heading sits between two
# mandated headings that are otherwise still in increasing order; the
# adjacency requirement must reject this (strict ordering alone would let
# it through).
SEMANTIC_D=$'---\ntitle: Some Pattern\nkeywords: [a]\nsource_issues: [7]\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Unrelated Aside\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'
run_case "FAIL: unrelated heading between two mandated headings violates adjacency" 2 \
  "$(json_write_payload docs/patterns/semantic-d.md "$SEMANTIC_D")"

# ---- Missing-core fixture: CLAUDE_PLUGIN_ROOT_CORE points nowhere — the
# guarded source line must deny (exit 2), not silently no-op-pass.
run_case "missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies" 2 \
  "$(json_write_payload docs/patterns/missing-core.md "$FULL_CONTENT")" \
  "CLAUDE_PLUGIN_ROOT_CORE=$CLAUDE_PROJECT_DIR/no-such-core"

echo "----"
echo "SUMMARY: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
