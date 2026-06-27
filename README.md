# Skills

A repository of **Claude Code skills** and their dependencies (subagents and
commands), packaged as **self-contained bundles**: each skill is a top-level
folder that carries everything it needs inside it.

## Available skills

### [`task-orchestrator/`](task-orchestrator/)

Orchestrates a development task end to end with a disciplined workflow: repo
analysis with subagents, a plan with an approval gate, delegated implementation,
independent and skeptical verification, atomic commits, a PR, and CI watching. The
workflow is a triage phase (phase 0) plus 12 numbered phases (1–12).

The bundle is self-contained:

| Path | What it is |
|---|---|
| `SKILL.md` | The skill (the triage + 12-phase workflow). |
| `INSTALL.md` | How to install it at the project or user level. |
| `install.sh` | Idempotent installer that wires up the whole bundle. |
| `agents/` | The 4 subagents: `task-analyzer`, `task-implementer`, `task-verifier`, `task-dreamer`. |
| `commands/` | `task.md` (`/task`, the fast entry point) and `task-execute.md` (relay to run an approved plan in a fresh session). |
| `hooks/` | Deterministic gates: block the default branch, tests before push, auto-format. |
| `assets/` | Templates (task log, ADR, PR body). |
| `references/` | Supporting documentation (subagents, logging, ADRs). |

**Install:** the quickest way is the bundled installer (see
[`task-orchestrator/INSTALL.md`](task-orchestrator/INSTALL.md) for all options):

```bash
./task-orchestrator/install.sh            # install into ~/.claude (user level)
./task-orchestrator/install.sh --project  # install into ./.claude (project level)
./task-orchestrator/install.sh --link     # symlinks: a 'git pull' updates the install
./task-orchestrator/install.sh --dry-run  # show what it would do
```

Once installed, kick off a task with the `/task` command (or `/task <issue #>`).

## Repository structure

```
.
├── README.md
├── IDEAS.md                  # backlog of proposed skills and improvements
└── task-orchestrator/        # self-contained bundle (one folder per skill)
    ├── SKILL.md
    ├── INSTALL.md
    ├── install.sh
    ├── agents/
    ├── commands/
    ├── hooks/
    ├── assets/
    └── references/
```

To add another skill, create it as a sibling folder of `task-orchestrator/`
following the same convention (start from `_template/`). See
[`CONTRIBUTING.md`](CONTRIBUTING.md). Ideas for future skills live in
[`IDEAS.md`](IDEAS.md).
