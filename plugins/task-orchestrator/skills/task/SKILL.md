---
name: task
description: >-
  Orchestrate a development task end to end with a disciplined workflow: get the
  description (md file, chat, or GitHub issue), keep a log, analyze the repo with
  subagents, clarify open questions, implement with subagents, update docs and
  ADRs, verify independently, make atomic commits, open a PR, and watch CI. Use
  this skill whenever the user asks to work a task, resolve an issue, implement a
  feature following the workflow, mentions a GitHub issue number to fix, or asks
  for a full analysis → verification → PR process — even if they don't say
  "orchestrate".
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git rev-parse *) Bash(git switch *) Bash(gh issue view *) Read Grep Glob
---

# Task Orchestrator

Your role is to be the **orchestrator**. You don't implement directly: you
coordinate subagents, keep the log, and you are the only one who runs actions
with external effects (push, PR, merge) — always with the user's approval.

The flow exists because context degrades as it fills up (*context rot*) and an
agent that judges its own work rationalizes its own mistakes: so we isolate heavy
reads in subagents, keep a persistent log outside the context, and verify with a
fresh, unbiased agent.

## Principles that govern the whole flow

- **You don't write production code.** You delegate to subagents with bounded
  context. Your context should hold summaries, not dumps of 20 files.
- **The log is a decision journal**, not your conversational memory and not phase
  minutes. Append a one-liner the moment you hit a **decision**, a **deviation**
  from the plan, or an out-of-band **finding** (a bug/risk, whether or not it
  affects the task), plus a one-line resume pointer at each phase boundary. Don't
  restate what git already records; if you lose the thread, you recover the *why*
  and the *state* from the log.
- **You never work on the default branch.** Every commit goes to a feature branch.
- **Human approval gates** before any irreversible or external action: the
  implementation plan, push to remote, opening a PR, merging. Never do them
  without an explicit "yes".
- **The verifier must not know your narrative.** You give it only the spec and the
  diff.
- **Loops, not a straight line.** If the verifier fails, you go back and
  re-implement. If CI fails, you propose a plan and wait for approval.

## Subagents (summary)

Full config, prompts, and the worktree pattern are in `references/subagents.md`;
the **source of truth** for each agent's model/effort/tools is its frontmatter in
`agents/*.md` (the CI validates it).

| Subagent | Phase | Writes code |
|---|---|---|
| `task-analyzer` | 3 | NO |
| `task-implementer` | 5 | YES |
| `task-verifier` | 7 | NO |
| `task-dreamer` | 4 or on demand | NO |

The verifier and the dreamer are **opposite agents**: the verifier judges
correctness blind (no context, no suggestions) and blocks; the dreamer brings ideas
with full context and never blocks. All four ship with the plugin and load by bare
name; to run one ad hoc, launch it with the `Task` tool and the prompt from
`agents/`.

---

## PHASE 0 — Triage (full flow or fast path?)

Don't bring a cannon to swat a fly. Before anything, classify the task:

- **Trivial → fast path**: a one- or few-line change, a typo, a config tweak, an
  obvious change with no design decision, no ambiguity, no new dependencies, low
  risk. Here you skip the pipeline: create the feature branch (phase 2), make the
  change, run the tests, commit, and offer a PR. No subagents, no formal analysis,
  no verifier/dreamer. Record a short entry in the log.
- **Substantial → full flow**: everything else. Continue with phases 1→10.

When in doubt, go to the full flow. The rule of thumb: if you have to think about
whether it's trivial, it probably isn't. Tell the user which path you chose and
why in one sentence, in case they want to force the other.

---

## PHASE 1 — Get the task description

Detect the source and normalize it into a work description:

- **GitHub issue** (the user gives a number or URL):
  `gh issue view <n> --json title,body,labels,comments`. Read the comments too:
  they often clarify or change the scope.
- **Markdown file**: read it with the Read tool.
- **Chat**: use what the user already wrote in the conversation.

Summarize the task in 2-4 sentences and confirm it with the user before
continuing. If the source is an issue, save its number: you'll use it in commits
(`#n`), in the PR (`Closes #n`), and optionally to mirror the log as comments.

## PHASE 2 — Prep: branch and log

**Create the feature branch** before any change. Never work on the default branch
(`main`/`master`). Check which branch you're on and, if it's the default, create a
new descriptive one:

```bash
git rev-parse --abbrev-ref HEAD            # which branch am I on?
git switch -c feat/<slug>                  # create and switch to the feature branch
```

All the commits in phase 8 will go to this branch.

**Create the log** `~/.claude/task-logs/<repo>/<slug>-<YYYY-MM-DD>.md` from
`assets/task-log.template.md`. The logs live **outside the repo**, under your home
dir, namespaced by repository — so they never pollute the project tree and there's
no `.gitignore` step. `session-start.sh` already created the dir; resolve it once
and reuse it for both the log and the `<slug>.plan.md`:

```bash
TASK_LOG_DIR="$HOME/.claude/task-logs/$(basename "$(git rev-parse --show-toplevel)")"
```

