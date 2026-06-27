---
name: task-orchestrator
description: >-
  Orchestrate a development task end to end with a disciplined workflow: get the
  description (md file, chat, or GitHub issue), keep a log, analyze the repo with
  subagents, clarify open questions, implement with subagents, update docs and
  ADRs, verify independently, make atomic commits, open a PR, and watch CI. Use
  this skill whenever the user asks to work a task, resolve an issue, implement a
  feature following the workflow, mentions a GitHub issue number to fix, or asks
  for a full analysis → verification → PR process — even if they don't say
  "orchestrate".
---

# Task Orchestrator

Your role is to be the **orchestrator**. You don't implement directly: you
coordinate subagents, keep the log, and you are the only one who runs actions
with external effects (push, PR, merge) — always with the user's approval.

The reasoning behind this whole flow: the context window degrades as it fills up
(*context rot*), and an agent that both implements AND judges itself rationalizes
its own mistakes. That's why we isolate heavy reads in subagents, keep a
persistent log outside the context, and verify with a fresh agent that doesn't
share your bias.

## Principles that govern the whole flow

- **You don't write production code.** You delegate to subagents with bounded
  context. Your context should hold summaries, not dumps of 20 files.
- **The log is the source of truth**, not your conversational memory. And it's
  written **by event**, not just at phase boundaries: every time something
  relevant happens (key information, an error, a bug — whether or not it affects
  the task, whether you went looking for it or stumbled onto it) you record it on
  the spot. If you lose the thread, you recover it from the log.
- **You never work on the default branch.** Every commit goes to a feature branch.
- **Human approval gates** before any irreversible or external action: the
  implementation plan, push to remote, opening a PR, merging. Never do them
  without an explicit "yes".
- **The verifier must not know your narrative.** You give it only the spec and the
  diff.
- **Loops, not a straight line.** If the verifier fails, you go back and
  re-implement. If CI fails, you propose a plan and wait for approval.

## Subagent configuration (summary)

Full detail and the agent files are in `references/subagents.md`. Summary:

| Subagent | Phase | Model | Effort | Tools | Writes code |
|---|---|---|---|---|---|
| `task-analyzer` | 3 | sonnet | medium | Read, Grep, Glob, Bash (read-only) + navigation MCP | NO |
| `task-implementer` | 5 | sonnet (opus if complex) | medium (↑ high if complex) | Read, Write, Edit, Bash, Grep, Glob | YES |
| `task-verifier` | 7a | opus | high | Read, Grep, Glob, Bash (tests/lint/build) | NO |
| `task-dreamer` | 7b (or 4) | opus | high | Read, Grep, Glob, Bash (read-only) | NO |

The verifier and the dreamer are **opposite, separate agents**: the verifier
judges correctness blind (no context, no improvement suggestions); the dreamer
brings ideas with all the context it can get and never blocks.

The `effort` field (low/medium/high/max/inherit) is relatively new in subagent
frontmatter; if your version doesn't honor it, control the effort by embedding
thinking keywords in the invocation prompt. Detail in `references/subagents.md`.

