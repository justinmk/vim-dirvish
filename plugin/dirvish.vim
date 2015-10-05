""  Copyright 2014 Jeet Sukumaran. Modified by Justin M. Keyes.

if exists('g:loaded_dirvish') || &cp || version < 700
  finish
endif
let g:loaded_dirvish = 1
let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? -complete=dir Dirvish call dirvish#open(<q-args>)

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
    autocmd BufEnter * if !exists('b:dirvish') && isdirectory(expand('<amatch>'))
      \ | redraw | echo ''
      \ | call dirvish#open(expand('<amatch>'))
      \ | endif
  augroup END
endif

nnoremap <Plug>(dirvish_quit)                       :doautocmd dirvish_bufclosed BufDelete<CR>
" TODO: handle case where Vim thinks the current window is the previous window, etc...
nnoremap <Plug>(dirvish_bgPreviousVisitTarget)      yy<c-w>p:e <c-r>=fnameescape(getreg('"',1,1)[0])<cr><cr>
nnoremap <Plug>(dirvish_visitTarget)                :<C-U>call b:dirvish.visit("edit", 0)<CR>
vnoremap <Plug>(dirvish_visitTarget)                :call b:dirvish.visit("edit", 0)<CR>
nnoremap <Plug>(dirvish_splitVerticalVisitTarget)   :<C-U>call b:dirvish.visit("vsplit", 1)<CR>
vnoremap <Plug>(dirvish_splitVerticalVisitTarget)   :call b:dirvish.visit("vsplit", 1)<CR>
nnoremap <Plug>(dirvish_splitVisitTarget)           :<C-U>call b:dirvish.visit("split", 1)<CR>
vnoremap <Plug>(dirvish_splitVisitTarget)           :call b:dirvish.visit("split", 1)<CR>
nnoremap <Plug>(dirvish_focusOnParent)              :call b:dirvish.visit_parent_dir()<CR>

let &cpo = s:save_cpo
