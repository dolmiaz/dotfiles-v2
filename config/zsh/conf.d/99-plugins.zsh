# zsh plugins — autosuggestions and syntax highlighting
#
# These should be loaded last. Syntax highlighting in particular
# must be sourced after all other widgets are defined.

# ── zsh-autosuggestions ──────────────────────────────────────
_plugin_autosuggestions=""
for _candidate in \
  "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  if [[ -r "${_candidate}" ]]; then
    _plugin_autosuggestions="${_candidate}"
    break
  fi
done

if [[ -n "${_plugin_autosuggestions}" ]]; then
  source "${_plugin_autosuggestions}"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
fi

unset _plugin_autosuggestions _candidate

# ── zsh-syntax-highlighting (must be last) ───────────────────
_plugin_syntax_hl=""
for _candidate in \
  "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  if [[ -r "${_candidate}" ]]; then
    _plugin_syntax_hl="${_candidate}"
    break
  fi
done

if [[ -n "${_plugin_syntax_hl}" ]]; then
  source "${_plugin_syntax_hl}"
fi

unset _plugin_syntax_hl _candidate
