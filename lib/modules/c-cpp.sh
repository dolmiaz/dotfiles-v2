#!/usr/bin/env bash
set -euo pipefail

# c-cpp.sh -- Install and verify C/C++ toolchain
# Requires: lib/common.sh (log, warn, have, run)
#           lib/detect.sh  (pkg_install, OS)

install_c_cpp() {
  log "Installing C/C++ toolchain"
  case "$OS" in
    macos)
      # Ensure Xcode command-line tools are present
      if ! xcode-select -p &>/dev/null; then
        log "Installing Xcode command-line tools"
        run xcode-select --install
      fi
      pkg_install cmake
      ;;
    debian)
      pkg_install build-essential cmake gdb
      ;;
    redhat)
      pkg_install gcc gcc-c++ cmake gdb
      ;;
  esac
}

# Return: 0 = OK, 1 = FAIL (cmake present but no compiler), 2 = SKIP (not installed)
check_c_cpp() {
  # cmake is the primary indicator that C/C++ was installed via our setup.
  # System compilers (e.g. macOS /usr/bin/cc) don't count as "our" install.
  have cmake || return 2
  if [[ "$(uname -s)" == "Darwin" ]]; then
    xcode-select -p &>/dev/null || return 1
  fi
  { have gcc || have cc; } || return 1
  return 0
}

repair_c_cpp() {
  install_c_cpp
}
