#!/usr/bin/env bash
set -euo pipefail

# vscode.sh -- Install and verify VS Code + extensions
# Requires: lib/common.sh (log, warn, have, run, DRY_RUN)
#           lib/detect.sh  (OS)

# Extensions installed unconditionally
VSCODE_EXTENSIONS_ALWAYS=(
  ms-vscode-remote.remote-ssh
  ms-vscode.remote-explorer
  editorconfig.editorconfig
  esbenp.prettier-vscode
)

# Toolchain-specific extensions
VSCODE_EXTENSIONS_C_CPP=(ms-vscode.cpptools ms-vscode.cmake-tools)
VSCODE_EXTENSIONS_RUST=(rust-lang.rust-analyzer)
VSCODE_EXTENSIONS_UV=(ms-python.python ms-python.vscode-pylance)
VSCODE_EXTENSIONS_NODE=(dbaeumer.vscode-eslint)

_vscode_install_extensions() {
  local exts=("$@")
  for ext in "${exts[@]}"; do
    log "Installing VS Code extension: $ext"
    run code --install-extension "$ext" --force
  done
}

install_vscode() {
  # ---- Install VS Code itself ----
  if ! have code; then
    log "Installing VS Code"
    case "$OS" in
      macos)
        run brew install --cask visual-studio-code
        ;;
      debian)
        if have snap; then
          run sudo snap install code --classic
        else
          warn "snap not found; skipping VS Code installation"
          return
        fi
        ;;
      redhat)
        if have snap; then
          run sudo snap install code --classic
        else
          warn "snap not found; skipping VS Code installation"
          return
        fi
        ;;
    esac
  fi

  # ---- Extensions ----
  if ! have code; then
    warn "code command not found after install; skipping extensions"
    return
  fi

  # Always-install extensions
  _vscode_install_extensions "${VSCODE_EXTENSIONS_ALWAYS[@]}"

  # Conditional extensions based on installed toolchains
  if have gcc || have cc; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_C_CPP[@]}"
  fi
  if have rustup; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_RUST[@]}"
  fi
  if have uv; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_UV[@]}"
  fi
  if have npm; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_NODE[@]}"
  fi
}

check_vscode() {
  # If VS Code is not installed, treat as skipped
  have code || return 0
  return 0
}

repair_vscode() {
  install_vscode
}
