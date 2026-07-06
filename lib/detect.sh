#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# detect.sh -- OS and package-manager detection
# ==============================================================================

# Ensure common.sh is loaded (provides log, warn, die, have).
if ! declare -f log &>/dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

# ---------- OS detection ------------------------------------------------------

# detect_os
#   Sets the global OS variable to one of: macos, debian, redhat, unknown.
detect_os() {
    OS="unknown"

    case "$(uname -s)" in
        Darwin)
            OS="macos"
            ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                # shellcheck source=/dev/null
                source /etc/os-release
                local id="${ID:-}"
                local id_like="${ID_LIKE:-}"

                case "$id" in
                    debian|ubuntu|linuxmint|pop|raspbian)
                        OS="debian"
                        ;;
                    fedora|rhel|centos|rocky|alma|ol)
                        OS="redhat"
                        ;;
                    *)
                        # Fall back to ID_LIKE for derivatives.
                        if [[ "$id_like" == *debian* ]] || [[ "$id_like" == *ubuntu* ]]; then
                            OS="debian"
                        elif [[ "$id_like" == *rhel* ]] || [[ "$id_like" == *fedora* ]] || [[ "$id_like" == *centos* ]]; then
                            OS="redhat"
                        fi
                        ;;
                esac
            fi
            ;;
    esac

    export OS
    log "Detected OS: $OS"
}

# ---------- package-manager detection -----------------------------------------

# detect_pkg_manager
#   Sets the global PKG_MANAGER variable based on the detected OS.
#   Must be called after detect_os.
#   Values: brew, apt, dnf, yum, or empty string if nothing found.
detect_pkg_manager() {
    PKG_MANAGER=""

    case "${OS:-unknown}" in
        macos)
            if have brew; then
                PKG_MANAGER="brew"
            else
                warn "Homebrew not found. Install it from https://brew.sh"
            fi
            ;;
        debian)
            if have apt; then
                PKG_MANAGER="apt"
            else
                warn "apt not found on Debian-based system"
            fi
            ;;
        redhat)
            if have dnf; then
                PKG_MANAGER="dnf"
            elif have yum; then
                PKG_MANAGER="yum"
            else
                warn "Neither dnf nor yum found on Red Hat-based system"
            fi
            ;;
        *)
            warn "Unknown OS -- cannot detect package manager"
            ;;
    esac

    export PKG_MANAGER
    log "Package manager: ${PKG_MANAGER:-none}"
}

# ---------- package install wrapper -------------------------------------------

# pkg_install PACKAGE...
#   Install one or more packages using the detected package manager.
#   Respects DRY_RUN via the run() wrapper from common.sh.
pkg_install() {
    if [[ $# -eq 0 ]]; then
        warn "pkg_install called with no packages"
        return 1
    fi

    if [[ -z "${PKG_MANAGER:-}" ]]; then
        die "No package manager available. Run detect_os && detect_pkg_manager first."
    fi

    case "$PKG_MANAGER" in
        brew)
            run brew install "$@"
            ;;
        apt)
            run sudo apt install -y "$@"
            ;;
        dnf)
            run sudo dnf install -y "$@"
            ;;
        yum)
            run sudo yum install -y "$@"
            ;;
        *)
            die "Unsupported package manager: $PKG_MANAGER"
            ;;
    esac
}
