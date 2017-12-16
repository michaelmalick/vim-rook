Rook.vim
========

Lightweight plugin integrating R and vim/neovim.

- 100% vim-script, no external dependencies
- Use motions and text-objects for sending code to R
- Run R in vim/neovim terminal or a tmux pane
- Switch between multiple R instances



Overview
--------

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

- `:Rhelp` opens an R help file in an html browser for the given function name.
  Given no arguments, the word under the cursor is used. Tab completion for most
  functions distributed with R is provided.

- `:Rview` Given a function name, wrap the word under the cursor in the supplied
  function and evaluate the expression in R. This is useful to quickly view the
  `head()` or `tail()` of a data frame or the `args()` of a function. Given no
  arguments, the previous function supplied to `:Rview` is used. Tab completion
  of previously called function names is available.

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

If you want to automate starting and attaching a new target R session in a
split, you can use the `rook#rstart()` function. For example, the following will
create an `:Rstart` command that will create and attach a new target in a
horizontal split below the current buffer:

```vim
if has('nvim')
    " vim/neovim terminal
    command! Rstart call rook#rstart('belowright 25new')
else
    " tmux
    command! Rstart call rook#rstart('tmux split-window -v -p 35')
endif
```

Several common plugin actions are available for mapping:

```vim
nmap <leader>rs <Plug>RookSourceFile " Source the current file
nmap <leader>rw <Plug>RookSetwd      " setwd() to current directory
nmap <leader>rh <Plug>RookRhelp      " Get help for function under cursor
nmap <leader>ri <Plug>RookRview      " Interactive Rview call
nmap <leader>ra <Plug>RookRargs      " Get arguments for function
```

More generally, if you want key mappings to evaluate frequently used commands
(with path expansion), you can use the `rook#send_text` function. For example,
the following mapping will render the current R-markdown file in the target R
session:

```vim
nnoremap <silent> <leader>rm :call
    \ rook#send_text('rmarkdown::render("' . expand('%:p') . '")')<CR>
```

See
[documentation](https://github.com/michaelmalick/vim-rook/blob/master/doc/rook.txt)
for full suit of commands and configuration options.



Installation
------------

Use your favorite plugin manager. If you don't have one, I recommend
[vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'michaelmalick/vim-rook'
```



License
-------
MIT
