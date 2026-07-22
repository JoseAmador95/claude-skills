# Install — task-orchestrator

This folder is a **Claude Code skill** plus its four subagents, two commands, and
templates.

## Quick install (recommended): `install.sh`

The bundled installer automates every step below and is **idempotent** (re-running
leaves the same state, with no duplicated hooks):

```bash
./task-orchestrator/install.sh            # install into ~/.claude (user level)
./task-orchestrator/install.sh --project  # install into ./.claude (project level)
./task-orchestrator/install.sh --link     # symlinks: a 'git pull' updates the install
./task-orchestrator/install.sh --dry-run  # show what it would do without touching anything
```

It installs the skill, the agents, the commands, makes the hooks executable, and
merges `hooks/settings.snippet.json` into `settings.json` (needs `jq` for the
merge — without it, it tells you the one manual step). Verify with `/agents`
inside Claude Code that `task-analyzer`, `task-implementer`, `task-verifier`, and
`task-dreamer` show up.

If you'd rather do it by hand, the manual steps follow.

## 1. Install the skill

At the project level (shared with the team via git):

```bash
mkdir -p .claude/skills
cp -r task-orchestrator .claude/skills/
```

Or at the user level (all your sessions):

```bash
mkdir -p ~/.claude/skills
cp -r task-orchestrator ~/.claude/skills/
```

## 2. Install the subagents

The subagents go in `.claude/agents/` (not inside the skill):

```bash
# project
cp task-orchestrator/agents/*.md .claude/agents/
# or user
cp task-orchestrator/agents/*.md ~/.claude/agents/
```

Verify with `/agents` inside Claude Code that `task-analyzer`,
`task-implementer`, `task-verifier`, and `task-dreamer` show up.

> If you'd rather not install the agents as files, you can delete the bundle's
> `agents/` folder: SKILL.md also explains how to launch equivalent subagents with
> the `Task` tool and inline prompts (see `references/subagents.md`).

## 3. Install the hooks (deterministic gates, optional but recommended)

The hooks enforce the rules you don't want left to the model's discretion: block
commits/push on the default branch, require green tests before push, and
auto-format what's edited.

```bash
# The scripts already ship with the skill; you just wire them into settings.json.
# Paste the contents of hooks/settings.snippet.json into .claude/settings.json
# (merging it with your existing hooks if any).
chmod +x .claude/skills/task-orchestrator/hooks/*.sh   # just in case
```

They require `jq`. The push gate's test command is set with the `TASK_TEST_CMD`
env var (default `npm test`). The hooks fail "safe": if `jq` or a formatter is
missing, they don't break anything.

## 4. Install the commands

The skill ships two slash commands:

- `/task` — the fast entry point: starts the full workflow from phase 0.
- `/task-execute <slug>` — relay to run an already-approved plan in a fresh
  session (hard context reset).

```bash
mkdir -p .claude/commands
cp task-orchestrator/commands/*.md .claude/commands/
```

## 5. Requirements

- `gh` (GitHub CLI) authenticated, for issues, PRs, and CI.
- `git` with worktrees (included in modern git) if you use the parallel pattern.
- `jq` for the hooks and the installer's settings merge. Optional formatters
  (prettier, ruff, gofmt…) depending on your stack.

## 6. Usage

Inside Claude Code:

```
/task 42
```

or just describe a task and ask to "resolve it with the full flow". The skill
handles the triage phase plus the 12 numbered phases (0–12), stopping to ask for
approval before pushing, opening the PR, and merging.
