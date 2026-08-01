#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "pattern-entry-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

gate_kill_switch_active "${KM_PATTERN_ENTRY_GATE_OFF:-}" || { trap - EXIT; exit 0; }

if ! command -v python3 >/dev/null 2>&1; then
  gate_deny "pattern-entry-gate" "python3 is required to run the pattern-entry gate but was not found on PATH"
fi

payload="$(cat)"

# Resolve project root: CLAUDE_PROJECT_DIR first, else git toplevel; fail closed if neither works.
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ]; then
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$project_root" ]; then
  gate_deny "pattern-entry-gate" "could not resolve project root (CLAUDE_PROJECT_DIR unset and git rev-parse failed)"
fi

verdict="$(KM_GATE_PAYLOAD="$payload" project_root="$project_root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PYEOF'
import importlib.util, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def fail(msg):
    print(msg)
    sys.exit(1)

def not_our_business():
    sys.exit(3)

raw = os.environ.get("KM_GATE_PAYLOAD", "")
payload = gate_lib.gate_parse_json_or_deny(raw, fail)

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}

TARGET_RE = re.compile(r"^docs/patterns/[^/]+\.md$")

def path_is_target(rel_path):
    if rel_path is None:
        return False
    return bool(TARGET_RE.match(rel_path)) and os.path.basename(rel_path) != "index.md"

project_root = os.environ.get("project_root", "")

if tool_name in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    # NotebookEdit carries its target under "notebook_path", not "file_path".
    file_path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not file_path:
        not_our_business()

    rel_path = gate_lib.gate_normalize_path(project_root, file_path)
    if not path_is_target(rel_path):
        not_our_business()

    abs_path = os.path.join(project_root, rel_path)

    def read_current(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception:
            return None

    current = read_current(abs_path)
    text, ok = gate_lib.gate_reconstruct_write(tool_name, tool_input, current)
    if not ok:
        fail(f"could not determine resulting text for {tool_name} on {rel_path}; cannot evaluate the gate")
else:
    # Bash is deliberately NOT covered here (see report / script header
    # comment): this gate's checks (front-matter key presence, heading
    # presence/order/adjacency) require the FULL resulting text of the
    # target file. gate_bash_write_targets only yields candidate
    # path-shaped tokens from the command string — it cannot tell us what
    # a Bash write (heredoc, echo redirect, sed -i, etc.) would leave in
    # the file, so there is no reliable "resulting text" to reconstruct
    # and run the semantic checks against, unlike a simple field-presence
    # gate. Bash writes to docs/patterns/*.md fall through as
    # not_our_business (unhandled) rather than being falsely allowed
    # through a best-effort text guess or falsely denied on a syntactic
    # heuristic.
    not_our_business()

def has_any(haystack, *needles):
    h = haystack.lower()
    return any(n.lower() in h for n in needles)

missing = []

# --- Front matter check ---
# Scope strictly to the block between the first '---' line and the next
# '---' line, and require each key as an actual "^key:" line start within
# that block (not a substring match anywhere, which a quoted value on a
# different key could falsely satisfy).
fm_match = re.match(r"^---[ \t]*\n(.*?\n)---[ \t]*(?:\n|$)", text, re.DOTALL)
front_matter = fm_match.group(1) if fm_match else None

if front_matter is None:
    missing.append("YAML front matter (leading '---' ... closing '---' block)")
else:
    fm_lines = front_matter.splitlines()
    for key in ("title", "keywords", "source_issues"):
        key_re = re.compile(r"^" + re.escape(key) + r":")
        if not any(key_re.match(line) for line in fm_lines):
            missing.append(f"front-matter key '{key}:'")

# --- Heading order + adjacency check ---
# Heading-line-scoped scan: only lines that are actually markdown headings
# ("^#{1,6}\s+...") are considered, and each required heading word must
# appear as a whole word on that heading line (not a bare substring match
# anywhere in the stripped line, which would also match prose-like heading
# text unrelated to the requirement).
lines = text.splitlines()
heading_words = ["context", "problem", "why", "solution", "consequences"]
HEADING_LINE_RE = re.compile(r"^#{1,6}\s+.*$")
found_indices = {}
heading_line_indices = []
for idx, line in enumerate(lines):
    stripped = line.strip()
    if not HEADING_LINE_RE.match(stripped):
        continue
    heading_line_indices.append(idx)
    lower = stripped.lower()
    for word in heading_words:
        if word not in found_indices and re.search(r"\b" + re.escape(word) + r"\b", lower):
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
        else:
            # Adjacency requirement: no unrelated heading line may sit
            # between two consecutive mandated headings. Strict ordering
            # alone (checked above) does not catch an unrelated heading
            # inserted between two mandated ones that are still in
            # increasing order, so walk the full set of heading lines
            # between each mandated pair and reject any heading line that
            # isn't itself the next mandated heading.
            mandated_line_set = set(ordered_indices)
            for i in range(len(ordered_indices) - 1):
                start, end = ordered_indices[i], ordered_indices[i + 1]
                between = [hl for hl in heading_line_indices if start < hl < end]
                if any(hl not in mandated_line_set for hl in between):
                    missing.append(
                        "unrelated heading found between mandated headings "
                        f"'{ordered_words[i].capitalize()}' and '{ordered_words[i+1].capitalize()}' "
                        "(adjacency requirement: mandated headings must be adjacent, "
                        "with no unrelated heading between them)"
                    )
                    break

if missing:
    fail("pattern entry missing/violating required elements: " + "; ".join(missing))

sys.exit(0)
PYEOF
)"
rc=$?

if [ $rc -eq 0 ]; then
  gate_allow
elif [ $rc -eq 3 ]; then
  gate_allow
else
  gate_deny "pattern-entry-gate" "$verdict"
fi
