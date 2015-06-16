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

nnoremap <Plug>(dirvish_setFilter)                  :call b:dirvish.set_filter_exp()<CR>
nnoremap <Plug>(dirvish_toggleFilter)               :call b:dirvish.toggle_filter()<CR>
nnoremap <Plug>(dirvish_toggleHidden)               :call b:dirvish.toggle_hidden()<CR>
nnoremap <Plug>(dirvish_quit)                       :call b:dirvish.quit_buffer()<CR>
nnoremap <Plug>(dirvish_visitTarget)                :<C-U>call b:dirvish.visit("edit", 0)<CR>
vnoremap <Plug>(dirvish_visitTarget)                :call b:dirvish.visit("edit", 0)<CR>
nnoremap <Plug>(dirvish_bgVisitTarget)              :<C-U>call b:dirvish.visit("edit", 1)<CR>
vnoremap <Plug>(dirvish_bgVisitTarget)              :call b:dirvish.visit("edit", 1)<CR>
nnoremap <Plug>(dirvish_splitVerticalVisitTarget)   :<C-U>call b:dirvish.visit("vsplit", 0)<CR>
vnoremap <Plug>(dirvish_splitVerticalVisitTarget)   :call b:dirvish.visit("vsplit", 0)<CR>
nnoremap <Plug>(dirvish_bgSplitVerticalVisitTarget) :<C-U>call b:dirvish.visit("vsplit", 1)<CR>
vnoremap <Plug>(dirvish_bgSplitVerticalVisitTarget) :call b:dirvish.visit("vsplit", 1)<CR>
nnoremap <Plug>(dirvish_splitVisitTarget)           :<C-U>call b:dirvish.visit("split", 0)<CR>
vnoremap <Plug>(dirvish_splitVisitTarget)           :call b:dirvish.visit("split", 0)<CR>
nnoremap <Plug>(dirvish_bgSplitVisitTarget)         :<C-U>call b:dirvish.visit("split", 1)<CR>
vnoremap <Plug>(dirvish_bgSplitVisitTarget)         :call b:dirvish.visit("split", 1)<CR>
nnoremap <Plug>(dirvish_tabVisitTarget)             :<C-U>call b:dirvish.visit("tabedit", 0)<CR>
vnoremap <Plug>(dirvish_tabVisitTarget)             :call b:dirvish.visit("tabedit", 0)<CR>
nnoremap <Plug>(dirvish_bgTabVisitTarget)           :<C-U>call b:dirvish.visit("tabedit", 1)<CR>
vnoremap <Plug>(dirvish_bgTabVisitTarget)           :call b:dirvish.visit("tabedit", 1)<CR>
nnoremap <Plug>(dirvish_focusOnParent)              :call b:dirvish.visit_parent_dir()<CR>

let &cpo = s:save_cpo
