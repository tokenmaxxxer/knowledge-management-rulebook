#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/../index-shape-gate.sh"

tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/docs/patterns"

pass_count=0
fail_count=0

run_case() {
  local name="$1"
  local expect="$2" # "pass" or "fail"
  local json="$3"
  local extra_env="${4:-}"

  local out rc
  if [ -n "$extra_env" ]; then
    out="$(printf '%s' "$json" | env CLAUDE_PROJECT_DIR="$tmp_root" $extra_env "$gate" 2>&1)"
  else
    out="$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$tmp_root" "$gate" 2>&1)"
  fi
  rc=$?

  local ok=0
  if [ "$expect" = "pass" ] && [ "$rc" = 0 ]; then
    ok=1
  elif [ "$expect" = "fail" ] && [ "$rc" != 0 ]; then
    ok=1
  fi

  if [ "$ok" = 1 ]; then
    echo "ok - $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL - $name (rc=$rc, expected=$expect) output: $out"
    fail_count=$((fail_count + 1))
  fi
}

# Case: PASS index.md write with recognizable header row (keyword+status).
json_pass_header=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "content": "# Pattern Index\n\n| Keyword | Status |\n| --- | --- |\n| foo | active |\n"
  }
}
EOF
)
run_case "index.md write with keyword+status header" "pass" "$json_pass_header"

# Case: FAIL no recognizable header.
json_fail_no_header=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "content": "# Pattern Index\n\nJust some prose, no table here.\n"
  }
}
EOF
)
run_case "index.md write without table header" "fail" "$json_fail_no_header"

# Case: PASS unrelated path.
json_pass_unrelated=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "docs/patterns/entry-42.md",
    "content": "Some unrelated pattern entry content."
  }
}
EOF
)
run_case "unrelated path is ignored" "pass" "$json_pass_unrelated"

# Case: PASS kill switch KM_CROSS_INDEX_GATE_OFF=1.
run_case "kill switch bypasses gate" "pass" "$json_fail_no_header" "KM_CROSS_INDEX_GATE_OFF=1"

# Case: FAIL malformed JSON (fail-closed).
run_case "malformed JSON fails closed" "fail" "{ not valid json"

# ---------------------------------------------------------------------
# Group 1: Edit with replace_all:true against a multiply-occurring
# old_string — must apply to ALL occurrences.
# ---------------------------------------------------------------------
printf '%s' "# Pattern Index

| Keyword | Status |
| --- | --- |
| foo | draft |
| bar | draft |
" > "$tmp_root/docs/patterns/index.md"

json_edit_replace_all=$(cat <<'EOF'
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "old_string": "draft",
    "new_string": "active",
    "replace_all": true
  }
}
EOF
)
run_case "Edit replace_all:true keeps header intact across all occurrences" "pass" "$json_edit_replace_all"

# ---------------------------------------------------------------------
# Group 2: MultiEdit mixing replace_all true/false in one call — each
# edit's own flag honored independently.
# ---------------------------------------------------------------------
printf '%s' "# Pattern Index

| Keyword | Status |
| --- | --- |
| foo | draft |
| bar | draft |
" > "$tmp_root/docs/patterns/index.md"

json_multiedit_mixed=$(cat <<'EOF'
{
  "tool_name": "MultiEdit",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "edits": [
      { "old_string": "draft", "new_string": "active", "replace_all": true },
      { "old_string": "Keyword", "new_string": "Keyword", "replace_all": false }
    ]
  }
}
EOF
)
run_case "MultiEdit mixed replace_all still yields valid header" "pass" "$json_multiedit_mixed"

# MultiEdit where a false-replace_all edit against an ambiguous old_string
# should fail closed (undeterminable), which this gate treats as deny.
printf '%s' "# Pattern Index

| Keyword | Status |
| --- | --- |
| foo | draft |
| bar | draft |
" > "$tmp_root/docs/patterns/index.md"

json_multiedit_ambiguous=$(cat <<'EOF'
{
  "tool_name": "MultiEdit",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "edits": [
      { "old_string": "nonexistent-token", "new_string": "x", "replace_all": false }
    ]
  }
}
EOF
)
run_case "MultiEdit with unmatched old_string fails closed" "fail" "$json_multiedit_ambiguous"

# ---------------------------------------------------------------------
# Group 3: Malformed JSON on stdin — truncated, non-object top level,
# empty stdin — all fail closed (deny, exit 2).
# ---------------------------------------------------------------------
run_case "truncated JSON fails closed" "fail" '{"tool_name": "Write", "tool_input": {'
run_case "non-object top-level JSON fails closed" "fail" '["Write", {}]'
run_case "empty stdin fails closed" "fail" ""

