#!/usr/bin/env bash
# PreToolUse (matcher: Bash). If the command is `git push`, run the project's
# tests; if they fail, block the push. Deterministic backstop for the verifier.
#
# Test command resolution (first match wins):
#   1. $TASK_TEST_CMD if set (explicit override).
#   2. Autodetected from the repo: npm/pytest/make/cargo/go.
#   3. Nothing inferable -> does NOT block (exit 0); set $TASK_TEST_CMD to enforce.
# Requires `jq`. If missing, it does not block.
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || { exit 0; }
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

case "$cmd" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

# Resolve the repo root so file checks work regardless of the hook's CWD.
root=$(git rev-parse --show-toplevel 2>/dev/null) || root="."

# Pick the test command.
TEST_CMD=""
if [ -n "${TASK_TEST_CMD:-}" ]; then
  TEST_CMD="$TASK_TEST_CMD"
elif [ -f "$root/package.json" ] && jq -e '.scripts.test' "$root/package.json" >/dev/null 2>&1; then
  TEST_CMD="npm test"
elif command -v pytest >/dev/null 2>&1 && {
  [ -f "$root/pyproject.toml" ] || [ -f "$root/tox.ini" ] || \
  [ -f "$root/pytest.ini" ] || [ -f "$root/setup.cfg" ] || [ -d "$root/tests" ]; }; then
  TEST_CMD="pytest"
elif [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile"; then
  TEST_CMD="make test"
elif [ -f "$root/Cargo.toml" ]; then
  TEST_CMD="cargo test"
elif [ -f "$root/go.mod" ]; then
  TEST_CMD="go test ./..."
fi

if [ -z "$TEST_CMD" ]; then
  echo "task-orchestrator: no test command inferred; push allowed. Set TASK_TEST_CMD to enforce tests before push." >&2
  exit 0
fi

# Log under ~/.claude/task-logs/<repo>/ (outside the repo, namespaced per repo).
log_dir="$HOME/.claude/task-logs/$(basename "$root")"
mkdir -p "$log_dir" 2>/dev/null || log_dir="${TMPDIR:-/tmp}"
log_file="$log_dir/push-tests.log"

if ! eval "$TEST_CMD" >"$log_file" 2>&1; then
  echo "Blocked: tests are failing ($TEST_CMD), push aborted. Log: $log_file" >&2
  exit 2
fi
exit 0
