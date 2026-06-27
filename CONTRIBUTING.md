# Contributing to this repository

Thanks for your interest in contributing. This document explains the repo's
conventions so that any new skill fits in with the existing ones without friction.

---

## Core principle: the self-contained bundle

Each skill is a **top-level folder** that carries everything it needs to work: the
skill itself, its subagents, its slash commands, its hooks, its templates, and its
supporting documentation. There are no implicit dependencies between different
skills.

```
<skill-name>/
├── SKILL.md              # The skill (frontmatter + workflow instructions)
├── INSTALL.md            # How to install it
├── install.sh            # Optional installer that automates INSTALL.md
├── agents/               # Workflow subagents (internal dependencies)
│   └── *.md
├── commands/             # Slash commands (internal dependencies)
│   └── *.md
├── hooks/                # Deterministic gate scripts
│   ├── *.sh
│   └── settings.snippet.json
├── assets/               # Templates the skill uses at runtime
└── references/           # Supporting documentation (not installed, it's guidance)
```

### What goes in each folder

| Folder | Contents |
|---|---|
| `agents/` | One `.md` per subagent. They are **workflow dependencies**: they live inside the bundle and are copied to `.claude/agents/` on install. |
| `commands/` | One `.md` per slash command. Also internal dependencies; copied to `.claude/commands/` on install. |
| `hooks/` | Bash scripts wired into `settings.json`. Includes `settings.snippet.json` with the ready-to-merge fragment. |
| `assets/` | Templates (markdown, JSON, YAML…) the skill creates or reads at runtime. |
| `references/` | Supporting documentation the model can read but that isn't installed anywhere. |

---

## Required frontmatter

### `SKILL.md`

```yaml
---
name: <skill-name>            # unique identifier, kebab-case
description: >-
  One or two sentences. Explain what the skill does and when to use it. The
  model reads this to decide whether to activate it.
---
```

### `agents/*.md`

```yaml
---
name: <agent-name>            # kebab-case
description: >-
  What this subagent does and which phase of the flow it's used in.
tools: Read, Bash, Edit       # comma-separated list
model: sonnet                 # or haiku, opus, etc.
effort: medium                # optional; if present must be low|medium|high|max|inherit
---
```

### `commands/*.md`

```yaml
---
description: One sentence describing what the command does.
argument-hint: "<expected argument>"   # optional
---
```

CI validates that these fields exist (and that `effort`, if present, is a valid
value). A PR with incomplete frontmatter won't pass the check.

---

## Adding a new skill

1. **Copy the template:**

   ```bash
   cp -r _template/ <skill-name>/
   ```

2. **Fill in `SKILL.md`** — set the `name`, `description`, and the workflow
   content in the body.

3. **Write the subagents** in `agents/`. Each file is a `.md` with valid
   frontmatter and the subagent's instructions in the body.

4. **Write the commands** in `commands/` if the skill needs slash commands.

5. **Fill in `INSTALL.md`** with your skill's specific steps (what to copy, in
   what order, requirements). Optionally add an `install.sh` to automate them.

6. **Delete the empty folders** you don't need (or leave them with their
   `.gitkeep` if you'll need them later).

7. **Update `README.md`** at the root by adding your skill to the available table.

---

## How to install and test

See each skill's `INSTALL.md` for the exact steps. Bundles that ship an
`install.sh` automate the whole thing:

```bash
./<skill-name>/install.sh            # install into ~/.claude (user level)
./<skill-name>/install.sh --project  # install into ./.claude (project level)
```

Without the script, the general pattern is:

```bash
# install the skill
cp -r <skill-name>/ ~/.claude/skills/

# install subagents
cp <skill-name>/agents/*.md ~/.claude/agents/

# install commands (if any)
cp <skill-name>/commands/*.md ~/.claude/commands/
```

---

## Writing style and conventions

- Docs are written in the **language of the project**. This repo is in **English**,
  so keep new content in English to match; a skill authored for a different-language
  project should follow that project's language instead.
- Folder and skill names in **kebab-case**.
- Don't break the self-contained bundle convention: if your skill needs something
  from another skill, document that dependency explicitly in its `INSTALL.md`.
