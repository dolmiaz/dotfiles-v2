#!/usr/bin/env bash
set -euo pipefail

# cli-tools.sh -- Install and verify modern CLI utilities
# Requires: lib/common.sh (log, warn, have, run, DRY_RUN)
#           lib/detect.sh  (pkg_install, OS, PKG_MANAGER)

CLI_TOOLS=(eza fzf zoxide starship direnv)

_cli_tool_has_fallback_installer() {
  case "$1" in
    starship|zoxide) return 0 ;;
    *) return 1 ;;
  esac
}

_cli_tool_installable() {
  local tool="$1"
  if _cli_tool_has_fallback_installer "$tool"; then
    return 0
  fi
  if declare -f pkg_available &>/dev/null; then
    pkg_available "$tool"
  else
    return 0
  fi
}

_install_pkg_cli_tool() {
  local tool="$1" manual_url="$2"
  if pkg_install "$tool"; then
    return 0
  fi

  if declare -f pkg_available &>/dev/null && ! pkg_available "$tool"; then
    warn "$tool is not available from ${PKG_MANAGER:-package manager}; install it manually ($manual_url)"
    return 0
  fi

  warn "Failed to install $tool from ${PKG_MANAGER:-package manager}"
  return 1
}

install_cli_tools() {
  log "Installing CLI tools: ${CLI_TOOLS[*]}"
  local failed=0

  # fzf/direnv/eza live in EPEL on Red Hat family systems.
  if [[ "${OS:-}" == "redhat" ]] && ! pkg_install epel-release; then
    warn "Could not enable EPEL -- some CLI tools may be unavailable"
  fi

  # ---- eza ----
  _install_pkg_cli_tool eza "https://eza.rocks" || failed=1

  # ---- fzf ----
  _install_pkg_cli_tool fzf "https://github.com/junegunn/fzf" || failed=1

  # ---- direnv ----
  _install_pkg_cli_tool direnv "https://direnv.net" || failed=1

  # ---- starship (official installer, all platforms) ----
  if ! have starship; then
    log "Installing starship via official installer"
    if ! fetch_and_run_installer https://starship.rs/install.sh -y; then
      failed=1
    fi
    if [[ "${DRY_RUN:-0}" != "1" ]] && ! have starship && [[ ! -x /usr/local/bin/starship ]] && [[ ! -x "$HOME/.local/bin/starship" ]]; then
      warn "starship installation appears to have failed"
      failed=1
    fi
  fi

  # ---- zoxide (official installer, all platforms) ----
  if ! have zoxide; then
    log "Installing zoxide via official installer"
    if ! fetch_and_run_installer https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh; then
      failed=1
    fi
    if [[ "${DRY_RUN:-0}" != "1" ]] && ! have zoxide && [[ ! -x /usr/local/bin/zoxide ]] && [[ ! -x "$HOME/.local/bin/zoxide" ]]; then
      warn "zoxide installation appears to have failed"
      failed=1
    fi
  fi

  return "$failed"
}

# Return: 0 = OK, 1 = FAIL (partially installed), 2 = SKIP (none installed)
check_cli_tools() {
  local missing=()
  local installable_missing=()
  local unavailable_missing=()
  local found=0
  local cmd
  for cmd in "${CLI_TOOLS[@]}"; do
    if have "$cmd"; then
      found=$((found + 1))
    else
      missing+=("$cmd")
    fi
  done

  # If none are installed, treat as skipped (2)
  if (( found == 0 )); then
    return 2
  fi

  for cmd in "${missing[@]}"; do
    if _cli_tool_installable "$cmd"; then
      installable_missing+=("$cmd")
    else
      unavailable_missing+=("$cmd")
    fi
  done

  # Missing tools with a package candidate or fallback installer are repairable.
  if (( ${#installable_missing[@]} > 0 )); then
    warn "Missing CLI tools: ${installable_missing[*]}"
    return 1
  fi

  # If the only missing tools are not available from this distro's package
  # manager and have no fallback installer, treat the configured set as healthy.
  return 0
}

repair_cli_tools() {
  install_cli_tools
}
