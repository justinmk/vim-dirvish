if exists('g:loaded_dirvish') || &cp || version < 700 || &cpo =~# 'C'
  finish
endif
let g:loaded_dirvish = 1

command! -bar -nargs=? -complete=dir Dirvish call dirvish#open(<q-args>)
command! -bar -nargs=* -complete=file -range Shdo call dirvish#shdo(<line1>, <line2>, <q-args>)

function! s:isdir(dir)
  return !empty(a:dir) && (isdirectory(a:dir) ||
    \ (!empty($SYSTEMDRIVE) && isdirectory('/'.tolower($SYSTEMDRIVE[0]).a:dir)))
endfunction

augroup dirvish_ftdetect
  autocmd!
  " nuke netrw brain damage
  autocmd VimEnter * silent! au! FileExplorer *
  autocmd BufEnter * if !exists('b:dirvish') && <SID>isdir(expand('%'))
    \ | redraw | echo ''
    \ | exe 'Dirvish %' | endif
augroup END

highlight! link DirvishPathTail Directory

nnoremap <silent> <Plug>(dirvish_up) :<C-U>exe 'Dirvish %:p'.repeat(':h',v:count1)<CR>
nnoremap <silent> <Plug>(dirvish_split_up) :<C-U>exe 'split +Dirvish\ %:p'.repeat(':h',v:count1)<CR>
nnoremap <silent> <Plug>(dirvish_vsplit_up) :<C-U>exe 'vsplit +Dirvish\ %:p'.repeat(':h',v:count1)<CR>

if mapcheck('-', 'n') ==# '' && !hasmapto('<Plug>(dirvish_up)', 'n')
  nmap - <Plug>(dirvish_up)
endif