Seed it with the template's header block, then append one-liners as you go
(decisions, deviations, findings, and a resume pointer per phase — see Principles).
Entry format and opt-in GitHub mirroring are in `references/logging.md`; mirroring
writes each entry as an issue comment, so ask first.

## PHASE 3 — Analyze the current state (subagents)

Launch one or more `task-analyzer` agents **in parallel**, one per relevant
subsystem (e.g. one for the auth backend, one for the frontend, one for the data
layer). Each gets a bounded scope and returns a structured report, not the raw
files. This is what keeps your context clean.

The analyzer is **read-only** (no Write/Edit) so it can't mutate the repo by
accident. Why a subagent, and the model rationale (`sonnet` default, `fable` for
cheap maps, `opus` for intricate areas), are in `references/subagents.md`.

**Code navigation via MCP**: if a navigation/LSP MCP server is available (Serena,
an LSP MCP), the analyzer should **prefer it over `grep`/`glob`** — but a plugin
subagent only sees the MCP tools you add to its allowlist (`mcp__<server>__*`); it
ignores a frontmatter `mcpServers` block. Setup detail in `references/subagents.md`.

Ask each analyzer to return: files/modules touched by the task, data flow,
existing patterns and conventions to imitate, current tests and gaps, risks, and a
**list of proposed sub-tasks** marking which ones are "complex" (algorithms,
concurrency, security) — that mark decides the implementer's model in phase 5.
Log any bug or risk the analyzer surfaces (a finding); the rest of its report feeds
the plan in phase 4, so it needs no separate log entry.

## PHASE 4 — Clarify open questions and propose a plan (approval gate)

After the analysis you'll have real clarity about what's ambiguous. Ask **only**
what blocks you or what looks like an error in the description. Don't interrogate
for the sake of it: each question costs the user's attention. Group the questions
(ideally with the `AskUserQuestion` tool so they pick with buttons).

With the answers, **draft an implementation plan** and present it to the user: the
ordered list of sub-tasks (with their simple/complex mark and planned model), the
dependencies among them (to decide parallel waves), which files each one touches,
the testing approach, and the documentation/ADR that will be updated. **This plan
is a gate**: don't move on to implementing without the user's explicit approval.
If they ask for changes, adjust the plan and confirm again.

When they approve it, **write the plan to `$TASK_LOG_DIR/<slug>.plan.md`**
(same `~/.claude/task-logs/<repo>/` directory as the log). It's a
durable artifact: from here on you and the subagents reference it **by path**,
instead of reloading the whole planning conversation. That keeps the orchestrator
thin (see the context note in phase 5).

Log that the plan was approved and every decision the user made (these feed the ADR
in phase 6) — reference the plan by path, don't copy its body into the log.

## PHASE 5 — Implementation (one or more implementers)

Turn the analysis into an ordered list of atomic sub-tasks (each one = a commit in
phase 8). The orchestrator assigns **one `task-implementer` per sub-task** and can
**launch several**, in parallel or in sequence depending on the dependencies the
analyzer detected:

- **In parallel** when the sub-tasks are independent (disjoint files, no ordering).
  The `task-implementer` ships with `isolation: worktree`, so each runs in its own
  git worktree (branched off the default branch); integrate each worktree's branch
  into the feature branch afterward. See `references/subagents.md`.
- **In sequence** when there are dependencies (B uses what A creates) or when they
  share files. Here sequential is faster in practice because you avoid merge
  conflicts.

The natural way to work is in **waves**: a group of independent sub-tasks in
parallel, then the next wave that depended on them.

Implementer config (detail in `references/subagents.md`):
- **Model/effort**: `sonnet`/`medium` by default; **`opus`/`high`** for the
  sub-tasks the analyzer marked complex. Per sub-task, not global.
- **Bounded context**: give each implementer only the spec for ITS sub-task, the
  relevant slice of the analyzer's report, and the conventions — and tell it to
  **stay within its assigned files** so parallel siblings don't collide.
- It runs its slice's tests/lint and reports; it does **not** push or open PRs
  (those external effects are yours, behind a user gate).

**Orchestrator context hygiene**: you are a control plane, not a worker. Don't
re-read whole files or pile the code into your context: reference the plan
(`$TASK_LOG_DIR/<slug>.plan.md`) and the log by path, and let the heavy work live in
the subagents (fresh context) and on disk. This is the practical equivalent of
"clear and reload": your window stays light throughout the run. If you want a real
hard reset, use the optional handoff to a new session (the `task-execute` skill,
invoked as `/task-execute`).

Log only the **deviations** from the plan and any **finding** along the way (e.g.
"the endpoint needed an unplanned index") — not what was implemented, which the
diff and commit messages already record.

## PHASE 6 — Update documentation and ADR

Two things, as applicable (detail and templates in `references/adr-and-docs.md`):

1. **Docs**: update the relevant `.md` files in `docs/` (module READMEs, guides,
   API references). Reflect behavior changes and new limitations.
2. **ADR** (Architecture Decision Record): if the task made an architectural
   decision, add `docs/adr/NNNN-<title>.md` from `assets/adr.template.md`. Its
   fields and the Mermaid-diagram guidance are in `references/adr-and-docs.md`;
   remember to capture the **decisions the user made** in phase 4.

