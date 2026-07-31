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

FULL_CONTENT=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

MISSING_KEYWORDS=$'---\ntitle: Some Pattern\nsource_issues: [7]\n---\n\n## Context\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Solution\ntext\n\n## Consequences\ntext\n'

ORDER_VIOLATION=$'---\ntitle: Some Pattern\nkeywords: [a, b]\nsource_issues: [7]\n---\n\n## Context\ntext\n\n## Solution\ntext\n\n## Problem\ntext\n\n## Why\ntext\n\n## Consequences\ntext\n'

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

# Case 1: PASS full pattern entry
run_case "PASS: full pattern entry with front matter and ordered headings" 0 \
  "$(json_write_payload docs/patterns/some-pattern.md "$FULL_CONTENT")"

# Case 2: FAIL missing keywords
run_case "FAIL: missing keywords in front matter" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$MISSING_KEYWORDS")"

# Case 3: FAIL heading order violation (Solution before Problem)
run_case "FAIL: Solution heading before Problem heading" 2 \
  "$(json_write_payload docs/patterns/some-pattern.md "$ORDER_VIOLATION")"

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

echo "----"
echo "SUMMARY: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
