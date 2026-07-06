# uv — Python package installer and resolver
# https://docs.astral.sh/uv/

# Place uv cache and tool data under XDG directories
export UV_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/uv"
export UV_TOOL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/uv/tools"

# uv installs its own binary here
[[ -d "${HOME}/.local/bin" ]] && path=("${HOME}/.local/bin" $path)
