# Basic PATH additions
#
# Prepend user-local binary directories so they take precedence
# over system-provided binaries.

# ~/.local/bin — standard user-installed binaries (pip, pipx, etc.)
[[ -d "${HOME}/.local/bin" ]] && path=("${HOME}/.local/bin" $path)

# ~/bin — personal scripts
[[ -d "${HOME}/bin" ]] && path=("${HOME}/bin" $path)
