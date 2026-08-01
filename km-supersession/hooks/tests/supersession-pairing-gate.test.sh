#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../supersession-pairing-gate.sh"

pass_count=0
fail_count=0
tmp_dirs=()

cleanup() {
  for d in "${tmp_dirs[@]}"; do
    rm -rf "$d"
  done
}
trap cleanup EXIT

new_repo() {
  local d
  d="$(mktemp -d)"
  tmp_dirs+=("$d")
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test User"
  mkdir -p "$d/docs/patterns"
  printf '%s' "$d"
}

run_gate() {
  # $1 = project dir, $2 = expected exit code, $3 = case label
  local proj="$1" expected="$2" label="$3"
  local payload actual
  payload="$(python3 -c '
import json
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "git commit -m test"}}))
')"
  actual_out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$proj" bash "$GATE" 2>&1)"
  actual="$?"
  if [ "$actual" = "$expected" ]; then
    echo "ok - $label (exit=$actual)"
    pass_count=$((pass_count+1))
  else
    echo "FAIL - $label (expected exit=$expected, got exit=$actual)"
    echo "  output: $actual_out"
    fail_count=$((fail_count+1))
  fi
}

run_gate_raw() {
  # $1 = project dir, $2 = raw stdin payload, $3 = expected exit code, $4 = label
  local proj="$1" raw="$2" expected="$3" label="$4"
  local actual_out actual
  actual_out="$(printf '%s' "$raw" | CLAUDE_PROJECT_DIR="$proj" bash "$GATE" 2>&1)"
  actual="$?"
  if [ "$actual" = "$expected" ]; then
    echo "ok - $label (exit=$actual)"
    pass_count=$((pass_count+1))
  else
    echo "FAIL - $label (expected exit=$expected, got exit=$actual)"
    echo "  output: $actual_out"
    fail_count=$((fail_count+1))
  fi
}

run_gate_env() {
  # $1 = project dir, $2 = extra env assignment (VAR=val), $3 = expected exit code, $4 = label
  local proj="$1" envassign="$2" expected="$3" label="$4"
  local payload actual_out actual
  payload="$(python3 -c '
import json
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "git commit -m test"}}))
')"
  actual_out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$proj" "$envassign" bash "$GATE" 2>&1)"
  actual="$?"
  if [ "$actual" = "$expected" ]; then
    echo "ok - $label (exit=$actual)"
    pass_count=$((pass_count+1))
  else
    echo "FAIL - $label (expected exit=$expected, got exit=$actual)"
    echo "  output: $actual_out"
    fail_count=$((fail_count+1))
  fi
}

# Case 1: PASS - reciprocal supersession pairing, both staged
repo1="$(new_repo)"
cat > "$repo1/docs/patterns/old.md" <<'EOF'
---
title: Old Pattern
superseded_by: docs/patterns/new.md
---
Context...
EOF
cat > "$repo1/docs/patterns/new.md" <<'EOF'
---
title: New Pattern
supersedes: docs/patterns/old.md
---
Context...
EOF
git -C "$repo1" add docs/patterns/old.md docs/patterns/new.md
run_gate "$repo1" 0 "case1: reciprocal pairing staged together"

# Case 2: PASS - unrelated commit, no supersession fields at all
repo2="$(new_repo)"
cat > "$repo2/docs/patterns/plain.md" <<'EOF'
---
title: Plain Pattern
---
Context...
EOF
git -C "$repo2" add docs/patterns/plain.md
run_gate "$repo2" 0 "case2: no supersession fields touched"

# Case 3: FAIL - supersedes target not staged at all
repo3="$(new_repo)"
cat > "$repo3/docs/patterns/old.md" <<'EOF'
---
title: Old Pattern
---
Context...
EOF
git -C "$repo3" add docs/patterns/old.md
git -C "$repo3" commit -q -m "baseline"
cat > "$repo3/docs/patterns/new.md" <<'EOF'
---
title: New Pattern
supersedes: docs/patterns/old.md
---
Context...
EOF
git -C "$repo3" add docs/patterns/new.md
run_gate "$repo3" 2 "case3: supersedes target not staged"

