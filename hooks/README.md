# Hooks

Shell hooks that intercept or observe tool calls. All scripts use the same
contract across Claude Code, Codex CLI, and Kimi Code: tool info arrives as
JSON on stdin (`tool_input.command` / `tool_input.file_path`), exit code 2
blocks (reason on stderr), exit code 0 allows.

## What These Do

- **block-railway.sh** — PreToolUse on `Bash`. Blocks direct destructive
  `railway` CLI commands (`up`, `delete`, `down`, `redeploy`, `remove`,
  `domain`, `volume`, and `variables --set/--delete`). Read-only commands
  (`status`, `logs`, plain `variables`) pass through. This is a best-effort
  guardrail, not a security boundary: shell indirection can bypass it, and it
  allows the command when `jq` is unavailable or the hook input is malformed.
- **approve-tests.sh** — PreToolUse on `Write|Edit`. Intercepts writes to
  `*_spec.rb` files and requires a `y` in the terminal before the write goes
  through. (Claude/Kimi only — Codex hooks don't support file-write tools.)
- **architecture-drift.sh** — PostToolUse on `Bash`. When the last commit
  touches infrastructure/config paths and `ARCHITECTURE.md` hasn't been
  updated in >7 days, prints a reminder to stderr. Never blocks.
- **product-drift.sh** — Same, but watches product-significant paths and
  nags about a stale `Product.md`. Never blocks.

## Installation

From the repo root (`install.sh` handles classification and merging):

```bash
# Claude + Codex, current project (./.claude/settings.json + ./.codex/hooks.json)
~/dotskills/install.sh --hooks

# Kimi Code, user-level (~/.kimi-code/config.toml — fires in every project)
~/dotskills/install.sh --kimi-hooks                  # all hooks
~/dotskills/install.sh --kimi-hooks block-railway    # just one

# Remove
~/dotskills/install.sh --uninstall --project          # claude + codex
~/dotskills/install.sh --uninstall --kimi-hooks       # kimi
```

Hook commands point back to the dotskills source, so they stay up to date.
Safe to run multiple times — existing hooks won't be duplicated, and other
settings/hooks are preserved.

## Codex Caveats

Codex hooks are experimental and off by default. To enable, add to
`~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

Only `Bash` tool events fire — `approve-tests.sh` is skipped for Codex.

## Kimi Caveats

Kimi reads hooks only from the user-level `~/.kimi-code/config.toml`, so
installed hooks fire in every project (scripts self-limit outside git repos).

- The drift hooks print to **stderr**, but Kimi only appends **stdout** to
  context — their nags may not surface there.
- `approve-tests.sh` reads your answer from `/dev/tty`; if the tty is
  unavailable in Kimi's hook process, spec-file writes will be blocked.

## Customizing Paths

Edit the `INFRA_PATHS` or `PRODUCT_PATHS` variable at the top of each drift
script to match your project's directory structure. Edit the subcommand
regexes in `block-railway.sh` to change what counts as destructive.

## Staleness Threshold

Default is 7 days. To change, modify the comparison in each drift script:

```bash
if [ "$days_stale" -gt 7 ]; then  # change 7 to your preferred threshold
```
