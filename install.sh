#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# install.sh -- dotfiles installer entry point
# ==============================================================================

# ---------- usage -------------------------------------------------------------

usage() {
    cat <<'USAGE'
Usage: install.sh [OPTIONS]

Install and configure dotfiles for the current user.

OPTIONS:
  --profile PROFILE    Profile to use: desktop | server | minimal
  --yes                Auto-accept all prompts with default values (CI mode)
  --link               Deploy files as symlinks (default: copy)
  --dry-run            Show what would be done without making changes
  --no-chsh            Do not change the default shell
  -h, --help           Show this help message
USAGE
}

# ---------- argument parsing --------------------------------------------------

PROFILE=""
NO_CHSH=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            [[ -n "${2:-}" ]] || { echo "Error: --profile requires a value" >&2; exit 1; }
            PROFILE="$2"
            shift 2
            ;;
        --yes)
            export YES=1
            shift
            ;;
        --link)
            export LINK_MODE=1
            shift
            ;;
        --dry-run)
            export DRY_RUN=1
            shift
            ;;
        --no-chsh)
            NO_CHSH=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ---------- load libraries ----------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

# Override DOTFILES_DIR after sourcing common.sh.  common.sh computes it via
# "dirname(BASH_SOURCE[1]) / .." which assumes the sourcing script lives in a
# subdirectory.  Since install.sh lives at the repo root, the automatic
# resolution goes one level too far up.
DOTFILES_DIR="$SCRIPT_DIR"
export DOTFILES_DIR

source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/prompt.sh"
source "$SCRIPT_DIR/lib/deploy.sh"

# ---------- OS and package manager detection ----------------------------------

detect_os
detect_pkg_manager

# ---------- profile selection -------------------------------------------------

if [[ -z "$PROFILE" ]]; then
    PROFILE="$(select_profile)"
fi

# Validate profile name.
case "$PROFILE" in
    desktop|server|minimal) ;;
    *) die "Unknown profile: $PROFILE (expected: desktop, server, minimal)" ;;
esac

log "Using profile: $PROFILE"

# shellcheck source=/dev/null
source "$DOTFILES_DIR/profiles/${PROFILE}.conf"

# ---------- tool selection (profile defaults + interactive) -------------------

# resolve_flag VARNAME LABEL PROFILE_VALUE
#   Sets the named variable to 1 or 0 based on profile value and user input.
#   Uses ask() directly (not in a subshell) to avoid stdout log contamination.
resolve_flag() {
    local varname="$1"
    local label="$2"
    local profile_val="$3"

    case "$profile_val" in
        SKIP)
            eval "$varname=0"
            ;;
        Y)
            if ask "Install ${label}?" "Y"; then
                eval "$varname=1"
            else
                eval "$varname=0"
            fi
            ;;
        N)
            if ask "Install ${label}?" "N"; then
                eval "$varname=1"
            else
                eval "$varname=0"
            fi
            ;;
        *)
            warn "Unknown profile value '$profile_val' for $label, treating as N"
            eval "$varname=0"
            ;;
    esac
}

resolve_flag INSTALL_BASE        "base packages"     "$BASE"
resolve_flag INSTALL_CLI_TOOLS   "CLI tools"         "$CLI_TOOLS"
resolve_flag INSTALL_C_CPP       "C/C++ toolchain"   "$C_CPP"
resolve_flag INSTALL_RUST        "Rust"              "$RUST"
resolve_flag INSTALL_UV          "uv (Python)"       "$UV"
resolve_flag INSTALL_NODE        "Node.js"           "$NODE"
resolve_flag INSTALL_VSCODE      "VS Code extensions" "$VSCODE"
resolve_flag INSTALL_ZSH_PLUGINS "zsh plugins"       "$ZSH_PLUGINS"

# ---------- git config generation ---------------------------------------------