# ---------------------------------------------------------------------
# Group 4: Kill switch set to unrecognized/garbage value — gate stays
# ACTIVE.
# ---------------------------------------------------------------------
run_case "kill switch garbage value keeps gate active" "fail" "$json_fail_no_header" "KM_CROSS_INDEX_GATE_OFF=banana"

# ---------------------------------------------------------------------
# Group 5: Absolute file_path matching same target as relative-path
# fixture, plus "./"-prefixed variant — treated identically.
# ---------------------------------------------------------------------
json_abs_path=$(cat <<EOF
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "$tmp_root/docs/patterns/index.md",
    "content": "# Pattern Index\n\nJust some prose, no table here.\n"
  }
}
EOF
)
run_case "absolute file_path treated same as relative" "fail" "$json_abs_path"

json_dotslash_path=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "./docs/patterns/index.md",
    "content": "# Pattern Index\n\nJust some prose, no table here.\n"
  }
}
EOF
)
run_case "./-prefixed file_path treated same as relative" "fail" "$json_dotslash_path"

# ---------------------------------------------------------------------
# Group 6: Bash tool_input.command writing to the same target a Write
# call would hit — this gate denies Bash-driven writes to the target
# since it cannot reconstruct resulting content for arbitrary shell
# redirection/append semantics (fail closed rather than pass through
# unverified).
# ---------------------------------------------------------------------
json_bash_write=$(cat <<EOF
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "echo 'no table' > $tmp_root/docs/patterns/index.md"
  }
}
EOF
)
run_case "Bash command writing to index.md is denied (unverifiable reconstruction)" "fail" "$json_bash_write"

json_bash_unrelated=$(cat <<'EOF'
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "ls -la"
  }
}
EOF
)
run_case "Bash command not touching index.md passes" "pass" "$json_bash_unrelated"

# ---------------------------------------------------------------------
# NotebookEdit support via gate_reconstruct_write.
# ---------------------------------------------------------------------
printf '%s' "# Pattern Index

| Keyword | Status |
| --- | --- |
| foo | draft |
" > "$tmp_root/docs/patterns/index.md"

json_notebookedit_pass=$(cat <<'EOF'
{
  "tool_name": "NotebookEdit",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "edit_mode": "replace",
    "new_source": "# Pattern Index\n\n| Keyword | Status |\n| --- | --- |\n| foo | active |\n"
  }
}
EOF
)
run_case "NotebookEdit replace with valid header passes" "pass" "$json_notebookedit_pass"

json_notebookedit_fail=$(cat <<'EOF'
{
  "tool_name": "NotebookEdit",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "edit_mode": "replace",
    "new_source": "# Pattern Index\n\nNo table here.\n"
  }
}
EOF
)
run_case "NotebookEdit replace without header fails" "fail" "$json_notebookedit_fail"

# ---------------------------------------------------------------------
# Semantic-upgrade fixtures: exact-cell-match header parsing.
# ---------------------------------------------------------------------

# (a) Header contains "Keywords_Extra" (substring of "keyword" but not an
# exact cell match) and no exact "status" cell — must NOT pass.
json_substring_leak=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "content": "# Pattern Index\n\n| Keywords_Extra | Note |\n| --- | --- |\n| foo | n/a |\n"
  }
}
EOF
)
run_case "header with Keywords_Extra column (substring leak) fails" "fail" "$json_substring_leak"

# (b) Header with exactly "Keyword" and "Status" cells among others —
# must pass.
json_exact_cells=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "content": "# Pattern Index\n\n| ID | Keyword | Status | Notes |\n| --- | --- | --- | --- |\n| 1 | foo | active | n/a |\n"
  }
}
EOF
)
run_case "header with exact Keyword and Status cells among others passes" "pass" "$json_exact_cells"

# (c) "keyword"/"status" appear only in prose outside any table header
# row — must NOT pass.
json_prose_only=$(cat <<'EOF'
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "docs/patterns/index.md",
    "content": "# Pattern Index\n\nEach entry has a keyword and a status, tracked below.\n\n| ID | Name |\n| --- | --- |\n| 1 | foo |\n"
  }
}
EOF
)
run_case "keyword/status only in prose (not header) fails" "fail" "$json_prose_only"

rm -rf "$tmp_root"

echo "---"
echo "index-shape-gate.test.sh: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