# Case 4: FAIL - old.md staged but missing/wrong superseded_by
repo4="$(new_repo)"
cat > "$repo4/docs/patterns/old.md" <<'EOF'
---
title: Old Pattern
---
Context...
EOF
cat > "$repo4/docs/patterns/new.md" <<'EOF'
---
title: New Pattern
supersedes: docs/patterns/old.md
---
Context...
EOF
git -C "$repo4" add docs/patterns/old.md docs/patterns/new.md
run_gate "$repo4" 2 "case4: old.md staged but missing reciprocal superseded_by"

# Case 5: FAIL - run outside a git repo entirely (fail-closed)
repo5="$(mktemp -d)"
tmp_dirs+=("$repo5")
run_gate "$repo5" 2 "case5: outside a git repo, fail-closed"

# Case 6: FAIL-CLOSED - malformed JSON on stdin (truncated)
repo6="$(new_repo)"
run_gate_raw "$repo6" '{"tool_name": "Bash", "tool_input": {"command": "git commit' 2 "case6: truncated JSON payload fails closed"

# Case 7: FAIL-CLOSED - non-object JSON on stdin
repo7="$(new_repo)"
run_gate_raw "$repo7" '["not", "an", "object"]' 2 "case7: non-object JSON payload fails closed"

# Case 8: FAIL-CLOSED - empty stdin
repo8="$(new_repo)"
run_gate_raw "$repo8" '' 2 "case8: empty payload fails closed"

# Case 9: PASS - kill switch set to unrecognized/garbage value stays ACTIVE
# (uses a repo missing reciprocal pairing so an inactive gate would exit 0,
# proving the garbage value did NOT disable it)
repo9="$(new_repo)"
cat > "$repo9/docs/patterns/old.md" <<'EOF'
---
title: Old Pattern
---
Context...
EOF
cat > "$repo9/docs/patterns/new.md" <<'EOF'
---
title: New Pattern
supersedes: docs/patterns/old.md
---
Context...
EOF
git -C "$repo9" add docs/patterns/old.md docs/patterns/new.md
run_gate_env "$repo9" "KM_SUPERSESSION_GATE_OFF=banana" 2 "case9: garbage kill-switch value stays ACTIVE (still denies)"

# Case 10: REGRESSION - multiline git-commit bypass. A Bash command string
# with an embedded newline between "git" and "commit" (e.g. produced by a
# heredoc or line-continuation) must still be recognized as a git-commit
# invocation, not slip past a single-line-only `[^\n]*` regex.
repo10="$(new_repo)"
cat > "$repo10/docs/patterns/old.md" <<'EOF'
---
title: Old Pattern
---
Context...
EOF
cat > "$repo10/docs/patterns/new.md" <<'EOF'
---
title: New Pattern
supersedes: docs/patterns/old.md
---
Context...
EOF
git -C "$repo10" add docs/patterns/old.md docs/patterns/new.md
payload10="$(python3 -c '
import json
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "git \\\ncommit -m test"}}))
')"
run_gate_raw "$repo10" "$payload10" 2 "case10: multiline git/commit command string still caught"

# Case 11: REGRESSION - staged pattern-entry path containing a space must
# be recognized as ONE entry, both as the entry itself and as a
# supersedes/superseded_by target value on another entry, rather than
# word-split by an unquoted for-loop.
repo11="$(new_repo)"
cat > "$repo11/docs/patterns/my entry.md" <<'EOF'
---
title: Old Pattern With Space
superseded_by: docs/patterns/new.md
---
Context...
EOF
cat > "$repo11/docs/patterns/new.md" <<'EOF'
---
title: New Pattern
supersedes: docs/patterns/my entry.md
---
Context...
EOF
git -C "$repo11" add "docs/patterns/my entry.md" docs/patterns/new.md
run_gate "$repo11" 0 "case11: spaced staged-path recognized as one entry (reciprocal pairing passes)"

echo "----"
echo "summary: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
