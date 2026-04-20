#!/usr/bin/env bash
set -euo pipefail

PRODUCT_PATHS="app/models/ app/controllers/ config/routes app/views/ app/services/ src/pages/ src/components/ routes/"

changed_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
[ -z "$changed_files" ] && exit 0

touched_product=false
for path in $PRODUCT_PATHS; do
  if echo "$changed_files" | grep -q "^${path}"; then
    touched_product=true
    break
  fi
done

[ "$touched_product" = false ] && exit 0

if [ ! -f "Product.md" ]; then
  echo "[drift-check] No Product.md found. Consider creating one — this commit touches product-significant paths." >&2
  exit 0
fi

last_updated=$(git log -1 --format=%ct -- Product.md 2>/dev/null || echo 0)
now=$(date +%s)
days_stale=$(( (now - last_updated) / 86400 ))

if [ "$days_stale" -gt 7 ]; then
  echo "[drift-check] Product.md last updated ${days_stale} days ago. This commit touches product-significant paths -- worth a refresh?" >&2
fi

exit 0
