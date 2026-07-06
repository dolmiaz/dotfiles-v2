# starship — cross-shell prompt
# https://starship.rs/

(( $+commands[starship] )) || return

export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"

eval "$(starship init zsh)"
