---
description: Run a development task end-to-end with the task-orchestrator workflow
argument-hint: "[issue # | task description]"
---

Start the **task-orchestrator** workflow for the task described in `$ARGUMENTS`
(a GitHub issue number/URL, a Markdown file, or a plain description). If
`$ARGUMENTS` is empty, use the task the user described in the conversation.

Follow the skill from **Phase 0** (triage): decide fast path vs. full workflow,
create the feature branch and log, analyze the repo with subagents, clarify and
get the plan approved, implement, update docs/ADR, verify independently, make
atomic commits, and open the PR — pausing for explicit approval before any push,
PR, or merge.

This is the entry point for a new task. To resume an already-approved plan in a
fresh session instead, use `/task-execute <slug>`.
