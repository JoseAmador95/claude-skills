# Subagent configuration

This file details the four subagents in the flow. Copy them to `.claude/agents/`
(the canonical version lives in the `agents/` folder of this skill) or launch them
inline with the `Task` tool using these same prompts.

The **source of truth** for each agent's `model`, `effort` and `tools` is its
frontmatter in `agents/*.md` (the CI validates it). The values quoted here and in
the SKILL.md summary table mirror those files; if they ever differ, the agent file
wins.

## Why subagents instead of doing everything in the main session

A subagent runs in its **own context window** and returns only its result to the
main session. This buys you two things:

1. **Context isolation**: the analyzer can read 30 files and hand you back a
   one-page summary. If you did this in your own context, those 30 files would
   stay occupying attention for the rest of the session (context rot).
2. **Independence of judgment**: the verifier doesn't see your reasoning, so it
   doesn't inherit your biases or your mistakes.

## Effort selection per subagent

Beyond the model, you can set the **reasoning effort per agent** with the
`effort` field in the frontmatter: `low | medium | high | xhigh | max | inherit`. This is
what lets the analyzer and the implementer think just enough (medium) while the
verifier thinks deeply (high), without paying extra latency where it isn't needed.

```yaml
---
name: task-verifier
model: opus
effort: high
---
```

Important nuances:
- **Varying effort per sub-task within the same agent** (simple vs. complex) is
  not done well with frontmatter alone, because it's a fixed value in the file.
  Two robust options: (a) keep two variants of the implementer (a standard
  `sonnet`/`medium` one and a `task-implementer-deep` `opus`/`high` one), or
  (b) embed thinking keywords in the invocation prompt —
  "think" < "think hard" < "think harder" < "ultrathink" — which scale the
  reasoning budget of that specific invocation.
- Related to the model: `model: inherit` uses the main session's model;
  `CLAUDE_CODE_SUBAGENT_MODEL` sets a default for all subagents that inherit.

## Code navigation via MCP (prefer over grep)

If there's a navigation or LSP MCP server connected (Serena, an LSP MCP, etc.),
the analyzer should prefer its semantic tools (symbols, go-to-definition,
find-references, type hierarchy) over `grep`/`glob`: it understands the structure
of the code instead of doing text matching, which is more precise and spends less
context.

Installation gotcha: a subagent with `tools` as an allowlist **does not see** the
MCP tools unless you add them explicitly. **Inside a plugin, add them to the
allowlist** — plugin subagents ignore a frontmatter `mcpServers` block for security:

```yaml
# Add the MCP tools to the allowlist (names mcp__<server>__<tool>)
tools: Read, Grep, Glob, Bash, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols
```

Only when you install this agent standalone in `.claude/agents/` (outside the
plugin) can you instead declare the server with an `mcpServers` block. Check with
`/mcp` which servers and tools you have available before assuming the analyzer can
navigate semantically.

---

## 1. task-analyzer (Phase 3)

**Purpose**: map the parts of the repo relevant to the task, without touching
anything.

**Model: `sonnet`. Effort: `medium`.** Analysis is retrieval + comprehension +
synthesis, not deep multi-step reasoning, so the mid-tier model hits the right
cost/quality balance. For cheap, straightforward maps, try **`fable`** (the fast,
low-cost tier); scale up to `opus`/`high` only if the area is genuinely intricate
(dense algorithms, legacy code without tests). The aliases `sonnet`, `opus`,
`haiku`, and `fable` resolve to the latest snapshot of each tier.

**Tools**: `Read, Grep, Glob, Bash` (+ MCP navigation tools if available, see the
previous section). Bash is **read-only**: `git log`, `git blame`, `git diff`,
`rg`, `ls`, `cat`, listing tests. **No Write/Edit** — the structural
guarantee that an explorer doesn't mutate the repo. Prefer semantic MCP
navigation over `grep` when available.

**Parallelism**: launch several at once, one per subsystem, with scopes that
don't overlap. It's the biggest accelerator of the flow: heavy reading in
parallel, isolated contexts.

**What it should return** (ask for it explicitly):
- Files and modules the task will touch.
- Relevant data flow and dependencies.
- Existing patterns/conventions to imitate (with example paths).
- Current tests covering the area and coverage gaps.
- Risks and potential side effects.
- **List of proposed sub-tasks**, marking each one as `simple` or `complex`
  (algorithms / concurrency / security / data migration). This mark decides the
  implementer's model in phase 5.

---

## 2. task-implementer (Phase 5)

**Purpose**: implement ONE atomic sub-task with its tests. The orchestrator
assigns one per sub-task and **can run several at once**: each implementer is an
independent unit of work, so you scale by launching more, not by making one
bigger.

