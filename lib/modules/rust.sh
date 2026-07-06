#!/usr/bin/env bash
set -euo pipefail

# rust.sh -- Install and verify Rust via rustup
# Requires: lib/common.sh (log, warn, have, run)

_rust_setup_xdg_env() {
  local xdg_data_home
  xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"

  export CARGO_HOME="${CARGO_HOME:-$xdg_data_home/cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-$xdg_data_home/rustup}"

  case ":$PATH:" in
    *":$CARGO_HOME/bin:"*) ;;
    *) export PATH="$CARGO_HOME/bin:$PATH" ;;
  esac
}

_rust_migrate_dir() {
  local old_dir="$1"
  local new_dir="$2"
  local marker="$3"

  [[ -d "$old_dir" ]] || return 0

  if [[ -e "$new_dir/$marker" ]]; then
    warn "Rust XDG target already exists: $new_dir"
    warn "Keeping legacy directory in place: $old_dir"
    return 0
  fi

  local ts
  ts="$(date +%Y%m%d%H%M%S)"

  if [[ -e "$new_dir" ]] || [[ -L "$new_dir" ]]; then
    warn "Moving partial Rust XDG directory aside: $new_dir"
    run mv "$new_dir" "${new_dir}.pre-xdg-migration.${ts}"
  fi

  run mkdir -p "$(dirname "$new_dir")"
  log "Migrating Rust directory: $old_dir -> $new_dir"
  run mv "$old_dir" "$new_dir"
}

_rust_migrate_legacy_dirs() {
  local default_cargo_home default_rustup_home xdg_data_home
  xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  default_cargo_home="$xdg_data_home/cargo"
  default_rustup_home="$xdg_data_home/rustup"

  if [[ "$CARGO_HOME" == "$default_cargo_home" ]]; then
    _rust_migrate_dir "$HOME/.cargo" "$CARGO_HOME" "bin/rustup"
  fi
  if [[ "$RUSTUP_HOME" == "$default_rustup_home" ]]; then
    _rust_migrate_dir "$HOME/.rustup" "$RUSTUP_HOME" "toolchains"
  fi
  return 0
}

install_rust() {
  # Ensure XDG-compliant paths so rustup and cargo match env.d/10-rust.zsh.
  _rust_setup_xdg_env
  _rust_migrate_legacy_dirs

  if have rustup; then
    log "rustup already installed; updating"
    run rustup update
    return
  fi

  log "Installing Rust via rustup (--no-modify-path)"
  fetch_and_run_installer https://sh.rustup.rs -y --no-modify-path || return 1
  if [[ "${DRY_RUN:-0}" != "1" ]] && ! have rustup && [[ ! -x "${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}/bin/rustup" ]]; then
    warn "rustup installation appears to have failed"
    return 1
  fi
}

# Return: 0 = OK, 1 = FAIL (wrong Rust path/config), 2 = SKIP (not installed)
check_rust() {
  _rust_setup_xdg_env

  local rustup_path cargo_path xdg_rustup xdg_cargo
  rustup_path="$(command -v rustup 2>/dev/null || true)"
  cargo_path="$(command -v cargo 2>/dev/null || true)"
  xdg_rustup="$CARGO_HOME/bin/rustup"
  xdg_cargo="$CARGO_HOME/bin/cargo"

  if [[ -z "$rustup_path" ]] && [[ -x "$xdg_rustup" ]]; then
    rustup_path="$xdg_rustup"
  fi
  if [[ -z "$cargo_path" ]] && [[ -x "$xdg_cargo" ]]; then
    cargo_path="$xdg_cargo"
  fi

  [[ -n "$rustup_path" ]] || [[ -n "$cargo_path" ]] || return 2
  [[ -n "$rustup_path" ]] || {
    warn "cargo exists but rustup was not found"
    return 1
  }
  [[ -n "$cargo_path" ]] || {
    warn "rustup exists but cargo was not found"
    return 1
  }
  rustup show active-toolchain &>/dev/null || return 1
  return 0
}

repair_rust() {
  install_rust
}
