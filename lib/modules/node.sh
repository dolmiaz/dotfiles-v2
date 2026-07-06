#!/usr/bin/env bash
set -euo pipefail

# node.sh -- Install and verify Node.js
# Requires: lib/common.sh (log, warn, have, run)
#           lib/detect.sh  (pkg_install, OS)

install_node() {
  log "Installing Node.js"
  case "$OS" in
    macos)
      pkg_install node
      ;;
    debian)
      pkg_install nodejs npm
      ;;
    redhat)
      if have dnf; then
        run sudo dnf module install -y nodejs
      else
        pkg_install nodejs
      fi
      ;;
  esac

  # Set npm global prefix to ~/.local for non-root installs.
  # Use XDG-compliant config path for npmrc.
  if have npm; then
    log "Setting npm prefix to ~/.local"
    export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
    run mkdir -p "$(dirname "$NPM_CONFIG_USERCONFIG")"
    run npm config set prefix "$HOME/.local"
  fi
}

# Return: 0 = OK, 1 = FAIL (wrong npm prefix), 2 = SKIP (npm not installed)
check_node() {
  # If npm is not installed, treat as skipped
  have npm || return 2

  local prefix
  prefix="$(npm config get prefix 2>/dev/null)"
  if [[ "$prefix" != "$HOME/.local" ]]; then
    warn "npm prefix is '$prefix', expected '$HOME/.local'"
    return 1
  fi
  return 0
}

repair_node() {
  export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
  mkdir -p "$(dirname "$NPM_CONFIG_USERCONFIG")"
  npm config set prefix "$HOME/.local"
}
