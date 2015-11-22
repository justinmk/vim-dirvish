let s:nowait = (v:version > 703 ? '<nowait>' : '')
execute 'nnoremap '.s:nowait.'<buffer><silent> q :doautocmd dirvish_buflocal BufDelete<CR>'
nnoremap <buffer><silent> -     :Dirvish %:h:h<CR>
nmap <buffer><silent> p     yy<c-w>p:e <c-r>=fnameescape(getreg('"',1,1)[0])<cr><cr>

execute 'nnoremap '.s:nowait.'<buffer><silent> i    :<C-U>call dirvish#visit("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <CR> :<C-U>call dirvish#visit("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> a    :<C-U>call dirvish#visit("vsplit", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> o    :<C-U>call dirvish#visit("split", 1)<CR>'

execute 'vnoremap '.s:nowait.'<buffer><silent> i    :call dirvish#visit("edit", 0)<CR>'
execute 'vnoremap '.s:nowait.'<buffer><silent> <CR> :call dirvish#visit("edit", 0)<CR>'
execute 'vnoremap '.s:nowait.'<buffer><silent> a    :call dirvish#visit("vsplit", 1)<CR>'
execute 'vnoremap '.s:nowait.'<buffer><silent> o    :call dirvish#visit("split", 1)<CR>'

nnoremap <buffer><silent> R :Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

