# Task logging

The log is a **decision & surprise journal**, not minutes of every phase. It holds
what you could NOT reconstruct later from `git log`, the diff, and the plan file —
so if the session drags on, gets compacted, or is handed off, you recover the *why*
and the *state*, not the *what* (git already has the *what*).

## Location

`~/.claude/task-logs/<repo>/<slug>-<YYYY-MM-DD>.md`, where `<repo>` is the
repository name and `<slug>` is a short name derived from the task (e.g.
`google-oauth`). The logs live **outside the repository**, under your home dir and
namespaced per repo, so they never pollute the project tree and there's no
`.gitignore` step. `session-start.sh` pre-creates the directory; resolve it once and
reuse it for the log and the plan:

```bash
TASK_LOG_DIR="$HOME/.claude/task-logs/$(basename "$(git rev-parse --show-toplevel)")"
```

Within a session the file survives compaction (the main thing it defends against);
in a remote/ephemeral session it may not outlive the container between sessions, and
in the local CLI it's fully durable. If you'd rather not leave files behind, Claude
Code's memory tool holds the same content.

## When to write (only the irreplaceable)

Append an entry the moment one of these happens — and **only** these:

- A **decision** (yours or the user's) and its *why*. Especially the user's phase-4
  answers: they feed the ADR and vanish if not captured.
- A **deviation** from the approved plan, and why.
- A **finding**: a bug or risk you hit — whether or not it affects the task, whether
  you went looking for it or stumbled on it. An unrecorded side bug is a lost bug.
- A **resume pointer** at each phase boundary: one line, current state → what's
  next, so a post-compaction restart knows where it is.

Do **not** log a restatement of what changed or a full per-phase summary: if it's
reconstructable from git + the plan file, it doesn't belong here. The rule: if a
week from now you'd want to know *"why was this done this way?"*, *"where did this
bug come from?"*, or *"where was I?"*, it goes in — everything else is noise.

## Entry format

One line is the default:

```
- [<YYYY-MM-DD HH:MM>] <decision|deviation|finding|resume> · <what> · <why>
```

Expand to a few lines only when a decision needs its context to make sense later
(the alternatives weighed, the constraint that forced it). The header block of
`assets/task-log.template.md` opens the file; after that, it's one-liners.

## Mirroring to GitHub (opt-in)

If the task comes from an issue, you can mirror entries as comments to leave a
public trace. **It's opt-in**: ask first, because it writes to the issue (a visible
external effect).

```bash
gh issue comment <n> --body-file <path-to-the-entry.md>
```

Keep the local file as the complete record. Don't publish secrets or sensitive
internal paths in public comments.
