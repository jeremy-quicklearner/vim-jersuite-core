" File: plugin/vim-jersuite-core.vim
" Description: Root script for vim-jersuite-core plugin
" Author: Jeremy Lerner <github.com/jeremy-quicklearner>
" License: MIT

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" vim-jersuite-core itself has no dependencies
let g:jersuite_core_version = 10001

" Command that generically checks a plugin dependency and aborts with an error
" message if it's not installed or its version is outside a range. This is a
" command instead of a function 
command! -nargs=+ JerCheckDep if !JerCheckDep(<f-args>) | exit | endif

" Command to open the buflog
command! -nargs=0 -complete=command JerLog buffer jersuite_buflog

" Command to clear the buflog
command! -nargs=0 -complete=command JerLogClear call jer_log#Clear()

" Command to set buflog and msglog level for a facility
" This command cannot *create* a logging facility. For that, jer_log#SetLevel
" must be called directly.
" :JerLogSet <facility> <bufloglevel> <msgloglevel>
command! -nargs=+ -complete=customlist,jer_log#CompleteSetCmd
       \ JerLogSet call jer_log#SetCmd(<f-args>)

" Mappings required by jer_mode.vim
noremap <silent> <expr> <plug>JerDetectMode
      \ '<c-w>:<c-u>call jer_mode#Detect("' . mode() . '")<cr>'
tnoremap <silent> <expr> <plug>JerDetectMode
      \ '<c-w>:<c-u>call jer_mode#Detect("' . mode() . '")<cr>'

" Just like windo, but restore the current window when done
command! -nargs=+ -count=0 -complete=command JerWindo
       \ call jer_util#WinDo(<count>,<q-args>)

" Just like Windo, but disable all autocommands for fast processing
command! -nargs=+ -count=0 -complete=command JerWindofast
       \ noautocmd call jer_util#WinDo(<count>, <q-args>)

" Just like bufdo, but restore the current buffer when done.
command! -nargs=+ -count=0 -complete=command JerBufdo
       \ call BufDo(<count>, <q-args>)

" Just like tabdo, but restore the current buffer when done.
command! -nargs=+ -count=0 -complete=command JerTabdo
       \ call TabDo(<count>, <q-args>, '')
