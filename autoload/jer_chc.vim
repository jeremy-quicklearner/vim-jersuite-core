" File: autoload/jer_chc.vim
" Description: CursorHold Callback system for Jersuite plugins
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid autoloading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

call jer_log#SetLevel('cursorhold-callback', 'CFG', 'WRN')
let s:Log = jer_log#LogFunctions('cursorhold-callback')

let s:callbacksRunning = 0

" Self-explanatory
if getcmdwintype()
    let s:inCmdWin = 1
else
    let s:inCmdWin = 0
endif

" Self-explanatory
function! s:EnsureCallbackListsExist()
    if !exists('g:jersuite_cursorHoldCallbacks')
        let g:jersuite_cursorHoldCallbacks = []
    endif
    if !exists('t:jersuite_cursorHoldCallbacks')
        let t:jersuite_cursorHoldCallbacks = []
    endif
endfunction

" Calling this function will cause callback(data) to be called on the
" next CursorHold event 
" callback must be a funcref, data can be anything. If cascade is truthy,
" autocommands can execute as side effects of the function.
" This effect cascades to side effects of those autocommands and so on.
" Callbacks with lower priority value go first
" The callback will only called once, on the next CursorHold event, unless
" permanent is true. In that case, the callback will be called for every
" CursorHold event from now on
" Callbacks with a falsey inCmdWin flag will not run while the command-line
" window is open.
" If global is truthy, the callback will execute even if the user switches to
" another tab before the next CursorHold event. Otherwise, the callback will
" run on the next CursorHold event that triggers in the current tab
function! jer_chc#Register(callback, data,
         \                 cascade, priority, permanent,
         \                 inCmdWin, global)
    if type(a:callback) != v:t_func
        throw 'CursorHold Callback ' . string(a:callback) . ' is not a function'
    endif
    if type(a:data) != v:t_list
        throw 'Data ' .
       \      string(a:data) .
       \      ' for CursorHold Callback ' .
       \      string(a:callback) .
       \      'is not a list'
    endif
    if type(a:cascade) != v:t_number
        throw 'Cascade flag ' .
       \      string(a:cascade) .
       \      ' for CursorHold Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:priority) != v:t_number
        throw 'Priority ' .
       \      string(a:priority) .
       \      ' for CursorHold Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:permanent) != v:t_number
        throw 'Permanent flag ' .
       \      string(a:permanent) .
       \      ' for CursorHold Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:inCmdWin) != v:t_number
        throw 'Even-in-command-window flag ' .
       \      string(a:inCmdWin) .
       \      ' for CursorHold Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:global) != v:t_number
        throw 'Global flag ' .
       \      string(a:global) .
       \      ' for CursorHold Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if s:callbacksRunning
       throw 'Cannot register a CursorHold callback as part of running a ' .
      \      'different CursorHold callback'
    endif
    if a:permanent && a:global
        call s:Log.CFG(
       \      'Permanent Global CursorHold Callback: ',
       \      string(a:callback)
       \)
    else
        call s:Log.INF('Register CursorHold Callback: ', string(a:callback)
       \)
    endif
    call s:EnsureCallbackListsExist()
    if a:global
        call add(g:jersuite_cursorHoldCallbacks, {
       \    'callback': a:callback,
       \    'data': a:data,
       \    'priority': a:priority,
       \    'permanent': a:permanent,
       \    'cascade': a:cascade,
       \    'inCmdWin': a:inCmdWin
       \})
    else
        call add(t:jersuite_cursorHoldCallbacks, {
       \    'callback': a:callback,
       \    'data': a:data,
       \    'priority': a:priority,
       \    'permanent': a:permanent,
       \    'cascade': a:cascade,
       \    'inCmdWin': a:inCmdWin
       \})
    endif
endfunction

" Run the registered callbacks
" This function is only called from here, but I'm keeping it available
" elsewhere so that it can be tested by other scripts
function! jer_chc#Run()
    call s:Log.DBG('Running CursorHold callbacks')

    call s:EnsureCallbackListsExist()

    let callbacks = g:jersuite_cursorHoldCallbacks +
                  \ t:jersuite_cursorHoldCallbacks

    call sort(callbacks, {c1, c2 -> c1.priority - c2.priority})
    for callback in callbacks
        if s:inCmdWin && !callback.inCmdWin
            continue
        endif
        call s:Log.DBG('Running CursorHold Callback ', callback.callback)
        try
            if callback.cascade
                call call(callback.callback, callback.data)
            else
                noautocmd call call(callback.callback, callback.data)
            endif
        catch /.*/
            call s:Log.WRN('Callback ', callback.callback, ' failed:')
            call s:Log.DBG(v:throwpoint)
            call s:Log.WRN(v:exception)
        endtry
    endfor

    let newCallbacks = []
    for callback in g:jersuite_cursorHoldCallbacks
        if callback.permanent || (s:inCmdWin && !callback.inCmdWin)
            call add(newCallbacks, callback)
        endif
    endfor
    let g:jersuite_cursorHoldCallbacks = newCallbacks

    let newCallbacks = []
    for callback in t:jersuite_cursorHoldCallbacks
        if callback.permanent || (s:inCmdWin && !callback.inCmdWin)
            call add(newCallbacks, callback)
        endif
    endfor
    let t:jersuite_cursorHoldCallbacks = newCallbacks
endfunction

function! s:HandleTerminalEnter()
    " If we aren't in terminal mode, then the terminal was opened
    " elsewhere and the CursorHold event will still fire. Do nothing.
    if mode() !=# 't'
        return
    endif

    call s:Log.DBG(
   \    'Terminal in terminal-job mode detected in current window. Force-running ' .
   \    'CursorHold Callbacks.'
   \)
    call jer_chc#Run()
endfunction

augroup CursorHoldCallbacks
    autocmd!
    " Detect when the command window is open
    autocmd CmdWinEnter * let s:inCmdWin = 1
    autocmd CmdWinLeave * let s:inCmdWin = 0

    " The callbacks run on the CursorHold event
    autocmd CursorHold * nested call jer_chc#Run()

    " The CursorHold autocmd doesn't run in active terminal windows, so
    " force-run them whenever the cursor enters a terminal window
    autocmd TerminalOpen,WinEnter * nested call s:HandleTerminalEnter()
augroup END
