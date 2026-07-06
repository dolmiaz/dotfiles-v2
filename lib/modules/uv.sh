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
  fetch_and_run_installer https://astral.sh/uv/install.sh || return 1
  if [[ "${DRY_RUN:-0}" != "1" ]] && ! have uv && [[ ! -x /usr/local/bin/uv ]] && [[ ! -x "$HOME/.local/bin/uv" ]]; then
    warn "uv installation appears to have failed"
    return 1
  fi
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
