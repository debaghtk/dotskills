#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
AGENTS_DIR="$SCRIPT_DIR/agents"

usage() {
  cat <<EOF
Usage: ./install.sh <mode> [options]

Modes:
  --personal [name]      Install to ~/.claude/ (all projects)
  --project  [name]      Install to ./.claude/ (current project)
  --list                 List available skills and agents
  --uninstall <mode> [name]
                         Remove installed symlinks
                         mode: --personal or --project

Examples:
  ./install.sh --list
  ./install.sh --personal              # Install all skills + agents
  ./install.sh --personal ux           # Install one skill
  ./install.sh --personal deven        # Install one agent
  ./install.sh --project               # Install all into current project
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

resolve_target_dir() {
  local mode="$1" item_type="$2"
  local base
  if [ "$mode" = "--personal" ]; then
    base="$HOME/.claude"
  elif [ "$mode" = "--project" ]; then
    base="$(pwd)/.claude"
  else
    echo "Error: specify --personal or --project" >&2
    exit 1
  fi

  if [ "$item_type" = "skill" ]; then
    echo "$base/skills"
  else
    echo "$base/agents"
  fi
}

install_item() {
  local name="$1" mode="$2"
  resolve_item "$name"
  local target_dir
  target_dir="$(resolve_target_dir "$mode" "$ITEM_TYPE")"
  mkdir -p "$target_dir"

  local dest
  if [ "$ITEM_TYPE" = "skill" ]; then
    dest="$target_dir/$name"
  else
    dest="$target_dir/$name.md"
  fi

  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    echo "Warning: $dest exists and is not a symlink, skipping" >&2
    return 1
  fi

  ln -s "$ITEM_SRC" "$dest"
  echo "Installed $ITEM_TYPE '$name' -> $dest"
}

uninstall_item() {
  local name="$1" mode="$2"
  resolve_item "$name"
  local target_dir
  target_dir="$(resolve_target_dir "$mode" "$ITEM_TYPE")"

  local dest
  if [ "$ITEM_TYPE" = "skill" ]; then
    dest="$target_dir/$name"
  else
    dest="$target_dir/$name.md"
  fi

  if [ -L "$dest" ]; then
    rm "$dest"
    echo "Removed $dest"
  elif [ -e "$dest" ]; then
    echo "Warning: $dest is not a symlink, skipping" >&2
  else
    echo "Not installed: $name"
  fi
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
