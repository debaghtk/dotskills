# dotskills

My reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills and agents.

## Install

```bash
git clone <this-repo> ~/dotskills
cd ~/dotskills

# Install all skills + agents globally (available in every project)
./install.sh --personal

# Or install into the current project only
cd /path/to/project
~/dotskills/install.sh --project

# Install a single item
./install.sh --personal ux
./install.sh --project dev
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
/ux evaluate whether adding a settings page improves or hurts the onboarding flow
/codex review this file for performance issues
```

Skills can also be auto-triggered by Claude when the task matches the skill's description.

### Agents

Agents are invoked from the terminal with `claude --agent`:

```bash
claude --agent dev "add rate limiting to the /api/search endpoint"
claude --agent research "best approach for real-time sync with conflict resolution"
```

Or from within a Claude Code session using the Agent tool — Claude will pick the right agent based on the task.
