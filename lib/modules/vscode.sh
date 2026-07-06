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

_vscode_cargo_bin_dir() {
  printf '%s\n' "${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}/bin"
}

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
  else
    # snap's bin dir may not be on PATH in the installing shell.
    if [[ -x /snap/bin/code ]]; then
      printf '%s\n' "/snap/bin/code"
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
  local attempts=0
  local failures=0
  local ext
  for ext in "${exts[@]}"; do
    attempts=$((attempts + 1))
    log "Installing VS Code extension: $ext"
    if ! run "$code_cmd" --install-extension "$ext" --force; then
      warn "Failed to install VS Code extension: $ext"
      failures=$((failures + 1))
    fi
  done

  if (( attempts > 0 )) && (( failures == attempts )); then
    warn "All VS Code extension installs failed"
    return 1
  fi
  return 0
}

_vscode_has_c_cpp_toolchain() {
  have gcc || have cc
}

_vscode_has_rust_toolchain() {
  have rustup || [[ -x "$(_vscode_cargo_bin_dir)/rustup" ]]
}

_vscode_has_uv_toolchain() {
  have uv || [[ -x "$HOME/.local/bin/uv" ]]
}

_vscode_has_node_toolchain() {
  have npm
}

_vscode_should_install_c_cpp_extensions() {
  _vscode_has_c_cpp_toolchain || [[ "${INSTALL_C_CPP:-0}" == "1" ]]
}

_vscode_should_install_rust_extensions() {
  _vscode_has_rust_toolchain || [[ "${INSTALL_RUST:-0}" == "1" ]]
}

_vscode_should_install_uv_extensions() {
  _vscode_has_uv_toolchain || [[ "${INSTALL_UV:-0}" == "1" ]]
}

_vscode_should_install_node_extensions() {
  _vscode_has_node_toolchain || [[ "${INSTALL_NODE:-0}" == "1" ]]
}

_vscode_expected_extensions() {
  local ext
  for ext in "${VSCODE_EXTENSIONS_ALWAYS[@]}"; do
    printf '%s\n' "$ext"
  done

  if _vscode_has_c_cpp_toolchain; then
    for ext in "${VSCODE_EXTENSIONS_C_CPP[@]}"; do
      printf '%s\n' "$ext"
    done
  fi
  if _vscode_has_rust_toolchain; then
    for ext in "${VSCODE_EXTENSIONS_RUST[@]}"; do
      printf '%s\n' "$ext"
    done
  fi
  if _vscode_has_uv_toolchain; then
    for ext in "${VSCODE_EXTENSIONS_UV[@]}"; do
      printf '%s\n' "$ext"
    done
  fi
  if _vscode_has_node_toolchain; then
    for ext in "${VSCODE_EXTENSIONS_NODE[@]}"; do
      printf '%s\n' "$ext"
    done
  fi
}

_vscode_extension_installed() {
  local installed="$1" ext="$2" ext_lower
  ext_lower="$(printf '%s\n' "$ext" | tr '[:upper:]' '[:lower:]')"
  printf '%s\n' "$installed" | grep -Fxq "$ext_lower"
}

_vscode_check_extensions() {
  local code_cmd="$1"
  local installed expected ext missing=0

  if ! installed="$("$code_cmd" --list-extensions 2>/dev/null)"; then
    return 0
  fi
  installed="$(printf '%s\n' "$installed" | tr '[:upper:]' '[:lower:]')"
  expected="$(_vscode_expected_extensions)"

  while IFS= read -r ext; do
    [[ -n "$ext" ]] || continue
    if ! _vscode_extension_installed "$installed" "$ext"; then
      warn "Missing VS Code extension: $ext"
      missing=1
    fi
  done <<< "$expected"

  [[ "$missing" == "0" ]]
}

_vscode_settings_path() {
  local os_name="${OS:-}"
  if [[ -z "$os_name" ]]; then
    case "$(uname -s 2>/dev/null || true)" in
      Darwin) os_name="macos" ;;
      Linux)  os_name="linux" ;;
    esac
  fi

  case "$os_name" in
    macos)
      printf '%s\n' "$HOME/Library/Application Support/Code/User/settings.json"
      ;;
    debian|redhat|linux)
      printf '%s\n' "$HOME/.config/Code/User/settings.json"
      ;;
    *)
      return 1
      ;;
  esac
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
          pkg_run_priv snap install code --classic
        else
          warn "snap not found; skipping VS Code installation"
          return
        fi
        ;;
      redhat)
        if have snap; then
          pkg_run_priv snap install code --classic
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
  if _vscode_should_install_c_cpp_extensions; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_C_CPP[@]}"
  fi
  if _vscode_should_install_rust_extensions; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_RUST[@]}"
  fi
  if _vscode_should_install_uv_extensions; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_UV[@]}"
  fi
  if _vscode_should_install_node_extensions; then
    _vscode_install_extensions "${VSCODE_EXTENSIONS_NODE[@]}"
  fi

  # ---- Settings ----
  _vscode_deploy_settings
}

# _vscode_deploy_settings
#   Deploy config/vscode/settings.json to the OS-correct VS Code settings
#   path.  Guarded on deploy_file since doctor.sh may source this module
#   standalone without lib/deploy.sh loaded.
_vscode_deploy_settings() {
  if ! declare -f deploy_file >/dev/null; then
    return 0
  fi

  local src="$DOTFILES_DIR/config/vscode/settings.json"
  [[ -r "$src" ]] || return 0

  local dest
  dest="$(_vscode_settings_path 2>/dev/null || true)"
  if [[ -z "$dest" ]]; then
    warn "Unknown OS -- skipping VS Code settings.json deployment"
    return 0
  fi

  deploy_file "$src" "$dest"
}

# Return: 0 = OK, 2 = SKIP (not installed)
check_vscode() {
  # If VS Code is not installed, treat as skipped
  local code_cmd
  code_cmd="$(_vscode_command 2>/dev/null || true)"
  [[ -n "$code_cmd" ]] || return 2

  local settings_file
  settings_file="$(_vscode_settings_path 2>/dev/null || true)"
  [[ -n "$settings_file" ]] || return 1
  [[ -f "$settings_file" ]] || return 1
  _vscode_check_extensions "$code_cmd" || return 1
  return 0
}

repair_vscode() {
  install_vscode
}
