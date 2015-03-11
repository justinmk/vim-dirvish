""  Copyright 2014 Jeet Sukumaran. Modified by Justin M. Keyes.

if exists('g:loaded_dirvish') || &cp || version < 700
  finish
endif
let g:loaded_dirvish = 1
let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? Dirvish call dirvish#open(<q-args>)

augroup dirvish_bufevents
  au!
  autocmd BufEnter * if exists('b:dirvish') && isdirectory(expand('<amatch>')) && empty(getline(1)) && 1 == line('$')
        \ | call b:dirvish.render_buffer()
        \ | endif
augroup END

if get(g:, 'dirvish_hijack_netrw', 1)
  augroup dirvish_netrw
    au!
    " nuke netrw brain damage
    autocmd VimEnter * silent! au! FileExplorer *
    " netrw hijack (from EasyTree by Dmitry Geurkov <d.geurkov@gmail.com>)
    autocmd BufEnter * if !exists('b:dirvish') && isdirectory(expand('<amatch>'))
      \ | call dirvish#open(expand('<amatch>'))
      \ | endif
  augroup END
endif

let &cpo = s:save_cpo
