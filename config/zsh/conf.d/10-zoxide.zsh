# zoxide — smarter cd
# https://github.com/ajeetdsouza/zoxide

(( $+commands[zoxide] )) || return

eval "$(zoxide init zsh)"
