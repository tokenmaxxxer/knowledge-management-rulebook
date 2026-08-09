# Shared test-env resolution helper.
#
# Implements the canonical resolution order from the on-the-record
# convention (docs/specs/test-env-resolution.md, issue #551):
#   $CLAUDE_PLUGIN_ROOT_CORE (if it contains hooks/lib/gate-lib.sh)
#   -> caller-supplied sibling candidate (if it contains the same file)
#   -> SKIP contract: stderr message + exit 75 (EX_TEMPFAIL).
#
# Sourced by each km-*/hooks/tests/*.test.sh file. Must be sourced, not
# executed, so `exit` below ends the *caller's* process.

resolve_core_or_skip() {
  # $1: caller's sibling-core candidate, e.g. "$SCRIPT_DIR/../../../core"
  # (the caller's own repo root's ../core, matching each gate script's
  # own "../../core" fallback) — passed in explicitly because deriving
  # it from this lib file's own location would resolve relative to
  # knowledge-management/hooks/tests/lib/ instead of the calling
  # plugin's own directory.
  local sibling_candidate="$1"

  if [ -n "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/gate-lib.sh" ]; then
    return 0
  fi

  if [ -n "$sibling_candidate" ] && [ -f "$sibling_candidate/hooks/lib/gate-lib.sh" ]; then
    return 0
  fi

  echo "SKIP: core plugin unreachable — unverifiable outside spawn env" >&2
  exit 75
}
