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
function! jer_util#JerCheckDep(name, depname, depwhere, depvermin, depvermax)
    if !exists('g:' . a:name . '_version')
        echom 'Jersuite plugin ' . a:name .
       \      ' requires ' . a:depname . ' (' . a:depwhere . ')' .
       \      ' to be installed before it'
        return 0
    else
        let depver = eval('g:' . a:name . '_version')
        if depver <# a:depvermin || depver ># a:depvermax
            echom 'Jersuite plugin ' . a:name . 
                  ' requires ' . a:depname .
                  ' version between ' . a:depvermin . ' and ' . a:depvermax .
                    ' but installed version is ' . depver
            return 0
        endif
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

function! BufDo(range, command)
    let currBuff=bufnr("%")
    let range = a:range
    if range ==# 0
        let range = ''
    endif
    execute range . 'bufdo ' . a:command
    execute 'buffer ' . currBuff
endfunction

function! TabDo(range, command)
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

