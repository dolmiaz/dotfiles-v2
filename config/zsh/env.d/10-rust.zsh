# Rust / Cargo environment
#
# Uses XDG-compliant paths for cargo and rustup data.

export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

[[ -d "${CARGO_HOME}/bin" ]] && path=("${CARGO_HOME}/bin" $path)
