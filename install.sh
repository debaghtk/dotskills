#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
AGENTS_DIR="$SCRIPT_DIR/agents"
CODEX_AGENTS_DIR="$SCRIPT_DIR/codex-agents"
PROBLEMS_DIR="$SCRIPT_DIR/problems"
HOOKS_DIR="$SCRIPT_DIR/hooks"

usage() {
  cat <<EOF
Usage: ./install.sh <mode> [options]

Modes:
  --personal [name]      Install to ~/.claude/ and ~/.codex/ (all projects)
  --project  [name]      Install to ./.claude/ and ./.codex/ (current project)
                         Also copies problems/ template and installs hooks
  --list                 List available skills and agents
  --sync <mode>          Install all + prune dangling/renamed symlinks
                         mode: --personal or --project
  --problems             Copy problems/ registry template into current project
  --hooks                Install drift-check hooks into .claude/settings.json
  --uninstall <mode> [name]
                         Remove installed symlinks (and hooks if --project)

Skills are installed for both Claude and Codex.
Agents are installed as .md for Claude and .toml for Codex.
Problems template is copied (not symlinked) — each project owns its registry.
Hooks are configured in .claude/settings.json pointing back to dotskills source.

Examples:
  ./install.sh --list
  ./install.sh --personal              # Install all skills + agents
  ./install.sh --personal ux           # Install one skill
  ./install.sh --personal deven        # Install one agent
  ./install.sh --project               # Install all + problems + hooks
  ./install.sh --sync --personal       # Install all + prune stale symlinks
  ./install.sh --problems              # Just copy problems/ template
  ./install.sh --hooks                 # Just install hooks
  ./install.sh --uninstall --personal  # Remove all symlinks
EOF
  exit 1
}

list_items() {
  if [ -d "$SKILLS_DIR" ]; then
    echo "Skills:"
    for dir in "$SKILLS_DIR"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      desc=""
      if [ -f "$dir/SKILL.md" ]; then
        desc=$(sed -n '/^description:/{ s/^description: *["]*//; s/"$//; p; q; }' "$dir/SKILL.md")
      fi
      printf "  %-20s %s\n" "$name" "$desc"
    done
  fi
  if [ -d "$AGENTS_DIR" ]; then
    echo ""
    echo "Agents:"
    for file in "$AGENTS_DIR"/*.md; do
      [ -f "$file" ] || continue
      name="$(basename "$file" .md)"
      desc=$(sed -n '/^description:/{ s/^description: *["]*//; s/"$//; p; q; }' "$file")
      printf "  %-20s %s\n" "$name" "$desc"
    done
  fi
}

# Determine if a name is a skill, agent, or unknown
# Sets: ITEM_TYPE ("skill" or "agent"), ITEM_SRC (source path)
resolve_item() {
  local name="$1"
  if [ -d "$SKILLS_DIR/$name" ] && [ -f "$SKILLS_DIR/$name/SKILL.md" ]; then
    ITEM_TYPE="skill"
    ITEM_SRC="$SKILLS_DIR/$name"
  elif [ -f "$AGENTS_DIR/$name.md" ]; then
    ITEM_TYPE="agent"
    ITEM_SRC="$AGENTS_DIR/$name.md"
  else
    echo "Error: '$name' not found in skills/ or agents/" >&2
    return 1
  fi
}

# Returns target dirs for a given mode/type/tool combo.
# For skills: returns both claude and codex paths.
# For agents: returns only claude path (codex has no agents).
resolve_target_dirs() {
  local mode="$1" item_type="$2"
  local claude_base codex_base
  if [ "$mode" = "--personal" ]; then
    claude_base="$HOME/.claude"
    codex_base="$HOME/.codex"
  elif [ "$mode" = "--project" ]; then
    claude_base="$(pwd)/.claude"
    codex_base="$(pwd)/.codex"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  if [ "$item_type" = "skill" ]; then
    echo "$claude_base/skills"
    echo "$codex_base/skills"
  else
    echo "$claude_base/agents"
    echo "$codex_base/agents"
  fi
}

