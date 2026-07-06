#!/usr/bin/env bash
set -euo pipefail

# cli-tools.sh -- Install and verify modern CLI utilities
# Requires: lib/common.sh (log, warn, have, run, DRY_RUN)
#           lib/detect.sh  (pkg_install, OS, PKG_MANAGER)

CLI_TOOLS=(eza fzf zoxide starship direnv)

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