**Model and effort**: three tiers by sub-task complexity — **`fable`** for
boilerplate, **`sonnet`/`medium`** as the default (covers most of the work), and
**`opus`/`high`** for the sub-tasks the analyzer marked as `complex`. Decide
per sub-task, not globally: don't waste Opus on boilerplate nor fall short with
Sonnet on a delicate algorithm. Since the frontmatter is fixed, to vary per
sub-task use a `task-implementer-deep` variant or embed "think harder"/"ultrathink"
in the invocation (see the effort section above).

**Tools**: `Read, Write, Edit, Bash, Grep, Glob`. Do **not** include
push capability or the ability to open PRs: external effects are controlled by the
orchestrator with a user gate.

**Bounded context**: give it only (a) the spec of its sub-task, (b) the portion of
the analyzer's report that concerns it, and (c) the repo conventions (from
CLAUDE.md). Don't pass it the entire conversation. A fresh, focused context
produces better code than a saturated one.

**Test responsibility**: each implementer runs the tests and the linter for its
slice and reports green/red. The **commit is made by the orchestrator** (phase 8),
to control granularity and message. Alternatively, if you parallelize with
worktrees, each implementer commits on its own branch.

### Several implementers in parallel (with git worktrees)

Launch several implementers at once when the sub-tasks are independent (separate
modules, no shared files). The `task-implementer` frontmatter sets
**`isolation: worktree`**, so Claude Code runs each invocation in its own git
worktree — an isolated checkout that shares the same `.git` — automatically. No
manual `git worktree add` needed.

Two things about how it works (Claude Code ≥ 2.1.203):
- Each worktree branches **from the default branch**, not from your current feature
  branch or HEAD, and it does **not** see the orchestrator's uncommitted work — so
  give each implementer everything it needs in its prompt.
- When an implementer finishes, integrate its worktree branch into the feature
  branch (merge/cherry-pick); a worktree with no changes is auto-removed.

The bottleneck is still the merge: with shared files conflicts appear, so 5-10
agents is the practical limit. If the sub-tasks touch the same files, **don't
parallelize** — sequential is faster in practice because you avoid merge hell.

---

## 3. task-verifier (Phase 7a)

**Purpose**: independently rule on whether the task meets its acceptance criteria.
It's the counterweight to the orchestrator's bias. It judges correctness, nothing
more: it isn't pedantic and doesn't propose improvements (that's the dreamer's
job, below).

**Model: `opus`. Effort: `high`** (bump to `xhigh` for the hardest verifications).
Here it pays off: verification is where strong reasoning yields the most, it runs
only once per task, and its verdict decides whether there's rework. The cost is
bounded. Sonnet is acceptable only if the budget is tight. The stance is
**skeptical and blind** on purpose.

**Tools**: `Read, Grep, Glob, Bash` (run tests, lint, build). **No Write/Edit** —
its job is to judge, not to fix. If it could edit, it would silently "fix" the
gaps and you'd lose the signal.

**What it receives (and what it does NOT)**:
- ✅ The original acceptance criteria (phase 1).
- ✅ The real diff: `git diff <base>...HEAD`, plus access to read the code and run tests.
- ❌ NOT your narrative, NOT the log, NOT the implementers' reasoning.

**Prompt with an adversarial stance**: instruct it to assume the task is NOT done
and to prove otherwise or enumerate gaps. Something like: "You are a skeptical,
independent reviewer. Don't trust any claim that this works; verify it against the
criteria and the real code."

**Output**:
- Verdict: `PASS` / `PARTIAL` / `FAIL`.
- For each acceptance criterion: met/not, with evidence (file:line, or test
  output).
- **Gaps**: defects that block the PASS, relative to the criteria (actionable).

`PARTIAL` or `FAIL` → the orchestrator goes back to phase 5 with the gaps as new
sub-tasks. You don't move on to commits/PR without a `PASS`.

---

## 4. task-dreamer (Phase 7b, optionally phase 4)

**Purpose**: contribute ideas and improvements. It's the generative role that was
split off from the verifier. Where the verifier is skeptical, blind and blocking,
the dreamer is expansive, well-informed and **never blocks**.

**Model: `opus`. Effort: `high`.** Good ideas (divergent thinking and then
filtering) are exactly where the strong model pays off. It runs once, bounded cost.

**Tools**: `Read, Grep, Glob, Bash`, read-only (+ MCP navigation if available).
**No Write/Edit**: it proposes, it doesn't implement.

**What it receives** (the opposite of the verifier — the more context, the
better): the task's objective, the analyzer's report, and the diff if it's
already been implemented.

**Output**: a list of ideas, each with value, impact/effort, and when
(`now` / `follow-up` / `someday`), ordered by value. If there's nothing to
improve, it should say so — that's valid.

The orchestrator brings the ideas to the user, who decides on each one: apply it
now (it becomes a sub-task → phase 5 → re-verify), defer it to a new issue, or
discard it. Since it doesn't block, the dreamer can run in parallel with the
verifier, or in phase 4 so that its ideas about the approach make it into the
approved plan.
