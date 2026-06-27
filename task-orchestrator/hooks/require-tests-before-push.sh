#!/usr/bin/env bash
# PreToolUse (matcher: Bash). If the command is `git push`, run the tests; if
# they fail, block the push. Deterministic backstop that backs up the verifier.
# Set the test command with the TASK_TEST_CMD env var (default: "npm test").
# Requires `jq`. If missing, it does not block.
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || { exit 0; }
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

case "$cmd" in
  *"git push"*)
    TEST_CMD=${TASK_TEST_CMD:-"npm test"}
    if ! eval "$TEST_CMD" >/tmp/task-orchestrator-tests.log 2>&1; then
      echo "Blocked: tests are failing, push aborted. Log: /tmp/task-orchestrator-tests.log" >&2
      exit 2
    fi
    ;;
esac
exit 0
