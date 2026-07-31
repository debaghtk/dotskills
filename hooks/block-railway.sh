#!/usr/bin/env bash
set -euo pipefail
# PreToolUse hook: hard-blocks destructive railway CLI commands.
# Works with Claude Code, Codex CLI, and Kimi Code — all three pass tool info
# as JSON via stdin (tool_input.command) and honor exit code 2 as "block".

if ! command -v jq &>/dev/null; then
  exit 0
fi

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -z "$command" ] && exit 0

block() {
  echo "Blocked by dotskills hook: destructive railway command detected." >&2
  echo "Command: $command" >&2
  echo "Run it yourself in a terminal if you really want this." >&2
  exit 2
}

# Deploys, deletions, teardowns, domain/volume mutations
if echo "$command" | grep -qE '(^|[;&|]+[[:space:]]*)railway[[:space:]]+(up|delete|down|redeploy|remove|domain|volume)([[:space:]]|$)'; then
  block
fi

# Variable mutations (plain `railway variables` lists — allowed)
if echo "$command" | grep -qE '(^|[;&|]+[[:space:]]*)railway[[:space:]]+variables([[:space:]]|$)' \
   && echo "$command" | grep -qE -- '--set|--delete'; then
  block
fi

exit 0
