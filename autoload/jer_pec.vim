" File: autoload/jer_pec.vim
" Description: Post-Event Callback system for Jersuite plugins
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid autoloading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

call jer_log#SetLevel('post-event-callback', 'CFG', 'WRN')
let s:Log = jer_log#LogFunctions('post-event-callback')

" If this flag is switched on, jer_pec will run post-event callbacks on the
" CursorHold autocmd event instead of the SafeState autocmd event, even if the
" SafeState autocmd event exists
if !exists('g:jersuite_forcecursorholdforpostevent')
    let g:jersuite_forcecursorholdforpostevent = 0
endif

let s:callbacksRunning = 0

" Self-explanatory
if getcmdwintype()
    let s:inCmdWin = 1
else
    let s:inCmdWin = 0
endif

" Self-explanatory
function! s:EnsureCallbackListsExist()
    if !exists('g:jersuite_postEventCallbacks')
        let g:jersuite_postEventCallbacks = []
    endif
    if !exists('t:jersuite_postEventCallbacks')
        let t:jersuite_postEventCallbacks = []
    endif
endfunction

" Calling this function will cause callback(data) to be called on the
" next Post-Event event: SafeState if supported, CursorHold otherwise
" callback must be a funcref, data can be anything. If cascade is truthy,
" autocommands can execute as side effects of the function.
" This effect cascades to side effects of those autocommands and so on.
" Callbacks with lower priority value go first
" The callback will only called once, on the next Post-Event event, unless
" permanent is true. In that case, the callback will be called for every
" Post-Event event from now on
" Callbacks with a falsey inCmdWin flag will not run while the command-line
" window is open.
" If global is truthy, the callback will execute even if the user switches to
" another tab before the next Post-Event event. Otherwise, the callback will
" run on the next Post-Event event that triggers in the current tab
function! jer_pec#Register(callback, data,
         \                 cascade, priority, permanent,
         \                 inCmdWin, global)
    if type(a:callback) != v:t_func
        throw 'Post-Event Callback ' . string(a:callback) . ' is not a function'
    endif
    if type(a:data) != v:t_list
        throw 'Data ' .
       \      string(a:data) .
       \      ' for Post-Event Callback ' .
       \      string(a:callback) .
       \      'is not a list'
    endif
    if type(a:cascade) != v:t_number
        throw 'Cascade flag ' .
       \      string(a:cascade) .
       \      ' for Post-Event Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:priority) != v:t_number
        throw 'Priority ' .
       \      string(a:priority) .
       \      ' for Post-Event Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:permanent) != v:t_number
        throw 'Permanent flag ' .
       \      string(a:permanent) .
       \      ' for Post-Event Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:inCmdWin) != v:t_number
        throw 'Even-in-command-window flag ' .
       \      string(a:inCmdWin) .
       \      ' for Post-Event Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if type(a:global) != v:t_number
        throw 'Global flag ' .
       \      string(a:global) .
       \      ' for Post-Event Callback ' .
       \      string(a:callback) .
       \      'is not a number'
    endif
    if s:callbacksRunning
       throw 'Cannot register a Post-Event callback as part of running a ' .
      \      'different Post-Event callback'
    endif
    if a:permanent && a:global
        call s:Log.CFG(
       \      'Permanent Global Post-Event Callback: ',
       \      string(a:callback)
       \)
    else
        call s:Log.INF('Register Post-Event Callback: ', string(a:callback)
       \)
    endif
    call s:EnsureCallbackListsExist()
    if a:global
        call add(g:jersuite_postEventCallbacks, {
       \    'callback': a:callback,
       \    'data': a:data,
       \    'priority': a:priority,
       \    'permanent': a:permanent,
       \    'cascade': a:cascade,
       \    'inCmdWin': a:inCmdWin
       \})
    else
        call add(t:jersuite_postEventCallbacks, {
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
function! jer_pec#Run()
    call s:Log.INF('Running Post-Event callbacks')

    call s:EnsureCallbackListsExist()

    let callbacks = g:jersuite_postEventCallbacks +
                  \ t:jersuite_postEventCallbacks

    call sort(callbacks, {c1, c2 -> c1.priority - c2.priority})
    for callback in callbacks
        if s:inCmdWin && !callback.inCmdWin
            continue
        endif
        call s:Log.DBG('Running Post-Event Callback ', callback.callback)
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
    for callback in g:jersuite_postEventCallbacks
        if callback.permanent || (s:inCmdWin && !callback.inCmdWin)
            call add(newCallbacks, callback)
        endif
    endfor
    let g:jersuite_postEventCallbacks = newCallbacks

    let newCallbacks = []
    for callback in t:jersuite_postEventCallbacks
        if callback.permanent || (s:inCmdWin && !callback.inCmdWin)
            call add(newCallbacks, callback)
        endif
    endfor
    let t:jersuite_postEventCallbacks = newCallbacks
endfunction

let s:deferToCursorHold = 0
function! s:OnSafeState()
    " If the last event *was* CursorHold, don't do anything for SafeState
    if s:lasteventwascursorhold
        let s:lasteventwascursorhold = 0
        return
    endif

    " If the user holds down a key, SafeState triggers lots of times. This
    " causes visual stutters if the post-event callbacks take too long. To
    " avoid this, check if there are pending characters after running the
    " callbacks. If there are, then a key is probably being held down. Defer
    " running the callbacks again until the CursorHold event fires.
    if s:deferToCursorHold || g:jersuite_forcecursorholdforpostevent
        return
    endif

    " Even with the deferring, the SafeState event fires much more often than
    " CursorHold. To maintain a semblance of parity between the two, don't run
    " the callbacks if:
    " - There are characters pending
    " - A mapping is being evaluated
    " - An operator is pending
    " - We're blocked on waiting
    " - A callback is being invoked
    " - We're not in normal mode
    " - A Macro is being recorded
    if getchar(1) !=# 0 ||
   \   state('moawc') !=# '' ||
   \   mode() !=# 'n' ||
   \   reg_recording() !=# ''
        return
    endif

    " Run the callbacks
    call jer_pec#Run()

    " Defer to CursorHold event if more characters were typed while the
    " callbacks were running (See above)
    if getchar(1) !=# 0
        let s:deferToCursorHold = 1
    endif
endfunction

let s:lasteventwascursorhold = 0
function! s:OnCursorHold()
    " SafeState will fire again after this, so signal to s:OnSafeState that it
    " shouldn't run callbacks
    let s:lasteventwascursorhold = 1

    " If there's no SafeState autocmd event, then the post-event callbacks
    " just run on CursorHold. So run them
    if !exists('##SafeState') || g:jersuite_forcecursorholdforpostevent
        call jer_pec#Run()
        return
    endif

    " If the post-event callbacks are being deferred to CursorHold,
    " stop deferring
    if s:deferToCursorHold ==# 1
        let s:deferToCursorHold = 0
        call jer_pec#Run()
    endif
endfunction

function! s:HandleTerminalEnter()
    " If we aren't in terminal mode, then the terminal was opened
    " elsewhere and the Post-Event event will still fire. Do nothing.
    if mode() !=# 't'
        return
    endif

    call s:Log.DBG(
   \    'Terminal in terminal-job mode detected in current window. ' .
   \    'Force-running Post-Event Callbacks.'
   \)
    call jer_pec#Run()
endfunction

augroup PostEventCallbacks
    autocmd!
    " Detect when the command window is open
    autocmd CmdWinEnter * let s:inCmdWin = 1
    autocmd CmdWinLeave * let s:inCmdWin = 0

    if exists('##SafeState')
        autocmd SafeState * nested call s:OnSafeState()
    endif
    autocmd CursorHold * nested call s:OnCursorHold()

    " The Post-Event autocmd doesn't run in active terminal windows, so
    " force-run them whenever the cursor enters a terminal window
    autocmd TerminalOpen,WinEnter * nested call s:HandleTerminalEnter()
augroup END
