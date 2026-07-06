# nvm — Node Version Manager
# https://github.com/nvm-sh/nvm

export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"

# Bail if nvm is not installed
[[ -s "${NVM_DIR}/nvm.sh" ]] || return

# Lazy-load nvm: define wrapper functions that replace themselves
# on first invocation. This avoids ~200ms startup penalty.
_lazy_nvm_cmds=(nvm node npm npx corepack)

_lazy_nvm_load() {
  for _cmd in "${_lazy_nvm_cmds[@]}"; do
    unfunction "${_cmd}" 2>/dev/null
  done
  source "${NVM_DIR}/nvm.sh"
  [[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
  unset _lazy_nvm_cmds
}

for _cmd in "${_lazy_nvm_cmds[@]}"; do
  eval "${_cmd}() { _lazy_nvm_load; ${_cmd} \"\$@\"; }"
done

unset _cmd
