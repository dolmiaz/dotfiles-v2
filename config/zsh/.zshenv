# ${ZDOTDIR}/.zshenv — sourced for ALL zsh sessions
#
# Sources every file in env.d/ to set up environment variables,
# PATH, and exports. No interactive or tty-dependent code here.

DOTFILES_ENV_DIR="${ZDOTDIR}/env.d"

if [[ -d "${DOTFILES_ENV_DIR}" ]]; then
  for _env_file in "${DOTFILES_ENV_DIR}"/*.zsh(N); do
    source "${_env_file}"
  done
  unset _env_file
fi

unset DOTFILES_ENV_DIR
