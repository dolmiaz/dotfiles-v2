# ${ZDOTDIR}/.zshrc — sourced for interactive shells
#
# Sources every file in conf.d/ in numeric order, then loads
# the landing pad from ~/.zshrc to pick up any tool-appended config.

# Bail out early if not interactive (safety guard)
[[ -o interactive ]] || return

DOTFILES_CONF_DIR="${ZDOTDIR}/conf.d"

if [[ -d "${DOTFILES_CONF_DIR}" ]]; then
  for _conf_file in "${DOTFILES_CONF_DIR}"/*.zsh(N); do
    source "${_conf_file}"
  done
  unset _conf_file
fi

unset DOTFILES_CONF_DIR

# ── Landing Pad ─────────────────────────────────────────────
# LLM/ツール互換: ~/.zshrc に追記された設定を拾う
if [[ "${ZDOTDIR:-$HOME}" != "$HOME" && -r "$HOME/.zshrc" ]]; then
  source "$HOME/.zshrc"
fi
