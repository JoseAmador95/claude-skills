# Ideas backlog

Proposals for new plugins and bigger improvements, **not built yet**. Ordered by
synergy with the existing `task-orchestrator` plugin. This is a backlog, not a
commitment — pick from it when there's appetite.

## Proposed new plugins

1. **`spec-writer`** — turns a vague request or a GitHub issue into a crisp spec
   with acceptance criteria (Given/When/Then). It produces exactly the input that
   `task-orchestrator` **Phase 1** expects, so the two chain naturally. Highest
   synergy: a good spec is what makes the verifier's blind judgment meaningful.

2. **`pr-review-responder`** — reads PR review comments
   (`gh pr view --comments`), triages them, implements the fixes on the branch,
   and replies to / resolves the threads. Complements the orchestrator's phases
   10–12 (the part that today ends at "CI green, wait for merge").

3. **`release-cutter`** — version bump, changelog generated from conventional
   commits, tag, and a drafted GitHub release. Picks up where a merged PR leaves
   off.

4. **`adr` (standalone)** — extract the ADR machinery from the orchestrator into a
   reusable plugin for ad-hoc architecture decisions outside a full task flow.
   Reuses `assets/adr.template.md` and `references/adr-and-docs.md`.

5. **`test-hardening`** — given a module, find coverage gaps and add tests. Could
   reuse the analyzer (to map the module) and the verifier (to confirm the new
   tests actually fail without the code).

6. **`dependency-upgrader`** — bump dependencies, run the test suite, and summarize
   breaking changes with a migration note. Pairs well with the hooks' "tests
   before push" gate.

Each new plugin is a `plugins/<name>/` folder listed in
`.claude-plugin/marketplace.json` (start from `_template/`).

## Bigger task-orchestrator improvements (deferred)

- **`/task-status` command** — summarize the current
  `~/.claude/task-logs/<repo>/<slug>` log (which phase, open gaps, pending gates) at
  a glance. The `subagent-usage.log` written by the SubagentStop hook feeds into this.
- **Resumability** — detect an interrupted task and resume from the last phase
  recorded in the log, beyond the existing `/task-execute` hard reset.
- **`bats` suite for the hooks** — unit-test `block-default-branch.sh`,
  `require-tests-before-push.sh`, and `auto-format.sh` beyond the `bash -n` and
  shellcheck coverage in CI.

## Delivered

- ~~**Worktree helper**~~ — parallel implementers now run in isolated git worktrees
  via the `task-implementer`'s `isolation: worktree` frontmatter.
- ~~**Per-task accounting**~~ — the `SubagentStop` hook records subagent usage to
  `~/.claude/task-logs/<repo>/subagent-usage.log`.
- ~~**Auto-detect `TASK_TEST_CMD`**~~ — the push hook infers the test command from
  `package.json` / `pyproject.toml` / `Makefile` / `Cargo.toml` / `go.mod`.
