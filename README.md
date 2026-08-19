# dotskills

My reusable skills and agents for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Codex](https://github.com/openai/codex), [Kimi Code](https://www.kimi.com/code/docs/en/), and [OpenCode](https://opencode.ai).

## Install

```bash
git clone <this-repo> ~/dotskills
cd ~/dotskills

# Install all skills + agents globally (available in every project)
./install.sh --personal

# Or install into the current project only (skills + agents + problems + hooks)
cd /path/to/project
~/dotskills/install.sh --project

# Install a single item
./install.sh --personal ds-ux
./install.sh --personal mountain
```

## Uninstall

```bash
./install.sh --uninstall --personal        # Remove all
./install.sh --uninstall --personal ds-ux  # Remove one
./install.sh --uninstall --project         # Remove from current project
```

## List available skills and agents

```bash
./install.sh --list
```

## Usage

### Skills

Skills are invoked inside a Claude Code session with `/skill-name`:

```
/ds-ux evaluate whether adding a settings page improves or hurts the onboarding flow
```

In Kimi Code, the same skills are invoked with `/skill:<name>`:

```
/skill:ds-ux evaluate whether adding a settings page improves or hurts the onboarding flow
```

In OpenCode, skills are discovered natively (it reads `.claude/skills/` as a
Claude-compatible fallback, so the same install works with no extra config)
and loaded on demand via its `skill` tool rather than a slash command.

Skills can also be auto-triggered when the task matches the skill's description.

### Agents

Agents are invoked from the terminal with `claude --agent` or `kimi --agent`:

```bash
claude --agent my-agent "best approach for real-time sync with conflict resolution"
kimi --agent my-agent "best approach for real-time sync with conflict resolution"
```

Or from within a session using the Agent tool — the assistant will pick the right agent based on the task.

OpenCode agents are `subagent`-mode and invoked the same way, either by name via `@` (e.g. `@my-agent best approach for real-time sync with conflict resolution`) or automatically via its Task tool.

## Adding a new skill

```bash
mkdir skills/my-skill
```

Add `skills/my-skill/SKILL.md`:

```yaml
---
name: my-skill
description: When and why to use this skill
---

Your skill instructions here.
```

Optionally, add `skills/my-skill/agents/openai.yaml` — Codex CLI's UI metadata for
skill lists and chips (display name, short description, icon, default prompt):

```yaml
interface:
  display_name: "My Skill"
  short_description: "One-line, user-facing description"
  default_prompt: "Use $my-skill to ..."
```

Only a few skills have this today (`ds-teach`, `linear-project`, `mountain`) — it's
recommended but not required, and every other tool ignores it, so it's safe to skip.

## Adding a new agent

Add `agents/my-agent.md`:

```yaml
---
name: my-agent
description: When and why to use this agent
---

Your agent instructions here.
```

This `.md` version is used for Claude and Kimi Code. Codex needs its own
`.toml` version in `codex-agents/my-agent.toml` (different frontmatter,
system prompt inlined as `developer_instructions` since Codex can't load
skills on demand). OpenCode needs its own `.md` version in
`opencode-agents/my-agent.md` (frontmatter is `description` + `mode:
subagent` instead of `name`/`skills`). Either `.toml` or OpenCode's `.md` is optional; if
missing, install.sh skips that tool for the agent with a warning.

Re-run `./install.sh --personal` to pick up new items.

## Problems Template

The `problems/` directory is a structured problem registry template. It's automatically copied into your project when you run `--project`:

```bash
~/dotskills/install.sh --project     # installs skills + agents + problems + hooks
~/dotskills/install.sh --problems    # just the problems registry
```

Each project gets its own copy (not a symlink) so the registry is mutable. Running again won't overwrite an existing `problems/` directory.

Skills like `/ds-inception` write to this registry after framing problems.

## Hooks

Hooks that intercept or observe tool calls — `block-railway.sh` (hard-blocks destructive Railway CLI commands), `approve-tests.sh` (requires terminal approval for spec-file writes), and the drift checks (nag when commits touch infra/product paths but `ARCHITECTURE.md`/`Product.md` are stale). Automatically installed with `--project`:

```bash
~/dotskills/install.sh --project        # installs everything including hooks
~/dotskills/install.sh --hooks          # just the hooks (claude + codex + opencode, current project)
~/dotskills/install.sh --kimi-hooks     # hooks for Kimi (user-level ~/.kimi-code/config.toml)
~/dotskills/install.sh --opencode-hooks # hooks for OpenCode (user-level ~/.config/opencode/plugins/)
```

Hooks are configured to point back to the dotskills source, so they stay up to date. Safe to run multiple times — existing hooks won't be duplicated, and other settings are preserved. Codex hooks need `codex_hooks = true` under `[features]` in `~/.codex/config.toml`. OpenCode hooks are a single plugin file that shells out to the same bash scripts (no per-hook selection, unlike `--kimi-hooks`). See `hooks/README.md` for details and per-tool caveats.

## Chat Versions

`docs/claude-project-prompts/` contains standalone system prompts for Claude.ai Projects — use these when you want Inception in a chat interface without filesystem access. Includes a context block template for priming projects.

## Plugins

Manage Claude Code plugins like dotfiles — track what you use, restore on any machine.

```bash
# Install all plugins from manifest
./plugins.sh install

# List tracked plugins and marketplaces
./plugins.sh list

# Add a new plugin (installs + saves to plugins.txt)
./plugins.sh add skill-codex@claude-plugins-official

# Remove a plugin (uninstalls + removes from plugins.txt)
./plugins.sh remove skill-codex@claude-plugins-official
```

Edit `plugins.txt` to manage your plugin list. Edit `marketplaces.txt` to register custom marketplaces.
