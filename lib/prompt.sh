#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# prompt.sh -- interactive prompts with --yes (auto-accept) support
# ==============================================================================

# Ensure common.sh is loaded (provides log, warn).
if ! declare -f log &>/dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

# YES mode: when set to 1, all prompts return their default value without
# waiting for user input.  Typically set by install.sh --yes.
YES="${YES:-0}"
export YES

# ---------- yes/no prompt -----------------------------------------------------

# ask QUESTION [DEFAULT]
#   Ask a yes/no question.  DEFAULT is Y or N (defaults to Y).
#   Returns 0 for yes, 1 for no.
#
#   In YES mode, the default answer is used automatically.
ask() {
    local question="${1:?ask: question required}"
    local default="${2:-Y}"
    default="$(printf '%s' "$default" | tr '[:lower:]' '[:upper:]')"  # uppercase (bash 3.2 compatible)

    local prompt
    if [[ "$default" == "Y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    # Auto-accept in YES mode.
    if [[ "$YES" == "1" ]]; then
        log "(auto) $question $prompt -> $default" >&2
        [[ "$default" == "Y" ]]
        return
    fi

    local answer
    printf '%s %s ' "$question" "$prompt" >&2
    read -r answer </dev/tty || answer=""
    answer="${answer:-$default}"
    answer="$(printf '%s' "$answer" | tr '[:lower:]' '[:upper:]')"

    [[ "$answer" == "Y" || "$answer" == "YES" ]]
}

# ---------- text input prompt -------------------------------------------------

# ask_input QUESTION [DEFAULT]
#   Prompt for a text value.  Returns the entered string via stdout.
#
#   In YES mode, DEFAULT is returned without prompting.
ask_input() {
    local question="${1:?ask_input: question required}"
    local default="${2:-}"

    # Auto-accept in YES mode.  log goes to stderr to avoid contaminating
    # the value captured by command substitution.
    if [[ "$YES" == "1" ]]; then
        log "(auto) $question -> ${default:-(empty)}" >&2
        printf '%s' "$default"
        return 0
    fi

    local answer
    if [[ -n "$default" ]]; then
        printf '%s [%s]: ' "$question" "$default" >&2
    else
        printf '%s: ' "$question" >&2
    fi
    read -r answer </dev/tty || answer=""
    printf '%s' "${answer:-$default}"
}

# ---------- profile selection -------------------------------------------------

# select_profile
#   Show a menu to choose a profile: desktop, server, minimal.
#   Prints the selected profile name to stdout.
#
#   In YES mode, defaults to "desktop".
select_profile() {
    local profiles=("desktop" "server" "minimal")
    local default="desktop"

    if [[ "$YES" == "1" ]]; then
        log "(auto) Profile -> $default" >&2
        printf '%s' "$default"
        return 0
    fi

    printf '\nSelect a profile:\n' >&2
    local i
    for i in "${!profiles[@]}"; do
        local marker=""
        if [[ "${profiles[$i]}" == "$default" ]]; then
            marker=" (default)"
        fi
        printf '  %d) %s%s\n' "$((i + 1))" "${profiles[$i]}" "$marker" >&2
    done

    local choice
    printf 'Enter number [1]: ' >&2
    read -r choice </dev/tty || choice=""
    choice="${choice:-1}"

    # Validate input.
    if [[ "$choice" =~ ^[1-3]$ ]]; then
        printf '%s' "${profiles[$((choice - 1))]}"
    else
        warn "Invalid choice '$choice', using default: $default"
        printf '%s' "$default"
    fi
}
