# Basic PATH additions
#
# Prepend user-local binary directories so they take precedence
# over system-provided binaries.

# ~/.local/bin — standard user-installed binaries (pip, pipx, etc.)
# Always prepend, even if it does not exist yet: tools installed later
# (uv, npm globals, etc.) place binaries here and existing shells should
# pick them up without needing to re-source.
path=("${HOME}/.local/bin" $path)

# ~/bin — personal scripts
[[ -d "${HOME}/bin" ]] && path=("${HOME}/bin" $path)
