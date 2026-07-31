#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
set -uo pipefail

# Kill switch
case "${KM_PATTERN_ENTRY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "knowledge-management: refused — $1" >&2
  exit 2
}

if ! command -v python3 >/dev/null 2>&1; then
  deny "python3 is required to run the pattern-entry gate but was not found on PATH"
fi

payload="$(cat)"

# Resolve project root: CLAUDE_PROJECT_DIR first, else git toplevel; fail closed if neither works.
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ]; then
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$project_root" ]; then
  deny "could not resolve project root (CLAUDE_PROJECT_DIR unset and git rev-parse failed)"
fi

verdict="$(KM_GATE_PAYLOAD="$payload" project_root="$project_root" python3 <<'PYEOF'
import json, os, re, sys

def fail(msg):
    print(msg)
    sys.exit(1)

def not_our_business():
    sys.exit(3)

try:
    payload = json.loads(os.environ.get("KM_GATE_PAYLOAD", ""))
except Exception:
    fail("could not parse PreToolUse JSON payload from stdin")

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}
file_path = tool_input.get("file_path")
if not file_path:
    not_our_business()

project_root = os.environ.get("project_root", "")
abs_path = file_path if os.path.isabs(file_path) else os.path.join(project_root, file_path)
try:
    rel_path = os.path.relpath(abs_path, project_root)
except Exception:
    not_our_business()
rel_path = rel_path.replace(os.sep, "/")

TARGET_RE = re.compile(r"^docs/patterns/[^/]+\.md$")
if not TARGET_RE.match(rel_path):
    not_our_business()

if os.path.basename(rel_path) == "index.md":
    # belongs to sibling plugin km-cross-index
    not_our_business()

# Reconstruct resulting text
def read_current(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None

if tool_name == "Write":
    text = tool_input.get("content")
    if text is None:
        fail("Write tool_input missing 'content'; cannot determine resulting text")
elif tool_name == "Edit":
    old_string = tool_input.get("old_string")
    new_string = tool_input.get("new_string")
    if old_string is None or new_string is None:
        fail("Edit tool_input missing old_string/new_string; cannot determine resulting text")
    current = read_current(abs_path)
    if old_string == "":
        text = new_string
    else:
        if current is None:
            fail(f"could not read current file on disk to apply Edit: {rel_path}")
        if old_string not in current:
            fail("Edit old_string not found in current file; cannot determine resulting text")
        replace_all = tool_input.get("replace_all", False)
        if replace_all:
            text = current.replace(old_string, new_string)
        else:
            text = current.replace(old_string, new_string, 1)
elif tool_name == "MultiEdit":
    edits = tool_input.get("edits")
    if not edits:
        fail("MultiEdit tool_input missing 'edits'; cannot determine resulting text")
    current = read_current(abs_path)
    if current is None:
        current = ""
    text = current
    for edit in edits:
        old_string = edit.get("old_string")
        new_string = edit.get("new_string")
        if old_string is None or new_string is None:
            fail("MultiEdit edit missing old_string/new_string; cannot determine resulting text")
        if old_string == "":
            text = new_string
            continue
        if old_string not in text:
            fail("MultiEdit old_string not found while applying edits in order; cannot determine resulting text")
        if edit.get("replace_all", False):
            text = text.replace(old_string, new_string)
        else:
            text = text.replace(old_string, new_string, 1)
else:
    not_our_business()

def has_any(haystack, *needles):
    h = haystack.lower()
    return any(n.lower() in h for n in needles)

missing = []

# --- Front matter check ---
fm_match = re.match(r"^---\s*\n(.*?\n)---\s*(?:\n|$)", text, re.DOTALL)
front_matter = fm_match.group(1) if fm_match else None

if front_matter is None:
    missing.append("YAML front matter (leading '---' ... closing '---' block)")
else:
    for key in ("title:", "keywords:", "source_issues:"):
        if not has_any(front_matter, key):
            missing.append(f"front-matter key '{key}'")

# --- Heading order check ---
lines = text.splitlines()
heading_words = ["context", "problem", "why", "solution", "consequences"]
found_indices = {}
for idx, line in enumerate(lines):
    stripped = line.strip()
    if not stripped.startswith("#"):
        continue
    lower = stripped.lower()
    for word in heading_words:
        if word not in found_indices and word in lower:
            found_indices[word] = idx

for word in heading_words:
    if word not in found_indices:
        missing.append(f"heading containing '{word.capitalize()}'")

if not missing:
    ordered_words = [w for w in heading_words if w in found_indices]
    ordered_indices = [found_indices[w] for w in ordered_words]
    if len(ordered_words) == len(heading_words):
        if ordered_indices != sorted(ordered_indices) or len(set(ordered_indices)) != len(ordered_indices):
            missing.append(
                "headings out of order: Context, Problem, Why, Solution, Consequences must appear in that order"
            )

if missing:
    fail("pattern entry missing/violating required elements: " + "; ".join(missing))

sys.exit(0)
PYEOF
)"
rc=$?

if [ $rc -eq 0 ]; then
  exit 0
elif [ $rc -eq 3 ]; then
  exit 0
else
  deny "$verdict"
fi
