#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# doctor.sh -- dotfiles diagnostic and auto-repair tool
#
# Usage:
#   ./doctor.sh [OPTIONS]
#
# Checks the health of the dotfiles environment and optionally repairs issues.
# Inspired by `brew doctor` and `flutter doctor`.
# ==============================================================================

# ---------- bootstrap ---------------------------------------------------------

_target="${BASH_SOURCE[0]}"
while [[ -L "$_target" ]]; do
    _dir="$(cd "$(dirname "$_target")" && pwd)"
    _target="$(readlink "$_target")"
    [[ "$_target" != /* ]] && _target="$_dir/$_target"
done
SCRIPT_DIR="$(cd "$(dirname "$_target")" && pwd)"
unset _target _dir
DOTFILES_DIR="$SCRIPT_DIR"

# Source library files if they exist.
# When running standalone (before install), these may not be present.
if [[ -r "$DOTFILES_DIR/lib/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$DOTFILES_DIR/lib/common.sh"
fi
if [[ -r "$DOTFILES_DIR/lib/detect.sh" ]]; then
    # shellcheck source=lib/detect.sh
    source "$DOTFILES_DIR/lib/detect.sh"
fi
if [[ -r "$DOTFILES_DIR/lib/deploy.sh" ]]; then
    # shellcheck source=lib/deploy.sh
    source "$DOTFILES_DIR/lib/deploy.sh"
fi

# Source all modules (provides check_*/repair_* functions).
if [[ -d "$DOTFILES_DIR/lib/modules" ]]; then
    for _mod in "$DOTFILES_DIR"/lib/modules/*.sh; do
        [[ -r "$_mod" ]] && source "$_mod"
    done
    unset _mod
fi

# ---------- backup helper (standalone fallback) ------------------------------

# backup_file_simple FILE
#   Simple backup when deploy.sh (and its backup_file) is not available.
backup_file_simple() {
    local file="$1"
    [[ -e "$file" ]] || return 0
    [[ -L "$file" ]] && return 0
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    cp -a "$file" "${file}.bak.${ts}" 2>/dev/null || true
}

# ---------- colour helpers (standalone fallback) ------------------------------

# If common.sh was not loaded, define colours ourselves.
if [[ -z "${_GREEN:-}" ]]; then
    if [[ -t 1 ]] && [[ -t 2 ]]; then
        _RED=$'\033[0;31m'
        _GREEN=$'\033[0;32m'
        _YELLOW=$'\033[0;33m'
        _BOLD=$'\033[1m'
        _RESET=$'\033[0m'
    else
        _RED=""
        _GREEN=""
        _YELLOW=""
        _BOLD=""
        _RESET=""
    fi
fi
# common.sh does not define _BOLD, so set it based on TTY capability.
if [[ -z "${_BOLD:-}" ]]; then
    if [[ -t 1 ]] && [[ -t 2 ]]; then
        _BOLD=$'\033[1m'
    else
        _BOLD=""
    fi
fi

# Provide log/warn stubs if common.sh was not loaded.
if ! declare -f log &>/dev/null; then
    log()  { printf '%s[INFO]%s %s\n' "$_GREEN" "$_RESET" "$*"; }
    warn() { printf '%s[WARN]%s %s\n' "$_YELLOW" "$_RESET" "$*" >&2; }
fi

# ---------- CLI options -------------------------------------------------------

FIX=0
FIX_SUDO=0
QUIET=0

usage() {
    cat <<'USAGE'
Usage: doctor.sh [OPTIONS]

Diagnose the dotfiles environment and optionally repair issues.

Options:
  --fix        Auto-repair problems that do not require sudo
  --fix-sudo   Auto-repair all problems, including those that require sudo
  --quiet      Only print items that have problems
  -h, --help   Show this help message and exit
USAGE
}

while (( $# > 0 )); do
    case "$1" in
        --fix)
            FIX=1
            shift
            ;;
        --fix-sudo)
            FIX=1
            FIX_SUDO=1
            shift
            ;;
        --quiet)
            QUIET=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '%sUnknown option: %s%s\n' "$_RED" "$1" "$_RESET" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if (( QUIET )); then
    if declare -f detect_os &>/dev/null; then
        detect_os >/dev/null 2>&1 || true
    fi
    if declare -f detect_pkg_manager &>/dev/null; then
        detect_pkg_manager >/dev/null 2>&1 || true
    fi
else
    if declare -f detect_os &>/dev/null; then
        detect_os 2>/dev/null || true
    fi
    if declare -f detect_pkg_manager &>/dev/null; then
        detect_pkg_manager 2>/dev/null || true
    fi
fi

# ---------- dotfiles-specific check/repair functions --------------------------

_zsh_deploy_copy() {
    local src="$1" dest="$2"

    if declare -f deploy_file &>/dev/null; then
        deploy_file "$src" "$dest" "copy" || return 1
    else
        if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
            backup_file_simple "$dest"
            rm -f "$dest" || {
                warn "Failed to remove broken zsh file: $dest"
                return 1
            }
        fi
        cp "$src" "$dest" || {
            warn "Failed to copy zsh file: $src -> $dest"
            return 1
        }
    fi
}

_repair_zsh_module_dir() {
    local src_dir="$1" dest_dir="$2" label="$3"
    local src dest

    mkdir -p "$dest_dir" || {
        warn "Failed to create $label directory: $dest_dir"
        return 1
    }

    if [[ ! -d "$src_dir" ]]; then
        warn "$label source directory not found in dotfiles repository"
        return 1
    fi

    for src in "$src_dir"/*.zsh; do
        [[ -e "$src" ]] || continue
        dest="$dest_dir/$(basename "$src")"
        if [[ ! -e "$dest" ]] || [[ -L "$dest" ]] || [[ ! -r "$dest" ]]; then
            _zsh_deploy_copy "$src" "$dest" || return 1
        fi
    done
}

# 1. ~/.zshenv exists and sets ZDOTDIR
check_dotfiles_zshenv() {
    [[ -r "$HOME/.zshenv" ]] || return 1
    grep -q 'ZDOTDIR' "$HOME/.zshenv" || return 1
    grep -q '\.config/zsh' "$HOME/.zshenv" || return 1
}
repair_dotfiles_zshenv() {
    if [[ -r "$DOTFILES_DIR/home/.zshenv" ]]; then
        if declare -f deploy_file &>/dev/null; then
            deploy_file "$DOTFILES_DIR/home/.zshenv" "$HOME/.zshenv" "copy"
        else
            backup_file_simple "$HOME/.zshenv"
            cp "$DOTFILES_DIR/home/.zshenv" "$HOME/.zshenv"
        fi
        log "Deployed home/.zshenv to ~/.zshenv"
    else
        warn "home/.zshenv not found in dotfiles repository"
        return 1
    fi
}

# 2. ~/.zshrc landing pad
check_dotfiles_zshrc() {
    [[ -r "$HOME/.zshrc" ]] || return 1
    grep -qF -- '~/.zshrc — Landing Pad' "$HOME/.zshrc" || return 1
}
repair_dotfiles_zshrc() {
    if [[ -r "$DOTFILES_DIR/home/.zshrc" ]]; then
        if declare -f deploy_file &>/dev/null; then
            deploy_file "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc" "copy"
        else
            backup_file_simple "$HOME/.zshrc"
            cp "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc"
        fi
        log "Deployed home/.zshrc to ~/.zshrc"
    else
        warn "home/.zshrc not found in dotfiles repository"
        return 1
    fi
}

# 3. ZDOTDIR entry files exist and source module directories
check_dotfiles_zdotdir() {
    [[ -d "$HOME/.config/zsh" ]] || return 1
    [[ -r "$HOME/.config/zsh/.zshenv" ]] || return 1
    [[ -r "$HOME/.config/zsh/.zshrc" ]] || return 1
    grep -q 'env.d' "$HOME/.config/zsh/.zshenv" || return 1
    grep -q 'conf.d' "$HOME/.config/zsh/.zshrc" || return 1
}
repair_dotfiles_zdotdir() {
    mkdir -p "$HOME/.config/zsh"
    local src_env="$DOTFILES_DIR/config/zsh/.zshenv"
    local src_rc="$DOTFILES_DIR/config/zsh/.zshrc"

    if [[ ! -r "$src_env" ]] || [[ ! -r "$src_rc" ]]; then
        warn "config/zsh entry files not found in dotfiles repository"
        return 1
    fi

    _zsh_deploy_copy "$src_env" "$HOME/.config/zsh/.zshenv" || return 1
    _zsh_deploy_copy "$src_rc" "$HOME/.config/zsh/.zshrc" || return 1
    log "Deployed config/zsh entry files to ~/.config/zsh/"
}

# 4. env.d/ has .zsh files
check_dotfiles_envd() {
    [[ -d "$HOME/.config/zsh/env.d" ]] || return 1
    if [[ -d "$DOTFILES_DIR/config/zsh/env.d" ]]; then
        local src dest
        for src in "$DOTFILES_DIR"/config/zsh/env.d/*.zsh; do
            [[ -e "$src" ]] || continue
            dest="$HOME/.config/zsh/env.d/$(basename "$src")"
            [[ -r "$dest" ]] || return 1
        done
        return 0
    fi
    local count
    count=$(find "$HOME/.config/zsh/env.d" -name "*.zsh" 2>/dev/null | wc -l)
    (( count > 0 ))
}
repair_dotfiles_envd() {
    _repair_zsh_module_dir "$DOTFILES_DIR/config/zsh/env.d" "$HOME/.config/zsh/env.d" "env.d" || return 1
    log "Repaired env.d/ files in ~/.config/zsh/env.d/"
}

# 5. conf.d/ has .zsh files
check_dotfiles_confd() {
    [[ -d "$HOME/.config/zsh/conf.d" ]] || return 1
    if [[ -d "$DOTFILES_DIR/config/zsh/conf.d" ]]; then
        local src dest
        for src in "$DOTFILES_DIR"/config/zsh/conf.d/*.zsh; do
            [[ -e "$src" ]] || continue
            dest="$HOME/.config/zsh/conf.d/$(basename "$src")"
            [[ -r "$dest" ]] || return 1
        done
        return 0
    fi
    local count
    count=$(find "$HOME/.config/zsh/conf.d" -name "*.zsh" 2>/dev/null | wc -l)
    (( count > 0 ))
}
repair_dotfiles_confd() {
    _repair_zsh_module_dir "$DOTFILES_DIR/config/zsh/conf.d" "$HOME/.config/zsh/conf.d" "conf.d" || return 1
    log "Repaired conf.d/ files in ~/.config/zsh/conf.d/"
}

# 6. ~/.local/bin is in PATH
check_path_local_bin() {
    local zsh_path
    [[ ":$PATH:" == *":$HOME/.local/bin:"* ]] && return 0
    if have zsh; then
        zsh_path="$(zsh -lc 'printf %s "$PATH"' 2>/dev/null || true)"
        [[ ":$zsh_path:" == *":$HOME/.local/bin:"* ]] && return 0
    fi
    return 1
}

# 7. git user.name and user.email configured
check_git_user() {
    git config --global user.name &>/dev/null || return 1
    git config --global user.email &>/dev/null || return 1
}

# 8. default shell is zsh
check_shell_zsh() {
    local user; user="${USER:-$(id -un)}"
    local current_shell
    current_shell="$(getent passwd "$user" 2>/dev/null | cut -d: -f7)" || \
    current_shell="$(dscl . -read /Users/"$user" UserShell 2>/dev/null | awk '{print $2}')" || \
    current_shell="$SHELL"
    [[ "$current_shell" == */zsh ]]
}
repair_shell_zsh() {
    local zsh_path user
    zsh_path="$(command -v zsh 2>/dev/null || true)"
    [[ -n "$zsh_path" ]] || {
        warn "zsh not found on PATH"
        return 1
    }
    user="${USER:-$(id -un)}"
    if declare -f pkg_run_priv &>/dev/null; then
        pkg_run_priv chsh -s "$zsh_path" "$user"
    elif [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        if declare -f run &>/dev/null; then
            run chsh -s "$zsh_path" "$user"
        else
            chsh -s "$zsh_path" "$user"
        fi
    else
        local cmd=()
        cmd+=(sudo)
        cmd+=(chsh -s "$zsh_path" "$user")
        if declare -f run &>/dev/null; then
            run "${cmd[@]}"
        else
            "${cmd[@]}"
        fi
    fi
}

# 9. /etc/sudoers.d/dotfiles-path exists (optional -- the installer does not
#    deploy this file, so its absence is SKIP rather than FAIL)
check_sudoers_path() {
    if [[ -f /etc/sudoers.d/dotfiles-path ]]; then
        return 0
    fi
    DOCTOR_SKIP_DETAIL="optional"
    return 2
}

# ---------- check registry ----------------------------------------------------
# Format: "label|check_fn|repair_fn|sudo_flag"
#   label      - human-readable name for the check
#   check_fn   - function that returns 0 (OK: installed & healthy),
#                1 (FAIL: installed but broken / expected but missing),
#                2 (SKIP: not installed on this machine / not applicable)
#   repair_fn  - function to call for repair (empty = no auto-repair)
#   sudo_flag  - "sudo" if the fix needs sudo privileges, "no" otherwise

CHECKS=(
    "~/.zshenv|check_dotfiles_zshenv|repair_dotfiles_zshenv|no"
    "~/.zshrc landing pad|check_dotfiles_zshrc|repair_dotfiles_zshrc|no"
    "ZDOTDIR = ~/.config/zsh|check_dotfiles_zdotdir|repair_dotfiles_zdotdir|no"
    "env.d/ files|check_dotfiles_envd|repair_dotfiles_envd|no"
    "conf.d/ files|check_dotfiles_confd|repair_dotfiles_confd|no"
    "~/.local/bin in PATH|check_path_local_bin||no"
    "base packages|check_base|repair_base|sudo"
    "CLI tools|check_cli_tools|repair_cli_tools|sudo"
    "C/C++ toolchain|check_c_cpp|repair_c_cpp|sudo"
    "Rust|check_rust|repair_rust|no"
    "uv|check_uv|repair_uv|no"
    "npm prefix/cache|check_node|repair_node|no"
    "npm dir ownership|check_npm_ownership|repair_npm_ownership|sudo"
    "~/.npmrc legacy|check_npm_legacy_config|repair_npm_legacy_config|no"
    "VS Code|check_vscode|repair_vscode|no"
    "zsh plugins|check_zsh_plugins|repair_zsh_plugins|no"
    "git user config|check_git_user||no"
    "default shell = zsh|check_shell_zsh|repair_shell_zsh|sudo"
    "sudoers.d PATH|check_sudoers_path||no"
)

# ---------- output formatting -------------------------------------------------

# Fixed display width for the check label + dots.
LABEL_WIDTH=40

# print_result LABEL STATUS [DETAIL]
#   STATUS: ok, fail, skip, sudo
print_result() {
    local label="$1" status="$2" detail="${3:-}"
    local tag dots ndots

    tag="[check] $label "
    ndots=$(( LABEL_WIDTH - ${#tag} ))
    if (( ndots < 2 )); then
        ndots=2
    fi
    dots=$(printf '%*s' "$ndots" '' | tr ' ' '.')

    case "$status" in
        ok)
            printf '%s%s %s%sOK%s\n' "$tag" "$dots" "$_GREEN" "$_BOLD" "$_RESET"
            ;;
        fail)
            if [[ -n "$detail" ]]; then
                printf '%s%s %s%sFAIL%s (%s)\n' "$tag" "$dots" "$_RED" "$_BOLD" "$_RESET" "$detail"
            else
                printf '%s%s %s%sFAIL%s\n' "$tag" "$dots" "$_RED" "$_BOLD" "$_RESET"
            fi
            ;;
        skip)
            if [[ -n "$detail" ]]; then
                printf '%s%s %s%sSKIP%s (%s)\n' "$tag" "$dots" "$_YELLOW" "$_BOLD" "$_RESET" "$detail"
            else
                printf '%s%s %s%sSKIP%s\n' "$tag" "$dots" "$_YELLOW" "$_BOLD" "$_RESET"
            fi
            ;;
        fixed)
            printf '%s%s %s%sFIXED%s\n' "$tag" "$dots" "$_GREEN" "$_BOLD" "$_RESET"
            ;;
    esac
}

