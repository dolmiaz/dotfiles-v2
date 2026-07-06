#!/usr/bin/env bash
set -euo pipefail

# rust.sh -- Install and verify Rust via rustup
# Requires: lib/common.sh (log, warn, have, run)

install_rust() {
  if have rustup; then
    log "rustup already installed; updating"
    run rustup update
    return
  fi

  log "Installing Rust via rustup (--no-modify-path)"
  run sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
}

check_rust() {
  # If rustup is not installed, treat as skipped
  have rustup || return 0
  have cargo || return 1
  [[ -d "${CARGO_HOME:-$HOME/.cargo}/bin" ]] || return 1
  return 0
}

repair_rust() {
  install_rust
}
