""  Copyright 2014 Jeet Sukumaran.

if exists('g:loaded_filebeagle') || &cp || version < 700
    finish
endif
let g:loaded_filebeagle = 1
let s:save_cpo = &cpo
set cpo&vim

let g:filebeagle_hijack_netrw = get(g:, 'filebeagle_hijack_netrw', 1)
let g:filebeagle_show_hidden = get(g:, 'filebeagle_show_hidden', 0)
let g:filebeagle_buffer_background_key_map_prefix = get(g:, 'filebeagle_buffer_background_key_map_prefix', 'p')

command! -complete=dir -nargs=? FileBeagle  :call filebeagle#open(<q-args>)
command! -nargs=0 FileBeagleBufferDir       :call filebeagle#open("")

nnoremap <silent> <Plug>FileBeagleOpenCurrentWorkingDir     :FileBeagle<CR>
nnoremap <silent> <Plug>FileBeagleOpenCurrentBufferDir      :FileBeagleBufferDir<CR>

if g:filebeagle_hijack_netrw
  augroup dirvish_netrw
    au!
    autocmd VimEnter * au! FileExplorer *
    " netrw hijack (from EasyTree by Dmitry Geurkov <d.geurkov@gmail.com>)
    autocmd BufEnter * if !exists('b:dirvish') && isdirectory(expand('<amatch>'))
      \ | call filebeagle#open(
      \     (has("win32")
      \       ? substitute(expand('<amatch>'), '/', '\\', 'g')
      \       : expand('<amatch>')))
      \ | endif
  augroup END
endif

let &cpo = s:save_cpo
