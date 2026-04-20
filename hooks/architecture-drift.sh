#!/usr/bin/env bash
set -euo pipefail

INFRA_PATHS="config/ Gemfile Gemfile.lock package.json package-lock.json db/migrate/ lib/ infrastructure/ docker-compose Dockerfile"

changed_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
[ -z "$changed_files" ] && exit 0

touched_infra=false
for path in $INFRA_PATHS; do
  if echo "$changed_files" | grep -q "^${path}"; then
    touched_infra=true
    break
  fi
done

[ "$touched_infra" = false ] && exit 0

if [ ! -f "ARCHITECTURE.md" ]; then
  echo "[drift-check] No ARCHITECTURE.md found. Consider creating one — this commit touches infrastructure paths." >&2
  exit 0
fi

last_updated=$(git log -1 --format=%ct -- ARCHITECTURE.md 2>/dev/null || echo 0)
now=$(date +%s)
days_stale=$(( (now - last_updated) / 86400 ))

if [ "$days_stale" -gt 7 ]; then
  echo "[drift-check] ARCHITECTURE.md last updated ${days_stale} days ago. This commit touches infrastructure paths -- worth a refresh?" >&2
fi

exit 0
