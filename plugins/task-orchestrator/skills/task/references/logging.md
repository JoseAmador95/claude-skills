# Task logging

The log is the source of truth for progress, persistent outside your context
window. If the session drags on or you lose the thread, you reconstruct it by
reading the log.

## Location

`~/.claude/task-logs/<repo>/<slug>-<YYYY-MM-DD>.md`, where `<repo>` is the
repository name and `<slug>` is a short name derived from the task (e.g.
`google-oauth`). The logs live **outside the repository**, under your home dir and
namespaced per repo, so they never pollute the project tree and there's no
`.gitignore` step. Resolve the directory once and reuse it for the log and the
plan:

```bash
TASK_LOG_DIR="$HOME/.claude/task-logs/$(basename "$(git rev-parse --show-toplevel)")"
mkdir -p "$TASK_LOG_DIR"
```

Alternative: if you prefer not to leave files behind at all, you can use Claude
Code's memory tool for the same content. The file under `~/.claude/task-logs/` is
the default option because it's inspectable and portable across sessions.

## When to write (per event, not just per phase)

The log is written **throughout all phases, every time something relevant
happens**, not only when closing each phase. Trigger a new entry whenever any of
these occurs:

- Key information learned (from analysis, from implementation, from CI).
- An **error or bug**, whether it directly affects the task or you found it by
  chance while doing something else. Note it down even if you're not going to fix
  it now: an unrecorded side bug is a lost bug.
- A **decision** (yours or the user's) and its why.
- A **deviation** from the approved plan.
- The closing of each phase (summary entry).

The mental rule: if a week from now you'd want to know "why was this done this
way?" or "where did this bug come from?", it should be in the log at the moment it
happened.

## Structure of each entry

**Phase-closing entries** use the full `assets/task-log.template.md` fields:

- **Timestamp**: date and time.
- **Phase**: number and name of the workflow phase.
- **What the agent learned**: relevant findings (from analysis, from
  implementation, from CI…).
- **What should be done**: derived actions, pending items.
- **How it affects the repo**: impacted files/modules, side effects.
- **Deviations from the initial plan**: any change from what was planned and why
  (this is one of the most valuable things in the log).
- **Conclusion**: state at the close of the phase.

**Incidental events** (a bug spotted in passing, a one-off decision) don't need the
full template — a single line is enough: `timestamp · what · why`. Keep them cheap
so there's never an excuse not to record them.

## Mirroring to GitHub (opt-in)

If the task comes from an issue, you can mirror each entry as a comment on the
issue to leave a public trace of progress. **It's opt-in**: ask the user first,
because it writes to the issue and that's a visible external effect.

If they accept:

```bash
gh issue comment <n> --body-file <path-to-the-entry.md>
```

Keep the local file as the complete record and publish each new entry as a
comment. Don't publish secrets or sensitive internal paths in public comments.
