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

install_cli_tools() {
  log "Installing CLI tools: ${CLI_TOOLS[*]}"

  # fzf/direnv/eza live in EPEL on Red Hat family systems.
  if [[ "$OS" == "redhat" ]] && ! pkg_install epel-release; then
    warn "Could not enable EPEL -- some CLI tools may be unavailable"
  fi

  # ---- eza ----
  case "$OS" in
    macos)  if ! pkg_install eza; then warn "eza is not available from $PKG_MANAGER; install it manually (https://eza.rocks)"; fi ;;
    debian) if ! pkg_install eza; then warn "eza is not available from $PKG_MANAGER; install it manually (https://eza.rocks)"; fi ;;       # eza is in recent Ubuntu/Debian repos
    redhat) if ! pkg_install eza; then warn "eza is not available from $PKG_MANAGER; install it manually (https://eza.rocks)"; fi ;;
  esac

  # ---- fzf ----
  if ! pkg_install fzf; then
    warn "fzf is not available from $PKG_MANAGER; install it manually (https://github.com/junegunn/fzf)"
  fi

  # ---- direnv ----
  if ! pkg_install direnv; then
    warn "direnv is not available from $PKG_MANAGER; install it manually (https://direnv.net)"
  fi

  # ---- starship (official installer, all platforms) ----
  if ! have starship; then
    log "Installing starship via official installer"
    fetch_and_run_installer https://starship.rs/install.sh -y
    if ! have starship && [[ ! -x /usr/local/bin/starship ]] && [[ ! -x "$HOME/.local/bin/starship" ]]; then
      warn "starship installation appears to have failed"
    fi
  fi

  # ---- zoxide (official installer, all platforms) ----
  if ! have zoxide; then
    log "Installing zoxide via official installer"
    fetch_and_run_installer https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh
    if ! have zoxide && [[ ! -x /usr/local/bin/zoxide ]] && [[ ! -x "$HOME/.local/bin/zoxide" ]]; then
      warn "zoxide installation appears to have failed"
    fi
  fi
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
