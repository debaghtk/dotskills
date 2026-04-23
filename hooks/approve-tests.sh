#!/bin/bash
set -e
# PreToolUse hook: intercepts test file writes and requires terminal approval
# Claude Code passes tool info as JSON via stdin with fields: tool_name, tool_input

if ! command -v jq &>/dev/null; then
  exit 0
fi

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Skip if we couldn't extract a file path
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Only intercept writes to actual spec files (not factories, support, fixtures)
if [[ "$file_path" == *_spec.rb ]]; then
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "🧪 TEST WRITE INTERCEPTED" >&2
  echo "File: $file_path" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "" >&2

  read -p "Approve this test write? [y/N]: " RESPONSE </dev/tty
  if [[ "$RESPONSE" =~ ^[Yy] ]]; then
    exit 0
  else
    echo '{"decision":"block","reason":"Test write rejected by developer — revise the test and try again"}' >&2
    exit 2
  fi
fi

exit 0
