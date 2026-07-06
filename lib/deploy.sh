#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# deploy.sh -- file deployment (copy / symlink / backup)
# ==============================================================================

# Ensure common.sh is loaded (provides log, warn, die, run, DRY_RUN).
if ! declare -f log &>/dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

# LINK_MODE: 1 = create symlinks, 0 = copy files.  Default is copy.
LINK_MODE="${LINK_MODE:-0}"
export LINK_MODE

# ---------- comparison ---------------------------------------------------------

# _files_identical A B
#   Content comparison that works even when diffutils (cmp) is missing
#   (e.g. minimal Rocky Linux containers): falls back to cksum.
_files_identical() {
    if have cmp; then
        cmp -s "$1" "$2"
    else
        [[ "$(cksum < "$1")" == "$(cksum < "$2")" ]]
    fi
}

# ---------- backup ------------------------------------------------------------

# backup_file FILE [SKIP_IF_TARGET]
#   Create a timestamped backup of FILE if it exists.
#   Backup is placed next to the original with a .bak.<timestamp> suffix.
#
#   If FILE is a symlink:
#     - and SKIP_IF_TARGET is given and readlink(FILE) equals it, no backup
#       is made (deploy_file already handles the "already linked to src"
#       case itself, but this lets callers pass the intended source anyway).
#     - otherwise the symlink itself is backed up (via `cp -a`, which
#       preserves the link rather than following it), so a symlink pointing
#       somewhere else is never silently discarded without a record.
#   SKIP_IF_TARGET is optional; when omitted, all symlinks are backed up.
#
#   Returns 0 if a backup was created or no backup was needed, 1 on error.
backup_file() {
    local file="${1:?backup_file: file path required}"
    local skip_if_target="${2:-}"

    # Nothing to back up if the file doesn't exist.
    [[ -e "$file" ]] || [[ -L "$file" ]] || return 0

    # Skip only when the symlink already points at the intended source.
    if [[ -L "$file" ]] && [[ -n "$skip_if_target" ]] && [[ "$(readlink "$file")" == "$skip_if_target" ]]; then
        return 0
    fi

    local timestamp
    timestamp="$(date +%Y%m%d%H%M%S)"
    local backup="${file}.bak.${timestamp}"

    if [[ "$DRY_RUN" == "1" ]]; then
        log "[DRY-RUN] backup $file -> $backup"
        return 0
    fi

    # cp -a preserves symlinks (copies the link itself, not its target).
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
#   If DEST already exists, it is backed up first. In link mode, an existing
#   symlink that already points to SOURCE is left untouched. DRY_RUN is respected.
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

    # In link mode, if DEST already points to SRC, nothing to do. Copy mode must
    # replace even matching symlinks with real files.
    if [[ "$mode" == "link" ]] && [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
        log "Already linked: $dest -> $src"
        return 0
    fi

    # In copy mode, skip identical regular files (avoids backup churn on re-runs).
    if [[ "$mode" == "copy" ]] && [[ -f "$dest" ]] && [[ ! -L "$dest" ]] && _files_identical "$src" "$dest"; then
        log "Up to date: $dest"
        return 0
    fi

    # Back up existing file at destination. backup_file keeps the existing
    # policy for symlinks, including matching repo symlinks.
    backup_file "$dest" "$src"

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
            if [[ "$DRY_RUN" == "1" ]]; then
                log "[DRY-RUN] Would link: $dest -> $src"
            else
                log "Linked: $dest -> $src"
            fi
            ;;
        copy)
            run cp -a "$src" "$dest"
            if [[ "$DRY_RUN" == "1" ]]; then
                log "[DRY-RUN] Would copy: $src -> $dest"
            else
                log "Copied: $src -> $dest"
            fi
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
