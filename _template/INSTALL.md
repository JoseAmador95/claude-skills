# Install — <skill-name>

<!-- Short description of what this bundle installs. -->

## 1. Install the skill

At the project level (shared with the team via git):

```bash
mkdir -p .claude/skills
cp -r <skill-name> .claude/skills/
```

Or at the user level (all your sessions):

```bash
mkdir -p ~/.claude/skills
cp -r <skill-name> ~/.claude/skills/
```

## 2. Install the subagents

```bash
# project
cp <skill-name>/agents/*.md .claude/agents/

# or user
cp <skill-name>/agents/*.md ~/.claude/agents/
```

<!-- If there are no subagents, delete this section. -->

## 3. Install the commands (if any)

```bash
mkdir -p .claude/commands
cp <skill-name>/commands/*.md .claude/commands/
```

<!-- If there are no commands, delete this section. -->

## 4. Install the hooks (if any)

```bash
chmod +x .claude/skills/<skill-name>/hooks/*.sh
# Merge hooks/settings.snippet.json into .claude/settings.json
```

<!-- If there are no hooks, delete this section. -->

## 5. Requirements

<!-- List the external dependencies (CLI, tools, etc.). -->

- ...

## 6. Usage

<!-- How to invoke the skill inside Claude Code. -->

```
<Example prompt or slash command>
```
