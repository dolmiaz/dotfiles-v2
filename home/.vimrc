" ~/.vimrc — redirect shim
"
" Vim configuration lives at ~/.config/vim/vimrc.
" This file forwards to the real vimrc so Vim finds it
" regardless of how it is invoked.

if filereadable(expand('~/.config/vim/vimrc'))
  source ~/.config/vim/vimrc
endif
