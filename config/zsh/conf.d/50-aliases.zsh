# Shell aliases

# ── ls ───────────────────────────────────────────────────────
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --group-directories-first --git'
  alias la='eza -la --group-directories-first --git'
  alias lt='eza --tree --level=2'
else
  alias ls='ls --color=auto 2>/dev/null || ls -G'
  alias ll='ls -lh'
  alias la='ls -lAh'
fi

# ── grep ─────────────────────────────────────────────────────
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ── cat ──────────────────────────────────────────────────────
if (( $+commands[bat] )); then
  alias cat='bat --paging=never'
  alias catp='bat --plain --paging=never'
fi

# ── navigation ───────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ── safety nets ──────────────────────────────────────────────
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ── mkdir ────────────────────────────────────────────────────
alias mkdir='mkdir -pv'

# ── disk usage ───────────────────────────────────────────────
if (( $+commands[dust] )); then
  alias du='dust'
fi
if (( $+commands[duf] )); then
  alias df='duf'
fi

# ── git shortcuts ────────────────────────────────────────────
alias g='git'
alias gs='git status --short'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpull='git pull'
alias gco='git checkout'
alias gsw='git switch'
alias gbr='git branch'

# ── docker ───────────────────────────────────────────────────
if (( $+commands[docker] )); then
  alias dk='docker'
  alias dkc='docker compose'
  alias dkps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
fi

# ── misc ─────────────────────────────────────────────────────
alias path='echo -e "${PATH//:/\\n}"'
alias reload='exec ${SHELL} -l'
