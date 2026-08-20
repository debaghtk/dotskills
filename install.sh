#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
AGENTS_DIR="$SCRIPT_DIR/agents"
CODEX_AGENTS_DIR="$SCRIPT_DIR/codex-agents"
OPENCODE_AGENTS_DIR="$SCRIPT_DIR/opencode-agents"
PROBLEMS_DIR="$SCRIPT_DIR/problems"
HOOKS_DIR="$SCRIPT_DIR/hooks"

usage() {
  cat <<EOF
Usage: ./install.sh <mode> [options]

Modes:
  --personal [name]      Install to ~/.claude/, ~/.codex/, ~/.kimi-code/, and
                         ~/.config/opencode/ (all projects)
  --project  [name]      Install to ./.claude/, ./.codex/, ./.kimi-code/, and
                         ./.opencode/ (current project)
                         Also copies problems/ template and installs hooks
  --list                 List available skills and agents
  --sync <mode>          Install all + prune dangling/renamed symlinks
                         mode: --personal or --project
  --problems             Copy problems/ registry template into current project
  --hooks                Install hooks into ./.claude/settings.json,
                         ./.codex/hooks.json, and ./.opencode/plugins/
                         (current project)
  --kimi-hooks [name..]  Install hooks into ~/.kimi-code/config.toml
                         (user-level, all projects; no name = all hooks)
  --opencode-hooks       Install the hooks plugin into
                         ~/.config/opencode/plugins/ (user-level, all projects)
  --uninstall <mode> [name]
                         Remove installed symlinks (and hooks if --project)
                         mode: --personal, --project, --kimi-hooks [name..],
                         or --opencode-hooks

Skills are installed for Claude, Codex, Kimi Code, and OpenCode.
Agents are installed as .md for Claude and Kimi Code, .toml for Codex, and
.md (OpenCode's own agent format) for OpenCode.
Problems template is copied (not symlinked) — each project owns its registry.
Hooks point back to dotskills source, so they stay up to date.
Note: Codex hooks require codex_hooks = true under [features] in
~/.codex/config.toml, and only support Bash (no file-write hooks).
Note: the OpenCode hooks plugin shells out to the same bash scripts as the
other tools — see hooks/README.md for its caveats (no per-hook selection).

Examples:
  ./install.sh --list
  ./install.sh --personal                   # Install all skills + agents
  ./install.sh --personal ux                # Install one skill
  ./install.sh --personal my-agent          # Install one agent
  ./install.sh --project                    # Install all + problems + hooks
  ./install.sh --sync --personal            # Install all + prune stale symlinks
  ./install.sh --problems                   # Just copy problems/ template
  ./install.sh --hooks                      # Just install hooks (claude + codex + opencode)
  ./install.sh --kimi-hooks block-railway   # Install one hook for Kimi
  ./install.sh --opencode-hooks             # Install hooks plugin for OpenCode (personal)
  ./install.sh --uninstall --kimi-hooks     # Remove all dotskills Kimi hooks
  ./install.sh --uninstall --opencode-hooks # Remove dotskills OpenCode hooks plugin
  ./install.sh --uninstall --personal       # Remove all symlinks
EOF
  exit 1
}

# Extract the value of a top-level "description:" frontmatter key from a
# skill/agent file. Handles a plain (optionally quoted) single-line value as
# well as YAML block scalars (`description: >` or `description: |`, with or
# without chomping indicators), which a plain regex would otherwise flatten
# to just the scalar indicator itself.
extract_description() {
  awk '
    !found && /^description:/ {
      val = $0
      sub(/^description: */, "", val)
      if (val ~ /^[>|][+-]?$/) {
        folded = 1
        next
      }
      gsub(/^"|"$/, "", val)
      print val
      found = 1
      exit
    }
    folded && /^[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      buf = (buf == "") ? line : buf " " line
      next
    }
    folded {
      print buf
      found = 1
      exit
    }
    END {
      if (folded && !found) print buf
    }
  ' "$1"
}

list_items() {
  if [ -d "$SKILLS_DIR" ]; then
    echo "Skills:"
    for dir in "$SKILLS_DIR"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      desc=""
      [ -f "$dir/SKILL.md" ] && desc=$(extract_description "$dir/SKILL.md")
      printf "  %-20s %s\n" "$name" "$desc"
    done
  fi
  if [ -d "$AGENTS_DIR" ]; then
    echo ""
    echo "Agents:"
    for file in "$AGENTS_DIR"/*.md; do
      [ -f "$file" ] || continue
      name="$(basename "$file" .md)"
      desc=$(extract_description "$file")
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

# Returns target dirs for a given mode/type/tool combo, one "tool:path" pair
# per line. Tool tags are explicit (not sniffed from the path) since
# "opencode" contains "codex" as a substring and would confuse a pattern
# match on the base dir.
resolve_target_dirs() {
  local mode="$1" item_type="$2"
  local claude_base codex_base kimi_base opencode_base
  if [ "$mode" = "--personal" ]; then
    claude_base="$HOME/.claude"
    codex_base="$HOME/.codex"
    kimi_base="${KIMI_CODE_HOME:-$HOME/.kimi-code}"
    opencode_base="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  elif [ "$mode" = "--project" ]; then
    claude_base="$(pwd)/.claude"
    codex_base="$(pwd)/.codex"
    kimi_base="$(pwd)/.kimi-code"
    opencode_base="$(pwd)/.opencode"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  local sub
  if [ "$item_type" = "skill" ]; then
    sub="skills"
  else
    sub="agents"
  fi
  echo "claude:$claude_base/$sub"
  echo "codex:$codex_base/$sub"
  echo "kimi:$kimi_base/$sub"
  echo "opencode:$opencode_base/$sub"
}

install_item() {
  local name="$1" mode="$2"
  resolve_item "$name"

  while IFS=: read -r tool target_dir; do
    mkdir -p "$target_dir"

    local src="$ITEM_SRC" dest
    if [ "$ITEM_TYPE" = "skill" ]; then
      dest="$target_dir/$name"
    elif [ "$tool" = "codex" ]; then
      # Codex agents use .toml files from codex-agents/
      if [ ! -f "$CODEX_AGENTS_DIR/$name.toml" ]; then
        echo "Skipping agent '$name' for Codex (no .toml version)" >&2
        continue
      fi
      src="$CODEX_AGENTS_DIR/$name.toml"
      dest="$target_dir/$name.toml"
    elif [ "$tool" = "opencode" ]; then
      # OpenCode agents use their own frontmatter dialect from opencode-agents/
      if [ ! -f "$OPENCODE_AGENTS_DIR/$name.md" ]; then
        echo "Skipping agent '$name' for OpenCode (no opencode-agents version)" >&2
        continue
      fi
      src="$OPENCODE_AGENTS_DIR/$name.md"
      dest="$target_dir/$name.md"
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

  while IFS=: read -r tool target_dir; do
    local dest
    if [ "$ITEM_TYPE" = "skill" ]; then
      dest="$target_dir/$name"
    elif [ "$tool" = "codex" ]; then
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
  local claude_base codex_base kimi_base opencode_base
  if [ "$mode" = "--personal" ]; then
    claude_base="$HOME/.claude"
    codex_base="$HOME/.codex"
    kimi_base="${KIMI_CODE_HOME:-$HOME/.kimi-code}"
    opencode_base="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  elif [ "$mode" = "--project" ]; then
    claude_base="$(pwd)/.claude"
    codex_base="$(pwd)/.codex"
    kimi_base="$(pwd)/.kimi-code"
    opencode_base="$(pwd)/.opencode"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  for dir in "$claude_base/skills" "$claude_base/agents" "$codex_base/skills" "$codex_base/agents" "$kimi_base/skills" "$kimi_base/agents" "$opencode_base/skills" "$opencode_base/agents"; do
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

# Install hooks into the current project's .claude/settings.json, .codex/hooks.json,
# and .opencode/plugins/
install_hooks() {
  install_hooks_json ".claude/settings.json" claude
  install_hooks_json ".codex/hooks.json" codex
  install_opencode_plugin "$(pwd)/.opencode"
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
  uninstall_opencode_plugin "$(pwd)/.opencode"
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

# --- OpenCode hooks (plugin-based, no JSON config to merge) ---

opencode_config_dir() {
  echo "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
}

# Symlink the OpenCode hooks plugin into <base>/plugins/. OpenCode auto-loads
# any file dropped in that directory at startup — no config.json entry needed.
install_opencode_plugin() {
  local base="$1"
  local plugin_dir="$base/plugins"
  local dest="$plugin_dir/dotskills-hooks.js"
  local src="$HOOKS_DIR/opencode-plugin.js"

  if [ ! -f "$src" ]; then
    echo "No opencode-plugin.js found in $HOOKS_DIR"
    return
  fi

  mkdir -p "$plugin_dir"
  if [ -L "$dest" ]; then
    echo "OpenCode hooks plugin already installed at $dest"
    return
  elif [ -e "$dest" ]; then
    echo "Warning: $dest exists and is not a symlink, skipping" >&2
    return
  fi

  ln -s "$src" "$dest"
  echo "Installed OpenCode hooks plugin -> $dest"
}

uninstall_opencode_plugin() {
  local base="$1"
  local dest="$base/plugins/dotskills-hooks.js"

  if [ -L "$dest" ]; then
    rm "$dest"
    echo "Removed $dest"
  elif [ -e "$dest" ]; then
    echo "Warning: $dest is not a symlink, skipping" >&2
  else
    echo "No dotskills OpenCode hooks plugin found at $dest"
  fi
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
  --opencode-hooks)
    install_opencode_plugin "$(opencode_config_dir)"
    ;;
  --uninstall)
    mode="${2:-}"
    name="${3:-}"
    if [ "$mode" = "--kimi-hooks" ]; then
      shift 2
      uninstall_kimi_hooks "$@"
    elif [ "$mode" = "--opencode-hooks" ]; then
      uninstall_opencode_plugin "$(opencode_config_dir)"
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
