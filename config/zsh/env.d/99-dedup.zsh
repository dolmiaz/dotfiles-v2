# Deduplicate PATH
#
# Must run after all other env.d files. typeset -U removes
# duplicate entries while preserving order.

typeset -U path
typeset -U fpath
typeset -U manpath
