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

command -v python3 >/dev/null 2>&1 || deny "python3 is required to evaluate the index pairing gate"

payload="$(cat)"

parsed="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("__MALFORMED__")
    sys.exit(0)
ti = d.get("tool_input", {}) or {}
print(d.get("tool_name", ""))
print(ti.get("command", ""))
' 2>/dev/null)" || deny "could not parse PreToolUse JSON payload"

if [ "$parsed" = "__MALFORMED__" ]; then
  deny "malformed PreToolUse JSON payload"
fi

tool_name="$(printf '%s\n' "$parsed" | sed -n '1p')"
command_str="$(printf '%s\n' "$parsed" | sed -n '2,$p')"

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

if [ -z "$command_str" ]; then
  exit 0
fi

if ! printf '%s' "$command_str" | grep -Eq '\bgit\b[^\n]*\bcommit\b'; then
  exit 0
fi

# Resolve project root: prefer CLAUDE_PROJECT_DIR, fall back to git toplevel.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  root="$CLAUDE_PROJECT_DIR"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || deny "could not resolve project root (no CLAUDE_PROJECT_DIR, not a git repo)"
fi
[ -n "$root" ] || deny "could not resolve project root"

name_status="$(git -C "$root" diff --cached --name-status 2>/dev/null)" || deny "git diff --cached --name-status failed; cannot verify index pairing"
name_only="$(git -C "$root" diff --cached --name-only 2>/dev/null)" || deny "git diff --cached --name-only failed; cannot verify index pairing"

result="$(python3 - "$name_status" "$name_only" <<'PYEOF'
import re
import sys

name_status = sys.argv[1]
name_only = sys.argv[2]

staged_names = [l for l in name_only.splitlines() if l.strip()]

new_entries = []
for line in name_status.splitlines():
    line = line.rstrip("\n")
    if not line.strip():
        continue
    parts = line.split("\t")
    status = parts[0]
    if not status.startswith("A"):
        continue
    path = parts[-1]
    if path == "docs/patterns/index.md":
        continue
    if re.match(r"^docs/patterns/[^/]+\.md$", path):
        new_entries.append(path)

if not new_entries:
    print("OK")
    sys.exit(0)

if "docs/patterns/index.md" in staged_names:
    print("OK")
    sys.exit(0)

print("DENY: new pattern entr" + ("y" if len(new_entries) == 1 else "ies") + " staged without updating docs/patterns/index.md in the same commit: " + ", ".join(new_entries))
PYEOF
)"

case "$result" in
  OK) exit 0 ;;
  DENY:*) deny "${result#DENY: }" ;;
  *) deny "index pairing gate produced an unexpected result" ;;
esac
