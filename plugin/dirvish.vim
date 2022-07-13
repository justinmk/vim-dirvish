if exists('g:loaded_dirvish') || &cp || v:version < 700 || &cpo =~# 'C'
  finish
endif
let g:loaded_dirvish = 1

command! -bar -nargs=? -complete=dir Dirvish call dirvish#open(<q-args>)
command! -nargs=* -complete=file -range -bang Shdo call dirvish#shdo(<bang>0 ? argv() : getline(<line1>, <line2>), <q-args>)

func! s:isdir(dir)
  return !empty(a:dir) && (isdirectory(a:dir) ||
    \ (!empty($SYSTEMDRIVE) && isdirectory('/'.tolower($SYSTEMDRIVE[0]).a:dir)))
endf

augroup dirvish
  autocmd!
  " Remove netrw and NERDTree directory handlers.
  autocmd VimEnter * if exists('#FileExplorer') | exe 'au! FileExplorer *' | endif
  autocmd VimEnter * if exists('#NERDTreeHijackNetrw') | exe 'au! NERDTreeHijackNetrw *' | endif
  autocmd BufEnter * if !exists('b:dirvish') && <SID>isdir(expand('%:p'))
    \ | Dirvish
    \ | elseif exists('b:dirvish') && &buflisted && bufnr('$') > 1 | setlocal nobuflisted | endif
  autocmd FileType dirvish if exists('#fugitive') | call FugitiveDetect(@%) | endif
  autocmd ShellCmdPost * if exists('b:dirvish') | Dirvish | endif
augroup END

nnoremap <silent> <Plug>(dirvish_up) :<C-U>exe 'Dirvish' fnameescape(fnamemodify(@%, ':p'.(@%[-1:]=~'[\\/]'?':h':'').repeat(':h',v:count1)))<CR>
nnoremap <silent> <Plug>(dirvish_split_up) :<C-U>split<bar>exe 'Dirvish' fnameescape(fnamemodify(@%, ':p'.(@%[-1:]=~'[\\/]'?':h':'').repeat(':h',v:count1)))<CR>
nnoremap <silent> <Plug>(dirvish_vsplit_up) :<C-U>vsplit<bar>exe 'Dirvish' fnameescape(fnamemodify(@%, ':p'.(@%[-1:]=~'[\\/]'?':h':'').repeat(':h',v:count1)))<CR>

highlight default link DirvishSuffix   SpecialKey
highlight default link DirvishPathTail Directory
highlight default link DirvishArg      Todo

if mapcheck('-', 'n') ==# '' && !hasmapto('<Plug>(dirvish_up)', 'n')
  nmap - <Plug>(dirvish_up)
endif
