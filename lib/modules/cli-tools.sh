#!/usr/bin/env bash
set -euo pipefail

# cli-tools.sh -- Install and verify modern CLI utilities
# Requires: lib/common.sh (log, warn, have, run, DRY_RUN)
#           lib/detect.sh  (pkg_install, OS, PKG_MANAGER)

CLI_TOOLS=(eza fzf zoxide starship direnv)

install_cli_tools() {
  log "Installing CLI tools: ${CLI_TOOLS[*]}"

  # ---- eza ----
  case "$OS" in
    macos)  pkg_install eza ;;
    debian) pkg_install eza ;;       # eza is in recent Ubuntu/Debian repos
    redhat) pkg_install eza ;;
  esac

  # ---- fzf ----
  pkg_install fzf

  # ---- direnv ----
  pkg_install direnv

  # ---- starship (official installer, all platforms) ----
  if ! have starship; then
    log "Installing starship via official installer"
    run sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
  fi

  # ---- zoxide (official installer, all platforms) ----
  if ! have zoxide; then
    log "Installing zoxide via official installer"
    run sh -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
  fi
}

# Return: 0 = OK, 1 = FAIL (partially installed), 2 = SKIP (none installed)
check_cli_tools() {
  local missing=()
  local found=0
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

  # If at least one is installed but others are missing, that is a failure
  if (( ${#missing[@]} > 0 )); then
    warn "Missing CLI tools: ${missing[*]}"
    return 1
  fi
  return 0
}

repair_cli_tools() {
  install_cli_tools
}
