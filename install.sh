#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
AGENTS_DIR="$SCRIPT_DIR/agents"
CODEX_AGENTS_DIR="$SCRIPT_DIR/codex-agents"

usage() {
  cat <<EOF
Usage: ./install.sh <mode> [options]

Modes:
  --personal [name]      Install to ~/.claude/ and ~/.codex/ (all projects)
  --project  [name]      Install to ./.claude/ and ./.codex/ (current project)
  --list                 List available skills and agents
  --sync <mode>          Install all + prune dangling/renamed symlinks
                         mode: --personal or --project
  --uninstall <mode> [name]
                         Remove installed symlinks
                         mode: --personal or --project

Skills are installed for both Claude and Codex.
Agents are installed as .md for Claude and .toml for Codex.

Examples:
  ./install.sh --list
  ./install.sh --personal              # Install all skills + agents
  ./install.sh --personal ux           # Install one skill
  ./install.sh --personal deven        # Install one agent
  ./install.sh --project               # Install all into current project
  ./install.sh --sync --personal       # Install all + prune stale symlinks
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
    fi
    ;;
  *)
    usage
    ;;
esac
