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
      run sudo dnf module install -y nodejs
      ;;
  esac

  # Set npm global prefix to ~/.local for non-root installs
  if have npm; then
    log "Setting npm prefix to ~/.local"
    run npm config set prefix "$HOME/.local"
  fi
}

check_node() {
  # If npm is not installed, treat as skipped
  have npm || return 0

  local prefix
  prefix="$(npm config get prefix 2>/dev/null)"
  if [[ "$prefix" != "$HOME/.local" ]]; then
    warn "npm prefix is '$prefix', expected '$HOME/.local'"
    return 1
  fi
  return 0
}

repair_node() {
  npm config set prefix "$HOME/.local"
}
