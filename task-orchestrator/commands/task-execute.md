---
description: Execute an already-approved task plan in a fresh session (hard context reset)
argument-hint: "<plan slug, e.g. google-oauth>"
---

You are about to execute an already-approved implementation plan in a clean
session. This is the "hard reset" of context: you don't carry over the planning
conversation, only the plan on disk.

1. Read the plan in `.task-logs/$1.plan.md` and the log in `.task-logs/$1-*.md`.
2. Resume the `task-orchestrator` workflow from **Phase 5** (implementation): the
   analysis, the questions, and the plan are already done and approved — don't
   repeat them.
3. Keep the same rules: feature branch, one implementer per sub-task
   (parallel/sequential per the plan), strict verifier (max 3 rounds), dreamer,
   docs/ADR, atomic commits, and user gates for push/PR/merge.
4. Keep logging by event.

If the plan or the log don't exist, say so and don't make things up: the task
probably never got its plan approved, and you should start from Phase 0.
