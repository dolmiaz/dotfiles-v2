# Node.js / npm environment
#
# Set npm prefix to ~/.local so global installs land in
# ~/.local/bin (already on PATH via 01-path.zsh).

export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"

# Ensure npm global bin is on PATH (matches prefix in npmrc)
[[ -d "${HOME}/.local/bin" ]] && path=("${HOME}/.local/bin" $path)
