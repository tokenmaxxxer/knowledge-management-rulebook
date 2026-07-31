#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
set -uo pipefail

# km-adr-proposal :: adr-shape-gate.sh
#
# Enforces the ADR-shape norm on phase-1 knowledge-management proposals:
# every docs/issue-<n>/proposals/knowledge-management/*.md write/edit must
# resolve to text carrying Context, >=2 reasoned Options considered,
# a Decision, Consequences (naming something easier and something harder),
# and Sources. Structurally modeled on the pricing-rulebook methodology-gate
# pattern (fail-closed trap, kill switch, has_any substring helper, additive
# missing-element reporting) — no script text is copied from that repo.

# --- kill switch ------------------------------------------------------
case "${KM_ADR_PROPOSAL_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "knowledge-management: refused — $1" >&2
  exit 2
}

# --- dependency check ---------------------------------------------------
command -v python3 >/dev/null 2>&1 || deny "python3 is required for the ADR-shape gate but was not found on PATH"

# --- read PreToolUse payload ---------------------------------------------
PAYLOAD="$(cat)"

# --- resolve project root (fail closed if neither source works) ---------
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$PROJECT_ROOT" ] || deny "could not resolve project root (CLAUDE_PROJECT_DIR is unset and git rev-parse --show-toplevel failed)"

# --- reconstruct resulting text via python3 (JSON parsing + Edit/MultiEdit
#     replay against the file currently on disk). Payload is passed through
#     an env var (base64) rather than stdin, since the python source itself
#     is fed to python3 via heredoc-stdin. ---------------------------------
PAYLOAD_B64="$(printf '%s' "$PAYLOAD" | base64 | tr -d '\n')"

RECON_OUT="$(KM_ADR_PAYLOAD_B64="$PAYLOAD_B64" KM_ADR_PROJECT_ROOT="$PROJECT_ROOT" python3 <<'PYEOF'
import base64
import json
import os
import re
import sys

payload_b64 = os.environ.get("KM_ADR_PAYLOAD_B64", "")
project_root = os.environ.get("KM_ADR_PROJECT_ROOT", "")

try:
    raw = base64.b64decode(payload_b64).decode("utf-8")
    payload = json.loads(raw)
except Exception:
    print("DENY malformed PreToolUse JSON on stdin")
    sys.exit(0)

if not isinstance(payload, dict):
    print("DENY malformed PreToolUse JSON on stdin")
    sys.exit(0)

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input") or {}
file_path = tool_input.get("file_path", "")

if not file_path:
    print("SKIP")
    sys.exit(0)

abs_root = os.path.abspath(project_root)
abs_path = file_path if os.path.isabs(file_path) else os.path.join(abs_root, file_path)
abs_path = os.path.abspath(abs_path)

try:
    rel_path = os.path.relpath(abs_path, abs_root)
except Exception:
    print("SKIP")
    sys.exit(0)

if rel_path.startswith(".."):
    print("SKIP")
    sys.exit(0)

TARGET_RE = re.compile(r"^docs/issue-[0-9]+/proposals/knowledge-management/.*\.md$")
if not TARGET_RE.match(rel_path.replace(os.sep, "/")):
    print("SKIP")
    sys.exit(0)


def read_current():
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None


if tool_name == "Write":
    if "content" not in tool_input:
        print("DENY Write payload missing content")
        sys.exit(0)
    result = tool_input["content"]

elif tool_name == "Edit":
    old = tool_input.get("old_string")
    new = tool_input.get("new_string")
    if old is None or new is None:
        print("DENY Edit payload missing old_string/new_string")
        sys.exit(0)
    current = read_current()
    if current is None:
        print("DENY could not read current file content on disk to apply Edit")
        sys.exit(0)
    if old == "":
        result = current
    elif old not in current:
        print("DENY Edit old_string does not match the current file content on disk")
        sys.exit(0)
    else:
        replace_all = bool(tool_input.get("replace_all", False))
        result = current.replace(old, new) if replace_all else current.replace(old, new, 1)

