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
  for entry in "${ZSH_PLUGINS[@]}"; do
    read -r name url <<< "$entry"
    if [[ -d "$ZSH_PLUGINS_DIR/$name/.git" ]]; then
      log "Updating zsh plugin: $name"
      run git -C "$ZSH_PLUGINS_DIR/$name" pull --quiet
    else
      log "Cloning zsh plugin: $name"
      run git clone --quiet "$url" "$ZSH_PLUGINS_DIR/$name"
    fi
  done
}

check_zsh_plugins() {
  [[ -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]]      || return 1
  [[ -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ]]  || return 1
  return 0
}

repair_zsh_plugins() {
  install_zsh_plugins
}
