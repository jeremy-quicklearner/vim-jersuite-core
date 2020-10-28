" File: autoload/jer_mode.vim
" Description: Mode preservation/restoration utilities for Jersuite plugins
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid autoloading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

call jer_log#SetLevel('detect-mode', 'CFG', 'WRN')
let s:Log = jer_log#LogFunctions('detect-mode')

let s:detectedmode = {'mode':'n'}
function! jer_mode#Detect(mode)
    call s:Log.DBG('jer_mode#Detect ', a:mode)
    let fixedmode = 'n'
    if a:mode ==# 'v'
        let fixedmode = visualmode()
    elseif a:mode ==# 's'
        let fixedmode = get(
       \    {'v':'s','V':'S',"\<c-v>":"\<c-s>"},
       \    visualmode(),
       \    's'
       \)
    elseif a:mode ==# 't'
        let fixedmode = 't'
    endif
    let s:detectedmode = {'mode':fixedmode}
    if index(['v', 'V', "\<c-v>", 's', 'S', "\<c-s>"], fixedmode) >=# 0
        let s:detectedmode.curline = line('.')
        let s:detectedmode.curcol = col('.')
        " line('v') and col('v') don't work here because by the time this
        " function is running, we are in normal mode
        let s:detectedmode.otherline = line("'<")
        let s:detectedmode.othercol = col("'<")
        if s:detectedmode.curline ==# s:detectedmode.otherline && 
       \   s:detectedmode.curcol ==# s:detectedmode.othercol
            let s:detectedmode.otherline = line("'>")
            let s:detectedmode.othercol = col("'>")
        endif
    endif
endfunction

" Restore the mode after it's been preserved by jer_mode#Detect
function! jer_mode#Restore()
    call s:Log.DBG('jer_mode#Restore ', s:detectedmode)
    if s:detectedmode.mode ==# 'n'
        if mode() ==# 't'
            execute "normal! \<c-\>\<c-n>"
        endif
        return
    elseif index(
   \    ['v', 'V', "\<c-v>", 's', 'S', "\<c-s>"],
   \    s:detectedmode.mode
   \) >=# 0
        if mode() ==# 't'
            execute "normal! \<c-\>\<c-n>"
        endif
        let normcmd = get({
       \    'v':'v','V':'V',"\<c-v>":"\<c-v>",
       \    's':"gh",'S':"gH","\<c-s>":"g\<c-h>"
       \},s:detectedmode.mode,'')
        call cursor(s:detectedmode.otherline, s:detectedmode.othercol)
        execute "normal! " . normcmd
        call cursor(s:detectedmode.curline, s:detectedmode.curcol)
    elseif s:detectedmode.mode ==# 't' && mode() !=# 't'
        normal! a
    endif
    return
endfunction

function! jer_mode#Retrieve()
    call s:Log.DBG('jer_mode#Retrieve ', s:detectedmode)
    return s:detectedmode
endfunction
function! jer_mode#ForcePreserve(mode)
    call s:Log.DBG('jer_mode#ForcePreserve ', a:mode)
    if type(a:mode) != v:t_dict || !has_key(a:mode, 'mode')
        let s:detectedmode = {'mode':'n'}
    else
        let s:detectedmode = a:mode
    endif
endfunction

