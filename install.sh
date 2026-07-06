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

_target="${BASH_SOURCE[0]}"
while [[ -L "$_target" ]]; do
    _dir="$(cd "$(dirname "$_target")" && pwd)"
    _target="$(readlink "$_target")"
    [[ "$_target" != /* ]] && _target="$_dir/$_target"
done
SCRIPT_DIR="$(cd "$(dirname "$_target")" && pwd)"
unset _target _dir

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

# Abort early when no package manager is available, before any prompts or work.
if [[ -z "$PKG_MANAGER" ]]; then
    if [[ "$OS" == "macos" ]]; then
        warn "Homebrew is required on macOS but was not found."
        warn "Install it first by running:"
        warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        die "No package manager available -- aborting before making any changes."
    else
        die "No supported package manager found (apt, dnf, or yum is required). Install one and re-run install.sh."
    fi
fi

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
            if ask "Install ${_BOLD}${label}${_RESET}?" "Y"; then
                eval "$varname=1"
            else
                eval "$varname=0"
            fi
            ;;
        N)
            if ask "Install ${_BOLD}${label}${_RESET}?" "N"; then
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

# ---------- git identity collection (values only -- nothing written yet) -------

git_name=""
git_email=""

if [[ "$GIT_CONFIG" != "SKIP" ]]; then
    # Use existing git config values as defaults when profile does not provide them.
    _default_git_name="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || true)}"
    _default_git_email="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"

    git_name="$(ask_input "Git user.name" "$_default_git_name")"
    git_email="$(ask_input "Git user.email" "$_default_git_email")"
fi

# ---------- chsh decision (asked now, executed after confirmation) --------------

DO_CHSH=0
CHSH_SUMMARY="skipped"

if [[ "$CHSH" == "SKIP" ]] || [[ "$NO_CHSH" == "1" ]]; then
    DO_CHSH=0
    CHSH_SUMMARY="skipped"
elif [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
    DO_CHSH=0
    CHSH_SUMMARY="no (already zsh)"
elif ask "Change default shell to zsh?" "Y"; then
    DO_CHSH=1
    CHSH_SUMMARY="yes"
else
    DO_CHSH=0
    CHSH_SUMMARY="no"
fi

# ---------- installation summary ------------------------------------------------

# summary_component FLAG LABEL
#   Print one component line: [install] (green) or [skip] (yellow), bold label.
summary_component() {
    local flag="$1"
    local label="$2"
    if [[ "$flag" == "1" ]]; then
        printf '   %s[install]%s %s%s%s\n' "$_GREEN" "$_RESET" "$_BOLD" "$label" "$_RESET"
    else
        printf '   %s[skip]%s    %s%s%s\n' "$_YELLOW" "$_RESET" "$_BOLD" "$label" "$_RESET"
    fi
}

if [[ "$GIT_CONFIG" == "SKIP" ]]; then
    GIT_SUMMARY="skipped"
elif [[ -z "$git_name" ]] || [[ -z "$git_email" ]]; then
    GIT_SUMMARY="(name or email empty -- will be skipped)"
else
    GIT_SUMMARY="$git_name <$git_email>"
fi

DEPLOY_MODE_SUMMARY="copy"
if [[ "$LINK_MODE" == "1" ]]; then
    DEPLOY_MODE_SUMMARY="link"
fi

DRY_RUN_SUMMARY="no"
if [[ "$DRY_RUN" == "1" ]]; then
    DRY_RUN_SUMMARY="yes"
fi

printf '\n'
printf '==============================================\n'
printf ' Installation Summary\n'
printf '==============================================\n'
printf ' Profile       : %s\n' "$PROFILE"
printf ' OS            : %s (%s)\n' "$OS" "$PKG_MANAGER"
printf ' Deploy mode   : %s\n' "$DEPLOY_MODE_SUMMARY"
printf ' Dry run       : %s\n' "$DRY_RUN_SUMMARY"
printf '\n'
printf ' Components:\n'
summary_component "$INSTALL_BASE"        "base packages"
summary_component "$INSTALL_CLI_TOOLS"   "CLI tools"
summary_component "$INSTALL_C_CPP"       "C/C++ toolchain"
summary_component "$INSTALL_RUST"        "Rust"
summary_component "$INSTALL_UV"          "uv (Python)"
summary_component "$INSTALL_NODE"        "Node.js"
summary_component "$INSTALL_VSCODE"      "VS Code extensions"
summary_component "$INSTALL_ZSH_PLUGINS" "zsh plugins"
printf '\n'
printf ' Git identity  : %s\n' "$GIT_SUMMARY"
printf ' Change shell  : %s\n' "$CHSH_SUMMARY"
printf '==============================================\n'
printf '\n'

# ---------- final confirmation --------------------------------------------------

if ! ask "Proceed with installation?" "Y"; then
    log "Aborted. No changes were made."
    exit 0
fi

# ---------- git config generation ---------------------------------------------

if [[ "$GIT_CONFIG" != "SKIP" ]]; then
    log "Configuring git..."

    git_editor="${VISUAL:-${EDITOR:-vim}}"
    git_version="$(git --version 2>/dev/null | awk '{print $3}' || true)"
    git_major="$(printf '%s\n' "$git_version" | awk -F. '{print $1 + 0}')"
    git_minor="$(printf '%s\n' "$git_version" | awk -F. '{print $2 + 0}')"
    _git_version_at_least() {
        local want_major="$1" want_minor="$2"
        if [[ "$git_major" -gt "$want_major" ]]; then
            return 0
        fi
        if [[ "$git_major" -eq "$want_major" ]] && [[ "$git_minor" -ge "$want_minor" ]]; then
            return 0
        fi
        return 1
    }

    if _git_version_at_least 2 35; then
        git_conflict_style="zdiff3"
    else
        git_conflict_style="diff3"
    fi
    if [[ "$OS" == "macos" ]] && _git_version_at_least 2 36; then
        git_enable_untrackedcache=1
    else
        git_enable_untrackedcache=0
    fi
    if _git_version_at_least 2 37; then
        git_enable_auto_setup_remote=1
    else
        git_enable_auto_setup_remote=0
    fi

    # Determine credential helper based on OS.
    case "$OS" in
        macos)  git_credential_helper="osxkeychain" ;;
        debian|redhat)
            if have git-credential-libsecret; then
                git_credential_helper="libsecret"
            else
                git_credential_helper="cache --timeout=86400"
            fi
            ;;
        *)      git_credential_helper="cache --timeout=86400" ;;
    esac

    template="$DOTFILES_DIR/config/git/config.template"
    git_config_dest="$HOME/.config/git/config"

    # Keep template substitutions to a single logical gitconfig value.
    sanitize_first_line() {
        printf '%s' "$1" | tr -d '\r' | sed -n '1p'
    }

    # Escape characters that are special inside quoted gitconfig strings.
    escape_gitconfig_string() {
        printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
    }

    # Escape sed replacement strings (handle &, \, / in user input).
    escape_sed() {
        printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g'
    }

    git_name_value="$(sanitize_first_line "$git_name")"
    git_email_value="$(sanitize_first_line "$git_email")"
    git_editor_value="$(sanitize_first_line "$git_editor")"
    git_credential_helper_value="$(sanitize_first_line "$git_credential_helper")"
    git_conflict_style_value="$(sanitize_first_line "$git_conflict_style")"

    if [[ -z "$git_name_value" ]] || [[ -z "$git_email_value" ]]; then
        warn "git user.name or user.email is empty — skipping git config generation"
        warn "Run install.sh again without --yes to set git identity interactively"
    fi

    if [[ -z "$git_name_value" ]] || [[ -z "$git_email_value" ]]; then
        : # skip git config generation (warning already printed above)
    elif [[ "$DRY_RUN" == "1" ]]; then
        log "[DRY-RUN] Generate git config from template -> $git_config_dest"
        log "[DRY-RUN]   user.name  = $git_name_value"
        log "[DRY-RUN]   user.email = $git_email_value"
        log "[DRY-RUN]   editor     = $git_editor_value"
        log "[DRY-RUN]   credential = $git_credential_helper_value"
        log "[DRY-RUN]   conflictstyle = $git_conflict_style_value"
        if [[ "$git_enable_untrackedcache" == "1" ]]; then
            log "[DRY-RUN]   untrackedcache = enabled"
        else
            log "[DRY-RUN]   untrackedcache = omitted"
        fi
        if [[ "$git_enable_auto_setup_remote" == "1" ]]; then
            log "[DRY-RUN]   push.autoSetupRemote = enabled"
        else
            log "[DRY-RUN]   push.autoSetupRemote = omitted"
        fi
    else
        mkdir -p "$(dirname "$git_config_dest")"
        # Backup existing git config before overwriting.
        git_config_write_ok=1
        if ! backup_file "$git_config_dest"; then
            warn "Backup failed -- skipping git config generation"
            git_config_write_ok=0
        fi

        if [[ "$git_config_write_ok" == "1" ]] && [[ -L "$git_config_dest" ]]; then
            if run rm -f "$git_config_dest"; then
                log "Removed git config symlink before generating machine-local config"
            else
                warn "Failed to remove git config symlink -- skipping git config generation"
                git_config_write_ok=0
            fi
        fi

        if [[ "$git_config_write_ok" == "1" ]]; then
            # Read template content.
            git_config_content="$(cat "$template")"

            local_name="$(escape_sed "$(escape_gitconfig_string "$git_name_value")")"
            local_email="$(escape_sed "$(escape_gitconfig_string "$git_email_value")")"
            local_editor="$(escape_sed "$git_editor_value")"
            local_cred="$(escape_sed "$git_credential_helper_value")"
            local_conflict_style="$(escape_sed "$git_conflict_style_value")"

            git_config_content="$(printf '%s' "$git_config_content" | sed \
                -e "s/__GIT_USER_NAME__/$local_name/g" \
                -e "s/__GIT_USER_EMAIL__/$local_email/g" \
                -e "s/__GIT_EDITOR__/$local_editor/g" \
                -e "s/__GIT_CREDENTIAL_HELPER__/$local_cred/g" \
                -e "s/__GIT_CONFLICT_STYLE__/$local_conflict_style/g")"

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

            # Remove Git-version-sensitive sections when the installed git is too old.
            if [[ "$git_enable_untrackedcache" == "1" ]]; then
                git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_GIT236__$/d' -e '/^# __END_GIT236__$/d')"
            else
                git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_GIT236__$/,/^# __END_GIT236__$/d')"
            fi
            if [[ "$git_enable_auto_setup_remote" == "1" ]]; then
                git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_GIT237__$/d' -e '/^# __END_GIT237__$/d')"
            else
                git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_GIT237__$/,/^# __END_GIT237__$/d')"
            fi

            # Remove LFS section if git-lfs is not installed.
            if ! have git-lfs; then
                git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_LFS__$/,/^# __END_LFS__$/d')"
            else
                git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_LFS__$/d' -e '/^# __END_LFS__$/d')"
            fi

            # Remove 1Password section if the app is not installed, or if it is
            # installed but the SSH agent has no signing key available (commit
            # signing would otherwise fail with "user.signingkey ... needs to be
            # configured").
            if [[ ! -d "/Applications/1Password.app" ]] && ! have op; then
                git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_1PASSWORD__$/,/^# __END_1PASSWORD__$/d')"
            else
                _op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
                git_signing_key=""
                if [[ -S "$_op_sock" ]]; then
                    git_signing_key="$(SSH_AUTH_SOCK="$_op_sock" ssh-add -L 2>/dev/null | head -n 1 || true)"
                fi
                git_signing_key="$(sanitize_first_line "$git_signing_key")"

                if [[ -n "$git_signing_key" ]]; then
                    local_signing_key="$(escape_sed "$(sanitize_first_line "key::$git_signing_key")")"
                    git_config_content="$(printf '%s' "$git_config_content" | sed -e '/^# __BEGIN_1PASSWORD__$/d' -e '/^# __END_1PASSWORD__$/d')"
                    git_config_content="$(printf '%s' "$git_config_content" | sed \
                        -e "s/__GIT_SIGNING_KEY__/$local_signing_key/g")"
                else
                    warn "1Password SSH agent has no keys -- commit signing disabled in generated git config"
                    git_config_content="$(printf '%s' "$git_config_content" | sed '/^# __BEGIN_1PASSWORD__$/,/^# __END_1PASSWORD__$/d')"
                fi
            fi

            printf '%s\n' "$git_config_content" > "$git_config_dest"
            log "Generated: $git_config_dest"
        fi
    fi

    # Deploy git ignore file.
    deploy_file "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"
fi

# ---------- dotfiles deployment -----------------------------------------------

log "Deploying dotfiles..."

# Deploy home/ -> ~/
for file in "$DOTFILES_DIR"/home/.*; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file")"
    # ~/.zshrc is the landing pad: external tools may append to it, and
    # ZDOTDIR/.zshrc sources it at the end. Always deploy it as a real copy so
    # appends never write into the repository through a symlink.
    if [[ "$name" == ".zshrc" ]] && [[ -f "$HOME/.zshrc" ]]; then
        if grep -qF '~/.zshrc — Landing Pad' "$HOME/.zshrc"; then
            if [[ ! -L "$HOME/.zshrc" ]]; then
                log "Skipping ~/.zshrc landing pad (copy-only user file)"
                continue
            fi
        fi
        log "Replacing existing ~/.zshrc with landing pad; previous file will be backed up"
        log "Re-add customizations under ~/.config/zsh/conf.d/ after installation"
    fi
    if [[ "$name" == ".zshrc" ]]; then
        deploy_file "$file" "$HOME/$name" "copy"
    else
        deploy_file "$file" "$HOME/$name"
    fi
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
    # Skip vscode/ -- deployed to the OS-specific VS Code settings path by
    # install_vscode() in lib/modules/vscode.sh, not ~/.config/vscode/.
    [[ "$rel" == vscode/* ]] && continue
    # npm/npmrc is managed by install_node()/_ensure_npm_prefix_config after
    # the first deployment (it writes prefix/cache into the live copy).
    if [[ "$rel" == "npm/npmrc" ]]; then
        if [[ -f "$HOME/.config/npm/npmrc" ]] && [[ ! -L "$HOME/.config/npm/npmrc" ]]; then
            log "Skipping npm/npmrc (managed live copy)"
            continue
        fi
        deploy_file "$file" "$HOME/.config/$rel" "copy"
        continue
    fi
    deploy_file "$file" "$HOME/.config/$rel"
done < <(find "$DOTFILES_DIR/config" -type f -print0)

# ---------- module installation -----------------------------------------------

log "Running module installers..."

# Module installers run in subshells, so PATH changes made inside earlier
# modules do not propagate. Prepend known user-local toolchain locations so
# later modules in this run can see freshly installed rustup/uv binaries.
export PATH="$HOME/.local/bin:${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}/bin:$PATH"

# Source all module files.
for mod in "$DOTFILES_DIR"/lib/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$mod"
done

# Track modules that fail so one bad module (e.g. a network blip during the
# rustup download) doesn't kill the whole installer via set -e -- the rest
# of the modules, chsh, and the completion message should still run.
FAILED_MODULES=()

# run_module NAME COMMAND [ARGS...]
#   Run COMMAND; on failure, warn and record NAME in FAILED_MODULES instead
#   of letting set -e abort the whole script.
#
#   COMMAND runs in a subshell with `set -e` re-enabled, not inside an
#   `if ! ...` condition: bash disables errexit for the duration of any
#   command that is itself the condition of an if/while/&&/||, so a plain
#   `if ! "$@"` would silently disable set -e *inside* the module -- a
#   failing command mid-module would not abort the module, and whatever
#   ran last would determine the (wrongly) reported success/failure.
#   Modules therefore run in a subshell: they must not rely on exporting
#   state (env vars, etc.) to steps later in install.sh. Verified this
#   holds today -- install_cli_tools/c_cpp/rust/uv/node/vscode/zsh_plugins
#   only set module-local or re-derived env (e.g. NPM_CONFIG_* is
#   re-derived by check_node()/repair_node() via _ensure_npm_prefix_config,
#   not read from a prior export), and nothing after the module block
#   consumes CARGO_HOME/RUSTUP_HOME/NPM_CONFIG_* etc.
run_module() {
    local name="$1"; shift
    local rc=0
    set +e
    ( set -e; "$@" )
    rc=$?
    set -e
    if (( rc != 0 )); then
        warn "Component '$name' failed to install -- continuing with the rest"
        FAILED_MODULES+=("$name")
    fi
}

# base packages is called directly (not via run_module): zsh/git are
# prerequisites for everything else, so a failure here should still be
# fatal via normal set -e semantics.
[[ "$INSTALL_BASE" == "1" ]]        && install_base
[[ "$INSTALL_CLI_TOOLS" == "1" ]]   && run_module "CLI tools" install_cli_tools
[[ "$INSTALL_C_CPP" == "1" ]]       && run_module "C/C++ toolchain" install_c_cpp
[[ "$INSTALL_RUST" == "1" ]]        && run_module "Rust" install_rust
[[ "$INSTALL_UV" == "1" ]]          && run_module "uv (Python)" install_uv
[[ "$INSTALL_NODE" == "1" ]]        && run_module "Node.js" install_node
[[ "$INSTALL_VSCODE" == "1" ]]      && run_module "VS Code extensions" install_vscode
[[ "$INSTALL_ZSH_PLUGINS" == "1" ]] && run_module "zsh plugins" install_zsh_plugins

# ---------- chsh (change default shell to zsh) --------------------------------

# Decision was made before the summary; only execute it here.
if [[ "$DO_CHSH" == "1" ]]; then
    zsh_path="$(command -v zsh 2>/dev/null || true)"
    if [[ -n "$zsh_path" ]]; then
        if ! run chsh -s "$zsh_path"; then
            warn "chsh failed -- change your default shell manually: chsh -s $zsh_path"
            warn "(on Linux this may require your login password; on macOS ensure $zsh_path is in /etc/shells)"
        fi
    else
        warn "zsh not found -- cannot change shell"
    fi
fi

# ---------- done --------------------------------------------------------------

if [[ ${#FAILED_MODULES[@]} -eq 0 ]]; then
    log "dotfiles installation complete!"
    if [[ "$DRY_RUN" == "1" ]]; then
        log "(dry-run mode -- no actual changes were made)"
    fi
else
    log "dotfiles installation finished with errors"
    if [[ "$DRY_RUN" == "1" ]]; then
        log "(dry-run mode -- no actual changes were made)"
    fi
    warn "Some components failed: ${FAILED_MODULES[*]}"
    warn "Re-run install.sh to retry, or install them manually"
    exit 1
fi