Install all four in `.claude/agents/` (copy them from this skill's `agents/`). If
you'd rather not install them, you can launch them with the `Task` tool and an
equivalent inline prompt; the prompts are in `agents/`.

---

## PHASE 0 — Triage (full flow or fast path?)

Don't bring a cannon to swat a fly. Before anything, classify the task:

- **Trivial → fast path**: a one- or few-line change, a typo, a config tweak, an
  obvious change with no design decision, no ambiguity, no new dependencies, low
  risk. Here you skip the pipeline: create the feature branch (phase 2), make the
  change, run the tests, commit, and offer a PR. No subagents, no formal analysis,
  no verifier/dreamer. Record a short entry in the log.
- **Substantial → full flow**: everything else. Continue with phases 1→12.

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

**Create the log** `.task-logs/<slug>-<YYYY-MM-DD>.md` from
`assets/task-log.template.md`. First, make sure `.task-logs/` is in `.gitignore`
(add it if missing) — the log is noise for the repo but gold for you.

Each log entry carries: timestamp, phase, **what the agent learned**, **what needs
to be done**, **repo impact**, **deviations from the initial plan**, and a
**conclusion**. Write entries **by event, throughout all phases**: not just when
closing each phase, but every time something relevant comes up — key information,
an error, a bug (whether it affects the task or you found it by chance), a
decision, a deviation. The log must be able to reconstruct the task's history
without your conversational context.

Format detail and GitHub mirroring in `references/logging.md`. Mirroring (each
entry as an issue comment via `gh issue comment`) is **opt-in**: ask the user if
they want it, because it writes to the public issue.

## PHASE 3 — Analyze the current state (subagents)

Launch one or more `task-analyzer` agents **in parallel**, one per relevant
subsystem (e.g. one for the auth backend, one for the frontend, one for the data
layer). Each gets a bounded scope and returns a structured report, not the raw
files. This is what keeps your context clean.

Why a subagent and why `sonnet`: analysis is read + comprehension + synthesis.
Sonnet is the cost/quality sweet spot; Opus is overkill here and Haiku doesn't
synthesize relationships across many files well. The analyzer is **read-only** (no
Write/Edit) so it can't mutate the repo by accident.

**Code navigation via MCP**: if a navigation/LSP MCP server is available (symbols,
go-to-definition, find-references — e.g. Serena or an LSP MCP), the analyzer
should **prefer it over `grep`/`glob`**: it understands code structure
(definitions, references, type hierarchy) instead of text matching, so it's more
precise and cheaper. For the subagent to use it, its tools (`mcp__<server>__*`)
must be in the agent's allowlist or declared via `mcpServers`; otherwise it won't
see them. If there's no navigation MCP, fall back to `grep`/`glob`. See
`references/subagents.md`.

Ask each analyzer to return: files/modules touched by the task, data flow,
existing patterns and conventions to imitate, current tests and gaps, risks, and a
**list of proposed sub-tasks** marking which ones are "complex" (algorithms,
concurrency, security) — that mark decides the implementer's model in phase 5.
Record the consolidated summary in the log, and any bug or risk that surfaces
along the way as its own log entry.

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

When they approve it, **write the plan to `.task-logs/<slug>.plan.md`**. It's a
durable artifact: from here on you and the subagents reference it **by path**,
instead of reloading the whole planning conversation. That keeps the orchestrator
thin (see the context note in phase 5).

Record the approved plan in the log along with every decision the user made — this
feeds the ADR (phase 6).

## PHASE 5 — Implementation (one or more implementers)

Turn the analysis into an ordered list of atomic sub-tasks (each one = a commit in
phase 8). The orchestrator assigns **one `task-implementer` per sub-task** and can
**launch several**, in parallel or in sequence depending on the dependencies the
analyzer detected:

- **In parallel** when the sub-tasks are independent (disjoint files, no ordering
  between them). This is the fast mode. So two implementers don't step on each
  other, isolate them: the safest is a `git worktree`/branch per implementer; if
  you keep them in the same tree, make sure their file sets don't overlap.
- **In sequence** when there are dependencies (B uses what A creates) or when they
  share files. Here sequential is faster in practice because you avoid merge
  conflicts.

The natural way to work is in **waves**: a group of independent sub-tasks in
parallel, then the next wave that depended on them.

Implementer config (detail in `references/subagents.md`):
- **Model/effort**: `sonnet`/`medium` by default; **`opus`/`high`** for the
  sub-tasks the analyzer marked as complex. Per sub-task, not global.
- **Bounded context**: give each implementer only the spec for ITS sub-task + the
  relevant portion of the analyzer's report + the conventions. Tell it explicitly
  to **stay within its assigned files**, so the parallel siblings don't collide.
- **Tools**: Read, Write, Edit, Bash, Grep, Glob. It does **not** open PRs or push:
  those external effects are yours and go through a user gate.
- Each implementer runs the tests/lint for its slice and reports.

**Orchestrator context hygiene**: you are a control plane, not a worker. Don't
re-read whole files or pile the code into your context: reference the plan
(`.task-logs/<slug>.plan.md`) and the log by path, and let the heavy work live in
the subagents (fresh context) and on disk. This is the practical equivalent of
"clear and reload": your window stays light throughout the run. If you want a real
hard reset, use the optional handoff to a new session (see
`commands/task-execute.md`).

**Commits (preview of phase 8)**: keep one atomic commit per sub-task. If you
parallelize in worktrees, each implementer commits on its own branch and you
integrate those branches into the feature branch. If you work in a single tree,
you commit each sub-task's files separately.

Record in the log what was implemented, how it affects the repo, and any deviation
from the plan (entry by event; e.g. "the endpoint required an index that wasn't
planned").

## PHASE 6 — Update documentation and ADR

Two things, as applicable (detail and templates in `references/adr-and-docs.md`):

1. **Docs**: update the relevant `.md` files in `docs/` (module READMEs, guides,
   API references). Reflect behavior changes and new limitations.
2. **ADR** (Architecture Decision Record): if the task made an architectural
   decision, add `docs/adr/NNNN-<title>.md` from `assets/adr.template.md`. Include:
   context, decision, consequences, **workflow changes**, **limitations**, and
   **decisions the user made** (from phase 4).

If the task changed neither architecture nor observable behavior, say no ADR is
needed and skip it — an empty ADR is debt, not documentation.

**Diagrams**: text is the primary medium. Use Mermaid diagrams only when they
genuinely help (a flow, a state machine, an architecture that would be confusing
in prose), embedded in ```mermaid blocks. Don't replace a clear explanation with a
diagram, and don't add decorative diagrams.

## PHASE 7 — Verification and ideation (two independent, separate subagents)

After implementing, two fresh agents look at the result with opposite purposes.
They are **different agents and they don't mix**: one judges, the other imagines.

### 7a — Verification (strict gate): `task-verifier`

Launch a fresh `task-verifier` and give it **only two things**:

1. The task's original acceptance criteria (phase 1).
2. The real diff (`git diff <base>...HEAD`) and access to the code and tests.

**Don't give it** your narrative, the log, or the implementers' reasoning. A
verifier that shares your context rationalizes your same mistakes. Its only job is
to rule on whether the task meets its criteria: it's **not pedantic and doesn't
propose improvements** — only correctness against the spec. Model `opus`, effort
`high`; read-only tools + test/lint/build execution, **no Write/Edit**.

**Run CI locally if possible**: ask the verifier to detect the CI config
(`.github/workflows/*.yml`, `.gitlab-ci.yml`, `Makefile`…), extract the commands,
and run them locally, skipping only the steps that depend on remote infra.
Catching the failure here is ~10x faster than waiting for the remote runner
(phases 10-11) and reduces the CI-red cycle to nearly zero.

Output: **PASS / PARTIAL / FAIL** + per-criterion evidence + **gaps**. If it's
PARTIAL or FAIL → go back to **PHASE 5** with the gaps as new sub-tasks.
**Cap: 3 rounds.** If after 3 verify→fix iterations the verifier still doesn't
give PASS, stop and escalate to the user with the remaining gaps instead of
spinning: there's probably something about the approach or the criteria that needs
rethinking with them. Don't move on to commits without PASS. Record every verdict.

### 7b — Ideation (non-blocking): `task-dreamer`

Launch a `task-dreamer` to bring **ideas and improvements**. It's the
verifier's counterpoint: where that one is skeptical and blind, this one is
expansive and well-informed — give it the task objective, the analyzer's report,
and the diff, because the more context, the better the ideas. Model `opus`, effort
`high`; read-only.

Its ideas **never block** progress. Output: a list of ideas with value,
impact/effort, and when (`now` / `follow-up` / `someday`). Take them to the user to
decide: apply now (they become sub-tasks → phase 5 → re-verify), defer to a new
issue (with their approval), or discard. Record the ideas and the decision in the
log.

> The dreamer can also be invoked in **phase 4** (planning), before implementing:
> there its ideas about the approach are the cheapest to incorporate. Since it
> doesn't block, its default home is here (7b), but it's flexible.

## PHASE 8 — Atomic commits per sub-task

One commit per sub-task, with a descriptive message in conventional format:

**Example:**
Sub-task: "Add email validation in signup"
Commit: `feat(auth): validate email format in signup (#42)`

Commit body: the why, not just the what. Reference the issue (`#n`). Do a
selective `git add` of that sub-task's files — not a `git add -A` that mixes
sub-tasks. If a sub-task touched tests + impl + docs, they go together in its
commit.

Before committing, **confirm you're on the feature branch** (the one from phase 2),
not the default one: `git rev-parse --abbrev-ref HEAD`. If for whatever reason
you're on `main`/`master`, stop and move to the feature branch before continuing.

Committing locally is fine without asking. **Pushing to a remote requires the
user's approval** (you combine it with phase 9).

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

## PHASE 10 — Wait for the CI result

```bash
gh pr checks <n> --watch     # blocks until the checks finish
```

If `--watch` doesn't apply in their setup, poll with `gh pr checks <n>` every so
often. Keep the user informed of the status.

## PHASE 11 — If CI fails: propose a plan (don't auto-fix)

Retrieve the failure logs:

```bash
gh run view <run-id> --log-failed
```

Diagnose the root cause and **propose a plan** to the user. Don't apply the fix
automatically: show the plan, wait for approval, and only then re-implement (phase
5 scoped to the fix) → commit → push → back to phase 10. Record in the log what
failed and why (this is valuable deviation information).

**Cap: 3 attempts.** If CI is still red after 3 fix cycles, stop and escalate to
the user instead of insisting — it might be flaky, an environment problem, or
something that needs a human decision. Always distinguish a real failure from a
flaky one before "fixing".

## PHASE 12 — If CI passes: wait for the user to merge

Report that it's green. **Don't merge automatically.** The merge is the user's
decision: wait for their explicit instruction. When they ask, you can do the merge
(`gh pr merge <n> --squash` or whatever option they prefer) and close the log with
the final conclusion.

---

## References

Read these files when you reach the corresponding phase:

- `references/subagents.md` — detailed configs, each subagent's prompt, and the
  worktree pattern for parallelism.
- `references/logging.md` — log format and opt-in mirroring to GitHub.
- `references/adr-and-docs.md` — ADR format and a guide to updating docs.

Templates in `assets/`: `task-log.template.md`, `adr.template.md`,
`pr-body.template.md`.

**Deterministic gates (hooks)**: if installed (see `INSTALL.md` and `hooks/`),
Claude Code enforces on its own — not depending on you — the block on commits/push
on the default branch, the tests-before-push gate, and auto-formatting. If a push
comes back blocked, don't force it: it means the tests are red or you're on the
default branch. Treat them as allies, don't route around them.
