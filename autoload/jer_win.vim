" File: autoload/jer_win.vim
" Description: Winid implementation compatible with pre-8.0 Vim
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid autoloading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

call jer_log#SetLevel('legacy-winid', 'CFG', 'WRN')
let s:Log = jer_log#LogFunctions('legacy-winid')

" If this flag is switched on, jer_win will use its backwards-compatible
" winid implementation even if the Vim version has native winids
if !exists('g:jersuite_forcelegacywinid')
    let g:jersuite_forcelegacywinid = 0
endif

" Mimic how native winids start at 1000 and count up
if !exists('s:maxwinid')
    let s:maxwinid = 999
endif
function! s:MakeWinid()
    let s:maxwinid += 1
    return s:maxwinid
endfunction

function! s:Getid_tab(winnr, tabnr)
    if a:tabnr <=# 0 || a:tabnr ># tabpagenr('$')
        return 0
    endif
    if a:winnr <=# 0 || a:winnr ># tabpagewinnr(a:tabnr, '$')
        return 0
    endif
    let existingwinid = gettabwinvar(
   \    a:tabnr,
   \    a:winnr,
   \    'jersuite_winid',
   \    999
   \)
    if existingwinid !=# 999
        return existingwinid
    endif
    let newwinid = s:MakeWinid()
    call settabwinvar(a:tabnr, a:winnr, 'jersuite_winid', newwinid)
    call s:Log.VRB(
   \    'Assigned synthetic winid ',
   \    newwinid,
   \    ' to window with winnr ',
   \    a:winnr,
   \    ' in tab with tabnr ',
   \    a:tabnr
   \)
    return newwinid
endfunction

function! s:Getid_win(winnr)
    let winnrarg = a:winnr
    if a:winnr == '.'
        let winnrarg = winnr()
    endif
    return s:Getid_tab(winnrarg, tabpagenr())
endfunction

function! s:Getid_cur()
    return s:Getid_win(winnr())
endfunction

function! jer_win#getid(...)
    if a:0 ==# 2
        return s:Getid_tab(a:1, a:2)
    elseif a:0 ==# 1
        return s:Getid_win(a:1)
    elseif a:0 ==# 0
        return s:Getid_cur()
    else
        call s:Log.WRN('Too many arguments for jer_win#getid: ' . a:0)
        return 0
    endif
endfunction

function! jer_win#id2win(winid)
    if a:winid <# 1000 || a:winid ># s:maxwinid
        call s:Log.WRN('Winid ', a:winid, ' does not exist')
        return 0
    endif
    for winnr in range(1, winnr('$'))
        if getwinvar(winnr, 'jersuite_winid', 999) ==# a:winid
            return winnr
        endif
    endfor
    return 0
endfunction

function! jer_win#gotoid(winid)
    let winnr = jer_win#id2win(a:winid)
    if winnr <=# 0 || winnr ># winnr('$')
        return
    endif
    execute winnr . 'wincmd w'
endfunction

function! s:Id2winInternal(winid)
    if a:winid ==# 0
        return 0
    elseif a:winid <# 1000 || a:winid ># s:maxwinid
        return a:winid
    endif
    for winnr in range(1, winnr('$'))
        if getwinvar(winnr, 'jersuite_winid', 999) ==# a:winid
            return winnr
        endif
    endfor
    return 0
endfunction
    
function! jer_win#bufnr(winid)
    return winbufnr(s:Id2WinInternal(a:winid))
endfunction

function! jer_win#width(winid)
    return winwidth(s:Id2WinInternal(a:winid))
endfunction

function! jer_win#height(winid)
    return winheight(s:Id2WinInternal(a:winid))
endfunction

function! jer_win#getwinvar(winid, ...)
    return call('getwinvar', [s:Id2WinInternal(a:winid)] + a:000[1:])
endfunction

function! jer_win#setwinvar(winid, varname, val)
    return setwinvar(s:Id2WinInternal(a:winid), a:varname, a:val)
endfunction

function! jer_win#setloclist(winid, list, ...)
    return call('setloclist', s:Id2WinInternal(a:winid), a:list, a:000[2:])
endfunction

if v:version >=# 800 && (!exists('g:jersuite_forcelegacywinid') ||
                       \ !g:jersuite_forcelegacywinid)
    call s:Log.CFG('Legacy winids disabled')
    let s:funcrefs = {
   \    'legacy': 0,
   \    'getid': function('win_getid'),
   \    'id2win': function('win_id2win'),
   \    'gotoid': function('win_gotoid'),
   \    'bufnr': function('winbufnr'),
   \    'width': function('winwidth'),
   \    'height': function('winheight'),
   \    'getwinvar': function('getwinvar'),
   \    'setwinvar': function('setwinvar'),
   \    'setloclist': function('setloclist')
   \}

else
    call s:Log.CFG('Legacy winids enabled')
    let s:funcrefs = {
   \    'legacy': 1,
   \    'getid': function('jer_win#getid'),
   \    'id2win': function('jer_win#id2win'),
   \    'gotoid': function('jer_win#gotoid'),
   \    'bufnr': function('jer_win#bufnr'),
   \    'width': function('jer_win#width'),
   \    'height': function('jer_win#height'),
   \    'getwinvar': function('jer_win#setwinvar'),
   \    'setwinvar': function('jer_win#setwinvar'),
   \    'setloclist': function('jer_win#setloclist')
   \}

endif

function! jer_win#WinFunctions()
    return s:funcrefs
endfunction
