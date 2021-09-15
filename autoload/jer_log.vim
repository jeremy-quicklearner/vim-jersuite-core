" File: autoload/jer_log.vim
" Description: Logging utilities for Jersuite plugins
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid autoloading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" Messages are dumped to a log buffer called jersuite_buflog. Sometimes (such
" as when evaluating a statusline or expr-mapping), the buffer is not
" writable. In that case, stage the messages in a queue for writing.
let s:buflog_queue = []
let s:buflog_lines = 0

function! s:MaybeStartBuflog()
    " Try to create the buffer
    if !exists('s:buflog') || s:buflog ==# -1
        let s:buflog = bufnr('jersuite_buflog', 1)
    endif
    if !bufloaded(s:buflog)
        return
    endif

    " Buffer created. Set a bunch of options
    call setbufvar(s:buflog, '&buftype', 'nofile')
    call setbufvar(s:buflog, '&swapfile', 0)
    call setbufvar(s:buflog, '&filetype', 'buflog')
    call setbufvar(s:buflog, '&bufhidden', 'hide')
    call setbufvar(s:buflog, '&buflisted', 1)
    call setbufvar(s:buflog, '&undolevels', -1)
    
    " Add one line to the buffer so that we can check it exists by reading
    " s:buflog_lines
    try
        silent if !setbufline(s:buflog, 1, '[INF][jersuite_log] Log start')
            let s:buflog_lines = 1
        endif
    " If the jersuite_buflog buffer is not writable for whatever reason, keep
    " queuing
    catch /.*/
    endtry
endfunction
function! s:MaybeFlushQueue()
    " If the buffer doesn't already exist, try to create it
    if !s:buflog_lines
        call s:MaybeStartBuflog()
    endif

    " If we failed to create it, we can't flush the queue
    if !s:buflog_lines
        return
    endif

    " Everything in the queue goes in the buffer
    while !empty(s:buflog_queue)
        try
            silent if setbufline(
           \    s:buflog,
           \    s:buflog_lines + 1,
           \    s:buflog_queue[0]
           \)
                break
            endif
        catch /.*/
            break
        endtry
        let s:buflog_lines += 1
        " Don't worry it's a linked list
        call remove(s:buflog_queue, 0)
    endwhile
endfunction

let s:loglevel_data = [
\   {'code':'CRT','hl':'ErrorMsg'  },
\   {'code':'ERR','hl':'ErrorMsg'  },
\   {'code':'WRN','hl':'WarningMsg'},
\   {'code':'CFG','hl':'WarningMsg'},
\   {'code':'INF','hl':'Normal'    },
\   {'code':'DBG','hl':'Normal'    },
\   {'code':'VRB','hl':'Normal'    }
\]
if has('lambda')
    let s:loglevel_codes = map(copy(s:loglevel_data), {i, f -> f['code']})
else
    let s:loglevel_codes = []
    for adict in s:loglevel_data
        call add(s:loglevel_codes, adict['code'])
    endfor
endif

let g:jersuite_loglevels = {}
function! jer_log#SetLevel(facility, bufloglevel, msgloglevel)
    if a:bufloglevel && index(g:jersuite_loglevel_codes, a:bufloglevel) ==# -1
        throw 'Unknown buffer log level for facility ' .
       \      a:facility . ': ' . a:bufloglevel
    endif
    if a:msgloglevel && index(g:jersuite_loglevel_codes, a:msgloglevel) ==# -1
        throw 'Unknown message log level for facility ' .
       \      a:facility . ': ' . a:msgloglevel
    endif
    let bufloglevel = index(s:loglevel_codes, a:bufloglevel)
    let msgloglevel = index(s:loglevel_codes, a:msgloglevel)

    " Pass something falsey to leave the loglevel unchanged.
    " If one of the levels is falsey and the facility doesn't exist, use CRT
    if a:bufloglevel <# 0 || a:bufloglevel >=# len(s:loglevel_data)
        let bufloglevel = get(g:jersuite_loglevels, a:facility, {'buf':0}).buf
    endif
    if a:bufloglevel <# 0 || a:bufloglevel >=# len(s:loglevel_data)
        let msgloglevel = get(g:jersuite_loglevels, a:facility, {'msg':0}).msg
    endif
    if bufloglevel <# msgloglevel
        throw 'bufloglevel may not be more restrictive than msgloglevel'
    endif

    let g:jersuite_loglevels[a:facility] = {
   \    'buf':bufloglevel,
   \    'msg':msgloglevel
   \}
    call add(s:buflog_queue,
        \    '[CFG][log] Loglevels for ' .
        \    a:facility .
        \    ' facility set to ' .
        \    s:loglevel_data[bufloglevel].code .
        \    ' and ' .
        \    s:loglevel_data[msgloglevel].code)
    call s:MaybeFlushQueue()
