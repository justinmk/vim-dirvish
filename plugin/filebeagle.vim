""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""  FileBeagle
""
""  VINE (Vim Is Not Emacs) file system explorer.
""
""  Copyright 2014 Jeet Sukumaran.
""
""  This program is free software; you can redistribute it and/or modify
""  it under the terms of the GNU General Public License as published by
""  the Free Software Foundation; either version 3 of the License, or
""  (at your option) any later version.
""
""  This program is distributed in the hope that it will be useful,
""  but WITHOUT ANY WARRANTY; without even the implied warranty of
""  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
""  GNU General Public License <http://www.gnu.org/licenses/>
""  for more details.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if (exists('g:loaded_filebeagle') && g:loaded_filebeagle) || &cp || version < 700
    finish
endif
let g:loaded_filebeagle = 1
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim

let g:filebeagle_hijack_netrw = get(g:, 'filebeagle_hijack_netrw', 1)
let g:filebeagle_suppress_keymaps = get(g:, 'filebeagle_suppress_keymaps', 0)
let g:filebeagle_show_hidden = get(g:, 'filebeagle_show_hidden', 0)
let g:filebeagle_show_line_numbers = get(g:, 'filebeagle_show_line_numbers', -1)
let g:filebeagle_show_line_relativenumbers = get(g:, 'filebeagle_show_line_relativenumbers', -1)
let g:filebeagle_buffer_legacy_key_maps = get(g:, 'filebeagle_buffer_legacy_key_maps', 0)
let g:filebeagle_buffer_background_key_map_prefix = get(g:, 'filebeagle_buffer_background_key_map_prefix', 'p')
let g:filebeagle_buffer_normal_key_maps = get(g:, 'filebeagle_buffer_normal_key_maps', {})
let g:filebeagle_buffer_visual_key_maps = get(g:, 'filebeagle_buffer_visual_key_maps', {})


command! -complete=dir -nargs=* FileBeagle  :call filebeagle#FileBeagleOpen(<q-args>, -1)
command! -nargs=0 FileBeagleBufferDir       :call filebeagle#FileBeagleOpenCurrentBufferDir()

nnoremap <silent> <Plug>FileBeagleOpenCurrentWorkingDir     :FileBeagle<CR>
nnoremap <silent> <Plug>FileBeagleOpenCurrentBufferDir      :FileBeagleBufferDir<CR>

if !exists('g:filebeagle_suppress_keymaps') || !g:filebeagle_suppress_keymaps
    map <silent> <Leader>f  <Plug>FileBeagleOpenCurrentWorkingDir
    map <silent> -  <Plug>FileBeagleOpenCurrentBufferDir
endif

" netrw hijacking {{{1
" ==============================================================================
" (from EasyTree by Dmitry "troydm" Geurkov <d.geurkov@gmail.com>)
function! s:OpenDirHere(dir)
    if isdirectory(a:dir)
        let l:focal_dir = a:dir
        let l:focal_file = bufnr("%")
        if has("win32")
            let l:focal_dir = substitute(l:focal_dir, '/', '\\', 'g')
            let l:focal_file = substitute(l:focal_file, '/', '\\', 'g')
        endif
        call filebeagle#FileBeagleOpen(l:focal_dir, l:focal_file)
    endif
endfunction

augroup FileBeagle
    au!
    autocmd VimEnter * if g:filebeagle_hijack_netrw | exe 'au! FileExplorer' | endif
    autocmd BufEnter * if g:filebeagle_hijack_netrw | call <SID>OpenDirHere(expand('<amatch>')) | endif
augroup end
" }}}1

let &cpo = s:save_cpo
" vim:foldlevel=4:
