if exists('g:loaded_dirvish') || &cp || version < 700 || &cpo =~# 'C'
  finish
endif
let g:loaded_dirvish = 1

let g:dirvish_strategy = get(g:,'dirvish_strategy','dirvish')
command! -bar -nargs=? -complete=dir Dirvish call {g:dirvish_strategy}#open(<q-args>)
command! -bar -nargs=* -complete=file -range -bang Shdo call {g:dirvish_strategy}#shdo(<bang>0 ? argv() : getline(<line1>, <line2>), <q-args>)

function! s:isdir(dir)
  return !empty(a:dir) && (isdirectory(a:dir) ||
    \ (!empty($SYSTEMDRIVE) && isdirectory('/'.tolower($SYSTEMDRIVE[0]).a:dir)))
endfunction

augroup dirvish_ftdetect
  autocmd!
  " Remove netrw and NERDTree directory handlers.
  autocmd VimEnter * silent! au! FileExplorer *
  autocmd VimEnter * silent! au! NERDTreeHijackNetrw *
  autocmd BufEnter * if !exists('b:dirvish') && <SID>isdir(expand('%'))
    \ | redraw | echo '' | exe 'Dirvish %'
    \ | elseif exists('b:dirvish') && &buflisted && bufnr('$') > 1 | setlocal nobuflisted | endif
augroup END

nnoremap <silent> <Plug>(dirvish_up) :<C-U>exe 'Dirvish %:p'.repeat(':h',v:count1)<CR>
nnoremap <silent> <Plug>(dirvish_split_up) :<C-U>exe 'split +Dirvish\ %:p'.repeat(':h',v:count1)<CR>
nnoremap <silent> <Plug>(dirvish_vsplit_up) :<C-U>exe 'vsplit +Dirvish\ %:p'.repeat(':h',v:count1)<CR>

highlight default link DirvishSuffix   SpecialKey
highlight default link DirvishPathTail Directory
highlight default link DirvishArg      Keyword

if mapcheck('-', 'n') ==# '' && !hasmapto('<Plug>(dirvish_up)', 'n')
  nmap - <Plug>(dirvish_up)
endif
