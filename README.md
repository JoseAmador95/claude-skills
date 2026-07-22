# Skills

A repository of **Claude Code plugins** that package skills, subagents, slash
commands, and hooks into installable units. It is a
[plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces): each
plugin lives under `plugins/` and is listed in `.claude-plugin/marketplace.json`.

## Install

From inside Claude Code, add this marketplace once:

```
/plugin marketplace add JoseAmador95/claude-skills
```

then install any plugin from it:

```
/plugin install task-orchestrator@amador-skills
```

Run `/reload-plugins` (or restart) and the plugin's skills, agents, and hooks load
automatically — no files to copy and no `settings.json` to edit.

## Available plugins

### [`task-orchestrator`](plugins/task-orchestrator/)

Orchestrates a development task end to end with a disciplined workflow: repo
analysis with subagents, a plan with an approval gate, delegated implementation,
independent and skeptical verification, atomic commits, a PR, and CI watching. The
workflow is a triage phase (phase 0) plus 12 numbered phases (1–12).

Entry point: `/task <issue # | description>` (manual-only). See
[`plugins/task-orchestrator/README.md`](plugins/task-orchestrator/README.md).

## Repository structure

```
.
├── .claude-plugin/
│   └── marketplace.json      # the marketplace catalog
├── plugins/
│   └── task-orchestrator/    # one plugin per folder
│       ├── .claude-plugin/plugin.json
│       ├── skills/           # skills/<name>/SKILL.md (+ references/, assets/)
│       ├── agents/           # subagents
│       └── hooks/            # hooks.json + gate scripts
├── _template/                # scaffold for a new plugin
├── scripts/                  # CI validators (frontmatter, manifests)
├── IDEAS.md                  # backlog of proposed plugins and improvements
└── CONTRIBUTING.md
```

To add another plugin, copy `_template/` into `plugins/<name>/`, fill it in, and
list it in `.claude-plugin/marketplace.json`. See
[`CONTRIBUTING.md`](CONTRIBUTING.md). Ideas for future plugins live in
[`IDEAS.md`](IDEAS.md).

## Migrating from the old installer

Earlier versions shipped a hand-rolled `install.sh` that copied files into
`~/.claude`. That is gone — the plugin system replaces it. If you installed the old
way, remove the leftovers before installing the plugin:

```bash
rm -rf ~/.claude/skills/task-orchestrator
rm -f  ~/.claude/agents/task-analyzer.md ~/.claude/agents/task-implementer.md \
       ~/.claude/agents/task-verifier.md ~/.claude/agents/task-dreamer.md
rm -f  ~/.claude/commands/task.md ~/.claude/commands/task-execute.md
```

and delete the task-orchestrator hooks block you pasted into
`~/.claude/settings.json`.
