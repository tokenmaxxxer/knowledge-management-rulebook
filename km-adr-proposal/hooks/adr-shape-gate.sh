#!/usr/bin/env bash
# km-adr-proposal :: adr-shape-gate.sh
#
# Enforces the ADR-shape norm on phase-1 knowledge-management proposals:
# every docs/issue-<n>/proposals/knowledge-management/*.md write/edit must
# resolve to text carrying, as actual heading lines in strict adjacent
# order: Context -> Options considered (>=2 distinct options, scoped to
# that section) -> Decision -> Consequences (naming something easier and
# something harder, scoped to that section) -> Sources.
#
# Migrated onto the gate-house standard (issue-72's core/hooks/lib/
# gate-lib.sh + gate-lib.py) per docs/issue-10's phase-1 proposal: trap/
# kill-switch/JSON-parse/path-normalize/Write-Edit-MultiEdit-NotebookEdit
# reconstruction are all delegated to the shared library instead of being
# hand-rolled here.

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "adr-shape-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${KM_ADR_PROPOSAL_GATE_OFF:-}" || { trap - EXIT; exit 0; }

# --- dependency check ---------------------------------------------------
command -v python3 >/dev/null 2>&1 || gate_deny "knowledge-management" "python3 is required for the ADR-shape gate but was not found on PATH"

# --- read PreToolUse payload ---------------------------------------------
PAYLOAD="$(cat)"

# --- resolve project root (fail closed if neither source works) ---------
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$PROJECT_ROOT" ] || gate_deny "knowledge-management" "could not resolve project root (CLAUDE_PROJECT_DIR is unset and git rev-parse --show-toplevel failed)"

# Payload is passed through an env var (base64) rather than stdin, since
# the python source itself is fed to python3 via heredoc-stdin (stdin
# cannot carry both the script and its input at once).
PAYLOAD_B64="$(printf '%s' "$PAYLOAD" | base64 | tr -d '\n')"

RECON_OUT="$(KM_ADR_PAYLOAD_B64="$PAYLOAD_B64" KM_ADR_PROJECT_ROOT="$PROJECT_ROOT" python3 <<'PYEOF'
import base64
import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)


def deny(msg):
    print("DENY " + msg)
    sys.exit(0)


try:
    raw = base64.b64decode(os.environ.get("KM_ADR_PAYLOAD_B64", "")).decode("utf-8")
except Exception:
    raw = ""
payload = gate_lib.gate_parse_json_or_deny(raw, deny)

project_root = os.environ.get("KM_ADR_PROJECT_ROOT", "")

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input") or {}

TARGET_RE = re.compile(r"^docs/issue-[0-9]+/proposals/knowledge-management/.*\.md$")


def read_current(abs_path):
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None


def check_target(rel):
    if rel is None:
        return None
    return rel if TARGET_RE.match(rel) else None


if tool_name in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    file_path = tool_input.get("file_path", "")
    if not file_path:
        print("SKIP")
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(project_root, file_path)
    target = check_target(rel)
    if target is None:
        print("SKIP")
        sys.exit(0)

    abs_path = os.path.join(project_root, target)
    current = read_current(abs_path)

    new_text, ok = gate_lib.gate_reconstruct_write(tool_name, tool_input, current)
    if not ok:
        deny("could not reconstruct the resulting content for this write "
             "(missing content, old_string not found in current file, or "
             "unsupported NotebookEdit edit_mode) — refusing rather than "
             "guessing")

    print("OK")
    print(new_text)
    sys.exit(0)

elif tool_name == "Bash":
    command = tool_input.get("command", "")
    matched = False
    for token in gate_lib.gate_bash_write_targets(command):
        rel = gate_lib.gate_normalize_path(project_root, token)
        if check_target(rel) is not None:
            matched = True
            break
    if matched:
        deny("a Bash command appears to write to a docs/issue-<n>/proposals/"
             "knowledge-management/*.md target; this gate cannot reconstruct "
             "the resulting content for a Bash-tool write, so it fails "
             "closed rather than letting an un-vetted ADR write through")
    print("SKIP")
    sys.exit(0)

else:
    print("SKIP")
    sys.exit(0)
PYEOF
)"

STATUS_LINE="$(printf '%s\n' "$RECON_OUT" | head -n1)"

