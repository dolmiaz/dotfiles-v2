# Completion system configuration

# Set completion cache directory
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
[[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh" ]] || mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Initialise the completion system
autoload -Uz compinit

# Only regenerate .zcompdump once a day for faster startup
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
if [[ -n "${_zcompdump}"(#qN.mh+24) ]]; then
  compinit -d "${_zcompdump}"
else
  compinit -C -d "${_zcompdump}"
fi
unset _zcompdump

# ── Completion styles ────────────────────────────────────────

# Case-insensitive, partial-word, and substring completion
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'

# Group completions by category
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'

# Menu selection with highlighting
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Complete . and .. directories
zstyle ':completion:*' special-dirs true

# Process completion
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
if [[ "${OSTYPE}" == darwin* ]]; then
  zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,time,command'
else
  zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
fi

# Directories first
zstyle ':completion:*' list-dirs-first true