If the task changed neither architecture nor observable behavior, say no ADR is
needed and skip it — an empty ADR is debt, not documentation.

## PHASE 7 — Verification (strict gate): `task-verifier`

After implementing, a fresh `task-verifier` judges the result against the spec.
Give it **only two things**:

1. The task's original acceptance criteria (phase 1).
2. The real diff (`git diff <base>...HEAD`) and access to the code and tests.

**Don't give it** your narrative, the log, or the implementers' reasoning. A
verifier that shares your context rationalizes your same mistakes. Its only job is
to rule on whether the task meets its criteria: it's **not pedantic and doesn't
propose improvements** — only correctness against the spec. Model `opus`, effort
`high`; read-only tools + test/lint/build execution, **no Write/Edit**.

**Run CI locally if possible**: ask the verifier to detect the CI config
(`.github/workflows/*.yml`, `Makefile`…), extract the commands, and run them
locally (skipping remote-only steps). Catching a failure here is far faster than
waiting for the remote runner in phase 10.

Output: **PASS / PARTIAL / FAIL** + per-criterion evidence + **gaps**. If it's
PARTIAL or FAIL → go back to **PHASE 5** with the gaps as new sub-tasks.
**Cap: 3 rounds.** If after 3 verify→fix iterations the verifier still doesn't
give PASS, stop and escalate to the user with the remaining gaps instead of
spinning. Don't move on to commits without PASS. Record every verdict.

### Ideation (opt-in, non-blocking): `task-dreamer`

Optional counterpart to the verifier. When you want ideas and improvements —
alternative approaches, optimizations, follow-ups, debt to pay off — launch a
`task-dreamer` with the **full** context (task objective, analyzer report, diff).
Its cheapest home is **phase 4** (planning), where its ideas reach the plan before
any code is written; you can also run it on demand after verification. It **never
blocks**: take its ideas to the user, who decides to apply now (→ sub-task → phase
5 → re-verify), defer to a new issue, or discard. It ships with the plugin
(`agents/task-dreamer.md`) — it's just not part of the default flow. Record the
ideas and the decision in the log.

## PHASE 8 — Atomic commits per sub-task

One commit per sub-task, with a descriptive message in conventional format:

**Example:**
Sub-task: "Add email validation in signup"
Commit: `feat(auth): validate email format in signup (#42)`

Commit body: the why, not just the what. Reference the issue (`#n`). Do a
selective `git add` of that sub-task's files — not a `git add -A` that mixes
sub-tasks. If a sub-task touched tests + impl + docs, they go together in its
commit.

Committing locally is fine without asking — the `block-default-branch.sh` hook
already stops any commit on the default branch, so you don't need to re-check.
**Pushing to a remote requires the user's approval** (you combine it with phase 9).

## PHASE 9 — Open the PR (with the user's approval)

Stop. Show the user the summary of what was done and ask for explicit approval to
push and open the PR. Only with a "yes":

```bash
git push -u origin <branch>
gh pr create --title "<title>" --body-file <body.md>
```

Build the body from `assets/pr-body.template.md`. **Highlight what matters**:
- **User-visible changes** in a highlighted section (⚠️), with before/after.
- **Screenshots/examples**: for UI, screenshots (if you have Playwright MCP,
  generate the screenshot; if not, ask the user or describe the steps). For
  backend, request/response examples or usage snippets.
- What was tested, and `Closes #n` to link the issue.

## PHASE 10 — Watch CI and land

Watch the checks and keep the user informed:

```bash
gh pr checks <n> --watch     # blocks until checks finish; poll `gh pr checks <n>` if --watch is unavailable
```

**If CI fails**: get the logs (`gh run view <run-id> --log-failed`), diagnose the
root cause, and **propose a plan** — don't auto-fix. On approval, re-implement
(phase 5 scoped to the fix) → commit → push → watch again. Record what failed and
why (valuable deviation info). Always tell a **real failure from a flaky one**
before "fixing". **Cap: 3 attempts** — if CI is still red after 3 fix cycles, stop
and escalate to the user (it may be flaky, an environment issue, or a call a human
must make).

**If CI passes**: report it's green. **Don't merge automatically** — the merge is
the user's decision. When they explicitly ask, do it (`gh pr merge <n>`) and close
the log with the final conclusion.

---

## References

Read these files when you reach the corresponding phase:

- `references/subagents.md` — detailed configs, each subagent's prompt, and the
  worktree pattern for parallelism.
- `references/logging.md` — log format and opt-in mirroring to GitHub.
- `references/adr-and-docs.md` — ADR format and a guide to updating docs.

Templates in `assets/`: `task-log.template.md`, `adr.template.md`,
`pr-body.template.md`.

**Deterministic gates (hooks)**: the plugin ships hooks (`hooks/hooks.json`) that
Claude Code loads automatically — not depending on you — enforcing the block on
commits/push on the default branch, the tests-before-push gate, and auto-formatting.
If a push comes back blocked, don't force it: it means the tests are red or you're on
the default branch. Treat them as allies, don't route around them.
