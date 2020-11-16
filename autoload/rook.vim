" rook.vim - autoload functions
" Author: Michael Malick <malickmj@gmail.com>

function rook#command_rdev(function)
    let l:str = 'devtools::'.a:function.'()'
    call rook#send_text(l:str)
endfunction

function! rook#completion_rdev(...)
    let l:funs = ["check", "document", "install",
                \ "test", "unload", "load_all",]
    return join(l:funs, "\n")
endfunction

function! rook#get_prev_function_name()
    let l:win_view = winsaveview()
    let l:pattern = '[0-9a-zA-Z:_\.]\+\s*\ze('
    let l:sea = search(l:pattern, 'bcW')
    if l:sea == 0
        call winrestview(l:win_view)
        return 0
    endif
    let l:line = getline(l:sea)
    let l:matched_raw  = matchstr(l:line, l:pattern)
    let l:matched_stripped = substitute(l:matched_raw, '^\s\+\|\s\+$', '', 'g')
    call winrestview(l:win_view)
    return l:matched_stripped
endfunction

function! rook#command_rargs(function)
    if empty(a:function)
        let l:fun = rook#get_prev_function_name()
    else
        let l:fun = a:function
    endif
    if string(l:fun) ==# '0'
        call rook#warning_msg("Rook: no previous function found")
        return
    else
        let g:rook_rargs_fun = l:fun
    endif
    call rook#send_text('args('.g:rook_rargs_fun.')')
endfunction

function! rook#warning_msg(message)
    echohl WarningMsg
    echom a:message
    echohl None
    return 0
endfunction