endfunction

function! jer_log#Clear()
    let s:buflog_queue = []
    if !s:buflog_lines
        return
    endif
    for linenr in range(s:buflog_lines + 1)
        silent call setbufline(s:buflog, linenr, '')
    endfor
    silent call setbufline(s:buflog, 1, '[INF][jersuite_log] Log start')
    let s:buflog_lines = 1
endfunction

function! jer_log#Log(facility, loglevel, ...)
    let currentbufloglevel = get(g:jersuite_loglevels,a:facility,{'buf':0}).buf
    let currentmsgloglevel = get(g:jersuite_loglevels,a:facility,{'msg':0}).msg
    " This function is always called from wrapper commands that skip calling
    " it if the buffer log level isn't high enough
    let logstr = '[' .
               \ s:loglevel_data[a:loglevel].code .
               \ '][' .
               \ a:facility .
               \ '] ' .
               \ join(a:000, '')
    if a:loglevel <=# currentbufloglevel
        call add(s:buflog_queue, logstr)
        call s:MaybeFlushQueue()
    endif
    if a:loglevel <=# currentmsgloglevel
        execute 'echohl ' . s:loglevel_data[a:loglevel].hl
        echom logstr
        " I know of no way to go back to the previous echohl
        echohl None
    endif
endfunction

" To avoid logging everything with direct calls to jer_log#Log (which requires
" passing the facility and level every time), allow the client script to pull
" out a functions that have facilities and levels hardcoded
function! jer_log#LogFunctions(facility)
    let Fn = function('jer_log#Log')
    let funcs = {}
    for level in range(0,len(s:loglevel_data) - 1)
        if has('lambda')
            let funcs[s:loglevel_codes[level]] =
           \    eval('{... -> call(Fn, [a:facility, ' . level . '] + a:000)}')
        else
            let nlname = 's:NLLOG_' .
          \     substitute(a:facility, '-', '_', 'g') .
          \     '_' . level
            execute "function! " . nlname . "(...) \n".
           \        "call call('jer_log#Log', ['" .
           \        a:facility .
           \        "', '" .
           \        level .
           \        "'] + a:000) \n" .
           \        "endfunction"
            let funcs[s:loglevel_codes[level]] = function(nlname)
        endif
    endfor
    return funcs
endfunction

" Function to read the log
function! jer_log#History()
    let history = []
    " Start at line 2 to skip the 'Log start' message, which
    " are absent if everything is stuck in the queue
    let history += getbufline('jersuite_buflog', 2, s:buflog_lines)
    let history += s:buflog_queue
    return history[1:]
endfunction

" Try to flush the queue on every SafeState event. If SafeState isn't
" supported, use CursorHold instead
augroup JersuiteLog
    autocmd!
    if exists('##SafeStateAgain') && exists('*state')
        autocmd SafeState * call s:MaybeFlushQueue()
    else
        autocmd CursorHold * call s:MaybeFlushQueue()
    endif
augroup END

" Process arguments from JerLogSet command
" see: plugin/vim-jersuite-core.vim
function! jer_log#SetCmd(...)
    if a:0 < 2 || a:0 > 3
        echoerr 'JerLogSet takes 2-3 arguments'
        return
    " First argument is the facility
    elseif !has_key(g:jersuite_loglevels, a:1)
        echoerr 'Logging facility ' . a:1 . ' does not exist'
        return

    " Second and third arguments are loglevels
    elseif index(s:loglevel_codes, toupper(a:2)) ==# -1
        echoerr 'Log level ' . a:2 . ' does not exist'
        return
    elseif a:0 ==# 3 && index(s:loglevel_codes, toupper(a:3)) ==# -1
        echoerr 'Log level ' . a:3 . ' does not exist'
        return
    endif

    " Default third arg (Message loglevel) to something falsey, which will
    " leave it unchanged
    let a3 = 0
    if a:0 ==# 3
        let a3 = a:3
    endif

    call jer_log#SetLevel(a:1, a:2, a3)
endfunction

" Autocomplete arguments for JerLogSet command
function! jer_log#CompleteSetCmd(ArgLead, CmdLine, CursorPos)
    let sofar = split(a:CmdLine)
    if len(sofar) > 3 && a:CmdLine =~# '\s$'
        return []
    endif
    
    " First argument is the facility. The other two are loglevels
    if len(sofar) == 1 || (len(sofar) == 2 && a:CmdLine !~# '\s$')
        let allcandidates = keys(g:jersuite_loglevels)
    else
        let allcandidates = s:loglevel_codes
    endif

    let candidates = []
    for c in allcandidates
        if toupper(c) =~ '^' . toupper(a:ArgLead) . '.*$'
            call add(candidates, c)
        endif
    endfor
    return candidates
endfunction
