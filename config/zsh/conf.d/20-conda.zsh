# conda / miniconda / miniforge initialisation

# Find conda installation (common locations)
_conda_root=""
for _candidate in \
  "${HOME}/miniforge3" \
  "${HOME}/miniconda3" \
  "${HOME}/anaconda3" \
  "/opt/homebrew/Caskroom/miniforge/base" \
  "/usr/local/Caskroom/miniforge/base" \
  "/opt/conda"; do
  if [[ -x "${_candidate}/bin/conda" ]]; then
    _conda_root="${_candidate}"
    break
  fi
done

if [[ -z "${_conda_root}" ]]; then
  unset _conda_root _candidate
  return
fi

# Lazy-load conda: define a function that replaces itself on first call
conda() {
  unfunction conda
  __conda_setup="$("${_conda_root}/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "${__conda_setup}"
  else
    # Fall back to simple PATH addition
    path=("${_conda_root}/bin" $path)
  fi
  unset __conda_setup
  conda "$@"
}

unset _candidate
