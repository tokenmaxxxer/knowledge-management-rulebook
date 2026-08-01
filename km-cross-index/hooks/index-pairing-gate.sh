#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail

# Shared kill switch for the km-cross-index plugin.
gate_kill_switch_active "${KM_CROSS_INDEX_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "index-pairing-gate" "python3 is required to evaluate the index pairing gate"

payload="$(cat)"

parsed="$(printf '%s' "$payload" | python3 -c '
import importlib.util, json, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)


def deny(msg):
    print("__MALFORMED__")
    sys.exit(0)


raw = sys.stdin.read()
event = gate_lib.gate_parse_json_or_deny(raw, deny)
ti = event.get("tool_input", {}) or {}
tool_name = event.get("tool_name", "")
command_str = ti.get("command", "")
if not isinstance(command_str, str):
    command_str = ""

is_commit = bool(re.search(r"\bgit\b.*\bcommit\b", command_str, re.DOTALL))

print(json.dumps({"tool_name": tool_name, "is_commit": is_commit}))
' 2>/dev/null)" || gate_deny "index-pairing-gate" "could not parse PreToolUse JSON payload"

if [ "$parsed" = "__MALFORMED__" ] || [ -z "$parsed" ]; then
  gate_deny "index-pairing-gate" "malformed PreToolUse JSON payload"
fi

tool_name="$(printf '%s' "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_name",""))')"
is_commit="$(printf '%s' "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("is_commit", False))')"

if [ "$tool_name" != "Bash" ]; then
  gate_allow
fi

if [ "$is_commit" != "True" ]; then
  gate_allow
fi

# Resolve project root: prefer CLAUDE_PROJECT_DIR, fall back to git toplevel.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  root="$CLAUDE_PROJECT_DIR"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || gate_deny "index-pairing-gate" "could not resolve project root (no CLAUDE_PROJECT_DIR, not a git repo)"
fi
[ -n "$root" ] || gate_deny "index-pairing-gate" "could not resolve project root"

status_file="$(mktemp)"
only_file="$(mktemp)"
trap_extra() { rm -f "$status_file" "$only_file"; }

# NUL bytes cannot survive a bash command-substitution variable, so the
# raw -z output is written straight to temp files rather than captured in
# "$(...)"; the python payload below reads them directly.
git -C "$root" diff --cached -z --name-status >"$status_file" 2>/dev/null || { trap_extra; gate_deny "index-pairing-gate" "git diff --cached --name-status failed; cannot verify index pairing"; }
git -C "$root" diff --cached -z --name-only >"$only_file" 2>/dev/null || { trap_extra; gate_deny "index-pairing-gate" "git diff --cached --name-only failed; cannot verify index pairing"; }

result="$(python3 -c '
import re
import sys

with open(sys.argv[1], "rb") as f:
    name_status = f.read().decode()
with open(sys.argv[2], "rb") as f:
    name_only = f.read().decode()

staged_names = [n for n in name_only.split("\x00") if n]

# NUL-terminated --name-status pairs each entry as: STATUS\0PATH\0 (rename
# adds an extra PATH\0 for the old path before the new one, but this gate
# only cares about additions ("A"), which are always STATUS\0PATH\0).
tokens = [t for t in name_status.split("\x00") if t != ""]

new_entries = []
i = 0
while i < len(tokens):
    status = tokens[i]
    i += 1
    if i >= len(tokens):
        break
    path = tokens[i]
    i += 1
    if status.startswith("R") or status.startswith("C"):
        # rename/copy: one extra path token (the new name) follows.
        if i < len(tokens):
            path = tokens[i]
            i += 1
    if not status.startswith("A"):
        continue
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
' "$status_file" "$only_file")"

trap_extra

case "$result" in
  OK) gate_allow ;;
  DENY:*) gate_deny "index-pairing-gate" "${result#DENY: }" ;;
  *) gate_deny "index-pairing-gate" "index pairing gate produced an unexpected result" ;;
esac