function! rook#win_path_fslash(path)
    let l:esc = substitute(a:path, '\', '/', 'g')
    return l:esc
endfunction

function! rook#auto_attach()
    if g:rook_auto_attach == 1
        call rook#set_buffer_target_id()
    endif
endfunction

function! rook#rstudio_folding()
    "" RStudio doesn't have nested folding, i.e., the different markers
    "" at the end of the lines do not signify different fold levels
    if(g:rook_nest_folds)
        let l:lev1 = ">1"
        let l:lev2 = ">2"
        let l:lev3 = ">3"
    else
        let l:lev1 = ">1"
        let l:lev2 = ">1"
        let l:lev3 = ">1"
    endif

    let h1 = matchstr(getline(v:lnum), '^#.*#\{4}$')
    let h2 = matchstr(getline(v:lnum), '^#.*=\{4}$')
    let h3 = matchstr(getline(v:lnum), '^#.*-\{4}$')

    if empty(h1) && empty(h2) && empty(h3)
        return "="
    elseif !empty(h1)
        return l:lev1
    elseif !empty(h2)
        return l:lev2
    elseif !empty(h3)
        return l:lev3
    endif
endfunction

function! rook#fold_expr()
    if g:rook_rstudio_folding
        setlocal foldmethod=expr
        setlocal foldexpr=rook#rstudio_folding()
    endif
endfunction

function! rook#get_source_cmd(fpath, echo, local)
    let l:fpath = rook#win_path_fslash(a:fpath)
    let l:args = [ ]
    if &fileencoding ==# 'utf-8'
        call add(l:args, 'encoding = "UTF-8"')
    endif
    if a:echo
        call add(l:args, 'echo = TRUE')
    endif
    if a:local
        call add(l:args, 'local = TRUE')
    endif
    let l:args = join(l:args, ',')
    let l:cmd = 'base::source("' . l:fpath . '",' . l:args . ')'
    return l:cmd
endfunction

function! rook#source_send()
    if g:rook_source_send
        let g:rook_source_send_command = rook#get_source_cmd(g:rook_tmp_file, 1, 1)
    endif
endfunction

function! rook#get_active_tmux_pane_id()
    let l:pane_id = system('tmux display-message -p "#{pane_id}"')
    let l:pane_id = matchstr(l:pane_id, '%\d\+\ze')
    return l:pane_id
endfunction

function! rook#get_active_tmux_window_id()
    let l:window_id = system('tmux display-message -p "#{window_id}"')
    let l:window_id = matchstr(l:window_id, '@\d\+\ze')
    return l:window_id
endfunction

function! rook#get_active_tmux_session_id()
    let l:session_id = system('tmux display-message -p "#{session_id}"')
    let l:session_id = matchstr(l:session_id, '$\d\+\ze')
    return l:session_id
endfunction

function! rook#rstart(new)
    if g:rook_target_type ==# 'tmux'
        if !exists('$TMUX')
            call rook#warning_msg("Rook: vim isn't inside tmux, use :Rattach instead")
            return
        endif
        let l:start_paneid = rook#get_active_tmux_pane_id()
        let l:start_windowid = rook#get_active_tmux_window_id()
        let l:start_sessionid = rook#get_active_tmux_session_id()
        call system(a:new)
        let l:target_paneid = rook#get_active_tmux_pane_id()
        if l:start_paneid == l:target_paneid
            call rook#warning_msg("Rook: command didn't create a new pane")
            return
        endif
        call system('tmux select-session -t '.l:start_sessionid)
        call system('tmux select-window -t '.l:start_windowid)
        call system('tmux select-pane -t '.l:start_paneid)
        let b:rook_target_id = l:target_paneid
        call rook#attach_dict_add(b:rook_target_id)
        call rook#send_text('R')
    elseif g:rook_target_type ==# 'vim'
        let l:start_winid = win_getid()
        exe a:new
        let l:end_winid = win_getid()
        if l:start_winid == l:end_winid
            call rook#warning_msg("Rook: command didn't create a new window")
            return
        endif
        exe 'enew'
        if has('nvim')
            let l:jobid = termopen('R')
        else
            let l:jobid = term_start('R', {'curwin':1})
        endif
        if g:rook_highlight_console == 1
            set syntax=rconsole
        endif
        call win_gotoid(l:start_winid)
        let b:rook_target_id = l:jobid
        call rook#attach_dict_add(b:rook_target_id)
    endif
endfunction

function! rook#send_line()
    let g:rook_count1 = v:count1
    call rook#save_view()
    set opfunc=rook#opfunc
endfunction

function! rook#send(visual)
    call rook#save_view()
    if a:visual
        call rook#opfunc(visualmode(), 1)
    else
        set opfunc=rook#opfunc
    endif
endfunction

function! rook#completion_target(...)
    if g:rook_target_type ==# 'tmux'
        return system('tmux list-panes -F "#S:#W.#P" -a')
    elseif g:rook_target_type ==# 'vim'
        let l:max_bufnr = bufnr('$')
        let l:bufname_list = []
        let l:c = 1
        while l:c <= l:max_bufnr
            if bufexists(l:c) && buflisted(l:c) && getbufvar(l:c, '&buftype') ==# 'terminal'
                call add(l:bufname_list, bufname(l:c))
            endif
            let l:c += 1
        endwhile
        return join(l:bufname_list, "\n")
    endif
endfunction

function! rook#completion_rhelp(...)
    return join(g:rook_rhelp_complete_list, "\n")
endfunction

function! rook#completion_rview(...)
    return join(g:rook_rview_complete_list, "\n")
endfunction

function! rook#complete_add(list, item)
    "" Add item to completion list
    let l:tmp_lst = insert(a:list, a:item)
    let l:tmp_lst = reverse(tmp_lst)
    let l:tmp_lst = filter(copy(l:tmp_lst), 'index(l:tmp_lst, v:val, v:key+1)==-1')
    return reverse(l:tmp_lst)
endfunction

function! rook#command_rview(function)
    let l:word = expand("<cword>")
    if !empty(a:function)
        let g:rook_rview_fun = a:function
    elseif !exists('g:rook_rview_fun')
        call rook#warning_msg("Rook: no previous function")
        return
    endif
    let l:text = g:rook_rview_fun.'('.l:word.')'
    call rook#send_text(l:text)
    let g:rook_rview_complete_list = rook#complete_add(g:rook_rview_complete_list, g:rook_rview_fun)
endfunction

function! rook#interact_rview(visual)
    if a:visual
        let l:word_lst = s:rook_get_selection()
        let l:word = l:word_lst[0]
    else
        let l:word = expand("<cword>")
    endif
    if !exists('g:rook_rview_fun')
        let g:rook_rview_fun = ''
    endif
    let l:input_text = 'Function: '
    call inputsave()
    let g:rook_rview_fun = input(l:input_text, g:rook_rview_fun, "custom,rook#completion_rview")
    call inputrestore()
    let l:text = g:rook_rview_fun.'('.l:word.')'
    if g:rook_rview_fun == ''
        normal :<ESC>
        return
    endif
    normal :<ESC>
    call rook#send_text(l:text)
    let g:rook_rview_complete_list = rook#complete_add(g:rook_rview_complete_list, g:rook_rview_fun)
endfunction

function! rook#get_help_call(function)
    if empty(a:function)
        if empty(a:function)
            let l:word = rook#get_prev_function_name()
        endif
        if string(l:word) ==# '0'
            call rook#warning_msg("Rook: no function found")
            return -1
        endif
    else
        let l:word = a:function
    endif
    let l:func_pack = rook#parse_function_name(l:word)
    let l:func = l:func_pack[0]
    let l:package = l:func_pack[1]
    if match(['html', 'text'], g:rook_help_type) == -1
        call rook#warning_msg("Rook: g:rook_help_type not set to 'html' or 'text'")
        return -1
    endif
    " Double and single quotes matter on next line:
    "   'help_type' needs to be in single quotes
    let l:help_call = "utils::help(".shellescape(l:func).", package=".l:package.", help_type='".g:rook_help_type."')"
    return l:help_call
endfunction

function! rook#parse_function_name(string)
    "" returns a list: [function, package]
    if match(a:string, '::') < 0
        let l:package = 'NULL'
        let l:func = a:string
    endif
    if match(a:string, ':::') > -1
        let l:package = split(a:string, ':::')[0]
        let l:func    = split(a:string, ':::')[1]
    elseif match(a:string, '::') > -1
        let l:package = split(a:string, '::')[0]
        let l:func    = split(a:string, '::')[1]
    endif
    return [l:func, l:package]
endfunction

function! rook#command_rhelp(function_input)
    if empty(a:function_input)
        let l:function_found = rook#get_prev_function_name()
    else
        let l:function_found = a:function_input
    endif
    let l:function_package = rook#parse_function_name(l:function_found)
    let l:function = l:function_package[0]
    let l:package = l:function_package[1]
    let l:help_call = rook#get_help_call(l:function_found)
    if l:help_call == -1
        return
    else
        call rook#send_text(l:help_call)
    endif
    let g:rook_rhelp_complete_list = rook#complete_add(g:rook_rhelp_complete_list, l:function_found)
endfunction

function! rook#command_rwrite(line1, line2, commands)
    if !exists('b:rook_target_id')
        call rook#warning_msg("Rook: no target attached")
        return
    elseif !s:target_still_exists()
        call rook#warning_msg("Rook: attached target doesn't exist anymore")
        return
    endif
    if empty(a:commands) && !empty(a:line1) && !empty(a:line2)
        exe 'normal! ' . a:line1 . 'GV' . a:line2 . 'G'
        call rook#send_selection()
    else
        call rook#send_text(a:commands)
    endif
endfunction

function! rook#attach_dict_add(value)
    "" a:value should be:
    ""  - vim: terminal buffer number
    ""  - nvim: terminal job id
    ""  - tmux: unique pane id (e.g., %1)
    let l:curr_bufnr = bufnr('%')
    let g:rook_attach_dict[l:curr_bufnr] = a:value
endfunction

function! rook#set_buffer_target_id()
    let l:curr_bufnr = bufnr('%')
    let l:unique_targets = uniq(sort(values(g:rook_attach_dict)))
    if len(l:unique_targets) > 1
    "" if more than one unique target exists in dict &&
    ""   if current buffer is listed in dict set b:rook_target_id to its value
    ""   if current buffer isn't listed in dict don't set b:rook_target_id
        let b:rook_target_id = get(g:rook_attach_dict, l:curr_bufnr)
        if b:rook_target_id == 0
            unlet b:rook_target_id
        endif
    elseif len(l:unique_targets) == 1
    "" if one unique target exists in dict set b:rook_target_id to
    "" the single unique target
        let b:rook_target_id = values(g:rook_attach_dict)[0]
        call rook#attach_dict_add(b:rook_target_id)
    endif
endfunction

function! rook#command_rdetach(bang)
    if !exists('b:rook_target_id')
        call rook#warning_msg("Rook: no target attached")
        return
    elseif !s:target_still_exists()
        call rook#warning_msg("Rook: attached target doesn't exist anymore")
        return
    endif
    let l:target_id = b:rook_target_id
    let l:target_bufnr = rook#get_target_bufnr(l:target_id)
    if a:bang && g:rook_target_type ==# 'vim'
        "" remove target in dict for all buffers
        "" this allows auto-attaching again if
        "" only one target exists
        for i in range(1, bufnr('$'))
            let l:id = getbufvar(i, 'rook_target_id')
            if !empty(l:id) && l:id == l:target_id
                call remove(g:rook_attach_dict, i)
            endif
        endfor
        exe 'bd!'.l:target_bufnr
    else
        call remove(g:rook_attach_dict, bufnr('%'))
    endif
    unlet b:rook_target_id
endfunction

function! rook#get_target_bufnr(target_id)
    "" a:target_id should be b:rook_target_id
    if has('nvim')
        for i in range(1, bufnr('$'))
            let l:id = getbufvar(i, 'terminal_job_id')
            if l:id == a:target_id
                let l:target_bufnr = i
                return l:target_bufnr
            else
            endif
        endfor
        if !exists('l:target_bufnr')
            let l:target_bufnr = 0
            return l:target_bufnr
        endif
    else "" vim
        return a:target_id
    endif
endfunction

function! rook#command_rattach(selected)
    if g:rook_target_type ==# 'tmux'
        let l:paneslist = system('tmux list-panes -F "#D #S:#W.#P" -a')
        let l:proposal_id = matchstr(l:paneslist, '%\d\+\ze '.a:selected.'\>')
        if empty(l:proposal_id)
            let l:msg = "Rook: ".a:selected." doesn't exist"
            call rook#warning_msg(l:msg)
            return
        endif
        if l:proposal_id ==# $TMUX_PANE && !has('gui_running')
            call rook#warning_msg("Rook: can't attach own pane" )
            return
        else
            "" set b:rook_target_id and add it to dict
            let b:rook_target_id = l:proposal_id
            call rook#attach_dict_add(b:rook_target_id)
        endif
    elseif g:rook_target_type ==# 'vim' " a:selected is a buffer name
        let l:bufnr = bufnr(a:selected)
        if !bufexists(l:bufnr)
            let l:msg = "Rook: ".a:selected." doesn't exist"
            call rook#warning_msg(l:msg)
            return
        endif
        if has('nvim')
            let l:proposal_id = getbufvar(bufname(l:bufnr), 'terminal_job_id')
            let l:status = l:proposal_id
        else
            let l:proposal_id = l:bufnr
            let l:status = term_getstatus(l:proposal_id)
        endif
        if empty(l:proposal_id) || empty(l:status)
            call rook#warning_msg("Rook: no terminal running in selected buffer")
            return
        else
            "" set b:rook_target_id and add it to dict
            let b:rook_target_id = l:proposal_id
            call rook#attach_dict_add(b:rook_target_id)
        endif
    endif
endfunction

function! rook#opfunc(type, ...)
    " See :h g@
    if !exists('b:rook_target_id')
        call rook#warning_msg("Rook: no target attached")
        call s:rook_restore_view()
        return
    elseif !s:target_still_exists()
        call rook#warning_msg("Rook: attached target doesn't exist anymore")
        call s:rook_restore_view()
        return
    endif
    if a:0  " called from visual mode
        exe 'normal! gv'
    elseif a:type == 'line'
        exe "normal! '[V']"
    elseif exists('s:not_in_text_object') && s:not_in_text_object
        " This conditional is needed otherwise rook#text_object()
        " will exe the normal! `[v`] command, which sends the character under
        " the cursor when the cursor is not inside a rook defined text object.
        let s:not_in_text_object = 0
        return
    else
        exe "normal! `[v`]"
    endif
    call rook#send_selection()
    call s:rook_restore_view()
endfunction

function! rook#send_selection()
    if !exists('b:rook_target_id')
        call rook#warning_msg("Rook: no target attached")
        return
    elseif !s:target_still_exists()
        call rook#warning_msg("Rook: attached target doesn't exist anymore")
        return
    endif
    call s:rook_save_selection()
    let l:start_line = line("'<")
    let l:end_line = line("'>")
    if g:rook_source_send && l:start_line != l:end_line
        call rook#send_text(g:rook_source_send_command)
    else
        let l:select_text = readfile(g:rook_tmp_file)
        for i in l:select_text
            call rook#send_text(i)
            exe 'sleep 2m'
        endfor
    endif
endfunction

function! rook#send_text(text)
    if !exists('b:rook_target_id')
        call rook#warning_msg("Rook: no target attached")
        return
    elseif !s:target_still_exists()
        call rook#warning_msg("Rook: attached target doesn't exist anymore")
        return
    endif
    if g:rook_target_type ==# 'tmux'
        let l:send_text = shellescape(a:text)
        " include the literal flag so Tmux keywords are not looked up
        call system("tmux send-keys -l -t " . b:rook_target_id . " " . l:send_text)
        call system("tmux send-keys -t " . b:rook_target_id . " " . "Enter")
    elseif g:rook_target_type ==# 'vim'
        if has('nvim')
            call jobsend(b:rook_target_id, [a:text, ""])
        else
            call term_sendkeys(b:rook_target_id, a:text."\n") " need double quotes here
        endif
    endif
endfunction

function! s:target_still_exists()
    "" check that an attached target still exists
    "" returns 1 if the target was found
    if g:rook_target_type ==# 'tmux'
        let l:paneslist = system('tmux list-panes -F "#D" -a')
        let l:matched = match(l:paneslist, b:rook_target_id)
        if l:matched == -1
            let l:out = 0
        else
            let l:out = 1
        endif
    elseif g:rook_target_type ==# 'vim'
        let l:out = 1
        if has('nvim')
            try
                let l:pid = jobpid(b:rook_target_id)
            catch /.*/
                let l:out = 0
                return
            endtry
        else
            let l:status = term_getstatus(b:rook_target_id)
            if empty(l:status)
                let l:out = 0
            endif
        endif
    endif
    return l:out
endfunction

function! s:rook_get_selection()
    " Returns a list where each element of list is a line that
    " was selected
    " '< '> marks are not set until after you leave the selection
    exe "normal! \<Esc>"
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    let l:lines = getline(lnum1, lnum2)
    let l:lines[-1] = l:lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let l:lines[0] = l:lines[0][col1 - 1:]
    return(l:lines)
endfunction

function! s:rook_save_selection()
    let l:lines = s:rook_get_selection()
    call writefile(l:lines, g:rook_tmp_file)
endfunction

function! rook#save_view()
    let s:win_view = winsaveview()
endfunction

function! s:rook_restore_view()
    if exists("s:win_view")
        call winrestview(s:win_view)
        unlet s:win_view
    endif
endfunction

function! s:cursor_in_text_object(start_end)
    "" a:start_end = [start_line, end_line]
    "" returns 1 if cursor is inside the
    "" lines defined by a:start_end (inclusive),
    "" and 0 othewise.
    let l:cursor = line('.')
    "" check if the start of a function is between
    "" the cursor and the top of the buffer
    if a:start_end[0] + a:start_end[1] == 0
        let l:in_fun = 0
    "" if so, check if cursor is inside the function definition
    elseif l:cursor < a:start_end[0] || l:cursor > a:start_end[1]
        let l:in_fun = 0
    else
        let l:in_fun = 1
    endif
    return l:in_fun
endfunction

function! s:start_end_rfunction()
    "" returns a list of start and end line numbers for
    "" the previous function definition in the buffer,
    "" [start_line, end_line]. If no previous function
    "" is found, return [0, 0].
    let l:win_view = winsaveview()
    let l:pattern = '[0-9a-zA-Z_\.]\+\s*\(<-\|=\)\s*function\s*('
    let l:start_line = search(l:pattern, 'bc')
    if l:start_line == 0
        let l:start_end = [0, 0]
    else
        normal! ^
        call search('{')
        normal! %
        let l:end_line = line('.')
        let l:start_end = [l:start_line, l:end_line]
    endif
    call winrestview(l:win_view)
    return l:start_end
endfunction

function! rook#text_object_rfunction()
    let l:start_end = s:start_end_rfunction()
    if !s:cursor_in_text_object(l:start_end)
        call rook#warning_msg("Rook: cursor not inside an R function")
        let s:not_in_text_object = 1
        return
    else
        execute 'normal! 'l:start_end[0].'GV'.l:start_end[1].'G'
    endif
endfunction

function! s:start_end_rmdchunk(inner)
    "" returns a list of start and end line numbers for
    "" the previous function definition in the buffer,
    "" [start_line, end_line]. If no previous function
    "" is found, return [0, 0].
    ""
    "" a:inner should be 1 for operating on an 'inner' chunk and
    "" 0 if operation should include beginning and ending ``` lines
    let l:win_view = winsaveview()
    let l:pattern = '^```{r'
    let l:start_line = search(l:pattern, 'bc')
    if l:start_line == 0
        let l:start_end = [0, 0]
    else
        normal! ^
        if a:inner
            call search('{')
            normal! %j^
            let l:start_line = line('.')
        endif
        call search('^```')
        if a:inner
            normal! k^
        endif
        let l:end_line = line('.')
        let l:start_end = [l:start_line, l:end_line]
    endif
    call winrestview(l:win_view)
    return l:start_end
endfunction

"" Potential patterns for rmd and rnw chunks
""  let l:pattern = '^```'
""  let l:pattern = '^<<.*>>=\s*$'

function! rook#text_object_rmdchunk(inner)
    let l:start_end = s:start_end_rmdchunk(a:inner)
    if !s:cursor_in_text_object(l:start_end)
        call rook#warning_msg("Rook: cursor not inside a chunk")
        let s:not_in_text_object = 1
        return
    else
        execute 'normal! 'l:start_end[0].'GV'.l:start_end[1].'G'
    endif
endfunction
