#!/usr/bin/env bash
# Smoke test for task-orchestrator/install.sh.
#
# Installs the bundle into a throwaway --project target, asserts every artifact
# landed where INSTALL.md promises, then installs a SECOND time and asserts the
# merged settings.json is byte-identical to the first run (idempotency: no
# duplicated hooks). Exits 0 on success, 1 on the first failed assertion.
#
# Runnable locally and from CI; kept shellcheck-clean so the CI lint covers it.
set -euo pipefail

# --- Locate the repo and the installer ------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P)
INSTALLER="$REPO_ROOT/task-orchestrator/install.sh"

# --- Throwaway target, cleaned up on exit ---------------------------------
WORK=$(mktemp -d)
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT

CLAUDE="$WORK/.claude"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "expected file missing: $1"
}

echo "test-install :: target $CLAUDE"

# --- Run 1 ----------------------------------------------------------------
echo "1. first install"
bash "$INSTALLER" --project "$WORK" >/dev/null

assert_file "$CLAUDE/skills/task-orchestrator/SKILL.md"
assert_file "$CLAUDE/commands/task.md"
assert_file "$CLAUDE/commands/task-execute.md"
assert_file "$CLAUDE/settings.json"

# Exactly the four expected agents must be installed.
agent_count=$(find "$CLAUDE/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
[ "$agent_count" -eq 4 ] || fail "expected 4 agents, found $agent_count"
for a in task-analyzer task-implementer task-verifier task-dreamer; do
  assert_file "$CLAUDE/agents/$a.md"
done

# The hooks must have been merged into settings.json.
if command -v jq >/dev/null 2>&1; then
  pre_hooks=$(jq '[.hooks.PreToolUse[]?.hooks[]?] | length' "$CLAUDE/settings.json")
  [ "$pre_hooks" -ge 2 ] || fail "expected >=2 PreToolUse hooks, found $pre_hooks"
else
  grep -q '"hooks"' "$CLAUDE/settings.json" || fail "settings.json has no hooks block"
fi

# Snapshot the merged settings to compare after the second run.
cp -- "$CLAUDE/settings.json" "$WORK/settings.after-run1.json"

# --- Run 2 (idempotency) --------------------------------------------------
echo "2. second install (idempotency)"
bash "$INSTALLER" --project "$WORK" >/dev/null

if ! diff -- "$WORK/settings.after-run1.json" "$CLAUDE/settings.json" >/dev/null; then
  echo "--- settings.json changed between runs (not idempotent):" >&2
  diff -- "$WORK/settings.after-run1.json" "$CLAUDE/settings.json" >&2 || true
  fail "install.sh is not idempotent: settings.json drifted on re-run"
fi

if command -v jq >/dev/null 2>&1; then
  pre_hooks2=$(jq '[.hooks.PreToolUse[]?.hooks[]?] | length' "$CLAUDE/settings.json")
  [ "$pre_hooks2" -eq "$pre_hooks" ] \
    || fail "hook count drifted on re-run: $pre_hooks -> $pre_hooks2 (duplicates?)"
fi

echo "OK — install.sh smoke test passed (artifacts present, re-run idempotent)."
