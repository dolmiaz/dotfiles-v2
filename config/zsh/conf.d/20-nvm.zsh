# nvm — Node Version Manager
# https://github.com/nvm-sh/nvm

_dotfiles_nvm_dir=""
_dotfiles_nvm_xdg_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"
if [[ -n "${NVM_DIR:-}" && -r "${NVM_DIR}/nvm.sh" ]]; then
  _dotfiles_nvm_dir="${NVM_DIR}"
elif [[ -r "${_dotfiles_nvm_xdg_dir}/nvm.sh" ]]; then
  _dotfiles_nvm_dir="${_dotfiles_nvm_xdg_dir}"
elif [[ -r "${HOME}/.nvm/nvm.sh" ]]; then
  _dotfiles_nvm_dir="${HOME}/.nvm"
fi

# Bail if nvm is not installed
[[ -n "${_dotfiles_nvm_dir}" ]] || {
  unset _dotfiles_nvm_dir _dotfiles_nvm_xdg_dir
  return
}

export NVM_DIR="${_dotfiles_nvm_dir}"
unset _dotfiles_nvm_dir _dotfiles_nvm_xdg_dir

# Lazy-load nvm: define wrapper functions that replace themselves
# on first invocation. This avoids ~200ms startup penalty.
_lazy_nvm_cmds=(nvm node npm npx corepack)

_lazy_nvm_load() {
  for _cmd in "${_lazy_nvm_cmds[@]}"; do
    unfunction "${_cmd}" 2>/dev/null
  done
  source "${NVM_DIR}/nvm.sh" --no-use
  if [[ -e "${NVM_DIR}/alias/default" ]]; then
    nvm use --delete-prefix default --silent >/dev/null || print -u2 "warning: nvm default alias could not be loaded"
  fi
  if [[ -n "${NVM_BIN:-}" ]]; then
    path=("${NVM_BIN}" "${path[@]}")
    typeset -U path
    rehash
  fi
  [[ -t 0 && -t 1 && -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
  unset _lazy_nvm_cmds
}

for _cmd in "${_lazy_nvm_cmds[@]}"; do
  eval "${_cmd}() { _lazy_nvm_load; ${_cmd} \"\$@\"; }"
done

unset _cmd
