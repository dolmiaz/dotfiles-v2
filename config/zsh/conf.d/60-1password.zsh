# 1Password SSH Agent integration
#
# On macOS, 1Password provides an SSH agent via a Unix socket.
# This lets ssh use keys stored in 1Password without exporting
# private keys to disk.

# Only relevant on macOS
[[ "${OSTYPE}" == darwin* ]] || return

_op_agent_sock="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

if [[ -S "${_op_agent_sock}" ]]; then
  export SSH_AUTH_SOCK="${_op_agent_sock}"
fi

unset _op_agent_sock
