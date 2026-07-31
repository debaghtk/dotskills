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
  --personal [name]      Install to ~/.claude/, ~/.codex/ and ~/.kimi-code/ (all projects)
  --project  [name]      Install to ./.claude/, ./.codex/ and ./.kimi-code/ (current project)
                         Also copies problems/ template and installs hooks
  --list                 List available skills and agents
  --sync <mode>          Install all + prune dangling/renamed symlinks
                         mode: --personal or --project
  --problems             Copy problems/ registry template into current project
  --hooks                Install hooks into ./.claude/settings.json and
                         ./.codex/hooks.json (current project)
  --kimi-hooks [name..]  Install hooks into ~/.kimi-code/config.toml
                         (user-level, all projects; no name = all hooks)
  --uninstall <mode> [name]
                         Remove installed symlinks (and hooks if --project)
                         mode: --personal, --project, or --kimi-hooks [name..]

Skills are installed for Claude, Codex, and Kimi Code.
Agents are installed as .md for Claude and Kimi Code, and .toml for Codex.
Problems template is copied (not symlinked) — each project owns its registry.
Hooks point back to dotskills source, so they stay up to date.
Note: Codex hooks require codex_hooks = true under [features] in
~/.codex/config.toml, and only support Bash (no file-write hooks).

Examples:
  ./install.sh --list
  ./install.sh --personal              # Install all skills + agents
  ./install.sh --personal ux           # Install one skill
  ./install.sh --personal deven        # Install one agent
  ./install.sh --project               # Install all + problems + hooks
  ./install.sh --sync --personal       # Install all + prune stale symlinks
  ./install.sh --problems              # Just copy problems/ template
  ./install.sh --hooks                 # Just install hooks (claude + codex)
  ./install.sh --kimi-hooks block-railway   # Install one hook for Kimi
  ./install.sh --uninstall --kimi-hooks     # Remove all dotskills Kimi hooks
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
# For skills and agents: returns claude, codex, and kimi paths.
resolve_target_dirs() {
  local mode="$1" item_type="$2"
  local claude_base codex_base kimi_base
  if [ "$mode" = "--personal" ]; then
    claude_base="$HOME/.claude"
    codex_base="$HOME/.codex"
    kimi_base="${KIMI_CODE_HOME:-$HOME/.kimi-code}"
  elif [ "$mode" = "--project" ]; then
    claude_base="$(pwd)/.claude"
    codex_base="$(pwd)/.codex"
    kimi_base="$(pwd)/.kimi-code"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  if [ "$item_type" = "skill" ]; then
    echo "$claude_base/skills"
    echo "$codex_base/skills"
    echo "$kimi_base/skills"
  else
    echo "$claude_base/agents"
    echo "$codex_base/agents"
    echo "$kimi_base/agents"
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
  local claude_base codex_base kimi_base
  if [ "$mode" = "--personal" ]; then
    claude_base="$HOME/.claude"
    codex_base="$HOME/.codex"
    kimi_base="${KIMI_CODE_HOME:-$HOME/.kimi-code}"
  elif [ "$mode" = "--project" ]; then
    claude_base="$(pwd)/.claude"
    codex_base="$(pwd)/.codex"
    kimi_base="$(pwd)/.kimi-code"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  for dir in "$claude_base/skills" "$claude_base/agents" "$codex_base/skills" "$codex_base/agents" "$kimi_base/skills" "$kimi_base/agents"; do
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

# Classify hook scripts by event/matcher.
# Sets: PRE_WRITE_HOOKS, PRE_BASH_HOOKS, POST_BASH_HOOKS (arrays of script paths)
classify_hooks() {
  PRE_WRITE_HOOKS=()
  PRE_BASH_HOOKS=()
  POST_BASH_HOOKS=()
  for script in "$HOOKS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    case "$(basename "$script")" in
      approve-tests.sh) PRE_WRITE_HOOKS+=("$script") ;;
      block-railway.sh) PRE_BASH_HOOKS+=("$script") ;;
      *)                POST_BASH_HOOKS+=("$script") ;;
    esac
  done
}

# Install hooks into the current project's .claude/settings.json and .codex/hooks.json
install_hooks() {
  install_hooks_json ".claude/settings.json" claude
  install_hooks_json ".codex/hooks.json" codex
}

