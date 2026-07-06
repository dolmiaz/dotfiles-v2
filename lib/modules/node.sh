#!/usr/bin/env bash
set -euo pipefail

# node.sh -- Install and verify Node.js
# Requires: lib/common.sh (log, warn, have, run)
#           lib/detect.sh  (pkg_install, OS)

_npm_userconfig() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
}

_npm_cache_dir() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/npm"
}

_nvm_dir() {
  printf '%s\n' "${NVM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvm}"
}

_node_has_nvm() {
  [[ -s "$(_nvm_dir)/nvm.sh" ]]
}

_ensure_npm_prefix_config() {
  have npm || return 0

  export NPM_CONFIG_USERCONFIG="$(_npm_userconfig)"
  export NPM_CONFIG_CACHE="$(_npm_cache_dir)"
  run mkdir -p "$(dirname "$NPM_CONFIG_USERCONFIG")"
  run mkdir -p "$NPM_CONFIG_CACHE"

  if [[ ! -f "$NPM_CONFIG_USERCONFIG" ]] && [[ -r "${DOTFILES_DIR:-}/config/npm/npmrc" ]]; then
    run cp -a "$DOTFILES_DIR/config/npm/npmrc" "$NPM_CONFIG_USERCONFIG"
  fi

  local cache prefix
  cache="$(env -u NPM_CONFIG_CACHE npm config get cache 2>/dev/null || true)"
  if [[ "$cache" != "$(_npm_cache_dir)" ]]; then
    run npm config set cache "$(_npm_cache_dir)"
    log "Set npm cache to $(_npm_cache_dir)"
  fi

  if _node_has_nvm; then
    if [[ -f "$NPM_CONFIG_USERCONFIG" ]] && grep -Eq '^[[:space:]]*prefix[[:space:]]*=' "$NPM_CONFIG_USERCONFIG"; then
      run npm config delete prefix
      log "npm prefix is left to nvm"
    else
      log "npm prefix is managed by nvm"
    fi
    return 0
  fi

  prefix="$(env -u NPM_CONFIG_PREFIX npm config get prefix 2>/dev/null || true)"
  if [[ "$prefix" != "$HOME/.local" ]]; then
    run npm config set prefix "$HOME/.local"
    log "Set npm prefix to $HOME/.local"
  else
    log "npm prefix is $HOME/.local"
  fi
}

check_npm_ownership() {
  local dirs=()
  [[ -d "$HOME/.npm" ]] && dirs+=("$HOME/.npm")
  [[ -d "$(_npm_cache_dir)" ]] && dirs+=("$(_npm_cache_dir)")

  (( ${#dirs[@]} > 0 )) || return 2

  local bad
  bad="$(find "${dirs[@]}" ! -user "$(id -un)" -print -quit 2>/dev/null)"
  if [[ -n "$bad" ]]; then
    warn "npm directory contains files not owned by $(id -un): $bad"
    return 1
  fi
  return 0
}

repair_npm_ownership() {
  local dirs=()
  [[ -d "$HOME/.npm" ]] && dirs+=("$HOME/.npm")
  [[ -d "$(_npm_cache_dir)" ]] && dirs+=("$(_npm_cache_dir)")

  if (( ${#dirs[@]} > 0 )); then
    run sudo chown -R "$(id -un):$(id -gn)" "${dirs[@]}"
  fi
  check_npm_ownership
}

check_npm_legacy_config() {
  [[ -f "$HOME/.npmrc" ]] || return 2

  if grep -Eq '^[[:space:]]*(prefix|globalconfig)[[:space:]]*=' "$HOME/.npmrc"; then
    warn "legacy ~/.npmrc overrides the XDG config and conflicts with nvm"
    return 1
  fi
  return 0
}

repair_npm_legacy_config() {
  local npmrc="$HOME/.npmrc"
  [[ -f "$npmrc" ]] || return 0

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "Would remove prefix/globalconfig lines from $npmrc"
    return 0
  fi

  if declare -f backup_file &>/dev/null; then
    backup_file "$npmrc"
  else
    cp -a "$npmrc" "${npmrc}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/npmrc.XXXXXX")"
  grep -Ev '^[[:space:]]*(prefix|globalconfig)[[:space:]]*=' "$npmrc" > "$tmp" || true
  run mv "$tmp" "$npmrc"
  log "Removed legacy npm prefix/globalconfig from $npmrc"
}

install_node() {
  log "Installing Node.js"
  case "$OS" in
    macos)
      pkg_install node
      ;;
    debian)
      pkg_install nodejs npm
      ;;
    redhat)
      if have dnf; then
        run sudo dnf module install -y nodejs
      else
        pkg_install nodejs
      fi
      ;;
  esac

  # Configure npm cache and prefix without conflicting with nvm.
  _ensure_npm_prefix_config
}

# Return: 0 = OK, 1 = FAIL (wrong npm config), 2 = SKIP (npm not installed)
check_node() {
  have npm || return 2

  local userconfig cache prefix
  userconfig="$(_npm_userconfig)"

  cache="$(env -u NPM_CONFIG_CACHE -u NPM_CONFIG_PREFIX NPM_CONFIG_USERCONFIG="$userconfig" npm config get cache 2>/dev/null)"
  if [[ "$cache" != "$(_npm_cache_dir)" ]]; then
    warn "npm cache is '$cache', expected '$(_npm_cache_dir)'"
    return 1
  fi

  if _node_has_nvm; then
    if [[ -f "$userconfig" ]] && grep -Eq '^[[:space:]]*prefix[[:space:]]*=' "$userconfig"; then
      warn "npm prefix in $userconfig conflicts with nvm"
      return 1
    fi
    return 0
  fi

  prefix="$(env -u NPM_CONFIG_CACHE -u NPM_CONFIG_PREFIX NPM_CONFIG_USERCONFIG="$userconfig" npm config get prefix 2>/dev/null)"
  if [[ "$prefix" != "$HOME/.local" ]]; then
    warn "npm prefix is '$prefix', expected '$HOME/.local'"
    return 1
  fi
  return 0
}

repair_node() {
  _ensure_npm_prefix_config
}
