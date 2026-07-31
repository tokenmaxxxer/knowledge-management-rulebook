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

rm -rf "$tmp_root"

echo "---"
echo "index-shape-gate.test.sh: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
