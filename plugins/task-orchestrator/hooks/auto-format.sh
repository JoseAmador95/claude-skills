#!/usr/bin/env bash
# PostToolUse (matcher: Write|Edit). Formats the just-edited file
# with the formatter matching its extension. Silent and non-blocking:
# if the formatter is not installed, it does nothing. Requires `jq`.
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || { exit 0; }
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.html|*.md|*.yaml|*.yml)
      npx --no-install prettier --write "$file" >/dev/null 2>&1 || true ;;
  *.py)  (command -v ruff >/dev/null && ruff format "$file" >/dev/null 2>&1) || true ;;
  *.go)  gofmt -w "$file" >/dev/null 2>&1 || true ;;
  *.rs)  rustfmt "$file" >/dev/null 2>&1 || true ;;
  *.c|*.h|*.cpp|*.hpp|*.cc)
      (command -v clang-format >/dev/null && clang-format -i "$file" >/dev/null 2>&1) || true ;;
esac
exit 0
