""  Copyright 2014 Jeet Sukumaran. Modified by Justin M. Keyes.

if exists('g:loaded_dirvish') || &cp || version < 700 || &cpo =~# 'C'
  finish
endif
let g:loaded_dirvish = 1

command! -nargs=? -complete=dir Dirvish call dirvish#open(<q-args>)

augroup dirvish_bufevents
  au!
  autocmd BufEnter * if exists('b:dirvish') && isdirectory(expand('<amatch>')) && empty(getline(1)) && 1 == line('$')
        \ | exe 'Dirvish '.fnameescape(expand('<afile>')) | endif
augroup END

if get(g:, 'dirvish_hijack_netrw', 1)
  augroup dirvish_netrw
    au!
    " nuke netrw brain damage
    autocmd VimEnter * silent! au! FileExplorer *
    autocmd BufEnter * if !exists('b:dirvish') && isdirectory(expand('<amatch>'))
      \ | redraw | echo ''
      \ | call dirvish#open(expand('<amatch>'))
      \ | endif
  augroup END
endif

