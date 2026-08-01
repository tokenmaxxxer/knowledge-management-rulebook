#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed

set -uo pipefail

# Kill switch
gate_kill_switch_active "${KM_SUPERSESSION_GATE_OFF:-}" || { trap - EXIT; exit 0; }

deny() {
  gate_deny "supersession-pairing-gate" "$1"
}

command -v python3 >/dev/null 2>&1 || deny "python3 is required for this gate but was not found"
command -v git >/dev/null 2>&1 || deny "git is required for this gate but was not found"

payload="$(cat)"

# Single python invocation: parse JSON via gate_lib.gate_parse_json_or_deny
# (fails closed on empty/truncated/non-object payloads), then emit
# tool_name and tool_input.command as two lines. The git+commit detection
# also happens here, newline-tolerant (embedded \n in the command string is
# collapsed to a space before matching \bgit\b...\bcommit\b), fixing the
# audit-named defect where `grep -Eq '\bgit\b[^\n]*\bcommit\b'` only matched
# within a single line.
parsed="$(printf '%s' "$payload" | GATE_LIB_PY="$GATE_LIB_PY" python3 -c '
import importlib.util, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def _deny(msg):
    print("__DENY__" + msg)
    sys.exit(0)

raw = sys.stdin.read()
event = gate_lib.gate_parse_json_or_deny(raw, _deny)

tool_name = event.get("tool_name", "")
command_str = (event.get("tool_input", {}) or {}).get("command", "")
if not isinstance(command_str, str):
    command_str = ""

normalized = re.sub(r"\s+", " ", command_str)
is_git_commit = bool(re.search(r"\bgit\b.*\bcommit\b", normalized))
is_empty_command = command_str == ""

# Emit only flags, never the raw (possibly multiline) command string
# itself, so the bash side never has to split output on newlines that
# might themselves be embedded in the command text.
print(tool_name)
print("0" if is_empty_command else "1")
print("1" if is_git_commit else "0")
')" || deny "could not parse PreToolUse JSON payload"

case "$parsed" in
  __DENY__*) deny "${parsed#__DENY__}" ;;
esac

tool_name="$(printf '%s\n' "$parsed" | sed -n '1p')"
has_command="$(printf '%s\n' "$parsed" | sed -n '2p')"
is_git_commit="$(printf '%s\n' "$parsed" | sed -n '3p')"

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

if [ "$has_command" != "1" ]; then
  exit 0
fi

if [ "$is_git_commit" != "1" ]; then
  exit 0
fi

# Determine project root
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  proj_root="$CLAUDE_PROJECT_DIR"
else
  proj_root="$(git rev-parse --show-toplevel 2>/dev/null)" || deny "could not determine project root (not in a git repo and CLAUDE_PROJECT_DIR unset)"
fi

[ -n "$proj_root" ] || deny "could not determine project root"

staged_files="$(git -C "$proj_root" diff --cached --name-only 2>/dev/null)" || deny "git diff --cached failed — cannot verify staged supersession pairing"

# Filter to staged pattern entries: docs/patterns/*.md excluding index.md
pattern_entries="$(printf '%s\n' "$staged_files" | grep -E '^docs/patterns/[^/]+\.md$' | grep -v '/index\.md$' || true)"

if [ -z "$pattern_entries" ]; then
  exit 0
fi

get_field() {
  # $1 = path, $2 = field name (supersedes|superseded_by)
  local path="$1" field="$2" content
  content="$(git -C "$proj_root" show ":$path" 2>/dev/null)" || return 2
  printf '%s\n' "$content" | python3 -c "
import sys, re
lines = sys.stdin.read().splitlines()
in_fm = False
seen_open = False
for line in lines:
    if line.strip() == '---':
        if not seen_open:
            seen_open = True
            in_fm = True
            continue
        else:
            break
    if in_fm:
        m = re.match(r'^${field}:\s*(.+?)\s*$', line)
        if m:
            print(m.group(1))
            break
"
}

is_staged() {
  local path="$1"
  printf '%s\n' "$staged_files" | grep -Fxq "$path"
}

missing=""

# Build a real bash array of pattern-entry paths, split only on newlines
# (never mid-line whitespace), fixing the audit-named defect where
# `for entry in $pattern_entries` (unquoted) word-split a path containing a
# space — e.g. "docs/patterns/my entry.md" — into multiple bogus entries.
pattern_entries_arr=()
if [ -n "$pattern_entries" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && pattern_entries_arr+=("$line")
  done <<< "$pattern_entries"
fi

for entry in "${pattern_entries_arr[@]}"; do
  git -C "$proj_root" show ":$entry" >/dev/null 2>&1 || deny "git show failed for staged file $entry — cannot read staged content"

  supersedes_val="$(get_field "$entry" supersedes)"
  rc=$?
  [ "$rc" = 2 ] && deny "git show failed for staged file $entry — cannot read staged content"

  superseded_by_val="$(get_field "$entry" superseded_by)"
  rc=$?
  [ "$rc" = 2 ] && deny "git show failed for staged file $entry — cannot read staged content"

  if [ -n "$supersedes_val" ]; then
    old_path="$supersedes_val"
    if ! is_staged "$old_path"; then
      missing="${missing}${entry}: declares supersedes: ${old_path}, but ${old_path} is not staged\n"
    else
      old_content_ok=1
      old_superseded_by="$(get_field "$old_path" superseded_by)" || old_content_ok=0
      if [ "$old_content_ok" != 1 ]; then
        deny "git show failed for staged file $old_path — cannot read staged content"
      fi
      if [ "$old_superseded_by" != "$entry" ]; then
        missing="${missing}${old_path}: missing/mismatched superseded_by: ${entry} (required by ${entry}'s supersedes field)\n"
      fi
    fi
  fi

  if [ -n "$superseded_by_val" ]; then
    new_path="$superseded_by_val"
    if ! is_staged "$new_path"; then
      missing="${missing}${entry}: declares superseded_by: ${new_path}, but ${new_path} is not staged\n"
    else
      new_content_ok=1
      new_supersedes="$(get_field "$new_path" supersedes)" || new_content_ok=0
      if [ "$new_content_ok" != 1 ]; then
        deny "git show failed for staged file $new_path — cannot read staged content"
      fi
      if [ "$new_supersedes" != "$entry" ]; then
        missing="${missing}${new_path}: missing/mismatched supersedes: ${entry} (required by ${entry}'s superseded_by field)\n"
      fi
    fi
  fi
done

if [ -n "$missing" ]; then
  deny "missing reciprocal supersession pairing(s):
$(printf '%b' "$missing")"
fi

gate_allow