if [[ "$GIT_CONFIG" != "SKIP" ]]; then
    log "Configuring git..."

    # Use existing git config values as defaults when profile does not provide them.
    _default_git_name="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || true)}"
    _default_git_email="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"

    git_name="$(ask_input "Git user.name" "$_default_git_name")"
    git_email="$(ask_input "Git user.email" "$_default_git_email")"
    git_editor="${VISUAL:-${EDITOR:-vim}}"

    # Determine credential helper based on OS.
    case "$OS" in
        macos)  git_credential_helper="osxkeychain" ;;
        debian) git_credential_helper="store" ;;
        redhat) git_credential_helper="store" ;;
        *)      git_credential_helper="store" ;;
    esac

    template="$DOTFILES_DIR/config/git/config.template"
    git_config_dest="$HOME/.config/git/config"

    if [[ "$DRY_RUN" == "1" ]]; then
        log "[DRY-RUN] Generate git config from template -> $git_config_dest"
        log "[DRY-RUN]   user.name  = $git_name"
        log "[DRY-RUN]   user.email = $git_email"
        log "[DRY-RUN]   editor     = $git_editor"
        log "[DRY-RUN]   credential = $git_credential_helper"
    else
        mkdir -p "$(dirname "$git_config_dest")"
        # Backup existing git config before overwriting.
        backup_file "$git_config_dest"

        # Read template content.
        git_config_content="$(cat "$template")"

        # Escape sed replacement strings (handle &, \, / in user input).
        escape_sed() {
            printf '%s' "$1" | sed -e 's/[&/\]/\\&/g'
        }

        local_name="$(escape_sed "$git_name")"
        local_email="$(escape_sed "$git_email")"
        local_editor="$(escape_sed "$git_editor")"
        local_cred="$(escape_sed "$git_credential_helper")"

        git_config_content="$(printf '%s' "$git_config_content" | sed \
            -e "s/__GIT_USER_NAME__/$local_name/g" \
            -e "s/__GIT_USER_EMAIL__/$local_email/g" \
            -e "s/__GIT_EDITOR__/$local_editor/g" \
            -e "s/__GIT_CREDENTIAL_HELPER__/$local_cred/g")"

        # Remove OS-specific sections based on detected OS.
        if [[ "$OS" == "macos" ]]; then
            # Remove LINUX section (including marker lines).
            git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_LINUX__$/,/^# __END_LINUX__$/d')"
            # Remove MACOS marker lines but keep content between them.
            git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_MACOS__$/d' -e '/^# __END_MACOS__$/d')"
        else
            # Remove MACOS section (including marker lines).
            git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_MACOS__$/,/^# __END_MACOS__$/d')"
            # Remove LINUX marker lines but keep content between them.
            git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_LINUX__$/d' -e '/^# __END_LINUX__$/d')"
        fi

        # Remove LFS section if git-lfs is not installed.
        if ! have git-lfs; then
            git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_LFS__$/,/^# __END_LFS__$/d')"
        else
            git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_LFS__$/d' -e '/^# __END_LFS__$/d')"
        fi

        # Remove 1Password section if the app is not installed.
        if [[ ! -d "/Applications/1Password.app" ]] && ! have op; then
            git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_1PASSWORD__$/,/^# __END_1PASSWORD__$/d')"
        else
            git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_1PASSWORD__$/d' -e '/^# __END_1PASSWORD__$/d')"
        fi

        printf '%s\n' "$git_config_content" > "$git_config_dest"
        log "Generated: $git_config_dest"
    fi

    # Deploy git ignore file.
    deploy_file "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"
fi

# ---------- dotfiles deployment -----------------------------------------------

log "Deploying dotfiles..."

# Deploy home/ -> ~/
for file in "$DOTFILES_DIR"/home/.*; do
    [[ -f "$file" ]] || continue
    deploy_file "$file" "$HOME/$(basename "$file")"
done

# Deploy config/ -> ~/.config/
# Skip config/git/config.template (handled in git config section above).
while IFS= read -r -d '' file; do
    rel="${file#"$DOTFILES_DIR"/config/}"
    # Skip the git config template -- it was processed separately.
    [[ "$rel" == "git/config.template" ]] && continue
    # Skip git/config if we generated it above (avoid overwriting).
    [[ "$rel" == "git/config" ]] && continue
    # Skip git/ignore if we already deployed it above.
    [[ "$rel" == "git/ignore" ]] && [[ "$GIT_CONFIG" != "SKIP" ]] && continue
    deploy_file "$file" "$HOME/.config/$rel"
done < <(find "$DOTFILES_DIR/config" -type f -print0)

# ---------- module installation -----------------------------------------------

log "Running module installers..."

# Source all module files.
for mod in "$DOTFILES_DIR"/lib/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$mod"
done

[[ "$INSTALL_BASE" == "1" ]]        && install_base
[[ "$INSTALL_CLI_TOOLS" == "1" ]]   && install_cli_tools
[[ "$INSTALL_C_CPP" == "1" ]]       && install_c_cpp
[[ "$INSTALL_RUST" == "1" ]]        && install_rust
[[ "$INSTALL_UV" == "1" ]]          && install_uv
[[ "$INSTALL_NODE" == "1" ]]        && install_node
[[ "$INSTALL_VSCODE" == "1" ]]      && install_vscode
[[ "$INSTALL_ZSH_PLUGINS" == "1" ]] && install_zsh_plugins

# ---------- chsh (change default shell to zsh) --------------------------------

if [[ "$CHSH" != "SKIP" ]] && [[ "$NO_CHSH" != "1" ]]; then
    current_shell="$(basename "${SHELL:-}")"
    if [[ "$current_shell" != "zsh" ]]; then
        if ask "Change default shell to zsh?" "Y"; then
            zsh_path="$(command -v zsh 2>/dev/null || true)"
            if [[ -n "$zsh_path" ]]; then
                run chsh -s "$zsh_path"
            else
                warn "zsh not found -- cannot change shell"
            fi
        fi
    else
        log "Default shell is already zsh"
    fi
fi

# ---------- done --------------------------------------------------------------

log "dotfiles installation complete!"
if [[ "$DRY_RUN" == "1" ]]; then
    log "(dry-run mode -- no actual changes were made)"
fi
