#!/usr/bin/env bash
set -euo pipefail

# zsh-plugins.sh -- Install and verify zsh plugins
# Requires: lib/common.sh (log, warn, have, run)

ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

ZSH_PLUGINS=(
  "zsh-autosuggestions   https://github.com/zsh-users/zsh-autosuggestions.git"
  "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

install_zsh_plugins() {
  run mkdir -p "$ZSH_PLUGINS_DIR"

  local name url
  local fail_count=0
  for entry in "${ZSH_PLUGINS[@]}"; do
    read -r name url <<< "$entry"
    if [[ -d "$ZSH_PLUGINS_DIR/$name/.git" ]]; then
      log "Updating zsh plugin: $name"
      if ! run git -C "$ZSH_PLUGINS_DIR/$name" pull --quiet; then
        warn "Failed to update/clone zsh plugin: $name"
        fail_count=$((fail_count + 1))
      fi
    else
      log "Cloning zsh plugin: $name"
      if ! run git clone --quiet "$url" "$ZSH_PLUGINS_DIR/$name"; then
        warn "Failed to update/clone zsh plugin: $name"
        fail_count=$((fail_count + 1))
      fi
    fi
  done

  # If every plugin failed, report overall failure so install.sh counts this
  # module as failed; a partial failure still returns success.
  if [[ "$fail_count" -eq "${#ZSH_PLUGINS[@]}" ]]; then
    return 1
  fi
  return 0
}

# Return: 0 = OK, 1 = FAIL (incomplete), 2 = SKIP (not installed)
check_zsh_plugins() {
  local plugin_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
  # Plugin directory does not exist -- not installed, skip.
  [[ -d "$plugin_dir" ]] || return 2
  # Directory exists but plugins are missing -- incomplete.
  [[ -r "$plugin_dir/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] || return 1
  [[ -r "$plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] || return 1
  return 0
}

repair_zsh_plugins() {
  install_zsh_plugins
}
