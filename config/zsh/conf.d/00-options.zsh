# Shell options and history configuration

# ── History ──────────────────────────────────────────────────
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
export HISTSIZE=50000
export SAVEHIST=50000

# Ensure history directory exists
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

# ── History options ──────────────────────────────────────────
setopt HIST_IGNORE_DUPS       # Don't record duplicate entries
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate first
setopt HIST_IGNORE_SPACE      # Don't record lines starting with space
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks
setopt HIST_VERIFY            # Show expansion before executing
setopt SHARE_HISTORY          # Share history between sessions
setopt APPEND_HISTORY         # Append rather than overwrite
setopt INC_APPEND_HISTORY     # Write after each command

# ── Directory navigation ─────────────────────────────────────
setopt AUTO_CD                # cd by typing directory name
setopt AUTO_PUSHD             # Push directories onto stack
setopt PUSHD_IGNORE_DUPS      # Don't push duplicates
setopt PUSHD_SILENT           # Don't print directory stack

# ── Globbing and expansion ───────────────────────────────────
setopt EXTENDED_GLOB          # Extended globbing (#, ~, ^)
setopt NO_CASE_GLOB           # Case-insensitive globbing
setopt GLOB_DOTS              # Include dotfiles in globbing

# ── Misc ─────────────────────────────────────────────────────
setopt INTERACTIVE_COMMENTS   # Allow comments in interactive shell
setopt NO_BEEP                # Don't beep on errors
setopt CORRECT                # Spelling correction for commands
setopt NO_FLOW_CONTROL        # Disable Ctrl-S/Ctrl-Q flow control
