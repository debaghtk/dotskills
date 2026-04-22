# dotskills

My reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills and agents.

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
./install.sh --project deven
```

## Uninstall

```bash
./install.sh --uninstall --personal        # Remove all
./install.sh --uninstall --personal ux     # Remove one
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
/ds-codex review this file for performance issues
```

Skills can also be auto-triggered by Claude when the task matches the skill's description.

### Agents

Agents are invoked from the terminal with `claude --agent`:

```bash
claude --agent deven "add rate limiting to the /api/search endpoint"
claude --agent research "best approach for real-time sync with conflict resolution"
```

Or from within a Claude Code session using the Agent tool — Claude will pick the right agent based on the task.

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

## Adding a new agent

Add `agents/my-agent.md`:

```yaml
---
name: my-agent
description: When and why to use this agent
---

Your agent instructions here.
```

Re-run `./install.sh --personal` to pick up new items.

## Problems Template

The `problems/` directory is a structured problem registry template. It's automatically copied into your project when you run `--project`:

```bash
~/dotskills/install.sh --project     # installs skills + agents + problems + hooks
~/dotskills/install.sh --problems    # just the problems registry
```

Each project gets its own copy (not a symlink) so the registry is mutable. Running again won't overwrite an existing `problems/` directory.

Skills like `/ds-shobhit` write to this registry after framing problems. `/ds-vinay` reads from it before scoping.

## Drift Hooks

Post-commit hooks that nag when documentation drifts out of sync with code. Automatically installed into `.claude/settings.json` with `--project`:

```bash
~/dotskills/install.sh --project     # installs everything including hooks
~/dotskills/install.sh --hooks       # just the hooks
```

Hooks are configured to point back to the dotskills source, so they stay up to date. Safe to run multiple times — existing hooks won't be duplicated, and other settings in your `settings.json` are preserved.

## Chat Versions

`docs/claude-project-prompts/` contains standalone system prompts for Claude.ai Projects — use these when you want Shobhit or Vinay in a chat interface without filesystem access. Includes a context block template for priming projects.

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
