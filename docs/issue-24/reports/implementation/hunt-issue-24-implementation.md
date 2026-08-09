---
proposal: docs/issue-24/proposals/implementation.md
---

# Hunt record — issue-24-implementation


## after-proposal -- stance 4: assume the write set cannot carry this work -- find the path the build will need that the proposal does not list

Verdict: FINDING -- the shared resolver's sibling-core candidate, if computed via the lib file's own BASH_SOURCE array element 0, resolves relative to knowledge-management/hooks/tests/lib/ (the lib's own location) instead of relative to each of the 5 km-*/hooks/tests/ callers, so it points at a nonexistent knowledge-management/hooks/core and SKIPs (exit 75) even when a real sibling core/ exists exactly where the 5 plugins' own gate scripts already find it.
Kind: design-error
Seed: docs/issue-24/proposals/implementation.md (commit 13de008), plan section: Add knowledge-management/hooks/tests/lib/test-env-resolve.sh
cap_seconds: 120
tier: size:21-200
diff_stat_lines: ~207
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:20:00Z

### Reproduce
Simulated the proposed layout and the natural implementation of a sourceable function that finds the sibling core via its own file location rather than the caller's, since the plan does not require the caller directory to be passed as a parameter.

Directory setup, run from an empty scratch dir named repro:
  mkdir -p repro/knowledge-management/hooks/tests/lib repro/km-adr-proposal/hooks/tests repro/core/hooks/lib
  touch repro/core/hooks/lib/gate-lib.sh

repro/knowledge-management/hooks/tests/lib/test-env-resolve.sh contains a function resolve_core_or_skip that computes its own directory from the sourced file's BASH_SOURCE entry, falls back to that directory plus /../../core when CLAUDE_PLUGIN_ROOT_CORE is unset, checks for hooks/lib/gate-lib.sh under the candidate, and prints a SKIP message plus returns 75 when the check fails.

repro/km-adr-proposal/hooks/tests/adr-shape-gate.test.sh sources that lib file by relative path from its own SCRIPT_DIR (three levels up then into knowledge-management/hooks/tests/lib) and calls resolve_core_or_skip.

Run:
  cd repro
  env -u CLAUDE_PLUGIN_ROOT_CORE bash km-adr-proposal/hooks/tests/adr-shape-gate.test.sh

### Observed
SKIP: core unreachable, computed candidate=/.../repro/knowledge-management/hooks/tests/lib/../../core
rc=75

The candidate resolves to repro/knowledge-management/hooks/core, which does not exist, so the guard SKIPs even though repro/core/hooks/lib/gate-lib.sh (a real, reachable core, sitting exactly where the plugin's own adr-shape-gate.sh looks via its own ../../core fallback) is present two directories away in the correct sibling position.

### Expected
The resolver should find repro/core (the sibling of the 5 km-* plugin dirs) and return success, matching what the existing gate script's own ../../core fallback would find from the same checkout. Instead every one of the 5 test files, sourced this way, would falsely report core unreachable and skip all gate-lib-dependent cases even in a checkout where core is perfectly reachable. The proposal's write set and plan text never state that the shared resolver must take the caller's directory as an argument rather than deriving it from its own file location, so the straightforward implementation of one shared sourced file silently breaks the very SKIP-vs-RUN distinction the proposal exists to test.
