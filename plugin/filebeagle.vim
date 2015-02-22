""  Copyright 2014 Jeet Sukumaran.

if (exists('g:loaded_filebeagle') && g:loaded_filebeagle) || &cp || version < 700
    finish
endif
let g:loaded_filebeagle = 1
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim

let g:filebeagle_hijack_netrw = get(g:, 'filebeagle_hijack_netrw', 1)
let g:filebeagle_show_hidden = get(g:, 'filebeagle_show_hidden', 0)
let g:filebeagle_buffer_background_key_map_prefix = get(g:, 'filebeagle_buffer_background_key_map_prefix', 'p')
let g:filebeagle_buffer_normal_key_maps = get(g:, 'filebeagle_buffer_normal_key_maps', {})
let g:filebeagle_buffer_visual_key_maps = get(g:, 'filebeagle_buffer_visual_key_maps', {})


command! -complete=dir -nargs=* FileBeagle  :call filebeagle#FileBeagleOpen(<q-args>, -1)
command! -nargs=0 FileBeagleBufferDir       :call filebeagle#FileBeagleOpen("", -1)

nnoremap <silent> <Plug>FileBeagleOpenCurrentWorkingDir     :FileBeagle<CR>
nnoremap <silent> <Plug>FileBeagleOpenCurrentBufferDir      :FileBeagleBufferDir<CR>

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

if g:filebeagle_hijack_netrw
augroup FileBeagle
    au!
    autocmd VimEnter * exe 'au! FileExplorer'
    autocmd BufEnter * call <SID>OpenDirHere(expand('<amatch>'))
augroup end
endif
" }}}1

let &cpo = s:save_cpo
" vim:foldlevel=4:
