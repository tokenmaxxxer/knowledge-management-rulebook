#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate="$here/../index-pairing-gate.sh"

pass_count=0
fail_count=0

make_repo() {
  local repo
  repo="$(mktemp -d)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test User"
  mkdir -p "$repo/docs/patterns"
  printf '# Pattern Index\n\n| Keyword | Status |\n| --- | --- |\n' > "$repo/docs/patterns/index.md"
  git -C "$repo" add docs/patterns/index.md
  git -C "$repo" commit -q -m "initial index"
  echo "$repo"
}

commit_json() {
  cat <<'EOF'
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m test"
  }
}
EOF
}

run_gate() {
  local repo="$1"
  commit_json | CLAUDE_PROJECT_DIR="$repo" "$gate" 2>&1
}

record() {
  local name="$1" expect="$2" rc="$3" out="$4"
  local ok=0
  if [ "$expect" = "pass" ] && [ "$rc" = 0 ]; then
    ok=1
  elif [ "$expect" = "fail" ] && [ "$rc" != 0 ]; then
    ok=1
  fi
  if [ "$ok" = 1 ]; then
    echo "ok - $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL - $name (rc=$rc, expected=$expect) output: $out"
    fail_count=$((fail_count + 1))
  fi
}

cleanup_dirs=()

# Case 1: PASS - new pattern entry staged + index.md also staged (edited) in same commit.
repo1="$(make_repo)"
cleanup_dirs+=("$repo1")
printf 'New pattern entry body.\n' > "$repo1/docs/patterns/entry-1.md"
git -C "$repo1" add docs/patterns/entry-1.md
printf '# Pattern Index\n\n| Keyword | Status |\n| --- | --- |\n| entry-1 | active |\n' > "$repo1/docs/patterns/index.md"
git -C "$repo1" add docs/patterns/index.md
out1="$(run_gate "$repo1")"; rc1=$?
record "new entry + index paired" "pass" "$rc1" "$out1"

# Case 2: FAIL - new pattern entry staged, index.md NOT staged.
repo2="$(make_repo)"
cleanup_dirs+=("$repo2")
printf 'New pattern entry body.\n' > "$repo2/docs/patterns/entry-2.md"
git -C "$repo2" add docs/patterns/entry-2.md
out2="$(run_gate "$repo2")"; rc2=$?
record "new entry without index update" "fail" "$rc2" "$out2"

# Case 3: PASS - no new pattern-entry files staged (unrelated file only).
repo3="$(make_repo)"
cleanup_dirs+=("$repo3")
printf 'unrelated content\n' > "$repo3/README.md"
git -C "$repo3" add README.md
out3="$(run_gate "$repo3")"; rc3=$?
record "unrelated staged file, not this gate's business" "pass" "$rc3" "$out3"

# Case 3b: PASS - only index.md edited alone with no new pattern file.
repo3b="$(make_repo)"
cleanup_dirs+=("$repo3b")
printf '# Pattern Index\n\n| Keyword | Status |\n| --- | --- |\n| foo | active |\n' > "$repo3b/docs/patterns/index.md"
git -C "$repo3b" add docs/patterns/index.md
out3b="$(run_gate "$repo3b")"; rc3b=$?
record "index.md edited alone, not this gate's business" "pass" "$rc3b" "$out3b"

# Case 4: FAIL - run outside a git repo (plain non-git tmp dir).
plain_dir="$(mktemp -d)"
cleanup_dirs+=("$plain_dir")
out4="$(commit_json | CLAUDE_PROJECT_DIR="$plain_dir" "$gate" 2>&1)"; rc4=$?
record "outside git repo fails closed" "fail" "$rc4" "$out4"

# Case 5: FAIL - multiline "git\ncommit" command must still be detected as
# a commit event (audit-named defect: [^\n]* stops at any newline, so a
# Bash tool_input.command with an embedded newline before "commit" used to
# bypass detection entirely).
repo5="$(make_repo)"
cleanup_dirs+=("$repo5")
printf 'New pattern entry body.\n' > "$repo5/docs/patterns/entry-5.md"
git -C "$repo5" add docs/patterns/entry-5.md
multiline_json='{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git\ncommit -m test"
  }
}'
out5="$(printf '%s' "$multiline_json" | CLAUDE_PROJECT_DIR="$repo5" "$gate" 2>&1)"; rc5=$?
record "multiline git/commit split across newline still caught" "fail" "$rc5" "$out5"

