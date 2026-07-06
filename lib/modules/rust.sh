#!/usr/bin/env bash
set -euo pipefail

# rust.sh -- Install and verify Rust via rustup
# Requires: lib/common.sh (log, warn, have, run)

install_rust() {
  # Ensure XDG-compliant paths so rustup and cargo match env.d/10-rust.zsh.
  export CARGO_HOME="${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/rustup}"

  if have rustup; then
    log "rustup already installed; updating"
    run rustup update
    return
  fi

  log "Installing Rust via rustup (--no-modify-path)"
  run sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
}

check_rust() {
  have rustup || return 0
  have cargo || return 1
  return 0
}

repair_rust() {
  install_rust
}
