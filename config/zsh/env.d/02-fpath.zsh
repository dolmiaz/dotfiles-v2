# zsh function path repair
#
# Homebrew zsh upgrades can leave parent processes with an old FPATH that points
# at a removed Cellar version.  Keep only existing entries, then add function
# directories for the currently running zsh before compinit/autoload run.

_dotfiles_repair_fpath() {
  [[ -n "${ZSH_VERSION:-}" ]] || return 0

  local -a existing candidates add
  local entry

  existing=()
  for entry in "${fpath[@]}"; do
    [[ -n "$entry" && -d "$entry" ]] && existing+=("$entry")
  done

  candidates=()
  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    candidates+=(
      "${HOMEBREW_PREFIX}/share/zsh/site-functions"
      "${HOMEBREW_PREFIX}/Cellar/zsh/${ZSH_VERSION}/share/zsh/functions"
    )
  fi
  candidates+=(
    "/opt/homebrew/share/zsh/site-functions"
    "/opt/homebrew/Cellar/zsh/${ZSH_VERSION}/share/zsh/functions"
    "/usr/local/share/zsh/site-functions"
    "/usr/local/Cellar/zsh/${ZSH_VERSION}/share/zsh/functions"
    "/usr/share/zsh/${ZSH_VERSION}/functions"
  )

  add=()
  for entry in "${candidates[@]}"; do
    [[ -d "$entry" ]] && add+=("$entry")
  done

  fpath=("${add[@]}" "${existing[@]}")
  typeset -U fpath
  export FPATH="${(j.:.)fpath}"
}

_dotfiles_repair_fpath
unfunction _dotfiles_repair_fpath
