#!/usr/bin/env bash
# Installer for the task-orchestrator bundle into a .claude/ target.
# Automates the manual steps documented in INSTALL.md:
#   1. Install the skill into   <target>/skills/task-orchestrator
#   2. Install the agents into  <target>/agents/
#   3. Install the commands into <target>/commands/
#   4. chmod +x the installed hooks
#   5. Merge hooks/settings.snippet.json into <target>/settings.json (with jq),
#      without clobbering the user's existing keys/hooks.
#
# Idempotent: re-running leaves the same final state, with no duplicated hooks.
set -euo pipefail

# --- Resolve this script's path (the bundle source) -----------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)
SNIPPET="$SCRIPT_DIR/hooks/settings.snippet.json"

# --- Flag defaults --------------------------------------------------------
MODE="user"          # user | project
PROJECT_DIR=""       # destination for --project (default: cwd)
USE_LINK=0           # 0 copy, 1 symlink
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Install the task-orchestrator bundle (skill, agents, commands, and hooks) into
a .claude/ target.

Options:
  --user            Install into ~/.claude (default).
  --project [DIR]   Install into DIR/.claude (DIR defaults to the current dir).
  --link            Use symlinks instead of copies for skill/agents/commands,
                    so a 'git pull' of the repo updates the installation.
  --dry-run         Show what it would do without touching anything.
  -h, --help        Show this help.
EOF
}

# --- Flag parsing ---------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      MODE="user"
      shift
      ;;
    --project)
      MODE="project"
      shift
      # Optional DIR: only consume it if it isn't another flag.
      if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
        PROJECT_DIR="$1"
        shift
      fi
      ;;
    --link)
      USE_LINK=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'." >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- Compute the destination ----------------------------------------------
if [ "$MODE" = "project" ]; then
  base_dir="${PROJECT_DIR:-$PWD}"
  TARGET="$base_dir/.claude"
else
  TARGET="$HOME/.claude"
fi

# --- Helpers --------------------------------------------------------------
log() { printf '%s\n' "$*"; }

# Run a command, or print it if we're in dry-run mode.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Install (copy or symlink) a source into a destination, idempotently.
install_path() {
  local src="$1" dest="$2"
  if [ "$USE_LINK" -eq 1 ]; then
    # symlink: remove the previous destination (file, dir, or link) and re-link.
    run rm -rf -- "$dest"
    run ln -s -- "$src" "$dest"
  else
    # copy: for directories, clean first so no orphan leftovers remain.
    if [ -d "$src" ]; then
      run rm -rf -- "$dest"
    fi
    run cp -R -- "$src" "$dest"
  fi
}

log "task-orchestrator :: install"
log "  source: $SCRIPT_DIR"
log "  target: $TARGET"
if [ "$USE_LINK" -eq 1 ]; then
  log "  mode:   symlink"
else
  log "  mode:   copy"
fi
if [ "$DRY_RUN" -eq 1 ]; then
  log "  (dry-run: nothing will be modified)"
fi
log ""

# --- 1. Skill -------------------------------------------------------------
log "1. Installing skill into $TARGET/skills/task-orchestrator"
run mkdir -p -- "$TARGET/skills"
install_path "$SCRIPT_DIR" "$TARGET/skills/task-orchestrator"

# --- 2. Agents ------------------------------------------------------------
log "2. Installing agents into $TARGET/agents/"
run mkdir -p -- "$TARGET/agents"
for agent in "$SCRIPT_DIR"/agents/*.md; do
  [ -e "$agent" ] || continue
  install_path "$agent" "$TARGET/agents/$(basename -- "$agent")"
done

# --- 3. Commands ----------------------------------------------------------
log "3. Installing commands into $TARGET/commands/"
run mkdir -p -- "$TARGET/commands"
for cmd in "$SCRIPT_DIR"/commands/*.md; do
  [ -e "$cmd" ] || continue
  install_path "$cmd" "$TARGET/commands/$(basename -- "$cmd")"
done

# --- 4. chmod +x the installed hooks --------------------------------------
log "4. Ensuring the hooks are executable"
# With symlinks the hooks point at the repo; with copies they live under the
# target. Either way, chmod on the installed path resolves the real file.
for hook in "$TARGET"/skills/task-orchestrator/hooks/*.sh; do
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] chmod +x %s\n' "$hook"
  else
    [ -e "$hook" ] || continue
    # Note: BSD chmod (macOS) doesn't support the '--' separator; the paths are
    # absolute, so omitting it is safe.
    chmod +x "$hook"
  fi
done

# --- 5. settings.json merge -----------------------------------------------
log "5. Merging hooks into $TARGET/settings.json"
SETTINGS="$TARGET/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  log "  WARNING: 'jq' is not available; skipping the settings.json merge."
  log "  Manual step: paste the contents of"
  log "    $SNIPPET"
  log "  into $SETTINGS (merging it with your existing hooks)."
else
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] would merge $SNIPPET into $SETTINGS (without duplicating hooks)."
  else
    # Strip the '//' comment keys from the snippet before merging.
    snippet_clean=$(jq 'del(.["//"], .["//paths"])' "$SNIPPET")

    # The snippet hardcodes hook paths under '$CLAUDE_PROJECT_DIR/.claude', which
    # only resolves for a project-level install. For a user-level install the
    # skill lives at $TARGET (~/.claude), so rewrite the path prefix to $TARGET.
    if [ "$MODE" != "project" ]; then
      snippet_clean=$(printf '%s' "$snippet_clean" | jq --arg t "$TARGET" '
        walk(if type == "object" and has("command")
             then .command |= sub("\\$CLAUDE_PROJECT_DIR/\\.claude"; $t)
             else . end)')
    fi

    if [ -f "$SETTINGS" ]; then
      current=$(cat "$SETTINGS")
    else
      current='{}'
    fi

    # Idempotent merge:
    #  - The user's top-level keys are preserved ('* + snippet' lets the snippet
    #    win only on .hooks, which we rebuild below).
    #  - For each hook event (PreToolUse, PostToolUse, ...) and each matcher, we
    #    union the command lists and dedupe by .command, so re-running does not
    #    accumulate repeated entries.
    merged=$(jq -n \
      --argjson cur "$current" \
      --argjson snip "$snippet_clean" '
      # Merge two arrays of {matcher, hooks:[...]} blocks, grouping by matcher
      # and deduping the hooks by their .command.
      def merge_event(a; b):
        ((a // []) + (b // []))
        | group_by(.matcher)
        | map({
            matcher: .[0].matcher,
            hooks: (map(.hooks // []) | add
                    | unique_by(.command // (. | tojson)))
          });

      # Merge the .hooks object event by event.
      def merge_hooks(a; b):
        reduce ((a // {}) * (b // {}) | keys_unsorted[]) as $k
          ({}; .[$k] = merge_event(a[$k]; b[$k]));

      $cur
      | .hooks = merge_hooks(($cur.hooks // {}); ($snip.hooks // {}))
      ' )

    printf '%s\n' "$merged" > "$SETTINGS"
    log "  settings.json updated (hooks deduplicated)."
  fi
fi

# --- Summary --------------------------------------------------------------
log ""
log "Installation complete."
log "  skill:    $TARGET/skills/task-orchestrator"
log "  agents:   $TARGET/agents/ (task-analyzer, task-implementer, task-verifier, task-dreamer)"
log "  commands: $TARGET/commands/ (task, task-execute)"
log "  settings: $TARGET/settings.json"
log ""
log "Note: verify with /agents inside Claude Code that the subagents show up."