# Case 6: PASS - a staged pattern-entry path containing a space, paired
# with an index.md update in the same commit, must still be recognized.
repo6="$(make_repo)"
cleanup_dirs+=("$repo6")
printf 'New pattern entry body.\n' > "$repo6/docs/patterns/my entry.md"
git -C "$repo6" add "docs/patterns/my entry.md"
printf '# Pattern Index\n\n| Keyword | Status |\n| --- | --- |\n| my entry | active |\n' > "$repo6/docs/patterns/index.md"
git -C "$repo6" add docs/patterns/index.md
out6="$(run_gate "$repo6")"; rc6=$?
record "spaced staged-path paired with index (accept)" "pass" "$rc6" "$out6"

# Case 7: FAIL - same spaced-path new entry, but index.md NOT staged; the
# gate must still detect the addition (proves the -z NUL-terminated
# parsing, not just that pairing accidentally passes).
repo7="$(make_repo)"
cleanup_dirs+=("$repo7")
printf 'New pattern entry body.\n' > "$repo7/docs/patterns/my entry.md"
git -C "$repo7" add "docs/patterns/my entry.md"
out7="$(run_gate "$repo7")"; rc7=$?
record "spaced staged-path without index update (deny)" "fail" "$rc7" "$out7"

# Case 8: FAIL - malformed JSON on stdin (truncated). Must fail closed.
repo8="$(make_repo)"
cleanup_dirs+=("$repo8")
out8="$(printf '{"tool_name": "Bash", "tool_in' | CLAUDE_PROJECT_DIR="$repo8" "$gate" 2>&1)"; rc8=$?
record "truncated JSON fails closed" "fail" "$rc8" "$out8"

# Case 9: FAIL - malformed JSON on stdin (non-object top level). Must fail closed.
repo9="$(make_repo)"
cleanup_dirs+=("$repo9")
out9="$(printf '"just a string"' | CLAUDE_PROJECT_DIR="$repo9" "$gate" 2>&1)"; rc9=$?
record "non-object JSON fails closed" "fail" "$rc9" "$out9"

# Case 10: FAIL - malformed JSON on stdin (empty payload). Must fail closed.
repo10="$(make_repo)"
cleanup_dirs+=("$repo10")
out10="$(printf '' | CLAUDE_PROJECT_DIR="$repo10" "$gate" 2>&1)"; rc10=$?
record "empty payload fails closed" "fail" "$rc10" "$out10"

# Case 11: FAIL (stays active) - kill switch set to an unrecognized/garbage
# value must NOT disable the gate (only recognized on-spellings do).
repo11="$(make_repo)"
cleanup_dirs+=("$repo11")
printf 'New pattern entry body.\n' > "$repo11/docs/patterns/entry-11.md"
git -C "$repo11" add docs/patterns/entry-11.md
out11="$(commit_json | KM_CROSS_INDEX_GATE_OFF="banana" CLAUDE_PROJECT_DIR="$repo11" "$gate" 2>&1)"; rc11=$?
record "garbage kill-switch value stays active" "fail" "$rc11" "$out11"

# Case 12: PASS - kill switch set to a recognized on-spelling disables the gate.
repo12="$(make_repo)"
cleanup_dirs+=("$repo12")
printf 'New pattern entry body.\n' > "$repo12/docs/patterns/entry-12.md"
git -C "$repo12" add docs/patterns/entry-12.md
out12="$(commit_json | KM_CROSS_INDEX_GATE_OFF="true" CLAUDE_PROJECT_DIR="$repo12" "$gate" 2>&1)"; rc12=$?
record "recognized on-spelling disables gate" "pass" "$rc12" "$out12"

for d in "${cleanup_dirs[@]}"; do
  rm -rf "$d"
done

echo "---"
echo "index-pairing-gate.test.sh: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
