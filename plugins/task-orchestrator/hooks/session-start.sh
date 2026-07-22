#!/usr/bin/env bash
# SessionStart. Pre-create the per-repo task-log directory so PHASE 2 never
# races on mkdir and the logs always have a home. Fail-open: always exits 0 and
# never blocks a session from starting.
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$HOME/.claude/task-logs/$(basename "$root")" 2>/dev/null || true
exit 0
