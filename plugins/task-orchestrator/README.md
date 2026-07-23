# task-orchestrator

A Claude Code **plugin** that orchestrates a development task end to end: triage,
repo analysis with subagents, an approval-gated plan, delegated implementation,
independent verification, atomic commits, a PR, and CI watching.

## Install

From inside Claude Code, add the marketplace and install the plugin:

```
/plugin marketplace add JoseAmador95/claude-skills
/plugin install task-orchestrator@amador-skills
```

Then run `/reload-plugins` (or restart Claude Code). The plugin auto-loads its
skills, agents, and hooks — there is nothing to copy by hand and no
`settings.json` to edit.

## Use

```
/task 42              # work GitHub issue #42
/task <description>   # or describe the task inline
```

`/task` is the entry point (its fully-qualified name is `/task-orchestrator:task`;
the short `/task` works unless another command already claims that name). It runs
the triage phase plus the 12 numbered phases (0–12), stopping for your explicit
approval before pushing, opening the PR, and merging. To resume an already-approved
plan in a fresh session, use `/task-execute <slug>`.

Both entry points are **manual-only** (`disable-model-invocation`): the workflow
starts when you invoke `/task`, never on its own.

## What's inside

| Path | What it is |
|---|---|
| `skills/task/` | The workflow skill (triage + 10 phases) with its `references/` and `assets/`. |
| `skills/task-execute/` | The relay skill to run an approved plan in a clean session. |
| `agents/` | The four subagents: `task-analyzer`, `task-implementer`, `task-verifier`, `task-dreamer`. |
| `hooks/` | Deterministic gates (`hooks.json` + scripts): block the default branch, tests before push, auto-format, plus SessionStart/SubagentStop bookkeeping. |

## Requirements

- `gh` (GitHub CLI) authenticated, for issues, PRs, and CI.
- `git` (with worktrees, included in modern git) for the parallel-implementer pattern.
- `jq` for the hooks. Optional formatters (prettier, ruff, gofmt…) for auto-format.

## Local development

Validate the plugin before publishing:

```
claude plugin validate ./plugins/task-orchestrator --strict
```

Or try it live without a marketplace: `claude --plugin-dir ./plugins/task-orchestrator`.
