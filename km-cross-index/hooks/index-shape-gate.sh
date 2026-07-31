#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
set -uo pipefail

# Shared kill switch for the km-cross-index plugin.
case "${KM_CROSS_INDEX_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "knowledge-management: refused — $1" >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || deny "python3 is required to evaluate the index shape gate"

payload="$(cat)"

# Resolve project root: prefer CLAUDE_PROJECT_DIR, fall back to git toplevel.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  root="$CLAUDE_PROJECT_DIR"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || deny "could not resolve project root (no CLAUDE_PROJECT_DIR, not a git repo)"
fi
[ -n "$root" ] || deny "could not resolve project root"

pyscript="$(mktemp "${TMPDIR:-/tmp}/km-cross-index-shape.XXXXXX.py")"
cat > "$pyscript" <<'PYEOF'
import json
import os
import sys

root = sys.argv[1]

try:
    payload = json.load(sys.stdin)
except Exception:
    print("DENY: malformed PreToolUse JSON payload")
    sys.exit(0)

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}

if tool_name not in ("Write", "Edit", "MultiEdit"):
    print("OK")
    sys.exit(0)

file_path = tool_input.get("file_path", "")
if not file_path:
    print("DENY: tool_input.file_path missing")
    sys.exit(0)

if not os.path.isabs(file_path):
    file_path = os.path.join(root, file_path)
file_path = os.path.normpath(file_path)

target = os.path.normpath(os.path.join(root, "docs/patterns/index.md"))

if file_path != target:
    print("OK")
    sys.exit(0)

# Reconstruct resulting text.
existing = ""
if os.path.exists(target):
    try:
        with open(target, "r", encoding="utf-8") as f:
            existing = f.read()
    except Exception:
        print("DENY: could not read existing docs/patterns/index.md to reconstruct result")
        sys.exit(0)

if tool_name == "Write":
    new_text = tool_input.get("content", None)
    if new_text is None:
        print("DENY: Write tool_input.content missing")
        sys.exit(0)
elif tool_name == "Edit":
    old_string = tool_input.get("old_string", None)
    new_string = tool_input.get("new_string", None)
    if old_string is None or new_string is None:
        print("DENY: Edit tool_input missing old_string/new_string")
        sys.exit(0)
    if old_string == "":
        new_text = new_string
    else:
        replace_all = bool(tool_input.get("replace_all", False))
        count = existing.count(old_string)
        if count == 0:
            print("DENY: Edit old_string not found in current docs/patterns/index.md; result undeterminable")
            sys.exit(0)
        if replace_all:
            new_text = existing.replace(old_string, new_string)
        else:
            if count > 1:
                print("DENY: Edit old_string is ambiguous in docs/patterns/index.md; result undeterminable")
                sys.exit(0)
            new_text = existing.replace(old_string, new_string, 1)
elif tool_name == "MultiEdit":
    edits = tool_input.get("edits", None)
    if not isinstance(edits, list) or not edits:
        print("DENY: MultiEdit tool_input.edits missing or empty")
        sys.exit(0)
    text = existing
    for edit in edits:
        old_string = edit.get("old_string", None)
        new_string = edit.get("new_string", None)
        if old_string is None or new_string is None:
            print("DENY: MultiEdit edit missing old_string/new_string; result undeterminable")
            sys.exit(0)
        if old_string == "":
            text = new_string
            continue
        replace_all = bool(edit.get("replace_all", False))
        count = text.count(old_string)
        if count == 0:
            print("DENY: MultiEdit old_string not found against running content; result undeterminable")
            sys.exit(0)
        if replace_all:
            text = text.replace(old_string, new_string)
        else:
            if count > 1:
                print("DENY: MultiEdit old_string is ambiguous against running content; result undeterminable")
                sys.exit(0)
            text = text.replace(old_string, new_string, 1)
    new_text = text
else:
    print("OK")
    sys.exit(0)

lines = new_text.splitlines()

header_idx = None
for i in range(len(lines) - 1):
    header = lines[i]
    sep = lines[i + 1]
    if not (header.startswith("|") and header.endswith("|")):
        continue
    import re
    if not re.match(r"^\|[-\s|:]+\|$", sep):
        continue
    header_idx = i
    break

if header_idx is None:
    print("DENY: docs/patterns/index.md must contain a markdown table with a header row followed by a separator row")
    sys.exit(0)

header_text = lines[header_idx].lower()
missing = []
if "keyword" not in header_text:
    missing.append("keyword")
if "status" not in header_text:
    missing.append("status")

if missing:
    print("DENY: docs/patterns/index.md table header is missing required column(s): " + ", ".join(missing))
    sys.exit(0)

print("OK")
PYEOF

result="$(printf '%s' "$payload" | python3 "$pyscript" "$root")"
rm -f "$pyscript"

case "$result" in
  OK) exit 0 ;;
  DENY:*) deny "${result#DENY: }" ;;
  *) deny "index shape gate produced an unexpected result" ;;
esac
