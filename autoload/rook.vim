" rook.vim - autoload functions
" Author:   Michael Malick <malickmj@gmail.com>

function! rook#rstudio_folding()
    "" RStudio doesn't have nested folding, i.e., the different markers
    "" at the end of the lines do not signify different fold levels
    let h1 = matchstr(getline(v:lnum), '^#.*#\{4}$')
    let h2 = matchstr(getline(v:lnum), '^#.*=\{4}$')
    let h3 = matchstr(getline(v:lnum), '^#.*-\{4}$')
    if empty(h1) && empty(h2) && empty(h3)
        return "="
    elseif !empty(h1)
        return ">1"
    elseif !empty(h2)
        return ">1"
    elseif !empty(h3)
        return ">1"
    endif
endfunction

function! rook#fold_expr()
    if g:rook_rstudio_folding
        setlocal foldmethod=expr
        setlocal foldexpr=rook#rstudio_folding()
    endif
endfunction

function! rook#source_cmd()
    if g:rook_source_send
        let g:rook_source_command = 'source("' . g:rook_tmp_file . '" , echo = TRUE)'
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
            echohl WarningMsg
            echo "Rook: vim isn't inside tmux, use :Rattach instead"
            echohl None
            return
        endif
        let l:start_paneid = rook#get_active_tmux_pane_id()
        let l:start_windowid = rook#get_active_tmux_window_id()
        let l:start_sessionid = rook#get_active_tmux_session_id()
        call system(a:new)
        let l:target_paneid = rook#get_active_tmux_pane_id()
        if l:start_paneid == l:target_paneid
            echohl WarningMsg
            echo "Rook: command didn't create a new pane"
            echohl None
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
            echohl WarningMsg
            echo "Rook: command didn't create a new window"
            echohl None
            return
        endif
        exe 'enew'
        if has('nvim')
            let l:jobid = termopen('R')
        else
            let l:jobid = term_start('R', {'curwin':1})
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

function! rook#completion_rfunctions(...)
    return join(s:r_base_functions, "\n")
endfunction

function! rook#completion_target(...)
    if g:rook_target_type ==# 'tmux'
        return system('tmux list-panes -F "#S:#W.#P" -a')
    elseif g:rook_target_type ==# 'vim'
        let l:max_bufnr = bufnr('$')
        let l:bufname_list = []
        let l:c = 1
        while l:c <= l:max_bufnr
            if bufexists(l:c) && buflisted(l:c)
                call add(l:bufname_list, bufname(l:c))
            endif
            let l:c += 1
        endwhile
        return join(l:bufname_list, "\n")
    endif
endfunction

function! rook#completion_rview(...)
    return join(g:rook_rview_complete_list, "\n")
endfunction

function! rook#rview_complete_add(function)
    "" Add function to rview completion list
    let l:tmp_lst = insert(g:rook_rview_complete_list, a:function)
    let l:tmp_lst = reverse(tmp_lst)
    let l:tmp_lst = filter(copy(l:tmp_lst), 'index(l:tmp_lst, v:val, v:key+1)==-1')
    let g:rook_rview_complete_list = reverse(l:tmp_lst)
endfunction

function! rook#command_rview(function)
    let l:word = expand("<cword>")
    if !empty(a:function)
        let g:rook_rview_fun = a:function
    elseif !exists('g:rook_rview_fun')
        echohl WarningMsg | echom "Rook: no previous function" | echohl None
        return
    endif
    let l:text = g:rook_rview_fun.'('.l:word.')'
    call rook#send_text(l:text)
    call rook#rview_complete_add(g:rook_rview_fun)
endfunction

function! rook#interact_rview()
    let l:word = expand("<cword>")
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
    call rook#rview_complete_add(g:rook_rview_fun)
endfunction

