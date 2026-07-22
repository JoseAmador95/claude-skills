---
name: <skill-name>
description: >-
  <One or two sentences explaining what this skill does and when it should
  activate. The model uses this text to decide whether to invoke it.>
---

# <Readable skill name>

<!-- Describe here the role the model takes on when running this skill. -->

## Goal

<!-- What problem it solves and what result it produces. -->

## Flow

<!-- List the phases or steps of the flow. For example: -->

1. **Analysis** — ...
2. **Planning** — ...
3. **Implementation** — ...
4. **Verification** — ...

## Subagents

<!-- List the subagents this flow uses and which phase they're invoked in.
     Their definitions live in agents/. -->

| Subagent | Phase | What it does |
|---|---|---|
| `<agent-name>` | Phase X | ... |

## Rules and constraints

<!-- What the model must not do even though it could. -->

- ...