install_item() {
  local name="$1" mode="$2"
  resolve_item "$name"

  while IFS= read -r target_dir; do
    mkdir -p "$target_dir"

    local src="$ITEM_SRC" dest
    if [ "$ITEM_TYPE" = "skill" ]; then
      dest="$target_dir/$name"
    elif [[ "$target_dir" == */.codex/* ]]; then
      # Codex agents use .toml files from codex-agents/
      if [ ! -f "$CODEX_AGENTS_DIR/$name.toml" ]; then
        echo "Skipping agent '$name' for Codex (no .toml version)" >&2
        continue
      fi
      src="$CODEX_AGENTS_DIR/$name.toml"
      dest="$target_dir/$name.toml"
    else
      dest="$target_dir/$name.md"
    fi

    if [ -L "$dest" ]; then
      rm "$dest"
    elif [ -e "$dest" ]; then
      echo "Warning: $dest exists and is not a symlink, skipping" >&2
      continue
    fi

    ln -s "$src" "$dest"
    echo "Installed $ITEM_TYPE '$name' -> $dest"
  done < <(resolve_target_dirs "$mode" "$ITEM_TYPE")
}

uninstall_item() {
  local name="$1" mode="$2"
  resolve_item "$name"

  while IFS= read -r target_dir; do
    local dest
    if [ "$ITEM_TYPE" = "skill" ]; then
      dest="$target_dir/$name"
    elif [[ "$target_dir" == */.codex/* ]]; then
      dest="$target_dir/$name.toml"
    else
      dest="$target_dir/$name.md"
    fi

    if [ -L "$dest" ]; then
      rm "$dest"
      echo "Removed $dest"
    elif [ -e "$dest" ]; then
      echo "Warning: $dest is not a symlink, skipping" >&2
    else
      echo "Not installed: $name ($target_dir)"
    fi
  done < <(resolve_target_dirs "$mode" "$ITEM_TYPE")
}

prune_stale() {
  local mode="$1"
  local claude_base codex_base
  if [ "$mode" = "--personal" ]; then
    claude_base="$HOME/.claude"
    codex_base="$HOME/.codex"
  elif [ "$mode" = "--project" ]; then
    claude_base="$(pwd)/.claude"
    codex_base="$(pwd)/.codex"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  for dir in "$claude_base/skills" "$claude_base/agents" "$codex_base/skills" "$codex_base/agents"; do
    [ -d "$dir" ] || continue
    for link in "$dir"/*; do
      [ -L "$link" ] || continue
      if [ ! -e "$link" ]; then
        rm "$link"
        echo "Pruned stale symlink $link"
      fi
    done
  done
}

get_all_names() {
  if [ -d "$SKILLS_DIR" ]; then
    for dir in "$SKILLS_DIR"/*/; do
      [ -d "$dir" ] && basename "$dir"
    done
  fi
  if [ -d "$AGENTS_DIR" ]; then
    for file in "$AGENTS_DIR"/*.md; do
      [ -f "$file" ] && basename "$file" .md
    done
  fi
}

install_problems() {
  if [ -d "problems" ]; then
    echo "problems/ already exists, skipping (won't overwrite existing registry)"
    return
  fi
  cp -r "$PROBLEMS_DIR" ./problems
  echo "Copied problems/ registry template"
}

install_hooks() {
  local settings=".claude/settings.json"
  mkdir -p .claude

  # Classify hook scripts into PreToolUse and PostToolUse
  local pre_hooks=()
  local post_hooks=()
  for script in "$HOOKS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    case "$(basename "$script")" in
      approve-tests.sh) pre_hooks+=("$script") ;;
      *)                post_hooks+=("$script") ;;
    esac
  done
  if [ ${#pre_hooks[@]} -eq 0 ] && [ ${#post_hooks[@]} -eq 0 ]; then
    echo "No hook scripts found in $HOOKS_DIR"
    return
  fi

  # If settings.json doesn't exist, create it with hooks
  if [ ! -f "$settings" ]; then
    _write_hooks_json "$settings"
    echo "Created $settings with hooks"
    return
  fi

  # Check which hooks are already installed
  local missing_pre=()
  local missing_post=()
  for script in "${pre_hooks[@]}"; do
    if ! grep -q "$script" "$settings" 2>/dev/null; then
      missing_pre+=("$script")
    fi
  done
  for script in "${post_hooks[@]}"; do
    if ! grep -q "$script" "$settings" 2>/dev/null; then
      missing_post+=("$script")
    fi
  done

  if [ ${#missing_pre[@]} -eq 0 ] && [ ${#missing_post[@]} -eq 0 ]; then
    echo "Hooks already configured in $settings"
    return
  fi

  # Merge missing hooks into existing settings using python3 (available on macOS)
  python3 - "$settings" "${#missing_pre[@]}" "${missing_pre[@]}" "${missing_post[@]}" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
num_pre = int(sys.argv[2])
all_scripts = sys.argv[3:]
pre_scripts = all_scripts[:num_pre]
post_scripts = all_scripts[num_pre:]

with open(settings_path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})

# Add PreToolUse hooks (Write|Edit|MultiEdit matcher)
if pre_scripts:
    pre_tool = hooks.setdefault("PreToolUse", [])
    write_entry = None
    for entry in pre_tool:
        if entry.get("matcher") == "Write|Edit|MultiEdit":
            write_entry = entry
            break
    if write_entry is None:
        write_entry = {"matcher": "Write|Edit|MultiEdit", "hooks": []}
        pre_tool.append(write_entry)
    existing_cmds = {h.get("command", "") for h in write_entry.get("hooks", [])}
    for script in pre_scripts:
        cmd = f"bash {script}"
        if cmd not in existing_cmds:
            write_entry["hooks"].append({"type": "command", "command": cmd})

# Add PostToolUse hooks (Bash matcher)
if post_scripts:
    post_tool = hooks.setdefault("PostToolUse", [])
    bash_entry = None
    for entry in post_tool:
        if entry.get("matcher") == "Bash":
            bash_entry = entry
            break
    if bash_entry is None:
        bash_entry = {"matcher": "Bash", "hooks": []}
        post_tool.append(bash_entry)
    existing_cmds = {h.get("command", "") for h in bash_entry.get("hooks", [])}
    for script in post_scripts:
        if script not in existing_cmds:
            bash_entry["hooks"].append({"type": "command", "command": script})

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  local all_missing=("${missing_pre[@]}" "${missing_post[@]}")
  echo "Added hooks to $settings: ${all_missing[*]}"
}

_write_hooks_json() {
  local dest="$1"

  # Classify hook scripts
  local pre_hooks=()
  local post_hooks=()
  for script in "$HOOKS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    case "$(basename "$script")" in
      approve-tests.sh) pre_hooks+=("$script") ;;
      *)                post_hooks+=("$script") ;;
    esac
  done

  # Build PreToolUse hooks JSON
  local pre_json=""
  for i in "${!pre_hooks[@]}"; do
    [ "$i" -gt 0 ] && pre_json+=","
    pre_json+="
            {\"type\": \"command\", \"command\": \"bash ${pre_hooks[$i]}\"}"
  done

  # Build PostToolUse hooks JSON
  local post_json=""
  for i in "${!post_hooks[@]}"; do
    [ "$i" -gt 0 ] && post_json+=","
    post_json+="
            {\"type\": \"command\", \"command\": \"${post_hooks[$i]}\"}"
  done

  cat > "$dest" <<ENDJSON
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [$pre_json
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [$post_json
        ]
      }
    ]
  }
}
ENDJSON
}

uninstall_hooks() {
  local settings=".claude/settings.json"
  if [ ! -f "$settings" ]; then
    echo "No $settings found"
    return
  fi

  # Remove hook entries that point to our HOOKS_DIR
  if ! grep -q "$HOOKS_DIR" "$settings" 2>/dev/null; then
    echo "No dotskills hooks found in $settings"
    return
  fi

  python3 - "$settings" "$HOOKS_DIR" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
hooks_dir = sys.argv[2]

with open(settings_path) as f:
    data = json.load(f)

hooks = data.get("hooks", {})

# Clean both PreToolUse and PostToolUse
for phase in ("PreToolUse", "PostToolUse"):
    entries = hooks.get(phase, [])
    for entry in entries:
        entry["hooks"] = [h for h in entry.get("hooks", [])
                          if hooks_dir not in h.get("command", "")]
    # Remove entries with no hooks left
    hooks[phase] = [e for e in entries if e.get("hooks")]
    if not hooks[phase]:
        hooks.pop(phase, None)

if not hooks:
    data.pop("hooks", None)

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  echo "Removed dotskills hooks from $settings"
}

# --- Main ---

[ $# -eq 0 ] && usage

case "${1:-}" in
  --list)
    list_items
    ;;
  --personal|--project)
    mode="$1"
    name="${2:-}"
    if [ -n "$name" ]; then
      install_item "$name" "$mode"
    else
      for n in $(get_all_names); do
        install_item "$n" "$mode"
      done
      if [ "$mode" = "--project" ]; then
        install_problems
        install_hooks
      fi
    fi
    ;;
  --sync)
    mode="${2:-}"
    if [ -z "$mode" ]; then
      echo "Error: --sync requires --personal or --project" >&2
      exit 1
    fi
    for n in $(get_all_names); do
      install_item "$n" "$mode"
    done
    prune_stale "$mode"
    if [ "$mode" = "--project" ]; then
      install_problems
      install_hooks
    fi
    ;;
  --problems)
    install_problems
    ;;
  --hooks)
    install_hooks
    ;;
  --uninstall)
    mode="${2:-}"
    name="${3:-}"
    if [ -n "$name" ]; then
      uninstall_item "$name" "$mode"
    else
      for n in $(get_all_names); do
        uninstall_item "$n" "$mode"
      done
      if [ "$mode" = "--project" ]; then
        uninstall_hooks
        echo "Note: problems/ not removed (contains project data). Delete manually if needed."
      fi
    fi
    ;;
  *)
    usage
    ;;
esac
