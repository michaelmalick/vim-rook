rook.vim
========

Lightweight plugin integrating R and vim/neovim.

- `:Rattach` attaches a target R console to send and evaluate code in (with tab
  completion). Rook can attach to an R console running either in a tmux pane or
  a neovim terminal buffer. If you are in neovim, rook assumes the
  R console is running in a neovim buffer and in vim, rook assumes it is running
  in a tmux pane. In neovim, `Rattach` accepts a buffer name and in vim
  `Rattach` accepts a tmux pane location in the form of
  `session_name:window_name.pane_index`.

- `:Rwrite` sends text/commands to be evaluated in the target R console. Given a
  range, those lines will be sent. Given an argument, that argument will be
  sent, e.g., `:Rwrite ls()`, and given neither a range or an argument, the
  current line is sent.

- `:Rhelp` opens an R help file in a new buffer for the given function name.
  Given no arguments, the word under the cursor is used. Tab completion for most
  functions distributed with R is provided.

- `:Rview` Given a function name, wrap the word under the cursor in the supplied
  function and evaluate the expression in R. This is useful to quickly view the
  `head()` or `tail()` of a data frame or the `args()` of a function. Given no
  arguments, the previous function supplied to `:Rview` is used. Tab completion
  of function names works here also.

If you want key mappings to send code from a vim buffer to the target R console,
add the following to your .vimrc:

```vim
xmap gl  <Plug>RookSend      " Send selected text
nmap gl  <Plug>RookSend      " Send motion/text object
nmap gll <Plug>RookSendLine  " Send current line
```

To send the current line, use `gll`. Use `gl` followed by a
motion to send the motion target, e.g., `glap` will send a paragraph. In visual
mode, use `gl` to send the current selection.

If you want key mappings to evaluate frequently used commands (with path
expansion), you can use the `rook#send_text` function. For example, the
following mapping will source the current file in the target R console:

```vim
nnoremap <silent> <leader>rs :call
    \ rook#send_text('source("' . expand('%:p') . '")')<CR>
```


Installation
============
To install, I recommend installing
[pathogen](https://github.com/tpope/vim-pathogen) and then simply run:

    cd ~/.vim/bundle
    git clone git://github.com/michaelmalick/vim-rook.git


License
=======
Rook is [MIT/X11](http://opensource.org/licenses/MIT) licensed.
Copyright (c) 2016-2017 Michael Malick

