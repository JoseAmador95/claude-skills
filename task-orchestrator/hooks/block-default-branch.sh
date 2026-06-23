#!/usr/bin/env bash
# PreToolUse (matcher: Bash). Bloquea `git commit`/`git push` si estás en la rama
# default (main/master). Convierte la regla de la FASE 8 en algo imposible de saltar.
# Requiere `jq`. Si falta, no bloquea (falla en seguro hacia "permitir").
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || { exit 0; }
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

case "$cmd" in
  *"git commit"*|*"git push"*)
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
    default=${default:-main}
    if [ "$branch" = "$default" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
      echo "Bloqueado: estás en la rama '$branch' (default). Crea una rama de feature (git switch -c feat/...) antes de commitear o pushear." >&2
      exit 2
    fi
    ;;
esac
exit 0
