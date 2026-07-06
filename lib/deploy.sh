#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# deploy.sh -- file deployment (copy / symlink / backup)
# ==============================================================================

# Ensure common.sh is loaded (provides log, warn, die, run, DRY_RUN).
if ! declare -f log &>/dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

# LINK_MODE: 1 = create symlinks, 0 = copy files.
LINK_MODE="${LINK_MODE:-1}"
export LINK_MODE

# ---------- backup ------------------------------------------------------------

# backup_file FILE
#   Create a timestamped backup of FILE if it exists and is not a symlink.
#   Backup is placed next to the original with a .bak.<timestamp> suffix.
#   Returns 0 if a backup was created or no backup was needed, 1 on error.
backup_file() {
    local file="${1:?backup_file: file path required}"

    # Nothing to back up if the file doesn't exist.
    [[ -e "$file" ]] || return 0

    # Skip symlinks -- we'll just replace them.
    [[ -L "$file" ]] && return 0

    local timestamp
    timestamp="$(date +%Y%m%d%H%M%S)"
    local backup="${file}.bak.${timestamp}"

    if [[ "$DRY_RUN" == "1" ]]; then
        log "[DRY-RUN] backup $file -> $backup"
        return 0
    fi

    if cp -a "$file" "$backup"; then
        log "Backed up: $file -> $backup"
    else
        warn "Failed to backup: $file"
        return 1
    fi
}

# ---------- single file deployment --------------------------------------------

# deploy_file SOURCE DEST [MODE]
#   Deploy a single file from SOURCE to DEST.
#
#   MODE can be "link" (default) or "copy".  When MODE is omitted, the global
#   LINK_MODE variable decides: 1 = link, 0 = copy.
#
#   If DEST already exists, it is backed up first (unless it is a symlink that
#   already points to SOURCE).  DRY_RUN is respected.
deploy_file() {
    local src="${1:?deploy_file: source required}"
    local dest="${2:?deploy_file: destination required}"
    local mode="${3:-}"

    # Resolve mode from argument or global variable.
    if [[ -z "$mode" ]]; then
        if [[ "$LINK_MODE" == "1" ]]; then
            mode="link"
        else
            mode="copy"
        fi
    fi

    # Ensure the source file exists.
    if [[ ! -e "$src" ]]; then
        warn "Source does not exist: $src"
        return 1
    fi

    # If DEST is already a symlink pointing to SRC, nothing to do.
    if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
        log "Already linked: $dest -> $src"
        return 0
    fi

    # Back up existing file at destination.
    backup_file "$dest"

    # Ensure parent directory exists.
    local dest_dir
    dest_dir="$(dirname "$dest")"
    if [[ ! -d "$dest_dir" ]]; then
        run mkdir -p "$dest_dir"
    fi

    # Remove existing file / symlink before deploying.
    if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
        run rm -f "$dest"
    fi

    case "$mode" in
        link)
            run ln -sf "$src" "$dest"
            log "Linked: $dest -> $src"
            ;;
        copy)
            run cp -a "$src" "$dest"
            log "Copied: $src -> $dest"
            ;;
        *)
            die "Unknown deploy mode: $mode (expected 'link' or 'copy')"
            ;;
    esac
}

# ---------- directory deployment ----------------------------------------------

# deploy_dir SOURCE_DIR DEST_DIR [MODE]
#   Recursively deploy every file under SOURCE_DIR into DEST_DIR, preserving
#   the relative directory structure.  MODE is forwarded to deploy_file.
deploy_dir() {
    local src_dir="${1:?deploy_dir: source directory required}"
    local dest_dir="${2:?deploy_dir: destination directory required}"
    local mode="${3:-}"

    if [[ ! -d "$src_dir" ]]; then
        warn "Source directory does not exist: $src_dir"
        return 1
    fi

    local file
    while IFS= read -r -d '' file; do
        # Compute the path relative to src_dir.
        local rel="${file#"$src_dir"/}"
        deploy_file "$file" "${dest_dir}/${rel}" "$mode"
    done < <(find "$src_dir" -type f -print0)
}
