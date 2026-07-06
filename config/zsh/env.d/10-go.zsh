# Go environment
#
# Keep GOPATH under XDG_DATA_HOME to avoid polluting $HOME.

export GOPATH="${XDG_DATA_HOME:-$HOME/.local/share}/go"
export GOBIN="${GOPATH}/bin"

[[ -d "${GOBIN}" ]] && path=("${GOBIN}" $path)