elif tool_name == "MultiEdit":
    edits = tool_input.get("edits")
    if not isinstance(edits, list) or not edits:
        print("DENY MultiEdit payload missing edits")
        sys.exit(0)
    current = read_current()
    if current is None:
        print("DENY could not read current file content on disk to apply MultiEdit")
        sys.exit(0)
    result = current
    for e in edits:
        old = (e or {}).get("old_string")
        new = (e or {}).get("new_string")
        if old is None or new is None:
            print("DENY MultiEdit edit entry missing old_string/new_string")
            sys.exit(0)
        if old == "":
            continue
        if old not in result:
            print("DENY MultiEdit old_string does not match content at the point it is applied")
            sys.exit(0)
        replace_all = bool((e or {}).get("replace_all", False))
        result = result.replace(old, new) if replace_all else result.replace(old, new, 1)

else:
    print("SKIP")
    sys.exit(0)

print("OK")
print(result)
PYEOF
)"

STATUS_LINE="$(printf '%s\n' "$RECON_OUT" | head -n1)"

case "$STATUS_LINE" in
  SKIP)
    exit 0
    ;;
  DENY*)
    deny "${STATUS_LINE#DENY }"
    ;;
  OK)
    ;;
  *)
    deny "internal error: unexpected gate reconciliation status"
    ;;
esac

TEXT="$(printf '%s\n' "$RECON_OUT" | tail -n +2)"
LOWER_TEXT="$(printf '%s' "$TEXT" | tr '[:upper:]' '[:lower:]')"

# has_any(needle...): case-insensitive substring search against the
# resulting text, structurally matching the pricing-rulebook pattern.
has_any() {
  local needle
  for needle in "$@"; do
    case "$LOWER_TEXT" in
      *"$needle"*) return 0 ;;
    esac
  done
  return 1
}

MISSING=()

# Context
has_any "## context" $'context\n' || MISSING+=("Context")

# Options considered — heading plus >=2 distinct reasoned options.
# Heuristic: count lines starting with a bolded option marker ("**A." /
# "**B.") or an "### Option" heading. This will under-count option lists
# that use other markers (e.g. plain numbered lists, "Option A:" without
# bold/heading), so it is deliberately additive-only (never a false pass
# on prose that merely repeats the word "options").
OPTION_HEADING_OK=0
has_any "## options considered" $'options considered\n' && OPTION_HEADING_OK=1

OPTION_COUNT="$(printf '%s\n' "$TEXT" | grep -Ec '^\*\*[A-Za-z][.)]|^###[[:space:]]+[Oo]ption' 2>/dev/null || true)"
OPTION_COUNT="${OPTION_COUNT:-0}"

if [ "$OPTION_HEADING_OK" -ne 1 ] || [ "$OPTION_COUNT" -lt 2 ]; then
  MISSING+=("Options considered (heading plus at least 2 distinct reasoned options — see heuristic note in this script's comments)")
fi

# Decision
has_any "## decision" "decision &" || MISSING+=("Decision")

# Consequences — heading plus something easier and something harder.
CONSEQUENCES_HEADING_OK=0
has_any "## consequences" $'consequences\n' && CONSEQUENCES_HEADING_OK=1

if [ "$CONSEQUENCES_HEADING_OK" -ne 1 ] || ! has_any "easier"; then
  EASIER_HARDER_MISSING=1
fi
if ! has_any "harder"; then
  EASIER_HARDER_MISSING=1
fi

if [ "$CONSEQUENCES_HEADING_OK" -ne 1 ] || [ "${EASIER_HARDER_MISSING:-0}" = "1" ]; then
  MISSING+=("Consequences (heading naming both something easier and something harder)")
fi

# Sources
has_any "## sources" $'sources\n' || MISSING+=("Sources")

if [ "${#MISSING[@]}" -gt 0 ]; then
  JOINED="$(printf '%s; ' "${MISSING[@]}")"
  deny "ADR-shape proposal is missing required elements: ${JOINED%; }"
fi

exit 0
