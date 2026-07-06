# direnv — per-directory environment variables
# https://direnv.net/

(( $+commands[direnv] )) || return

eval "$(direnv hook zsh)"
