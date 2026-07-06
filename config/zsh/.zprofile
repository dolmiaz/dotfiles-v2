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

# On macOS, source path_helper for /etc/paths.d entries
if [[ -x /usr/libexec/path_helper ]]; then
  eval "$(/usr/libexec/path_helper -s)"
fi