case "$STATUS_LINE" in
  SKIP)
    exit 0
    ;;
  DENY*)
    gate_deny "knowledge-management" "${STATUS_LINE#DENY }"
    ;;
  OK)
    ;;
  *)
    gate_deny "knowledge-management" "internal error: unexpected gate reconciliation status"
    ;;
esac

TEXT="$(printf '%s\n' "$RECON_OUT" | tail -n +2)"
TEXT_B64="$(printf '%s' "$TEXT" | base64 | tr -d '\n')"

# --- semantic shape check (structural, not substring) --------------------
SHAPE_OUT="$(KM_ADR_TEXT_B64="$TEXT_B64" python3 <<'PYEOF'
import base64
import os
import re
import sys

text = base64.b64decode(os.environ.get("KM_ADR_TEXT_B64", "")).decode("utf-8")
lines = text.split("\n")

HEADING_RE = re.compile(r"^#{1,6}\s+.*$")

# All heading lines, in order: (line_index, text)
headings = [(i, l) for i, l in enumerate(lines) if HEADING_RE.match(l)]


def find_heading(word_re):
    for i, l in headings:
        if word_re.search(l):
            return i
    return None

SEQUENCE = [
    ("Context", re.compile(r"\bcontext\b", re.IGNORECASE)),
    ("Options considered", re.compile(r"\boptions considered\b", re.IGNORECASE)),
    ("Decision", re.compile(r"\bdecision\b", re.IGNORECASE)),
    ("Consequences", re.compile(r"\bconsequences\b", re.IGNORECASE)),
    ("Sources", re.compile(r"\bsources\b", re.IGNORECASE)),
]

missing = []
indices = {}
for name, word_re in SEQUENCE:
    idx = find_heading(word_re)
    if idx is None:
        missing.append(name)
    else:
        indices[name] = idx

if missing:
    print("DENY ADR-shape proposal is missing required heading(s): " + "; ".join(missing))
    sys.exit(0)

# Order: strictly increasing.
ordered_names = [n for n, _ in SEQUENCE]
ordered_idx = [indices[n] for n in ordered_names]
for a, b in zip(ordered_idx, ordered_idx[1:]):
    if not (a < b):
        print("DENY ADR-shape proposal's required headings are not in the "
              "mandated order (Context -> Options considered -> Decision -> "
              "Consequences -> Sources)")
        sys.exit(0)

# Adjacency: no other heading line strictly between two consecutive
# mandated headings.
heading_line_indices = [i for i, _ in headings]
for a, b in zip(ordered_idx, ordered_idx[1:]):
    between = [i for i in heading_line_indices if a < i < b]
    if between:
        print("DENY ADR-shape proposal has an unrelated heading between two "
              "mandated headings; the sequence Context -> Options considered "
              "-> Decision -> Consequences -> Sources must be adjacent with "
              "no other heading in between")
        sys.exit(0)


def next_heading_after(idx):
    for i, _ in headings:
        if i > idx:
            return i
    return len(lines)


# Options considered: >=2 distinct options, scoped to its own section.
opt_start = indices["Options considered"]
opt_end = next_heading_after(opt_start)
opt_lines = lines[opt_start + 1:opt_end]
option_count = 0
for l in opt_lines:
    if re.match(r"^\*\*[A-Za-z][.)]", l) or re.match(r"^#{1,6}\s+[Oo]ption\b", l):
        option_count += 1

if option_count < 2:
    print("DENY ADR-shape proposal's Options considered section names fewer "
          "than 2 distinct reasoned options (heuristic: bolded 'A.'/'B.' "
          "markers or '### Option' headings, scoped to that section only)")
    sys.exit(0)

# Consequences: must name something easier and something harder, scoped to
# its own section.
cons_start = indices["Consequences"]
cons_end = next_heading_after(cons_start)
cons_text = "\n".join(lines[cons_start + 1:cons_end]).lower()

if "easier" not in cons_text or "harder" not in cons_text:
    print("DENY ADR-shape proposal's Consequences section does not name "
          "both something easier and something harder (scoped to that "
          "section only)")
    sys.exit(0)

print("OK")
PYEOF
)"

case "$SHAPE_OUT" in
  OK)
    exit 0
    ;;
  DENY*)
    gate_deny "knowledge-management" "${SHAPE_OUT#DENY }"
    ;;
  *)
    gate_deny "knowledge-management" "internal error: unexpected shape-check status"
    ;;
esac
