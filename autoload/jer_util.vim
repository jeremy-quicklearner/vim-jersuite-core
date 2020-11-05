" File: autoload/jer_util.vim
" Description: Common utilities for Jersuite plugins
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid autoloading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" Function used by JerCheckDep
function! jer_util#CheckDep(name, depname, depwhere, depminver, depmaxver)
    if !exists('g:' . a:depname . '_version')
        echom 'Jersuite plugin ' . a:name .
       \      ' requires ' . a:depname . ' (' . a:depwhere . ')' .
       \      ' to be installed before it'
        return 0
    endif
    let actverstr = eval('g:' . a:depname . '_version')
    let actver = split(actverstr, '\.')
    let minver = split(a:depminver,  '\.')
    let maxver = split(a:depmaxver, '\.')
    let maxok = 0
    let ok = 1
    for idx in range(3)
        if !maxok && actver[idx] < maxver[idx]
            let maxok = 1
        endif
        if actver[idx] <# minver[idx] || (!maxok && actver[idx] >=# maxver[idx])
            let ok = 0
            break
        endif
    endfor
    if !ok
        echom 'Jersuite plugin ' . a:name . 
       \      ' requires ' . a:depname .
       \      ' version between ' . a:depminver .
       \      ' (inclusive) and ' . a:depmaxver .
       \      ' (exclusive) but installed version is ' . actverstr
        return 0
    endif
    return 1
endfunction

" Functions used by WinDo, BufDo, and TabDo
function! jer_util#WinDo(range, command)
    let currwin=winnr()
    let range = a:range
    if range ==# 0
        let range = ''
    endif
    execute range . 'windo ' . a:command
    execute currwin . 'wincmd w'
endfunction

function! jer_util#BufDo(range, command)
    let currBuff=bufnr("%")
    let range = a:range
    if range ==# 0
        let range = ''
    endif
    execute range . 'bufdo ' . a:command
    execute 'buffer ' . currBuff
endfunction

function! jer_util#TabDo(range, command)
    let curtabnr = tabpagenr()
    let range = a:range
    if range ==# 0
        let range = ''
    endif
    execute range . 'tabdo ' . a:command
    execute curtabnr . 'tabnext'
endfunction

" Add escape characters to a string so that it doesn't trigger any
" evaluation when passed to the value of the statusline or tabline options
function! jer_util#SanitizeForStatusLine(arg, str)
    let retstr = a:str

    let retstr = substitute(retstr, ' ', '\ ', 'g')
    let retstr = substitute(retstr, '-', '\-', 'g')
    let retstr = substitute(retstr, '%', '%%', 'g')

    return retstr
endfunction

