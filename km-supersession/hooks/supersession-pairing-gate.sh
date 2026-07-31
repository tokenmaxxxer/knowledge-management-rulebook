#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT

set -uo pipefail

# Kill switch
case "${KM_SUPERSESSION_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "knowledge-management: refused — $1" >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || deny "python3 is required for this gate but was not found"
command -v git >/dev/null 2>&1 || deny "git is required for this gate but was not found"

payload="$(cat)"

# Extract tool_name and tool_input.command via python3 (stdlib json only)
tool_name="$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
print(data.get("tool_name", ""))
')"

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command_str="$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
print(data.get("tool_input", {}).get("command", ""))
')"

if [ -z "$command_str" ]; then
  exit 0
fi

if ! printf '%s' "$command_str" | grep -Eq '\bgit\b[^\n]*\bcommit\b'; then
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
        m = re.match(r'^${field}:\s*(\S+)', line)
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

for entry in $pattern_entries; do
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

exit 0
