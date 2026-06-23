#!/usr/bin/env bash
# PreToolUse (matcher: Bash). Si el comando es `git push`, corre los tests; si
# fallan, bloquea el push. Backstop determinista que respalda al verificador.
# Ajusta el comando de test con la env var TASK_TEST_CMD (default: "npm test").
# Requiere `jq`. Si falta, no bloquea.
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || { exit 0; }
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

case "$cmd" in
  *"git push"*)
    TEST_CMD=${TASK_TEST_CMD:-"npm test"}
    if ! eval "$TEST_CMD" >/tmp/task-orchestrator-tests.log 2>&1; then
      echo "Bloqueado: los tests fallan, no se hace push. Log: /tmp/task-orchestrator-tests.log" >&2
      exit 2
    fi
    ;;
esac
exit 0