# ---------- main loop ---------------------------------------------------------

passed=0
failed=0
need_sudo=0
fixed=0
skipped=0

for entry in "${CHECKS[@]}"; do
    IFS='|' read -r label check_fn repair_fn needs_sudo <<< "$entry"

    # Skip checks whose function is not defined (module not loaded).
    if ! declare -f "$check_fn" &>/dev/null; then
        if (( ! QUIET )); then
            print_result "$label" "skip" "module not loaded"
        fi
        skipped=$((skipped + 1))
        continue
    fi

    # Run the check, capturing its return code robustly under `set -e`.
    #   0 = OK, 1 = FAIL, 2 = SKIP (not installed / not applicable)
    DOCTOR_SKIP_DETAIL=""
    rc=0
    "$check_fn" 2>/dev/null || rc=$?

    # SKIP is never an error and is never repaired (applies to sudo checks too).
    if (( rc == 2 )); then
        if (( ! QUIET )); then
            print_result "$label" "skip" "${DOCTOR_SKIP_DETAIL:-not installed}"
        fi
        skipped=$((skipped + 1))
        continue
    fi

    # For sudo-requiring checks without --fix-sudo: report the result but
    # flag that sudo would be needed for the fix.
    if [[ "$needs_sudo" == "sudo" ]] && (( ! FIX_SUDO )); then
        if (( rc == 0 )); then
            if (( ! QUIET )); then
                print_result "$label" "ok"
            fi
            passed=$((passed + 1))
        else
            print_result "$label" "fail" "needs --fix-sudo"
            need_sudo=$((need_sudo + 1))
        fi
        continue
    fi

    if (( rc == 0 )); then
        if (( ! QUIET )); then
            print_result "$label" "ok"
        fi
        passed=$((passed + 1))
    else
        # Check failed -- attempt repair if requested.
        if (( FIX )) && [[ -n "$repair_fn" ]] && declare -f "$repair_fn" &>/dev/null; then
            if $repair_fn; then
                # Re-verify: a repair that "succeeds" but doesn't actually
                # fix the underlying check should not be reported as FIXED.
                recheck_rc=0
                "$check_fn" 2>/dev/null || recheck_rc=$?
                if (( recheck_rc == 0 )); then
                    print_result "$label" "fixed"
                    fixed=$((fixed + 1))
                else
                    print_result "$label" "fail" "repair did not resolve"
                    failed=$((failed + 1))
                fi
            else
                print_result "$label" "fail" "repair failed"
                failed=$((failed + 1))
            fi
        else
            if [[ -z "$repair_fn" ]]; then
                print_result "$label" "fail" "no auto-repair"
            else
                print_result "$label" "fail"
            fi
            failed=$((failed + 1))
        fi
    fi
done

# ---------- summary -----------------------------------------------------------

echo ""
printf '%s' "${_BOLD}"

parts=()
parts+=("$passed passed")
if (( fixed > 0 )); then
    parts+=("$fixed fixed")
fi
if (( failed > 0 )); then
    parts+=("$failed failed")
fi
if (( need_sudo > 0 )); then
    parts+=("$need_sudo needs sudo")
fi
if (( skipped > 0 )); then
    parts+=("$skipped skipped")
fi

# Join parts with ", "
summary=""
for i in "${!parts[@]}"; do
    if (( i > 0 )); then
        summary+=", "
    fi
    summary+="${parts[$i]}"
done
printf '%s%s\n' "$summary" "$_RESET"

# Exit with failure if any check failed or needs sudo.
if (( failed > 0 )) || (( need_sudo > 0 )); then
    exit 1
fi
exit 0
