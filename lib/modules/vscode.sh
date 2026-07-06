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

_vscode_command() {
  if have code; then
    printf '%s\n' "code"
    return 0
  fi

  if [[ "${OS:-}" == "macos" ]]; then
    local app_code="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [[ -x "$app_code" ]]; then
      printf '%s\n' "$app_code"
      return 0
    fi
  fi

  return 1
}

_vscode_install_extensions() {
  local code_cmd="${VSCODE_CODE_CMD:-}"
  if [[ -z "$code_cmd" ]]; then
    code_cmd="$(_vscode_command 2>/dev/null || true)"
  fi

  if [[ -z "$code_cmd" ]]; then
    warn "code command not found; skipping extensions"
    return 0
  fi

  local exts=("$@")
  for ext in "${exts[@]}"; do
    log "Installing VS Code extension: $ext"
    run "$code_cmd" --install-extension "$ext" --force
  done
}

install_vscode() {
  VSCODE_CODE_CMD="$(_vscode_command 2>/dev/null || true)"

  # ---- Install VS Code itself ----
  if [[ -z "$VSCODE_CODE_CMD" ]]; then
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

    VSCODE_CODE_CMD="$(_vscode_command 2>/dev/null || true)"
  elif [[ "$VSCODE_CODE_CMD" != "code" ]]; then
    log "Using VS Code bundled CLI: $VSCODE_CODE_CMD"
  fi

  # ---- Extensions ----
  if [[ -z "$VSCODE_CODE_CMD" ]]; then
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

# Return: 0 = OK, 2 = SKIP (not installed)
check_vscode() {
  # If VS Code is not installed, treat as skipped
  _vscode_command &>/dev/null || return 2
  return 0
}

repair_vscode() {
  install_vscode
}
