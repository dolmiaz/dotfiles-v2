# Node.js / npm environment
#
# Use XDG npm config/cache. Without nvm, set npm prefix to ~/.local
# so global installs land in ~/.local/bin (already on PATH via 01-path.zsh).

export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/npm"

# Keep ~/.local/bin on PATH for non-nvm npm globals and local tools.
# When nvm is present, its default bin is prepended later so it stays first.
# Always prepend, even if it does not exist yet (see 01-path.zsh).
path=("${HOME}/.local/bin" $path)

_dotfiles_nvm_dir="${NVM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvm}"
if [[ ! -s "${_dotfiles_nvm_dir}/nvm.sh" ]]; then
  export NPM_CONFIG_PREFIX="${HOME}/.local"
else
  unset NPM_CONFIG_PREFIX

  # Interactive shells still get exact resolution via nvm lazy-load
  # (conf.d/20-nvm.zsh); this is the fallback for non-interactive sessions.
  _dotfiles_nvm_bin=""
  _dotfiles_nvm_default=""
  _dotfiles_nvm_hops=0
  _dotfiles_nvm_alias=""
  _dotfiles_nvm_default_file="${_dotfiles_nvm_dir}/alias/default"
  if [[ -r "${_dotfiles_nvm_default_file}" ]]; then
    IFS= read -r _dotfiles_nvm_default < "${_dotfiles_nvm_default_file}"
    while [[ -n "${_dotfiles_nvm_default}" && "${_dotfiles_nvm_default}" != v* && ${_dotfiles_nvm_hops} -lt 2 ]]; do
      _dotfiles_nvm_alias="${_dotfiles_nvm_dir}/alias/${_dotfiles_nvm_default}"
      [[ -r "${_dotfiles_nvm_alias}" ]] || break
      IFS= read -r _dotfiles_nvm_default < "${_dotfiles_nvm_alias}"
      _dotfiles_nvm_hops=$(( _dotfiles_nvm_hops + 1 ))
    done
    if [[ "${_dotfiles_nvm_default}" == v* && -d "${_dotfiles_nvm_dir}/versions/node/${_dotfiles_nvm_default}/bin" ]]; then
      _dotfiles_nvm_bin="${_dotfiles_nvm_dir}/versions/node/${_dotfiles_nvm_default}/bin"
    fi
  fi

  if [[ -z "${_dotfiles_nvm_bin}" ]]; then
    _vers=("${_dotfiles_nvm_dir}"/versions/node/v*(Nn/))
    if (( ${#_vers[@]} > 0 )) && [[ -d "${_vers[-1]}/bin" ]]; then
      _dotfiles_nvm_bin="${_vers[-1]}/bin"
    fi
  fi
  [[ -n "${_dotfiles_nvm_bin}" ]] && path=("${_dotfiles_nvm_bin}" $path)
fi
unset _dotfiles_nvm_dir _dotfiles_nvm_bin _dotfiles_nvm_default_file _dotfiles_nvm_default
unset _dotfiles_nvm_hops _dotfiles_nvm_alias _vers
