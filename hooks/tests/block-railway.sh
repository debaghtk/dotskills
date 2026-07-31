#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || exit 0
hook="$(cd "$(dirname "$0")/.." && pwd)/block-railway.sh"

check() {
  local expected="$1" payload="$2" actual
  set +e
  printf '%s' "$payload" | "$hook" >/dev/null 2>&1
  actual=$?
  set -e
  [ "$actual" -eq "$expected" ] || {
    echo "expected $expected, got $actual: $payload" >&2
    exit 1
  }
}

check 0 'not json'
check 0 '{"tool_input":{"command":"railway status"}}'
check 2 '{"tool_input":{"command":"railway up"}}'
check 0 '{"tool_input":{"command":"bash -c \"railway up\""}}'
check 0 '{"tool_input":{"command":"railway variables --setter foo"}}'
check 2 '{"tool_input":{"command":"railway variables --set FOO=bar"}}'
