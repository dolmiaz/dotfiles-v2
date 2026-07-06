#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# common.sh -- dotfiles installer utility functions
# ==============================================================================

# Resolve the dotfiles root directory from the location of the sourcing script.
# Works whether the script is called directly or sourced via symlink.
DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")")" && cd .. && pwd)"
export DOTFILES_DIR

# DRY_RUN mode: when set to 1, run() prints commands instead of executing them.
DRY_RUN="${DRY_RUN:-0}"
export DRY_RUN

# ---------- colour helpers (tty-aware) ----------------------------------------

_use_color() {
    [[ -t 1 ]] && [[ -t 2 ]]
}

if _use_color; then
    _RED=$'\033[0;31m'
    _GREEN=$'\033[0;32m'
    _YELLOW=$'\033[0;33m'
    _CYAN=$'\033[0;36m'
    _RESET=$'\033[0m'
else
    _RED=""
    _GREEN=""
    _YELLOW=""
    _CYAN=""
    _RESET=""
fi

# ---------- logging -----------------------------------------------------------

# log MESSAGE...
#   Print an informational message in green.
log() {
    printf '%s[INFO]%s %s\n' "$_GREEN" "$_RESET" "$*"
}

# warn MESSAGE...
#   Print a warning message in yellow to stderr.
warn() {
    printf '%s[WARN]%s %s\n' "$_YELLOW" "$_RESET" "$*" >&2
}

# die MESSAGE...
#   Print an error message in red to stderr and exit 1.
die() {
    printf '%s[ERROR]%s %s\n' "$_RED" "$_RESET" "$*" >&2
    exit 1
}

# ---------- command helpers ---------------------------------------------------

# have COMMAND
#   Return 0 if COMMAND exists on PATH, 1 otherwise.
have() {
    command -v "$1" &>/dev/null
}

# run COMMAND [ARGS...]
#   Execute COMMAND with ARGS.  When DRY_RUN=1, print the command instead.
run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '%s[DRY-RUN]%s %s\n' "$_CYAN" "$_RESET" "$*"
        return 0
    fi
    "$@"
}