# $1 = target file, $2 = flavor (claude|codex) — both use the same JSON schema
install_hooks_json() {
  local settings="$1" flavor="$2"
  mkdir -p "$(dirname "$settings")"
  classify_hooks

  if [ "$flavor" = codex ]; then
    # Codex hooks only fire for the Bash tool — file-write hooks unsupported
    if [ ${#PRE_WRITE_HOOKS[@]} -gt 0 ]; then
      echo "Note: Codex hooks only support the Bash tool, skipping: ${PRE_WRITE_HOOKS[*]##*/}"
      PRE_WRITE_HOOKS=()
    fi
    if ! grep -q 'codex_hooks' "${CODEX_HOME:-$HOME/.codex}/config.toml" 2>/dev/null; then
      echo "Note: Codex hooks are experimental and off by default. To enable, add to ~/.codex/config.toml:"
      echo "  [features]"
      echo "  codex_hooks = true"
    fi
  fi

  if [ ${#PRE_WRITE_HOOKS[@]} -eq 0 ] && [ ${#PRE_BASH_HOOKS[@]} -eq 0 ] && [ ${#POST_BASH_HOOKS[@]} -eq 0 ]; then
    echo "No hook scripts to install for $flavor"
    return
  fi

  local created=false
  if [ ! -f "$settings" ]; then
    echo '{}' > "$settings"
    created=true
  fi

  # Determine which hooks are missing (per group, empty-array safe)
  local missing_pw=() missing_pb=() missing_po=() script
  if [ ${#PRE_WRITE_HOOKS[@]} -gt 0 ]; then
    for script in "${PRE_WRITE_HOOKS[@]}"; do
      grep -qF "$script" "$settings" 2>/dev/null || missing_pw+=("$script")
    done
  fi
  if [ ${#PRE_BASH_HOOKS[@]} -gt 0 ]; then
    for script in "${PRE_BASH_HOOKS[@]}"; do
      grep -qF "$script" "$settings" 2>/dev/null || missing_pb+=("$script")
    done
  fi
  if [ ${#POST_BASH_HOOKS[@]} -gt 0 ]; then
    for script in "${POST_BASH_HOOKS[@]}"; do
      grep -qF "$script" "$settings" 2>/dev/null || missing_po+=("$script")
    done
  fi

  if [ ${#missing_pw[@]} -eq 0 ] && [ ${#missing_pb[@]} -eq 0 ] && [ ${#missing_po[@]} -eq 0 ]; then
    echo "Hooks already configured in $settings"
    return
  fi

  local all_missing=()
  [ ${#missing_pw[@]} -gt 0 ] && all_missing+=("${missing_pw[@]}")
  [ ${#missing_pb[@]} -gt 0 ] && all_missing+=("${missing_pb[@]}")
  [ ${#missing_po[@]} -gt 0 ] && all_missing+=("${missing_po[@]}")

  # Merge missing hooks into existing settings using python3 (available on macOS)
  python3 - "$settings" "${#missing_pw[@]}" "${#missing_pb[@]}" "${all_missing[@]}" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
num_pw = int(sys.argv[2])
num_pb = int(sys.argv[3])
scripts = sys.argv[4:]
pre_write = scripts[:num_pw]
pre_bash = scripts[num_pw:num_pw + num_pb]
post_bash = scripts[num_pw + num_pb:]

with open(settings_path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})

def add_hooks(phase, matcher, cmds, prefix_bash):
    if not cmds:
        return
    entries = hooks.setdefault(phase, [])
    entry = None
    for e in entries:
        if e.get("matcher") == matcher:
            entry = e
            break
    if entry is None:
        entry = {"matcher": matcher, "hooks": []}
        entries.append(entry)
    existing = {h.get("command", "") for h in entry.get("hooks", [])}
    for script in cmds:
        cmd = f"bash {script}" if prefix_bash else script
        if cmd not in existing:
            entry["hooks"].append({"type": "command", "command": cmd})

add_hooks("PreToolUse", "Write|Edit|MultiEdit", pre_write, True)
add_hooks("PreToolUse", "Bash", pre_bash, True)
add_hooks("PostToolUse", "Bash", post_bash, False)

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  if [ "$created" = true ]; then
    echo "Created $settings with hooks: ${all_missing[*]}"
  else
    echo "Added hooks to $settings: ${all_missing[*]}"
  fi
}

uninstall_hooks() {
  uninstall_hooks_json ".claude/settings.json"
  uninstall_hooks_json ".codex/hooks.json"
}

uninstall_hooks_json() {
  local settings="$1"
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

# --- Kimi Code hooks (user-level ~/.kimi-code/config.toml only) ---

kimi_config() {
  echo "${KIMI_CODE_HOME:-$HOME/.kimi-code}/config.toml"
}

# Install hooks into Kimi's config.toml as [[hooks]] entries.
# Usage: install_kimi_hooks [name ...] — no names installs all hooks.
install_kimi_hooks() {
  local names=("$@")
  local config
  config="$(kimi_config)"
  mkdir -p "$(dirname "$config")"
  [ -f "$config" ] || touch "$config"
  classify_hooks

  local all_hooks=()
  [ ${#PRE_WRITE_HOOKS[@]} -gt 0 ] && all_hooks+=("${PRE_WRITE_HOOKS[@]}")
  [ ${#PRE_BASH_HOOKS[@]} -gt 0 ] && all_hooks+=("${PRE_BASH_HOOKS[@]}")
  [ ${#POST_BASH_HOOKS[@]} -gt 0 ] && all_hooks+=("${POST_BASH_HOOKS[@]}")
  if [ ${#all_hooks[@]} -eq 0 ]; then
    echo "No hook scripts found in $HOOKS_DIR"
    return
  fi

  # Filter by name if given (matches basename with or without .sh)
  local selected=() script name
  if [ ${#names[@]} -eq 0 ]; then
    selected=("${all_hooks[@]}")
  else
    for script in "${all_hooks[@]}"; do
      for name in "${names[@]}"; do
        if [ "$(basename "$script" .sh)" = "${name%.sh}" ]; then
          selected+=("$script")
          break
        fi
      done
    done
  fi
  if [ ${#selected[@]} -eq 0 ]; then
    echo "No matching hooks found for: ${names[*]}" >&2
    return 1
  fi

  local event matcher
  for script in "${selected[@]}"; do
    case "$(basename "$script")" in
      approve-tests.sh)
        event="PreToolUse"; matcher="Write|Edit"
        echo "Note: approve-tests reads from /dev/tty — if Kimi hooks can't open a tty, spec writes will be blocked."
        ;;
      block-railway.sh)
        event="PreToolUse"; matcher="Bash"
        ;;
      *)
        event="PostToolUse"; matcher="Bash"
        echo "Note: $(basename "$script") prints to stderr, but Kimi only appends stdout to context — nags may not surface."
        ;;
    esac

    if grep -qF "$script" "$config"; then
      echo "Already in $config: $(basename "$script")"
      continue
    fi

    cat >> "$config" <<EOF

[[hooks]]
event = "$event"
matcher = "$matcher"
command = "bash $script"
EOF
    echo "Added to $config: $(basename "$script") ($event, matcher \"$matcher\")"
  done
}

# Remove dotskills [[hooks]] entries from Kimi's config.toml.
# Usage: uninstall_kimi_hooks [name ...] — no names removes all dotskills hooks.
uninstall_kimi_hooks() {
  local config
  config="$(kimi_config)"
  if [ ! -f "$config" ]; then
    echo "No $config found"
    return
  fi
  if ! grep -q "$HOOKS_DIR" "$config" 2>/dev/null; then
    echo "No dotskills hooks found in $config"
    return
  fi

  python3 - "$config" "$HOOKS_DIR" "$@" <<'PYEOF'
import re, sys

config_path = sys.argv[1]
hooks_dir = sys.argv[2]
names = [n[:-3] if n.endswith(".sh") else n for n in sys.argv[3:]]

with open(config_path) as f:
    text = f.read()

parts = re.split(r"(?m)^(?=\[\[hooks\]\])", text)

def should_drop(block):
    if not block.startswith("[[hooks]]") or hooks_dir not in block:
        return False
    if not names:
        return True
    return any(n in block for n in names)

kept = [b for b in parts if not should_drop(b)]
with open(config_path, "w") as f:
    f.write("".join(kept))
PYEOF
  echo "Removed dotskills hooks from $config"
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
  --kimi-hooks)
    shift
    install_kimi_hooks "$@"
    ;;
  --uninstall)
    mode="${2:-}"
    name="${3:-}"
    if [ "$mode" = "--kimi-hooks" ]; then
      shift 2
      uninstall_kimi_hooks "$@"
    elif [ -n "$name" ]; then
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
