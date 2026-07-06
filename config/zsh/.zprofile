# ${ZDOTDIR}/.zprofile — sourced for login shells only
#
# Keep this file lightweight. Heavy initialisation belongs in
# conf.d/ (loaded via .zshrc for interactive sessions).

# Ensure /usr/local/bin and /opt/homebrew/bin are available early.
# Homebrew on Apple Silicon uses /opt/homebrew; Intel uses /usr/local.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# /etc/zprofile (path_helper) reorders PATH after .zshenv ran, demoting
# user-priority entries added by env.d.  Re-source env.d so ~/.local/bin,
# cargo, nvm, etc. are prepended again (typeset -U keeps first occurrence).
if [[ -d "${ZDOTDIR}/env.d" ]]; then
  for _env_file in "${ZDOTDIR}/env.d"/*.zsh(N); do
    source "${_env_file}"
  done
  unset _env_file
fi
