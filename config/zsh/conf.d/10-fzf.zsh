# fzf — fuzzy finder integration
# https://github.com/junegunn/fzf

(( $+commands[fzf] )) || return

# Default options
export FZF_DEFAULT_OPTS="\
  --height=40% \
  --layout=reverse \
  --border=rounded \
  --info=inline \
  --marker='*' \
  --bind='ctrl-/:toggle-preview'"

# Use fd if available for faster traversal
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# Load fzf key bindings and completion
# fzf 0.48+ uses this path; older versions use the shell script
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.zsh" ]]; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.zsh"
elif (( $+commands[fzf] )); then
  # fzf 0.48+ built-in shell integration
  eval "$(fzf --zsh 2>/dev/null)" || true
fi
