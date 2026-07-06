#!/usr/bin/env bash
set -euo pipefail

# uv.sh -- Install and verify uv (Python package manager)
# Requires: lib/common.sh (log, have, run)

install_uv() {
  if have uv; then
    log "uv already installed"
    return
  fi

  log "Installing uv via official installer"
  run sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
}

# Return: 0 = OK, 2 = SKIP (not installed)
check_uv() {
  # If uv is not installed, treat as skipped
  have uv || return 2
  return 0
}

repair_uv() {
  install_uv
}
