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
let g:filebeagle_buffer_normal_key_maps = get(g:, 'filebeagle_buffer_normal_key_maps', {})
let g:filebeagle_buffer_visual_key_maps = get(g:, 'filebeagle_buffer_visual_key_maps', {})


command! -complete=dir -nargs=* FileBeagle  :call filebeagle#FileBeagleOpen(<q-args>)
command! -nargs=0 FileBeagleBufferDir       :call filebeagle#FileBeagleOpen("")

nnoremap <silent> <Plug>FileBeagleOpenCurrentWorkingDir     :FileBeagle<CR>
nnoremap <silent> <Plug>FileBeagleOpenCurrentBufferDir      :FileBeagleBufferDir<CR>

" netrw hijacking
" ==============================================================================
" (from EasyTree by Dmitry "troydm" Geurkov <d.geurkov@gmail.com>)
function! s:OpenDirHere(dir)
    if isdirectory(a:dir)
        let l:focal_dir = has("win32")? substitute(a:dir, '/', '\\', 'g') : a:dir
        call filebeagle#FileBeagleOpen(l:focal_dir)
    endif
endfunction

if g:filebeagle_hijack_netrw
augroup FileBeagle
    au!
    autocmd VimEnter * exe 'au! FileExplorer'
    autocmd BufEnter * call <SID>OpenDirHere(expand('<amatch>'))
augroup end
endif

let &cpo = s:save_cpo
