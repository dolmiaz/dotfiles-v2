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

check_c_cpp() {
  local has_compiler=0 has_cmake=0
  { have gcc || have cc; } && has_compiler=1
  have cmake && has_cmake=1
  # Nothing installed at all -- skip (not an error).
  (( has_compiler == 0 && has_cmake == 0 )) && return 0
  # Both present -- OK.
  (( has_compiler && has_cmake )) || return 1
  return 0
}

repair_c_cpp() {
  install_c_cpp
}
