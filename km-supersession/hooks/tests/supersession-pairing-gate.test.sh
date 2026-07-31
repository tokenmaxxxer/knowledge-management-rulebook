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

echo "----"
echo "summary: $pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
