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
" SafeState autocmd event exists. 
" On by default. Running post-event callbacks on SafeState is currently
" experimental behaviour.
if !exists('g:jersuite_forcecursorholdforpostevent')
    let g:jersuite_forcecursorholdforpostevent = 1
endif

" Maximum time interval (in milliseconds) between two SafeState events such that
" the post-event callbacks should not execute after the first event but
" instead be deferred to the next CursorHold event. Should be set to a value
" slightly longer than the time between two keystrokes issued by the Operating
" System when a key is held down
" The default value of 35 is based on Mac OS Catalina's maximum 'Key Repeat'
" setting
if !exists('g:jersuite_safestate_timeout')
    let g:jersuite_safestate_timeout = 35
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

let s:calibrating = 0
let s:deferToCursorHold = 0
function! s:OnSafeState()
    " If the calibration tool is running, do nothing
    if s:calibrating
        return
    endif

    " If the last event was CursorHold, don't do anything for SafeState
    if s:lasteventwascursorhold
        let s:lasteventwascursorhold = 0
        return
    endif

    " If the callbacks are being deferred, don't run them on SafeState.
    " Eventually CursorHold will fire, run them, and stop deferring.
    if s:deferToCursorHold || g:jersuite_forcecursorholdforpostevent
        return
    endif

    " Maintain parity between SafeState and CursorHold by not running
    " the callbacks if:
    " - A mapping is being evaluated
    " - An operator is pending
    " - We're blocked on waiting
    " - A callback is being invoked
    " - We're not in normal mode
    " - A Macro is being recorded
    if state('moawc') !=# '' ||
   \   mode() !=# 'n' ||
   \   reg_recording() !=# ''
        return
    endif
    
    " If the user holds down a key, SafeState triggers lots of times. Running
    " expensive callbacks on every one of those SafeState events would cause
    " visual stutters. To avoid this, check for pending characters before and
    " after running the callbacks. If pending characters are found, then a key
    " is probably being held down. Defer running the callbacks again until the
    " CursorHold event fires.

    " But first, give the user a bit of extra time to press a key and cancel the
    " callbacks. Skipping this sleep would make the timeout too fast for a
    " realistic keyboard to keep up with - thus never deferring

    " Why not just defer until the next SafeState event? Because then this
    " sleep would cause visual stutters
    execute 'sleep ' . g:jersuite_safestate_timeout . 'm'

    if getchar(1) !=# 0
        call s:Log.INF('Callbacks deferred before running due to pending input')
        let s:deferToCursorHold = 1
        return
    endif

    " Run the callbacks
    call jer_pec#Run()

    " Defer to CursorHold event if more characters were typed while the
    " callbacks were running (See above)
    if getchar(1) !=# 0
        call s:Log.INF('Callbacks deferred after running due to pending input')
        let s:deferToCursorHold = 1
    endif
endfunction

let s:lasteventwascursorhold = 0
function! s:OnCursorHold()
    " If the calibration tool is running, do nothing
    if s:calibrating
        return
    endif

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
    " run them because this is CursorHold. Also stop deferring
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

augroup JersuitePEC
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

" SafeState timeout calibration tool
let s:sleeps = []
let s:firstss = 0
function! jer_pec#StartCalibrateTimeout()
    if !exists('##SafeState')
        call s:Log.WRN(
       \    'Cannot run Jersuite PEC timeout calibration tool in ',
       \    'a version of Vim without the SafeState autocmd event'
       \)
        return
    endif
    if !empty(mapcheck('j', 'n'))
        call s:Log.WRN(
       \    'Cannot run Jersuite PEC timeout calibration tool with ',
       \    'j mapped in normal mode'
       \)
        return
    endif

    let s:calibrating = 1
    try
        tabnew
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal nobuflisted
        let lines = [
\'Welcome to the Jersuite PEC timeout calibration tool. This process will',
\'recommend a good value for g:jersuite_safestate_timeout - the number of',
\'milliseconds to wait for keystrokes before assuming none will be typed for',
\'a while. A too-low value can cause visual stutters when Vim starts running',
\'expensive callbacks between frequent keystrokes. A too-high value can cause',
\'slowness with Vim waiting too long after infrequent keystrokes.',
\'',
\'To get your g:jersuite_safestate_timeout value, hold down the j key on your',
\'keyboard until the view scrolls down to the recommendation below.',
\'Do not press any other keys.'
\       ]
        for i in range(150)
            call add(lines, '')
        endfor
        call add(lines, '$')
        for i in range(10)
            call add(lines, '')
        endfor
        call append(0, lines)
        goto

        let s:sleeps = []

        augroup JersuitePECTool
            autocmd!
            autocmd SafeState * call s:ToolEvent()
        augroup END
        let s:firstss = 1

    catch /.*/
        let calibrating = 0
        call s:Log.WRN('PEC Timeout Calibration Tool Failed: ')
        call s:Log.WRN(v:throwpoint)
        call s:Log.WRN(v:exception)
    endtry
endfunction

function s:ToolEvent()
    if !s:calibrating
        return
    endif
    if s:firstss
        let s:firstss = 0
        return
    endif

    if getline('.') ==# '$'
        let s:calibrating = 0
        augroup JersuitePECTool | autocmd! | augroup END
        augroup! Jersuite PECTool

        " Don't consider values from the start and end
        let sleeps = s:sleeps[25:-25]

        " Calculate a different recommendation for each measurement
        let recs = []
        for sleep in sleeps
            if sleep ==# 0
                let rec = 0
            else
                let rec = sleep
                " Round up to nearest 5
                let rec += 5
                let rec /= 5
                let rec *= 5
    
                " Add an extra 10 for good measure
                let rec += 10
            endif
            call add(recs, rec)
        endfor

        " Output the highest number seen more than twice
        call sort(recs)
        while (recs[-1] != recs[-3])
            let recs = recs[:-2]
        endwhile
        let recommended = recs[-1]

        let lines = [
\'Thank you for using the Jersuite PEC timeout calibration tool!',
\'Your recommended value for g:jersuite_safestate_timeout is: ' . recommended,
\'You can set it by adding the following line to your .vimrc:',
\'',
\'let g:jersuite_safestate_timeout = ' . recommended,
\'',
\'You may want to run this tool two or three times to make sure the value is',
\'consistent.',
\'',
\'Feel free to exit this tab now.',
\'',
\'Measurements taken: ' . string(sleeps)
\       ]
        for i in range(len(lines))
            call setline(line('.') + i, lines[i])
        endfor
        return
    endif

    let sleepcount = 0
    while 1
        let ch = getchar(1)
        if ch ==# 0
            let sleepcount += 1
            sleep 1m
        elseif nr2char(ch) !=# 'j'
            call s:Log.WRN('Non-j keystroke detected. Close tab and retry')
            let s:calibrating = 0
            augroup JersuitePECTool | autocmd! | augroup END
            augroup! JersuitePECTool
            return
        else
            " We got a j
            break
        endif
    endwhile
    call add(s:sleeps, sleepcount)

endfunction
