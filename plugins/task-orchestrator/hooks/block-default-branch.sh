#!/usr/bin/env bash
# PreToolUse (matcher: Bash). Blocks `git commit`/`git push` if you are on the
# default branch (main/master). Makes the PHASE 8 rule impossible to skip.
# Requires `jq`. If missing, it does not block (fails safe toward "allow").
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
      echo "Blocked: you are on branch '$branch' (default). Create a feature branch (git switch -c feat/...) before committing or pushing." >&2
      exit 2
    fi
    ;;
esac
exit 0
