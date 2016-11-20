" rook.vim - Evaluate R code in a tmux pane or neovim terminal
" Author:   Michael Malick <malickmj@gmail.com>
" Version:  1.1


if exists('g:loaded_rook') || &cp || v:version < 700 || !executable('tmux')
  finish
endif
let g:loaded_rook = 1

if !exists('g:rook_tmp_file')
    let g:rook_tmp_file = tempname()
endif

if !exists('g:rook_source_send')
    let g:rook_source_send = 1
endif

if !exists('g:rook_target_type')
    if has('nvim')
        let g:rook_target_type = 'neovim'
    else
        let g:rook_target_type = 'tmux'
    endif
endif

command! -nargs=1 -complete=custom,rook#completion_target Rattach 
    \:call rook#command_rattach(<q-args>)

command! -range -nargs=? Rwrite 
    \:call rook#command_rwrite(<line1>, <line2>, <q-args>)

command! -nargs=? -complete=custom,rook#completion_rfunctions Rhelp 
    \:call rook#command_rhelp(<q-args>)

command! -nargs=? -complete=custom,rook#completion_rfunctions Rview 
    \:call rook#command_rview(<q-args>)

xnoremap <silent> <Plug>RookSend     :<C-U>call rook#send(1)<CR>
nnoremap <silent> <Plug>RookSend     :<C-U>call rook#send(0)<CR>g@
nnoremap <silent> <Plug>RookSendLine :<C-U>call rook#send_line()<Bar>
    \ exe 'norm! '.g:rook_count1.'g@_'<CR>

augroup rook_plugin
    autocmd!
    autocmd VimLeave * call delete(g:rook_tmp_file)
    if g:rook_source_send
        let source_cmd = 'source("' . g:rook_tmp_file . '" , echo = TRUE)'
        autocmd BufNewFile,BufRead *.r,*.R,*.rmd,*.Rmd,*.rnw,*.Rnw
            \ let g:rook_source_command = source_cmd
    endif
augroup END

