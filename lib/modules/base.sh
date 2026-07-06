#!/usr/bin/env bash
set -euo pipefail

# base.sh -- Install and verify essential packages
# Requires: lib/common.sh (log, warn, have, run)
#           lib/detect.sh  (pkg_install)

BASE_PACKAGES=(zsh git vim curl wget unzip)

install_base() {
  log "Installing base packages: ${BASE_PACKAGES[*]}"
  pkg_install "${BASE_PACKAGES[@]}"
}

# Return: 0 = OK, 1 = FAIL (base packages are always expected, so never SKIP)
check_base() {
  local missing=()
  for cmd in "${BASE_PACKAGES[@]}"; do
    have "$cmd" || missing+=("$cmd")
  done
  if (( ${#missing[@]} > 0 )); then
    warn "Missing base packages: ${missing[*]}"
    return 1
  fi
  return 0
}

repair_base() {
  install_base
}
