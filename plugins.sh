#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_FILE="$SCRIPT_DIR/plugins.txt"
MARKETPLACES_FILE="$SCRIPT_DIR/marketplaces.txt"

usage() {
  cat <<EOF
Usage: ./plugins.sh <command> [args]

Commands:
  install                        Install all marketplaces + plugins from manifest
  list                           Show what's in plugins.txt and marketplaces.txt
  add <plugin@marketplace>       Add to plugins.txt and install
  remove <plugin@marketplace>    Remove from plugins.txt and uninstall

Examples:
  ./plugins.sh install
  ./plugins.sh list
  ./plugins.sh add skill-codex@claude-plugins-official
  ./plugins.sh remove skill-codex@claude-plugins-official
EOF
  exit 1
}

# Read non-empty, non-comment lines from a file
read_lines() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -v '^\s*#' "$file" | grep -v '^\s*$' || true
}

install_marketplaces() {
  while IFS=' ' read -r name repo; do
    [ -z "$name" ] && continue
    echo "Registering marketplace: $name ($repo)"
    claude plugin marketplace add "https://github.com/$repo" || echo "  Warning: failed to add marketplace $name"
  done < <(read_lines "$MARKETPLACES_FILE")
}

install_plugins() {
  while IFS= read -r plugin; do
    [ -z "$plugin" ] && continue
    echo "Installing plugin: $plugin"
    claude plugin install "$plugin" --scope user || echo "  Warning: failed to install $plugin"
  done < <(read_lines "$PLUGINS_FILE")
}

list_items() {
  echo "Marketplaces:"
  if [ -f "$MARKETPLACES_FILE" ]; then
    local has_items=false
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "  $line"
      has_items=true
    done < <(read_lines "$MARKETPLACES_FILE")
    $has_items || echo "  (none)"
  else
    echo "  (no marketplaces.txt found)"
  fi

  echo ""
  echo "Plugins:"
  if [ -f "$PLUGINS_FILE" ]; then
    local has_items=false
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "  $line"
      has_items=true
    done < <(read_lines "$PLUGINS_FILE")
    $has_items || echo "  (none)"
  else
    echo "  (no plugins.txt found)"
  fi
}

add_plugin() {
  local plugin="$1"

  # Check if already in manifest
  if grep -qF "$plugin" "$PLUGINS_FILE" 2>/dev/null; then
    echo "$plugin is already in plugins.txt"
  else
    echo "$plugin" >> "$PLUGINS_FILE"
    echo "Added $plugin to plugins.txt"
  fi

  echo "Installing $plugin..."
  claude plugin install "$plugin" --scope user
}

remove_plugin() {
  local plugin="$1"

  if grep -qF "$plugin" "$PLUGINS_FILE" 2>/dev/null; then
    grep -vF "$plugin" "$PLUGINS_FILE" > "$PLUGINS_FILE.tmp" && mv "$PLUGINS_FILE.tmp" "$PLUGINS_FILE"
    echo "Removed $plugin from plugins.txt"
  else
    echo "$plugin is not in plugins.txt"
  fi

  echo "Uninstalling $plugin..."
  claude plugin uninstall "$plugin" || echo "  Warning: failed to uninstall $plugin"
}

# --- Main ---

[ $# -eq 0 ] && usage

case "${1:-}" in
  install)
    install_marketplaces
    install_plugins
    echo "Done."
    ;;
  list)
    list_items
    ;;
  add)
    [ -z "${2:-}" ] && { echo "Error: specify plugin@marketplace"; exit 1; }
    add_plugin "$2"
    ;;
  remove)
    [ -z "${2:-}" ] && { echo "Error: specify plugin@marketplace"; exit 1; }
    remove_plugin "$2"
    ;;
  *)
    usage
    ;;
esac
