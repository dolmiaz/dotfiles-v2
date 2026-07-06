# ~/.zshenv — ZDOTDIR bootstrap
#
# This file sets ZDOTDIR so zsh loads configuration from
# ~/.config/zsh/ instead of $HOME, keeping the home directory clean.
# It then sources the real .zshenv to set up the environment.

export ZDOTDIR="${HOME}/.config/zsh"

# Source the real .zshenv if it exists
[[ -r "${ZDOTDIR}/.zshenv" ]] && source "${ZDOTDIR}/.zshenv"