function! rook#command_rhelp(function)
    if empty(a:function)
        let l:cur_char = matchstr(getline('.'), '\%' . col('.') . 'c.')
        if l:cur_char ==# ':'
            let l:win_view = winsaveview()
            normal! Bv3e
            let l:lword = s:rook_get_selection()
            let l:word = join(l:lword)
            call winrestview(l:win_view)
        else
            let l:word = expand("<cword>")
        endif
    else
        let l:word = a:function
    endif
    if match(l:word, '::') < 0
        " let l:package = '(.packages(all.available=TRUE))'
        let l:package = 'NULL'
        let l:func = l:word
    else
        let l:package = split(l:word, '::')[0]
        let l:func    = split(l:word, '::')[1]
    endif
    " Double and single quotes matter on next line:
    "   'help_type' needs to be in single quotes
    let l:helpstr = "help(".shellescape(l:func).", package=".l:package.", help_type='".g:rook_help_type."')"
    if(g:rook_help_type ==# 'html')
        call rook#send_text(l:helpstr)
    elseif(g:rook_help_type ==# 'text')
        let l:rh_bufname = 'RH:'.l:word
        let l:rh_bufnr = bufnr(l:rh_bufname)
        let l:rh_winnr = rook#rhelp_winnr()
        "" rh_buf = current rhelp buffer name/number
        "" rh_win = window with *any* rhelp file
        let l:rh_buf_exists = bufexists(l:rh_bufname)
        let l:rh_buf_visible = bufwinnr(l:rh_bufnr) != -1
        let l:rh_win_visible = l:rh_winnr != -1
        if l:rh_buf_exists && l:rh_buf_visible
            exe bufwinnr(l:rh_bufnr) . "wincmd w"
        elseif l:rh_buf_exists && l:rh_win_visible
            exe  l:rh_winnr . "wincmd w"
            exe l:rh_bufnr.'buffer'
        elseif l:rh_buf_exists && !l:rh_win_visible
            exe 'aboveleft '.l:rh_bufnr.'sbuffer'
        elseif !l:rh_buf_exists && l:rh_win_visible
            exe  l:rh_winnr . "wincmd w"
            exe 'silent! edit '.l:rh_bufname
            call rook#rhelp_buffer_setup(l:helpstr)
        else
            exe 'silent! aboveleft new '.l:rh_bufname
            call rook#rhelp_buffer_setup(l:helpstr)
        endif
    endif
endfunction

function! rook#rhelp_buffer_setup(helpstring)
    "" Rhelp buffers are not associated with a file, i.e.,
    "" a new buffer is created and text is read into the buffer.
    "" This means that if the buffer is deleted (:bd) and
    "" `bufhidden=hide` the help buffer becomes empty and unlisted.
    "" Need to use `:bw` to wipe the buffer.
    exe 'read !Rscript -e "'.a:helpstring.'"'
    exe 'silent! %s/_//g'
    normal! gg
    setlocal syntax=rhelp
    setlocal filetype=rhelp
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nomodifiable
    setlocal nobuflisted
endfunction

function! rook#rhelp_winnr()
    "" Returns the first winnr with &ft=rhelp
    "" Returns -1 if no buffers with &ft=rhelp are visible
    let g:rh_buffers = filter(range(1, bufnr('$')), 'getbufvar(v:val, "&ft") ==# "rhelp"')
    let l:rh_windows = filter(g:rh_buffers, 'bufwinnr(v:val) >= 0')
    if empty(l:rh_windows)
        return -1
    else
        return bufwinnr(l:rh_windows[0])
    endif
endfunction

function! rook#command_rwrite(line1, line2, commands)
    if !exists('b:rook_target_id') || string(b:rook_target_id) ==# '0'
        echohl WarningMsg | echo "Rook: no target attached" | echohl None
        return
    elseif !s:target_still_exists()
        echohl WarningMsg
        echo "Rook: attached target doesn't exist anymore"
        echohl None
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
    ""   if current buffer isn't listed in dict set b:rook_target_id = 0
        let b:rook_target_id = get(g:rook_attach_dict, l:curr_bufnr)
    elseif len(l:unique_targets) == 1
    "" if one unique target exists in dict set b:rook_target_id to
    "" the single unique target
        let b:rook_target_id = values(g:rook_attach_dict)[0]
        call rook#attach_dict_add(b:rook_target_id)
    else
    "" otherwise set b:rook_target = 0, indicating no target is associated
    "" with the current buffer
        let b:rook_target_id = 0
    endif
endfunction

function! rook#command_rattach(selected)
    if g:rook_target_type ==# 'tmux'
        let l:paneslist = system('tmux list-panes -F "#D #S:#W.#P" -a')
        let l:proposal_id = matchstr(l:paneslist, '%\d\+\ze '.a:selected.'\>')
        if empty(l:proposal_id)
            echohl WarningMsg
            echo "Rook: ".a:selected." doesn't exist"
            echohl None
            return
        endif
        if l:proposal_id ==# $TMUX_PANE && !has('gui_running')
            echohl WarningMsg | echo "Rook: can't attach own pane" | echohl None
            return
        else
            "" set b:rook_target_id and add it to dict
            let b:rook_target_id = l:proposal_id
            call rook#attach_dict_add(b:rook_target_id)
        endif
    elseif g:rook_target_type ==# 'vim' " a:selected is a buffer name
        let l:bufnr = bufnr(a:selected)
        if !bufexists(l:bufnr)
            echohl WarningMsg
            echo "Rook: buffer ".a:selected." doesn't exist"
            echohl None
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
            echohl WarningMsg
            echo "Rook: no terminal running in selected buffer"
            echohl None
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
    if !exists('b:rook_target_id') || string(b:rook_target_id) ==# '0'
        echohl WarningMsg | echo "Rook: no target attached" | echohl None
        call s:rook_restore_view()
        return
    elseif !s:target_still_exists()
        echohl WarningMsg
        echo "Rook: attached target doesn't exist anymore"
        echohl None
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
    if !exists('b:rook_target_id') || string(b:rook_target_id) ==# '0'
        echohl WarningMsg | echo "Rook: no target attached" | echohl None
        return
    elseif !s:target_still_exists()
        echohl WarningMsg
        echo "Rook: attached target doesn't exist anymore"
        echohl None
        return
    endif
    call s:rook_save_selection()
    let l:start_line = line("'<")
    let l:end_line = line("'>")
    if exists("g:rook_source_command") && l:start_line != l:end_line
        call rook#send_text(g:rook_source_command)
    else
        let l:select_text = readfile(g:rook_tmp_file)
        for i in l:select_text
            call rook#send_text(i)
            exe 'sleep 2m'
        endfor
    endif
endfunction

function! rook#send_text(text)
    if !exists('b:rook_target_id') || string(b:rook_target_id) ==# '0'
        echohl WarningMsg | echo "Rook: no target attached" | echohl None
        return
    elseif !s:target_still_exists()
        echohl WarningMsg
        echo "Rook: attached target doesn't exist anymore"
        echohl None
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
        echo 'Rook: cursor not inside an R function'
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
        echo 'Rook: cursor not inside a chunk'
        let s:not_in_text_object = 1
        return
    else
        execute 'normal! 'l:start_end[0].'GV'.l:start_end[1].'G'
    endif
endfunction

"" Completion list taken from running:
""   loaded <- (.packages())
""   loaded <- paste("package:", loaded, sep ="")
""   sort(unlist(lapply(loaded, lsf.str)))
let s:r_base_functions = [
    \ "abbreviate",
    \ "abline",
    \ "abs",
    \ "acf",
    \ "acf2AR",
    \ "acos",
    \ "acosh",
    \ "add.scope",
    \ "add1",
    \ "addmargins",
    \ "addNA",
    \ "addNextMethod",
    \ "addTaskCallback",
    \ "adist",
    \ "adjustcolor",
    \ "aggregate",
    \ "aggregate.data.frame",
    \ "aggregate.ts",
    \ "agrep",
    \ "agrepl",
    \ "AIC",
    \ "alarm",
    \ "alias",
    \ "alist",
    \ "all",
    \ "all.equal",
    \ "all.equal.character",
    \ "all.equal.default",
    \ "all.equal.environment",
    \ "all.equal.envRefClass",
    \ "all.equal.factor",
    \ "all.equal.formula",
    \ "all.equal.language",
    \ "all.equal.list",
    \ "all.equal.numeric",
    \ "all.equal.POSIXt",
    \ "all.equal.raw",
    \ "all.names",
    \ "all.vars",
    \ "allGenerics",
    \ "allNames",
    \ "anova",
    \ "ansari.test",
    \ "any",
    \ "anyDuplicated",
    \ "anyDuplicated.array",
    \ "anyDuplicated.data.frame",
    \ "anyDuplicated.default",
    \ "anyDuplicated.matrix",
    \ "anyNA",
    \ "anyNA.numeric_version",
    \ "anyNA.POSIXlt",
    \ "aov",
    \ "aperm",
    \ "aperm.default",
    \ "aperm.table",
    \ "append",
    \ "apply",
    \ "approx",
    \ "approxfun",
    \ "apropos",
    \ "ar",
    \ "ar.burg",
    \ "ar.mle",
    \ "ar.ols",
    \ "ar.yw",
    \ "aregexec",
    \ "Arg",
    \ "args",
    \ "argsAnywhere",
    \ "arima",
    \ "arima.sim",
    \ "arima0",
    \ "arima0.diag",
    \ "Arith",
    \ "ARMAacf",
    \ "ARMAtoMA",
    \ "array",
    \ "arrayInd",
    \ "arrows",
    \ "as",
    \ "as.array",
    \ "as.array.default",
    \ "as.call",
    \ "as.character",
    \ "as.character.condition",
    \ "as.character.Date",
    \ "as.character.default",
    \ "as.character.error",
    \ "as.character.factor",
    \ "as.character.hexmode",
    \ "as.character.numeric_version",
    \ "as.character.octmode",
    \ "as.character.POSIXt",
    \ "as.character.srcref",
    \ "as.complex",
    \ "as.data.frame",
    \ "as.data.frame.array",
    \ "as.data.frame.AsIs",
    \ "as.data.frame.character",
    \ "as.data.frame.complex",
    \ "as.data.frame.data.frame",
    \ "as.data.frame.Date",
    \ "as.data.frame.default",
    \ "as.data.frame.difftime",
    \ "as.data.frame.factor",
    \ "as.data.frame.integer",
    \ "as.data.frame.list",
    \ "as.data.frame.logical",
    \ "as.data.frame.matrix",
    \ "as.data.frame.model.matrix",
    \ "as.data.frame.noquote",
    \ "as.data.frame.numeric",
    \ "as.data.frame.numeric_version",
    \ "as.data.frame.ordered",
    \ "as.data.frame.POSIXct",
    \ "as.data.frame.POSIXlt",
    \ "as.data.frame.raw",
    \ "as.data.frame.table",
    \ "as.data.frame.ts",
    \ "as.data.frame.vector",
    \ "as.Date",
    \ "as.Date.character",
    \ "as.Date.date",
    \ "as.Date.dates",
    \ "as.Date.default",
    \ "as.Date.factor",
    \ "as.Date.numeric",
    \ "as.Date.POSIXct",
    \ "as.Date.POSIXlt",
    \ "as.dendrogram",
    \ "as.difftime",
    \ "as.dist",
    \ "as.double",
    \ "as.double.difftime",
    \ "as.double.POSIXlt",
    \ "as.environment",
    \ "as.expression",
    \ "as.expression.default",
    \ "as.factor",
    \ "as.formula",
    \ "as.function",
    \ "as.function.default",
    \ "as.graphicsAnnot",
    \ "as.hclust",
    \ "as.hexmode",
    \ "as.integer",
    \ "as.list",
    \ "as.list.data.frame",
    \ "as.list.Date",
    \ "as.list.default",
    \ "as.list.environment",
    \ "as.list.factor",
    \ "as.list.function",
    \ "as.list.numeric_version",
    \ "as.list.POSIXct",
    \ "as.logical",
    \ "as.logical.factor",
    \ "as.matrix",
    \ "as.matrix.data.frame",
    \ "as.matrix.default",
    \ "as.matrix.noquote",
    \ "as.matrix.POSIXlt",
    \ "as.name",
    \ "as.null",
    \ "as.null.default",
    \ "as.numeric",
    \ "as.numeric_version",
    \ "as.octmode",
    \ "as.ordered",
    \ "as.package_version",
    \ "as.pairlist",
    \ "as.person",
    \ "as.personList",
    \ "as.POSIXct",
    \ "as.POSIXct.date",
    \ "as.POSIXct.Date",
    \ "as.POSIXct.dates",
    \ "as.POSIXct.default",
    \ "as.POSIXct.numeric",
    \ "as.POSIXct.POSIXlt",
    \ "as.POSIXlt",
    \ "as.POSIXlt.character",
    \ "as.POSIXlt.date",
    \ "as.POSIXlt.Date",
    \ "as.POSIXlt.dates",
    \ "as.POSIXlt.default",
    \ "as.POSIXlt.factor",
    \ "as.POSIXlt.numeric",
    \ "as.POSIXlt.POSIXct",
    \ "as.qr",
    \ "as.raster",
    \ "as.raw",
    \ "as.relistable",
    \ "as.roman",
    \ "as.single",
    \ "as.single.default",
    \ "as.stepfun",
    \ "as.symbol",
    \ "as.table",
    \ "as.table.default",
    \ "as.ts",
    \ "as.vector",
    \ "as.vector.factor",
    \ "as<-",
    \ "asin",
    \ "asinh",
    \ "asMethodDefinition",
    \ "asNamespace",
    \ "asOneSidedFormula",
    \ "aspell",
    \ "aspell_package_C_files",
    \ "aspell_package_R_files",
    \ "aspell_package_Rd_files",
    \ "aspell_package_vignettes",
    \ "aspell_write_personal_dictionary_file",
    \ "asS3",
    \ "asS4",
    \ "assign",
    \ "assignClassDef",
    \ "assignInMyNamespace",
    \ "assignInNamespace",
    \ "assignMethodsMetaData",
    \ "assocplot",
    \ "atan",
    \ "atan2",
    \ "atanh",
    \ "attach",
    \ "attachNamespace",
    \ "attr",
    \ "attr.all.equal",
    \ "attr<-",
    \ "attributes",
    \ "attributes<-",
    \ "autoload",
    \ "autoloader",
    \ "available.packages",
    \ "ave",
    \ "axis",
    \ "Axis",
    \ "axis.Date",
    \ "axis.POSIXct",
    \ "axisTicks",
    \ "axTicks",
    \ "backsolve",
    \ "balanceMethodsList",
    \ "bandwidth.kernel",
    \ "barplot",
    \ "barplot.default",
    \ "bartlett.test",
    \ "baseenv",
    \ "basename",
    \ "besselI",
    \ "besselJ",
    \ "besselK",
    \ "besselY",
    \ "beta",
    \ "bibentry",
    \ "BIC",
    \ "bindingIsActive",
    \ "bindingIsLocked",
    \ "bindtextdomain",
    \ "binom.test",
    \ "binomial",
    \ "biplot",
    \ "bitmap",
    \ "bitwAnd",
    \ "bitwNot",
    \ "bitwOr",
    \ "bitwShiftL",
    \ "bitwShiftR",
    \ "bitwXor",
    \ "bmp",
    \ "body",
    \ "body<-",
    \ "body<-",
    \ "box",
    \ "Box.test",
    \ "boxplot",
    \ "boxplot.default",
    \ "boxplot.matrix",
    \ "boxplot.stats",
    \ "bquote",
    \ "break",
    \ "browseEnv",
    \ "browser",
    \ "browserCondition",
    \ "browserSetDebug",
    \ "browserText",
    \ "browseURL",
    \ "browseVignettes",
    \ "bug.report",
    \ "builtins",
    \ "bw.bcv",
    \ "bw.nrd",
    \ "bw.nrd0",
    \ "bw.SJ",
    \ "bw.ucv",
    \ "bxp",
    \ "by",
    \ "by.data.frame",
    \ "by.default",
    \ "bzfile",
    \ "c",
    \ "C",
    \ "c.Date",
    \ "c.difftime",
    \ "c.noquote",
    \ "c.numeric_version",
    \ "c.POSIXct",
    \ "c.POSIXlt",
    \ "c.warnings",
    \ "cacheGenericsMetaData",
    \ "cacheMetaData",
    \ "cacheMethod",
    \ "cairo_pdf",
    \ "cairo_ps",
    \ "call",
    \ "callCC",
    \ "callGeneric",
    \ "callNextMethod",
    \ "canCoerce",
    \ "cancor",
    \ "capabilities",
    \ "capture.output",
    \ "case.names",
    \ "casefold",
    \ "cat",
    \ "cbind",
    \ "cbind.data.frame",
    \ "cbind2",
    \ "ccf",
    \ "cdplot",
    \ "ceiling",
    \ "changedFiles",
    \ "char.expand",
    \ "character",
    \ "charmatch",
    \ "charToRaw",
    \ "chartr",
    \ "check_tzones",
    \ "check.options",
    \ "checkAtAssignment",
    \ "checkCRAN",
    \ "checkSlotAssignment",
    \ "chisq.test",
    \ "chkDots",
    \ "chol",
    \ "chol.default",
    \ "chol2inv",
    \ "choose",
    \ "chooseBioCmirror",
    \ "chooseCRANmirror",
    \ "chull",
    \ "CIDFont",
    \ "citation",
    \ "cite",
    \ "citeNatbib",
    \ "citEntry",
    \ "citFooter",
    \ "citHeader",
    \ "class",
    \ "class<-",
    \ "classesToAM",
    \ "classLabel",
    \ "classMetaName",
    \ "className",
    \ "clearPushBack",
    \ "clip",
    \ "close",
    \ "close.connection",
    \ "close.screen",
    \ "close.socket",
    \ "close.srcfile",
    \ "close.srcfilealias",
    \ "closeAllConnections",
    \ "cm",
    \ "cm.colors",
    \ "cmdscale",
    \ "co.intervals",
    \ "coef",
    \ "coefficients",
    \ "coerce",
    \ "coerce<-",
    \ "col",
    \ "col2rgb",
    \ "colMeans",
    \ "colnames",
    \ "colnames<-",
    \ "colorConverter",
    \ "ColorOut",
    \ "colorRamp",
    \ "colorRampPalette",
    \ "colors",
    \ "colours",
    \ "colSums",
    \ "combn",
    \ "commandArgs",
    \ "comment",
    \ "comment<-",
    \ "Compare",
    \ "compareVersion",
    \ "complete.cases",
    \ "completeClassDefinition",
    \ "completeExtends",
    \ "completeSubclasses",
    \ "complex",
    \ "Complex",
    \ "computeRestarts",
    \ "conditionCall",
    \ "conditionCall.condition",
    \ "conditionMessage",
    \ "conditionMessage.condition",
    \ "confint",
    \ "confint.default",
    \ "confint.lm",
    \ "conflicts",
    \ "conformMethod",
    \ "Conj",
    \ "constrOptim",
    \ "contour",
    \ "contour.default",
    \ "contourLines",
    \ "contr.helmert",
    \ "contr.poly",
    \ "contr.SAS",
    \ "contr.sum",
    \ "contr.treatment",
    \ "contrasts",
    \ "contrasts<-",
    \ "contrib.url",
    \ "contributors",
    \ "convertColor",
    \ "convolve",
    \ "cooks.distance",
    \ "cophenetic",
    \ "coplot",
    \ "cor",
    \ "cor.test",
    \ "cos",
    \ "cosh",
    \ "cospi",
    \ "count.fields",
    \ "cov",
    \ "cov.wt",
    \ "cov2cor",
    \ "covratio",
    \ "cpgram",
    \ "CRAN.packages",
    \ "create.post",
    \ "crossprod",
    \ "Cstack_info",
    \ "cummax",
    \ "cummin",
    \ "cumprod",
    \ "cumsum",
    \ "curlGetHeaders",
    \ "curve",
    \ "cut",
    \ "cut.Date",
    \ "cut.default",
    \ "cut.POSIXt",
    \ "cutree",
    \ "cycle",
    \ "D",
    \ "data",
    \ "data.class",
    \ "data.entry",
    \ "data.frame",
    \ "data.matrix",
    \ "dataentry",
    \ "date",
    \ "dbeta",
    \ "dbinom",
    \ "dcauchy",
    \ "dchisq",
    \ "de",
    \ "de.ncols",
    \ "de.restore",
    \ "de.setup",
    \ "debug",
    \ "debugcall",
    \ "debugger",
    \ "debuggingState",
    \ "debugonce",
    \ "decompose",
    \ "default.stringsAsFactors",
    \ "defaultDumpName",
    \ "defaultPrototype",
    \ "delayedAssign",
    \ "delete.response",
    \ "deltat",
    \ "demo",
    \ "dendrapply",
    \ "densCols",
    \ "density",
    \ "density.default",
    \ "deparse",
    \ "deriv",
    \ "deriv3",
    \ "det",
    \ "detach",
    \ "determinant",
    \ "determinant.matrix",
    \ "dev.capabilities",
    \ "dev.capture",
    \ "dev.control",
    \ "dev.copy",
    \ "dev.copy2eps",
    \ "dev.copy2pdf",
    \ "dev.cur",
    \ "dev.flush",
    \ "dev.hold",
    \ "dev.interactive",
    \ "dev.list",
    \ "dev.new",
    \ "dev.next",
    \ "dev.off",
    \ "dev.prev",
    \ "dev.print",
    \ "dev.set",
    \ "dev.size",
    \ "dev2bitmap",
    \ "devAskNewPage",
    \ "deviance",
    \ "deviceIsInteractive",
    \ "dexp",
    \ "df",
    \ "df.kernel",
    \ "df.residual",
    \ "dfbeta",
    \ "dfbetas",
    \ "dffits",
    \ "dgamma",
    \ "dgeom",
    \ "dget",
    \ "dhyper",
    \ "diag",
    \ "diag<-",
    \ "diff",
    \ "diff.Date",
    \ "diff.default",
    \ "diff.difftime",
    \ "diff.POSIXt",
    \ "diffinv",
    \ "difftime",
    \ "digamma",
    \ "dim",
    \ "dim.data.frame",
    \ "dim<-",
    \ "dimnames",
    \ "dimnames.data.frame",
    \ "dimnames<-",
    \ "dimnames<-.data.frame",
    \ "dir",
    \ "dir.create",
    \ "dir.exists",
    \ "dirname",
    \ "dist",
    \ "dlnorm",
    \ "dlogis",
    \ "dmultinom",
    \ "dnbinom",
    \ "dnorm",
    \ "do.call",
    \ "dontCheck",
    \ "doPrimitiveMethod",
    \ "dotchart",
    \ "double",
    \ "download.file",
    \ "download.packages",
    \ "dpois",
    \ "dput",
    \ "dQuote",
    \ "drop",
    \ "drop.scope",
    \ "drop.terms",
    \ "drop1",
    \ "droplevels",
    \ "droplevels.data.frame",
    \ "droplevels.factor",
    \ "dsignrank",
    \ "dt",
    \ "dummy.coef",
    \ "dummy.coef.lm",
    \ "dump",
    \ "dump.frames",
    \ "dumpMethod",
    \ "dumpMethods",
    \ "dunif",
    \ "duplicated",
    \ "duplicated.array",
    \ "duplicated.data.frame",
    \ "duplicated.default",
    \ "duplicated.matrix",
    \ "duplicated.numeric_version",
    \ "duplicated.POSIXlt",
    \ "duplicated.warnings",
    \ "dweibull",
    \ "dwilcox",
    \ "dyn.load",
    \ "dyn.unload",
    \ "dynGet",
    \ "eapply",
    \ "ecdf",
    \ "edit",
    \ "eff.aovlist",
    \ "effects",
    \ "eigen",
    \ "el",
    \ "el<-",
    \ "elNamed",
    \ "elNamed<-",
    \ "emacs",
    \ "embed",
    \ "embedFonts",
    \ "empty.dump",
    \ "emptyenv",
    \ "emptyMethodsList",
    \ "enc2native",
    \ "enc2utf8",
    \ "encodeString",
    \ "Encoding",
    \ "Encoding<-",
    \ "end",
    \ "endsWith",
    \ "enquote",
    \ "env.profile",
    \ "environment",
    \ "environment<-",
    \ "environmentIsLocked",
    \ "environmentName",
    \ "erase.screen",
    \ "estVar",
    \ "eval",
    \ "eval.parent",
    \ "evalOnLoad",
    \ "evalq",
    \ "evalqOnLoad",
    \ "evalSource",
    \ "example",
    \ "exists",
    \ "existsFunction",
    \ "existsMethod",
    \ "exp",
    \ "expand.grid",
    \ "expand.model.frame",
    \ "expm1",
    \ "expression",
    \ "extendrange",
    \ "extends",
    \ "externalRefMethod",
    \ "extractAIC",
    \ "extSoftVersion",
    \ "factanal",
    \ "factor",
    \ "factor.scope",
    \ "factorial",
    \ "family",
    \ "fft",
    \ "fifo",
    \ "file",
    \ "file_test",
    \ "file.access",
    \ "file.append",
    \ "file.choose",
    \ "file.copy",
    \ "file.create",
    \ "file.edit",
    \ "file.exists",
    \ "file.info",
    \ "file.link",
    \ "file.mode",
    \ "file.mtime",
    \ "file.path",
    \ "file.remove",
    \ "file.rename",
    \ "file.show",
    \ "file.size",
    \ "file.symlink",
    \ "fileSnapshot",
    \ "filled.contour",
    \ "filter",
    \ "Filter",
    \ "finalDefaultMethod",
    \ "find",
    \ "Find",
    \ "find.package",
    \ "findClass",
    \ "findFunction",
    \ "findInterval",
    \ "findLineNum",
    \ "findMethod",
    \ "findMethods",
    \ "findMethodSignatures",
    \ "findPackageEnv",
    \ "findRestart",
    \ "findUnique",
    \ "fisher.test",
    \ "fitted",
    \ "fitted.values",
    \ "fivenum",
    \ "fix",
    \ "fixInNamespace",
    \ "fixPre1.8",
    \ "fligner.test",
    \ "floor",
    \ "flush",
    \ "flush.connection",
    \ "flush.console",
    \ "for",
    \ "force",
    \ "forceAndCall",
    \ "formalArgs",
    \ "formals",
    \ "formals<-",
    \ "format",
    \ "format.AsIs",
    \ "format.data.frame",
    \ "format.Date",
    \ "format.default",
    \ "format.difftime",
    \ "format.factor",
    \ "format.hexmode",
    \ "format.info",
    \ "format.libraryIQR",
    \ "format.numeric_version",
    \ "format.octmode",
    \ "format.packageInfo",
    \ "format.POSIXct",
    \ "format.POSIXlt",
    \ "format.pval",
    \ "format.summaryDefault",
    \ "formatC",
    \ "formatDL",
    \ "formatOL",
    \ "formatUL",
    \ "formula",
    \ "forwardsolve",
    \ "fourfoldplot",
    \ "frame",
    \ "frequency",
    \ "friedman.test",
    \ "ftable",
    \ "function",
    \ "functionBody",
    \ "functionBody<-",
    \ "gamma",
    \ "Gamma",
    \ "gaussian",
    \ "gc",
    \ "gc.time",
    \ "gcinfo",
    \ "gctorture",
    \ "gctorture2",
    \ "generic.skeleton",
    \ "get",
    \ "get_all_vars",
    \ "get0",
    \ "getAccess",
    \ "getAllConnections",
    \ "getAllMethods",
    \ "getAllSuperClasses",
    \ "getAnywhere",
    \ "getCall",
    \ "getCallingDLL",
    \ "getCallingDLLe",
    \ "getClass",
    \ "getClassDef",
    \ "getClasses",
    \ "getClassName",
    \ "getClassPackage",
    \ "getConnection",
    \ "getCRANmirrors",
    \ "getDataPart",
    \ "getDLLRegisteredRoutines",
    \ "getDLLRegisteredRoutines.character",
    \ "getDLLRegisteredRoutines.DLLInfo",
    \ "getElement",
    \ "geterrmessage",
    \ "getExportedValue",
    \ "getExtends",
    \ "getFromNamespace",
    \ "getFunction",
    \ "getGeneric",
    \ "getGenerics",
    \ "getGraphicsEvent",
    \ "getGraphicsEventEnv",
    \ "getGroup",
    \ "getGroupMembers",
    \ "getHook",
    \ "getInitial",
    \ "getLoadActions",
    \ "getLoadedDLLs",
    \ "getMethod",
    \ "getMethods",
    \ "getMethodsForDispatch",
    \ "getMethodsMetaData",
    \ "getNamespace",
    \ "getNamespaceExports",
    \ "getNamespaceImports",
    \ "getNamespaceInfo",
    \ "getNamespaceName",
    \ "getNamespaceUsers",
    \ "getNamespaceVersion",
    \ "getNativeSymbolInfo",
    \ "getOption",
    \ "getPackageName",
    \ "getParseData",
    \ "getParseText",
    \ "getProperties",
    \ "getPrototype",
    \ "getRefClass",
    \ "getRversion",
    \ "getS3method",
    \ "getSlots",
    \ "getSrcDirectory",
    \ "getSrcFilename",
    \ "getSrcLines",
    \ "getSrcLocation",
    \ "getSrcref",
    \ "getSubclasses",
    \ "getTaskCallbackNames",
    \ "gettext",
    \ "gettextf",
    \ "getTxtProgressBar",
    \ "getValidity",
    \ "getVirtual",
    \ "getwd",
    \ "gl",
    \ "glm",
    \ "glm.control",
    \ "glm.fit",
    \ "glob2rx",
    \ "globalenv",
    \ "globalVariables",
    \ "graphics.off",
    \ "gray",
    \ "gray.colors",
    \ "grconvertX",
    \ "grconvertY",
    \ "gregexpr",
    \ "grep",
    \ "grepl",
    \ "grepRaw",
    \ "grey",
    \ "grey.colors",
    \ "grid",
    \ "grouping",
    \ "grSoftVersion",
    \ "gsub",
    \ "gzcon",
    \ "gzfile",
    \ "hasArg",
    \ "hasLoadAction",
    \ "hasMethod",
    \ "hasMethods",
    \ "hasName",
    \ "hasTsp",
    \ "hat",
    \ "hatvalues",
    \ "hcl",
    \ "hclust",
    \ "head",
    \ "head.matrix",
    \ "heat.colors",
    \ "heatmap",
    \ "help",
    \ "help.request",
    \ "help.search",
    \ "help.start",
    \ "hist",
    \ "hist.default",
    \ "history",
    \ "HoltWinters",
    \ "hsearch_db",
    \ "hsearch_db_concepts",
    \ "hsearch_db_keywords",
    \ "hsv",
    \ "I",
    \ "iconv",
    \ "iconvlist",
    \ "icuGetCollate",
    \ "icuSetCollate",
    \ "identical",
    \ "identify",
    \ "identity",
    \ "if",
    \ "ifelse",
    \ "Im",
    \ "image",
    \ "image.default",
    \ "implicitGeneric",
    \ "importIntoEnv",
    \ "influence",
    \ "influence.measures",
    \ "inheritedSlotNames",
    \ "inherits",
    \ "initFieldArgs",
    \ "initialize",
    \ "initRefFields",
    \ "insertClassMethods",
    \ "insertMethod",
    \ "insertSource",
    \ "install.packages",
    \ "installed.packages",
    \ "integer",
    \ "integrate",
    \ "interaction",
    \ "interaction.plot",
    \ "interactive",
    \ "intersect",
    \ "intToBits",
    \ "intToUtf8",
    \ "inverse.gaussian",
    \ "inverse.rle",
    \ "invisible",
    \ "invokeRestart",
    \ "invokeRestartInteractively",
    \ "IQR",
    \ "is",
    \ "is.array",
    \ "is.atomic",
    \ "is.call",
    \ "is.character",
    \ "is.complex",
    \ "is.data.frame",
    \ "is.double",
    \ "is.element",
    \ "is.empty.model",
    \ "is.environment",
    \ "is.expression",
    \ "is.factor",
    \ "is.finite",
    \ "is.function",
    \ "is.infinite",
    \ "is.integer",
    \ "is.language",
    \ "is.leaf",
    \ "is.list",
    \ "is.loaded",
    \ "is.logical",
    \ "is.matrix",
    \ "is.mts",
    \ "is.na",
    \ "is.na.data.frame",
    \ "is.na.numeric_version",
    \ "is.na.POSIXlt",
    \ "is.na<-",
    \ "is.na<-.default",
    \ "is.na<-.factor",
    \ "is.na<-.numeric_version",
    \ "is.name",
    \ "is.nan",
    \ "is.null",
    \ "is.numeric",
    \ "is.numeric_version",
    \ "is.numeric.Date",
    \ "is.numeric.difftime",
    \ "is.numeric.POSIXt",
    \ "is.object",
    \ "is.ordered",
    \ "is.package_version",
    \ "is.pairlist",
    \ "is.primitive",
    \ "is.qr",
    \ "is.R",
    \ "is.raster",
    \ "is.raw",
    \ "is.recursive",
    \ "is.relistable",
    \ "is.single",
    \ "is.stepfun",
    \ "is.symbol",
    \ "is.table",
    \ "is.ts",
    \ "is.tskernel",
    \ "is.unsorted",
    \ "is.vector",
    \ "isatty",
    \ "isBaseNamespace",
    \ "isClass",
    \ "isClassDef",
    \ "isClassUnion",
    \ "isdebugged",
    \ "isGeneric",
    \ "isGrammarSymbol",
    \ "isGroup",
    \ "isIncomplete",
    \ "isNamespace",
    \ "isNamespaceLoaded",
    \ "ISOdate",
    \ "ISOdatetime",
    \ "isOpen",
    \ "isoreg",
    \ "isRematched",
    \ "isRestart",
    \ "isS3method",
    \ "isS3stdGeneric",
    \ "isS4",
    \ "isSealedClass",
    \ "isSealedMethod",
    \ "isSeekable",
    \ "isSymmetric",
    \ "isSymmetric.matrix",
    \ "isTRUE",
    \ "isVirtualClass",
    \ "isXS3Class",
    \ "jitter",
    \ "jpeg",
    \ "julian",
    \ "julian.Date",
    \ "julian.POSIXt",
    \ "KalmanForecast",
    \ "KalmanLike",
    \ "KalmanRun",
    \ "KalmanSmooth",
    \ "kappa",
    \ "kappa.default",
    \ "kappa.lm",
    \ "kappa.qr",
    \ "kernapply",
    \ "kernel",
    \ "kmeans",
    \ "knots",
    \ "kronecker",
    \ "kronecker",
    \ "kruskal.test",
    \ "ks.test",
    \ "ksmooth",
    \ "l10n_info",
    \ "La_library",
    \ "La_version",
    \ "La.svd",
    \ "labels",
    \ "labels.default",
    \ "lag",
    \ "lag.plot",
    \ "languageEl",
    \ "languageEl<-",
    \ "lapply",
    \ "layout",
    \ "layout.show",
    \ "lazyLoad",
    \ "lazyLoadDBexec",
    \ "lazyLoadDBfetch",
    \ "lbeta",
    \ "lchoose",
    \ "lcm",
    \ "legend",
    \ "length",
    \ "length.POSIXlt",
    \ "length<-",
    \ "length<-.factor",
    \ "lengths",
    \ "levels",
    \ "levels.default",
    \ "levels<-",
    \ "levels<-.factor",
    \ "lfactorial",
    \ "lgamma",
    \ "libcurlVersion",
    \ "library",
    \ "library.dynam",
    \ "library.dynam.unload",
    \ "licence",
    \ "license",
    \ "limitedLabels",
    \ "line",
    \ "linearizeMlist",
    \ "lines",
    \ "lines.default",
    \ "list",
    \ "list.dirs",
    \ "list.files",
    \ "list2env",
    \ "listFromMethods",
    \ "listFromMlist",
    \ "lm",
    \ "lm.fit",
    \ "lm.influence",
    \ "lm.wfit",
    \ "load",
    \ "loadedNamespaces",
    \ "loadhistory",
    \ "loadingNamespaceInfo",
    \ "loadings",
    \ "loadMethod",
    \ "loadNamespace",
    \ "local",
    \ "localeToCharset",
    \ "locator",
    \ "lockBinding",
    \ "lockEnvironment",
    \ "loess",
    \ "loess.control",
    \ "loess.smooth",
    \ "log",
    \ "log10",
    \ "log1p",
    \ "log2",
    \ "logb",
    \ "Logic",
    \ "logical",
    \ "logLik",
    \ "loglin",
    \ "lower.tri",
    \ "lowess",
    \ "ls",
    \ "ls.diag",
    \ "ls.print",
    \ "ls.str",
    \ "lsf.str",
    \ "lsfit",
    \ "mad",
    \ "mahalanobis",
    \ "maintainer",
    \ "make.link",
    \ "make.names",
    \ "make.packages.html",
    \ "make.rgb",
    \ "make.socket",
    \ "make.unique",
    \ "makeActiveBinding",
    \ "makeARIMA",
    \ "makeClassRepresentation",
    \ "makeExtends",
    \ "makeGeneric",
    \ "makeMethodsList",
    \ "makepredictcall",
    \ "makePrototypeFromClassDef",
    \ "makeRweaveLatexCodeRunner",
    \ "makeStandardGeneric",
    \ "manova",
    \ "mantelhaen.test",
    \ "Map",
    \ "mapply",
    \ "margin.table",
    \ "mat.or.vec",
    \ "match",
    \ "match.arg",
    \ "match.call",
    \ "match.fun",
    \ "matchSignature",
    \ "Math",
    \ "Math.data.frame",
    \ "Math.Date",
    \ "Math.difftime",
    \ "Math.factor",
    \ "Math.POSIXt",
    \ "Math2",
    \ "matlines",
    \ "matplot",
    \ "matpoints",
    \ "matrix",
    \ "mauchly.test",
    \ "max",
    \ "max.col",
    \ "mcnemar.test",
    \ "mean",
    \ "mean.Date",
    \ "mean.default",
    \ "mean.difftime",
    \ "mean.POSIXct",
    \ "mean.POSIXlt",
    \ "median",
    \ "median.default",
    \ "medpolish",
    \ "mem.limits",
    \ "memCompress",
    \ "memDecompress",
    \ "memory.limit",
    \ "memory.profile",
    \ "memory.size",
    \ "menu",
    \ "merge",
    \ "merge.data.frame",
    \ "merge.default",
    \ "mergeMethods",
    \ "message",
    \ "metaNameUndo",
    \ "method.skeleton",
    \ "MethodAddCoerce",
    \ "methods",
    \ "methodSignatureMatrix",
    \ "MethodsList",
    \ "MethodsListSelect",
    \ "methodsPackageMetaName",
    \ "mget",
    \ "min",
    \ "mirror2html",
    \ "missing",
    \ "missingArg",
    \ "mlistMetaName",
    \ "Mod",
    \ "mode",
    \ "mode<-",
    \ "model.extract",
    \ "model.frame",
    \ "model.frame.default",
    \ "model.matrix",
    \ "model.matrix.default",
    \ "model.matrix.lm",
    \ "model.offset",
    \ "model.response",
    \ "model.tables",
    \ "model.weights",
    \ "modifyList",
    \ "monthplot",
    \ "months",
    \ "months.Date",
    \ "months.POSIXt",
    \ "mood.test",
    \ "mosaicplot",
    \ "mostattributes<-",
    \ "mtext",
    \ "multipleClasses",
    \ "mvfft",
    \ "n2mfrow",
    \ "na.action",
    \ "na.contiguous",
    \ "na.exclude",
    \ "na.fail",
    \ "na.omit",
    \ "na.pass",
    \ "names",
    \ "names.POSIXlt",
    \ "names<-",
    \ "names<-.POSIXlt",
    \ "namespaceExport",
    \ "namespaceImport",
    \ "namespaceImportClasses",
    \ "namespaceImportFrom",
    \ "namespaceImportMethods",
    \ "napredict",
    \ "naprint",
    \ "naresid",
    \ "nargs",
    \ "nchar",
    \ "nclass.FD",
    \ "nclass.scott",
    \ "nclass.Sturges",
    \ "ncol",
    \ "NCOL",
    \ "Negate",
    \ "new",
    \ "new.env",
    \ "new.packages",
    \ "newBasic",
    \ "newClassRepresentation",
    \ "newEmptyObject",
    \ "news",
    \ "next",
    \ "NextMethod",
    \ "nextn",
    \ "ngettext",
    \ "nlevels",
    \ "nlm",
    \ "nlminb",
    \ "nls",
    \ "nls.control",
    \ "NLSstAsymptotic",
    \ "NLSstClosestX",
    \ "NLSstLfAsymptote",
    \ "NLSstRtAsymptote",
    \ "nobs",
    \ "noColorOut",
    \ "noquote",
    \ "norm",
    \ "normalizePath",
    \ "nrow",
    \ "NROW",
    \ "nsl",
    \ "numeric",
    \ "numeric_version",
    \ "numericDeriv",
    \ "nzchar",
    \ "object.size",
    \ "objects",
    \ "offset",
    \ "old.packages",
    \ "oldClass",
    \ "oldClass<-",
    \ "OlsonNames",
    \ "on.exit",
    \ "oneway.test",
    \ "open",
    \ "open.connection",
    \ "open.srcfile",
    \ "open.srcfilealias",
    \ "open.srcfilecopy",
    \ "Ops",
    \ "Ops.data.frame",
    \ "Ops.Date",
    \ "Ops.difftime",
    \ "Ops.factor",
    \ "Ops.numeric_version",
    \ "Ops.ordered",
    \ "Ops.POSIXt",
    \ "optim",
    \ "optimHess",
    \ "optimise",
    \ "optimize",
    \ "options",
    \ "order",
    \ "order.dendrogram",
    \ "ordered",
    \ "outer",
    \ "p.adjust",
    \ "pacf",
    \ "package_version",
    \ "package.skeleton",
    \ "packageDescription",
    \ "packageEvent",
    \ "packageHasNamespace",
    \ "packageName",
    \ "packageSlot",
    \ "packageSlot<-",
    \ "packageStartupMessage",
    \ "packageStatus",
    \ "packageVersion",
    \ "packBits",
    \ "page",
    \ "pairlist",
    \ "pairs",
    \ "pairs.default",
    \ "pairwise.prop.test",
    \ "pairwise.t.test",
    \ "pairwise.table",
    \ "pairwise.wilcox.test",
    \ "palette",
    \ "panel.smooth",
    \ "par",
    \ "parent.env",
    \ "parent.env<-",
    \ "parent.frame",
    \ "parse",
    \ "parseNamespaceFile",
    \ "paste",
    \ "paste0",
    \ "path.expand",
    \ "path.package",
    \ "pbeta",
    \ "pbinom",
    \ "pbirthday",
    \ "pcauchy",
    \ "pchisq",
    \ "pcre_config",
    \ "pdf",
    \ "pdf.options",
    \ "pdfFonts",
    \ "person",
    \ "personList",
    \ "persp",
    \ "pexp",
    \ "pf",
    \ "pgamma",
    \ "pgeom",
    \ "phyper",
    \ "pico",
    \ "pictex",
    \ "pie",
    \ "pipe",
    \ "plclust",
    \ "plnorm",
    \ "plogis",
    \ "plot",
    \ "plot.default",
    \ "plot.design",
    \ "plot.ecdf",
    \ "plot.function",
    \ "plot.new",
    \ "plot.spec.coherency",
    \ "plot.spec.phase",
    \ "plot.stepfun",
    \ "plot.ts",
    \ "plot.window",
    \ "plot.xy",
    \ "pmatch",
    \ "pmax",
    \ "pmax.int",
    \ "pmin",
    \ "pmin.int",
    \ "pnbinom",
    \ "png",
    \ "pnorm",
    \ "points",
    \ "points.default",
    \ "poisson",
    \ "poisson.test",
    \ "poly",
    \ "polygon",
    \ "polym",
    \ "polypath",
    \ "polyroot",
    \ "pos.to.env",
    \ "Position",
    \ "possibleExtends",
    \ "postscript",
    \ "postscriptFonts",
    \ "power",
    \ "power.anova.test",
    \ "power.prop.test",
    \ "power.t.test",
    \ "PP.test",
    \ "ppoints",
    \ "ppois",
    \ "ppr",
    \ "prcomp",
    \ "predict",
    \ "predict.glm",
    \ "predict.lm",
    \ "preplot",
    \ "pretty",
    \ "pretty.default",
    \ "prettyNum",
    \ "princomp",
    \ "print",
    \ "print.AsIs",
    \ "print.by",
    \ "print.condition",
    \ "print.connection",
    \ "print.data.frame",
    \ "print.Date",
    \ "print.default",
    \ "print.difftime",
    \ "print.Dlist",
    \ "print.DLLInfo",
    \ "print.DLLInfoList",
    \ "print.DLLRegisteredRoutines",
    \ "print.eigen",
    \ "print.factor",
    \ "print.function",
    \ "print.hexmode",
    \ "print.libraryIQR",
    \ "print.listof",
    \ "print.NativeRoutineList",
    \ "print.noquote",
    \ "print.numeric_version",
    \ "print.octmode",
    \ "print.packageInfo",
    \ "print.POSIXct",
    \ "print.POSIXlt",
    \ "print.proc_time",
    \ "print.restart",
    \ "print.rle",
    \ "print.simple.list",
    \ "print.srcfile",
    \ "print.srcref",
    \ "print.summary.table",
    \ "print.summaryDefault",
    \ "print.table",
    \ "print.warnings",
    \ "printCoefmat",
    \ "prmatrix",
    \ "proc.time",
    \ "process.events",
    \ "prod",
    \ "profile",
    \ "prohibitGeneric",
    \ "proj",
    \ "promax",
    \ "prompt",
    \ "promptClass",
    \ "promptData",
    \ "promptImport",
    \ "promptMethods",
    \ "promptPackage",
    \ "prop.table",
    \ "prop.test",
    \ "prop.trend.test",
    \ "prototype",
    \ "provideDimnames",
    \ "ps.options",
    \ "psigamma",
    \ "psignrank",
    \ "pt",
    \ "ptukey",
    \ "punif",
    \ "pushBack",
    \ "pushBackLength",
    \ "pweibull",
    \ "pwilcox",
    \ "q",
    \ "qbeta",
    \ "qbinom",
    \ "qbirthday",
    \ "qcauchy",
    \ "qchisq",
    \ "qexp",
    \ "qf",
    \ "qgamma",
    \ "qgeom",
    \ "qhyper",
    \ "qlnorm",
    \ "qlogis",
    \ "qnbinom",
    \ "qnorm",
    \ "qpois",
    \ "qqline",
    \ "qqnorm",
    \ "qqplot",
    \ "qr",
    \ "qr.coef",
    \ "qr.default",
    \ "qr.fitted",
    \ "qr.Q",
    \ "qr.qty",
    \ "qr.qy",
    \ "qr.R",
    \ "qr.resid",
    \ "qr.solve",
    \ "qr.X",
    \ "qsignrank",
    \ "qt",
    \ "qtukey",
    \ "quade.test",
    \ "quantile",
    \ "quarters",
    \ "quarters.Date",
    \ "quarters.POSIXt",
    \ "quartz",
    \ "quartz.options",
    \ "quartz.save",
    \ "quartzFont",
    \ "quartzFonts",
    \ "quasi",
    \ "quasibinomial",
    \ "quasipoisson",
    \ "quit",
    \ "qunif",
    \ "quote",
    \ "Quote",
    \ "qweibull",
    \ "qwilcox",
    \ "R_system_version",
    \ "R.home",
    \ "R.Version",
    \ "r2dtable",
    \ "rainbow",
    \ "range",
    \ "range.default",
    \ "rank",
    \ "rapply",
    \ "rasterImage",
    \ "raw",
    \ "rawConnection",
    \ "rawConnectionValue",
    \ "rawShift",
    \ "rawToBits",
    \ "rawToChar",
    \ "rbeta",
    \ "rbind",
    \ "rbind.data.frame",
    \ "rbind2",
    \ "rbinom",
    \ "rc.getOption",
    \ "rc.options",
    \ "rc.settings",
    \ "rc.status",
    \ "rcauchy",
    \ "rchisq",
    \ "rcond",
    \ "Re",
    \ "read.csv",
    \ "read.csv2",
    \ "read.dcf",
    \ "read.delim",
    \ "read.delim2",
    \ "read.DIF",
    \ "read.fortran",
    \ "read.ftable",
    \ "read.fwf",
    \ "read.socket",
    \ "read.table",
    \ "readBin",
    \ "readChar",
    \ "readCitationFile",
    \ "readline",
    \ "readLines",
    \ "readRDS",
    \ "readRenviron",
    \ "Recall",
    \ "reconcilePropertiesAndPrototype",
    \ "recordGraphics",
    \ "recordPlot",
    \ "recover",
    \ "rect",
    \ "rect.hclust",
    \ "Reduce",
    \ "reformulate",
    \ "reg.finalizer",
    \ "regexec",
    \ "regexpr",
    \ "registerImplicitGenerics",
    \ "registerS3method",
    \ "registerS3methods",
    \ "regmatches",
    \ "regmatches<-",
    \ "relevel",
    \ "relist",
    \ "rematchDefinition",
    \ "remove",
    \ "remove.packages",
    \ "removeClass",
    \ "removeGeneric",
    \ "removeMethod",
    \ "removeMethods",
    \ "removeMethodsObject",
    \ "removeSource",
    \ "removeTaskCallback",
    \ "reorder",
    \ "rep",
    \ "rep_len",
    \ "rep.Date",
    \ "rep.factor",
    \ "rep.int",
    \ "rep.numeric_version",
    \ "rep.POSIXct",
    \ "rep.POSIXlt",
    \ "repeat",
    \ "replace",
    \ "replayPlot",
    \ "replicate",
    \ "replications",
    \ "representation",
    \ "require",
    \ "requireMethods",
    \ "requireNamespace",
    \ "resetClass",
    \ "resetGeneric",
    \ "reshape",
    \ "resid",
    \ "residuals",
    \ "residuals.glm",
    \ "residuals.lm",
    \ "restartDescription",
    \ "restartFormals",
    \ "retracemem",
    \ "return",
    \ "returnValue",
    \ "rev",
    \ "rev.default",
    \ "rexp",
    \ "rf",
    \ "rgamma",
    \ "rgb",
    \ "rgb2hsv",
    \ "rgeom",
    \ "rhyper",
    \ "rle",
    \ "rlnorm",
    \ "rlogis",
    \ "rm",
    \ "rmultinom",
    \ "rnbinom",
    \ "RNGkind",
    \ "RNGversion",
    \ "rnorm",
    \ "round",
    \ "round.Date",
    \ "round.POSIXt",
    \ "row",
    \ "row.names",
    \ "row.names.data.frame",
    \ "row.names.default",
    \ "row.names<-",
    \ "row.names<-.data.frame",
    \ "row.names<-.default",
    \ "rowMeans",
    \ "rownames",
    \ "rownames<-",
    \ "rowsum",
    \ "rowsum.data.frame",
    \ "rowsum.default",
    \ "rowSums",
    \ "rpois",
    \ "Rprof",
    \ "Rprofmem",
    \ "RShowDoc",
    \ "rsignrank",
    \ "RSiteSearch",
    \ "rstandard",
    \ "rstudent",
    \ "rt",
    \ "rtags",
    \ "Rtangle",
    \ "RtangleSetup",
    \ "RtangleWritedoc",
    \ "rug",
    \ "runif",
    \ "runmed",
    \ "RweaveChunkPrefix",
    \ "RweaveEvalWithOpt",
    \ "RweaveLatex",
    \ "RweaveLatexFinish",
    \ "RweaveLatexOptions",
    \ "RweaveLatexSetup",
    \ "RweaveLatexWritedoc",
    \ "RweaveTryStop",
    \ "rweibull",
    \ "rwilcox",
    \ "rWishart",
    \ "S3Class",
    \ "S3Class<-",
    \ "S3Part",
    \ "S3Part<-",
    \ "sample",
    \ "sample.int",
    \ "sapply",
    \ "save",
    \ "save.image",
    \ "savehistory",
    \ "savePlot",
    \ "saveRDS",
    \ "scale",
    \ "scale.default",
    \ "scan",
    \ "scatter.smooth",
    \ "screen",
    \ "screeplot",
    \ "sd",
    \ "se.contrast",
    \ "sealClass",
    \ "search",
    \ "searchpaths",
    \ "seek",
    \ "seek.connection",
    \ "seemsS4Object",
    \ "segments",
    \ "select.list",
    \ "selectMethod",
    \ "selectSuperClasses",
    \ "selfStart",
    \ "seq",
    \ "seq_along",
    \ "seq_len",
    \ "seq.Date",
    \ "seq.default",
    \ "seq.int",
    \ "seq.POSIXt",
    \ "sequence",
    \ "serialize",
    \ "sessionInfo",
    \ "set.seed",
    \ "setAs",
    \ "setBreakpoint",
    \ "setClass",
    \ "setClassUnion",
    \ "setDataPart",
    \ "setdiff",
    \ "setEPS",
    \ "setequal",
    \ "setGeneric",
    \ "setGenericImplicit",
    \ "setGraphicsEventEnv",
    \ "setGraphicsEventHandlers",
    \ "setGroupGeneric",
    \ "setHook",
    \ "setIs",
    \ "setLoadAction",
    \ "setLoadActions",
    \ "setMethod",
    \ "setNames",
    \ "setNamespaceInfo",
    \ "setOldClass",
    \ "setOutputColors",
    \ "setOutputColors256",
    \ "setPackageName",
    \ "setPrimitiveMethods",
    \ "setPS",
    \ "setRefClass",
    \ "setReplaceMethod",
    \ "setRepositories",
    \ "setSessionTimeLimit",
    \ "setTimeLimit",
    \ "setTxtProgressBar",
    \ "setValidity",
    \ "setwd",
    \ "setZero",
    \ "shapiro.test",
    \ "show",
    \ "show256Colors",
    \ "showClass",
    \ "showConnections",
    \ "showDefault",
    \ "showExtends",
    \ "showMethods",
    \ "showMlist",
    \ "shQuote",
    \ "sigma",
    \ "sign",
    \ "signalCondition",
    \ "signature",
    \ "SignatureMethod",
    \ "signif",
    \ "sigToEnv",
    \ "simpleCondition",
    \ "simpleError",
    \ "simpleMessage",
    \ "simpleWarning",
    \ "simplify2array",
    \ "simulate",
    \ "sin",
    \ "single",
    \ "sinh",
    \ "sink",
    \ "sink.number",
    \ "sinpi",
    \ "slice.index",
    \ "slot",
    \ "slot<-",
    \ "slotNames",
    \ "slotsFromS3",
    \ "smooth",
    \ "smooth.spline",
    \ "smoothEnds",
    \ "smoothScatter",
    \ "socketConnection",
    \ "socketSelect",
    \ "solve",
    \ "solve.default",
    \ "solve.qr",
    \ "sort",
    \ "sort.default",
    \ "sort.int",
    \ "sort.list",
    \ "sort.POSIXlt",
    \ "sortedXyData",
    \ "source",
    \ "spec.ar",
    \ "spec.pgram",
    \ "spec.taper",
    \ "spectrum",
    \ "spineplot",
    \ "spline",
    \ "splinefun",
    \ "splinefunH",
    \ "split",
    \ "split.data.frame",
    \ "split.Date",
    \ "split.default",
    \ "split.POSIXct",
    \ "split.screen",
    \ "split<-",
    \ "split<-.data.frame",
    \ "split<-.default",
    \ "sprintf",
    \ "sqrt",
    \ "sQuote",
    \ "srcfile",
    \ "srcfilealias",
    \ "srcfilecopy",
    \ "srcref",
    \ "SSasymp",
    \ "SSasympOff",
    \ "SSasympOrig",
    \ "SSbiexp",
    \ "SSD",
    \ "SSfol",
    \ "SSfpl",
    \ "SSgompertz",
    \ "SSlogis",
    \ "SSmicmen",
    \ "SSweibull",
    \ "stack",
    \ "standardGeneric",
    \ "Stangle",
    \ "stars",
    \ "start",
    \ "startsWith",
    \ "stat.anova",
    \ "stderr",
    \ "stdin",
    \ "stdout",
    \ "stem",
    \ "step",
    \ "stepfun",
    \ "stl",
    \ "stop",
    \ "stopifnot",
    \ "storage.mode",
    \ "storage.mode<-",
    \ "str",
    \ "strcapture",
    \ "strftime",
    \ "strheight",
    \ "stripchart",
    \ "strOptions",
    \ "strptime",
    \ "strrep",
    \ "strsplit",
    \ "strtoi",
    \ "strtrim",
    \ "StructTS",
    \ "structure",
    \ "strwidth",
    \ "strwrap",
    \ "sub",
    \ "subset",
    \ "subset.data.frame",
    \ "subset.default",
    \ "subset.matrix",
    \ "substitute",
    \ "substituteDirect",
    \ "substituteFunctionArgs",
    \ "substr",
    \ "substr<-",
    \ "substring",
    \ "substring<-",
    \ "sum",
    \ "summary",
    \ "Summary",
    \ "summary.aov",
    \ "summary.connection",
    \ "summary.data.frame",
    \ "Summary.data.frame",
    \ "summary.Date",
    \ "Summary.Date",
    \ "summary.default",
    \ "Summary.difftime",
    \ "summary.factor",
    \ "Summary.factor",
    \ "summary.glm",
    \ "summary.lm",
    \ "summary.manova",
    \ "summary.matrix",
    \ "Summary.numeric_version",
    \ "Summary.ordered",
    \ "summary.POSIXct",
    \ "Summary.POSIXct",
    \ "summary.POSIXlt",
    \ "Summary.POSIXlt",
    \ "summary.proc_time",
    \ "summary.srcfile",
    \ "summary.srcref",
    \ "summary.stepfun",
    \ "summary.table",
    \ "summaryRprof",
    \ "sunflowerplot",
    \ "superClassDepth",
    \ "suppressForeignCheck",
    \ "suppressMessages",
    \ "suppressPackageStartupMessages",
    \ "suppressWarnings",
    \ "supsmu",
    \ "svd",
    \ "svg",
    \ "Sweave",
    \ "SweaveHooks",
    \ "SweaveSyntConv",
    \ "sweep",
    \ "switch",
    \ "symbols",
    \ "symnum",
    \ "sys.call",
    \ "sys.calls",
    \ "Sys.chmod",
    \ "Sys.Date",
    \ "sys.frame",
    \ "sys.frames",
    \ "sys.function",
    \ "Sys.getenv",
    \ "Sys.getlocale",
    \ "Sys.getpid",
    \ "Sys.glob",
    \ "Sys.info",
    \ "sys.load.image",
    \ "Sys.localeconv",
    \ "sys.nframe",
    \ "sys.on.exit",
    \ "sys.parent",
    \ "sys.parents",
    \ "Sys.readlink",
    \ "sys.save.image",
    \ "Sys.setenv",
    \ "Sys.setFileTime",
    \ "Sys.setlocale",
    \ "Sys.sleep",
    \ "sys.source",
    \ "sys.status",
    \ "Sys.time",
    \ "Sys.timezone",
    \ "Sys.umask",
    \ "Sys.unsetenv",
    \ "Sys.which",
    \ "system",
    \ "system.file",
    \ "system.time",
    \ "system2",
    \ "t",
    \ "t.data.frame",
    \ "t.default",
    \ "t.test",
    \ "table",
    \ "tabulate",
    \ "tail",
    \ "tail.matrix",
    \ "tan",
    \ "tanh",
    \ "tanpi",
    \ "tapply",
    \ "tar",
    \ "taskCallbackManager",
    \ "tcrossprod",
    \ "tempdir",
    \ "tempfile",
    \ "termplot",
    \ "terms",
    \ "terms.formula",
    \ "terrain.colors",
    \ "testInheritedMethods",
    \ "testPlatformEquivalence",
    \ "testVirtual",
    \ "text",
    \ "text.default",
    \ "textConnection",
    \ "textConnectionValue",
    \ "tiff",
    \ "time",
    \ "timestamp",
    \ "title",
    \ "toBibtex",
    \ "toeplitz",
    \ "toLatex",
    \ "tolower",
    \ "topenv",
    \ "topo.colors",
    \ "toString",
    \ "toString.default",
    \ "toupper",
    \ "trace",
    \ "traceback",
    \ "tracemem",
    \ "traceOff",
    \ "traceOn",
    \ "tracingState",
    \ "trans3d",
    \ "transform",
    \ "transform.data.frame",
    \ "transform.default",
    \ "trigamma",
    \ "trimws",
    \ "trunc",
    \ "trunc.Date",
    \ "trunc.POSIXt",
    \ "truncate",
    \ "truncate.connection",
    \ "try",
    \ "tryCatch",
    \ "tryNew",
    \ "ts",
    \ "ts.intersect",
    \ "ts.plot",
    \ "ts.union",
    \ "tsdiag",
    \ "tsp",
    \ "tsp<-",
    \ "tsSmooth",
    \ "TukeyHSD",
    \ "txtProgressBar",
    \ "type.convert",
    \ "Type1Font",
    \ "typeof",
    \ "unclass",
    \ "undebug",
    \ "undebugcall",
    \ "union",
    \ "unique",
    \ "unique.array",
    \ "unique.data.frame",
    \ "unique.default",
    \ "unique.matrix",
    \ "unique.numeric_version",
    \ "unique.POSIXlt",
    \ "unique.warnings",
    \ "uniroot",
    \ "units",
    \ "units.difftime",
    \ "units<-",
    \ "units<-.difftime",
    \ "unix.time",
    \ "unlink",
    \ "unlist",
    \ "unloadNamespace",
    \ "unlockBinding",
    \ "unname",
    \ "unRematchDefinition",
    \ "unserialize",
    \ "unsetZero",
    \ "unsplit",
    \ "unstack",
    \ "untar",
    \ "untrace",
    \ "untracemem",
    \ "unz",
    \ "unzip",
    \ "update",
    \ "update.default",
    \ "update.formula",
    \ "update.packages",
    \ "update.packageStatus",
    \ "upgrade",
    \ "upper.tri",
    \ "url",
    \ "url.show",
    \ "URLdecode",
    \ "URLencode",
    \ "UseMethod",
    \ "utf8ToInt",
    \ "validEnc",
    \ "validObject",
    \ "validSlotNames",
    \ "validUTF8",
    \ "vapply",
    \ "var",
    \ "var.test",
    \ "variable.names",
    \ "varimax",
    \ "vcov",
    \ "vector",
    \ "Vectorize",
    \ "vi",
    \ "View",
    \ "vignette",
    \ "warning",
    \ "warnings",
    \ "weekdays",
    \ "weekdays.Date",
    \ "weekdays.POSIXt",
    \ "weighted.mean",
    \ "weighted.residuals",
    \ "weights",
    \ "which",
    \ "which.max",
    \ "which.min",
    \ "while",
    \ "wilcox.test",
    \ "window",
    \ "window<-",
    \ "with",
    \ "with.default",
    \ "withAutoprint",
    \ "withCallingHandlers",
    \ "within",
    \ "within.data.frame",
    \ "within.list",
    \ "withRestarts",
    \ "withVisible",
    \ "write",
    \ "write.csv",
    \ "write.csv2",
    \ "write.dcf",
    \ "write.ftable",
    \ "write.socket",
    \ "write.table",
    \ "writeBin",
    \ "writeChar",
    \ "writeLines",
    \ "x11",
    \ "X11",
    \ "X11.options",
    \ "X11Font",
    \ "X11Fonts",
    \ "xedit",
    \ "xemacs",
    \ "xfig",
    \ "xinch",
    \ "xor",
    \ "xor.hexmode",
    \ "xor.octmode",
    \ "xpdrows.data.frame",
    \ "xspline",
    \ "xtabs",
    \ "xtfrm",
    \ "xtfrm.AsIs",
    \ "xtfrm.Date",
    \ "xtfrm.default",
    \ "xtfrm.difftime",
    \ "xtfrm.factor",
    \ "xtfrm.numeric_version",
    \ "xtfrm.POSIXct",
    \ "xtfrm.POSIXlt",
    \ "xtfrm.Surv",
    \ "xy.coords",
    \ "xyinch",
    \ "xyTable",
    \ "xyz.coords",
    \ "xzfile",
    \ "yinch",
    \ "zapsmall",
    \ "zip",
\ ]
