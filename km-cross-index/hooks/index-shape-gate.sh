#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "index-shape-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

# Shared kill switch for the km-cross-index plugin.
gate_kill_switch_active "${KM_CROSS_INDEX_GATE_OFF:-}" || { trap - EXIT; exit 0; }

deny() {
  gate_deny "index-shape-gate" "$1"
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
import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

root = sys.argv[1]


def _deny(msg):
    print("DENY: " + msg)
    sys.exit(0)


raw = sys.stdin.read()
payload = gate_lib.gate_parse_json_or_deny(raw, _deny)

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}

if tool_name == "Bash":
    command = tool_input.get("command", "") or ""
    # gate_bash_write_targets is a bash function (gate-lib.sh), not
    # exposed to gate-lib.py; mirror its token-scan regex here.
    targets = re.findall(r"[[:alnum:]_./~$-]+".replace("[:alnum:]", "A-Za-z0-9"), command)
    hit = False
    for tok in targets:
        rel = gate_lib.gate_normalize_path(root, tok)
        if rel == "docs/patterns/index.md":
            hit = True
            break
    if not hit:
        print("OK")
        sys.exit(0)
    # A Bash command touching the target path cannot be reliably
    # reconstructed into resulting file content (shell redirection/append
    # semantics are not general-purpose parseable here), so fail closed
    # rather than silently let a shape-breaking write through.
    _deny("Bash command appears to write docs/patterns/index.md; this gate "
          "cannot verify table shape for shell-driven writes, refusing")

if tool_name not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    print("OK")
    sys.exit(0)

file_path = tool_input.get("file_path", "")
if not file_path:
    _deny("tool_input.file_path missing")

rel = gate_lib.gate_normalize_path(root, file_path)
if rel != "docs/patterns/index.md":
    print("OK")
    sys.exit(0)

target = os.path.join(root, "docs/patterns/index.md")

# Reconstruct resulting text.
existing = None
if os.path.exists(target):
    try:
        with open(target, "r", encoding="utf-8") as f:
            existing = f.read()
    except Exception:
        _deny("could not read existing docs/patterns/index.md to reconstruct result")
else:
    existing = ""

new_text, ok = gate_lib.gate_reconstruct_write(tool_name, tool_input, existing)
if not ok:
    _deny("could not reconstruct the resulting docs/patterns/index.md content; refusing")

lines = new_text.splitlines()

header_idx = None
for i in range(len(lines) - 1):
    header = lines[i]
    sep = lines[i + 1]
    if not (header.startswith("|") and header.endswith("|")):
        continue
    if not re.match(r"^\|[-\s|:]+\|$", sep):
        continue
    header_idx = i
    break

if header_idx is None:
    _deny("docs/patterns/index.md must contain a markdown table with a header row followed by a separator row")

header_cells = [c.strip().lower() for c in lines[header_idx].strip("|").split("|")]
missing = []
if not any(c in ("keyword", "keywords") for c in header_cells):
    missing.append("keyword")
if not any(c == "status" for c in header_cells):
    missing.append("status")

if missing:
    _deny("docs/patterns/index.md table header is missing required column(s): " + ", ".join(missing))

print("OK")
PYEOF

result="$(printf '%s' "$payload" | GATE_LIB_PY="$GATE_LIB_PY" python3 "$pyscript" "$root")"
rm -f "$pyscript"

case "$result" in
  OK) gate_allow ;;
  DENY:*) deny "${result#DENY: }" ;;
  *) deny "index shape gate produced an unexpected result" ;;
esac
