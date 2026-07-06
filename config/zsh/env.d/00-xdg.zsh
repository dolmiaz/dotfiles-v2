# XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir-spec/latest/

# Respect values that are already set (e.g. by the login environment).
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"

# Ensure XDG directories exist
# (created quietly; install.sh also handles this)
[[ -d "${XDG_CONFIG_HOME}" ]] || mkdir -p "${XDG_CONFIG_HOME}"
[[ -d "${XDG_DATA_HOME}" ]]   || mkdir -p "${XDG_DATA_HOME}"
[[ -d "${XDG_CACHE_HOME}" ]]  || mkdir -p "${XDG_CACHE_HOME}"
[[ -d "${XDG_STATE_HOME}" ]]  || mkdir -p "${XDG_STATE_HOME}"
