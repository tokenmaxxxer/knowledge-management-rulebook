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

for d in "${cleanup_dirs[@]}"; do
  rm -rf "$d"
done

echo "---"
echo "index-pairing-gate.test.sh: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
