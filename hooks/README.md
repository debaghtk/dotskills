# Drift Detection Hooks

Informational post-commit hooks that nag when documentation drifts out of sync with code changes.

## What These Do

- **architecture-drift.sh** — When a commit touches infrastructure/config paths and `ARCHITECTURE.md` hasn't been updated in >7 days, prints a reminder to stderr.
- **product-drift.sh** — When a commit touches product-significant paths and `Product.md` hasn't been updated in >7 days, prints a reminder to stderr.

Both always exit 0. They never block commits.

## Installation

Add to your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/hooks/architecture-drift.sh"
          },
          {
            "type": "command",
            "command": "/path/to/hooks/product-drift.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `/path/to/hooks/` with the absolute path to these scripts (or copy them into your project).

## Customizing Paths

Edit the `INFRA_PATHS` or `PRODUCT_PATHS` variable at the top of each script to match your project's directory structure.

## Staleness Threshold

Default is 7 days. To change, modify the comparison in each script:

```bash
if [ "$days_stale" -gt 7 ]; then  # change 7 to your preferred threshold
```
