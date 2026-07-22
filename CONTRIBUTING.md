# Contributing to this repository

Thanks for your interest in contributing. This document explains the repo's
conventions so that any new plugin fits in with the existing ones without friction.

---

## Core principle: one plugin per folder

This repo is a **Claude Code plugin marketplace**. Each skill ships as a **plugin**
under `plugins/<name>/` and is listed in `.claude-plugin/marketplace.json`. A plugin
carries everything it needs — its skills, subagents, hooks, and templates — and
Claude Code loads it natively via `/plugin`, so there is no installer to maintain.

```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json          # manifest (name is the only required field)
├── README.md                # how to install and use this plugin
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md         # frontmatter + instructions
│       ├── references/      # supporting docs the model can read (inside the skill)
│       └── assets/          # templates the skill reads/creates at runtime
├── agents/                  # one .md per subagent
└── hooks/
    ├── hooks.json           # event → matcher → command wiring
    └── *.sh                 # deterministic gate scripts
```

`skills/`, `agents/`, and `hooks/` sit at the **plugin root** — only `plugin.json`
goes inside `.claude-plugin/`. A skill's `references/` and `assets/` live **inside**
its `skills/<name>/` folder so relative links from `SKILL.md` keep working.

---

## Required frontmatter

### `skills/<name>/SKILL.md`

```yaml
---
name: <skill-name>            # sets the /command name; kebab-case
description: >-
  One or two sentences: what the skill does and when it applies.
disable-model-invocation: true                 # optional: manual-only (/name), no auto-trigger
allowed-tools: Bash(git status *) Read Grep    # optional: pre-approve tools for the invoking turn
---
```

A plugin skill is invoked as `/<plugin>:<name>`, and the short `/<name>` also works
unless another command already claims it.

### `agents/*.md`

```yaml
---
name: <agent-name>            # kebab-case; invoked as <plugin>:<agent-name> or bare
description: >-
  What this subagent does and which phase of the flow it is used in.
tools: Read, Bash, Edit       # comma-separated allowlist (optional; omit to inherit all)
model: sonnet                 # sonnet | opus | haiku | fable, or a full model id
effort: medium                # optional; low | medium | high | xhigh | max | inherit
color: cyan                   # optional display color
isolation: worktree           # optional: run each invocation in its own git worktree
---
```

> **Plugin agents ignore `mcpServers`, `permissionMode`, and `hooks`** in their
> frontmatter (a security restriction). To give a plugin agent MCP tools, add the
> `mcp__<server>__*` names to its `tools` allowlist instead.

CI validates that `SKILL.md` has `name`+`description`, that each agent has
`name`+`description`+`tools`+`model`, and that `effort` (if present) is valid.

---

## Adding a new plugin

1. **Copy the template:**

   ```bash
   cp -r _template plugins/<plugin-name>
   ```

2. **Fill in `.claude-plugin/plugin.json`** — set at least `name`.

3. **Fill in the skill**: rename `skills/<skill-name>/` and write its `SKILL.md`
   (name, description, body).

4. **Add subagents** in `agents/` and **hooks** in `hooks/hooks.json` if the plugin
   needs them; otherwise delete those folders.

5. **Write `README.md`** with install (`/plugin install <name>@amador-skills`) and
   usage.

6. **List the plugin** in `.claude-plugin/marketplace.json` under `plugins`.

7. **Update the root `README.md`** to mention the new plugin.

---

## How to test

Validate the manifests and frontmatter the way CI does:

```bash
python3 scripts/validate-plugins.py .              # marketplace + plugin.json structure
python3 scripts/validate-frontmatter.py .          # SKILL.md and agents/*.md frontmatter
claude plugin validate ./plugins/<name> --strict   # the full Claude Code check
```

Try a plugin live without publishing: `claude --plugin-dir ./plugins/<name>`, or add
the marketplace from a local path with `/plugin marketplace add ./`.

---

## Writing style and conventions

- Docs are written in the **language of the project** — this repo is in **English**,
  so keep new content in English.
- Folder, plugin, skill, and agent names in **kebab-case**.
- Keep hook scripts **fail-open**: if a tool like `jq` is missing, do not break the
  workflow.
