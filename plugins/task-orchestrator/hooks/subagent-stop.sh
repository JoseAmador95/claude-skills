#!/usr/bin/env bash
# SubagentStop. Append one accounting line (timestamp + agent name) to
# ~/.claude/task-logs/<repo>/subagent-usage.log every time a subagent finishes,
# so the cost of the workflow (how many subagents ran, of which kind) is visible.
# Fail-open: always exits 0, so it never prevents a subagent from stopping.
# Requires jq to read the agent name from the event payload on stdin.
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
dir="$HOME/.claude/task-logs/$(basename "$root")"
mkdir -p "$dir" 2>/dev/null || exit 0
# SubagentStop exposes agent_type (the agent's frontmatter name, plugin-scoped
# as e.g. task-orchestrator:task-analyzer); fall back to the id, then unknown.
name=$(printf '%s' "$input" | jq -r '.agent_type // .agent_id // "unknown"' 2>/dev/null)
printf '%s\t%s\n' "$(date -u +%FT%TZ)" "$name" >> "$dir/subagent-usage.log" 2>/dev/null || true
exit 0
