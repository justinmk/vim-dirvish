let s:nowait = (v:version > 703 ? '<nowait>' : '')
execute 'nmap '.s:nowait.'<buffer><silent> q :doautocmd dirvish_bufclosed BufDelete<CR>'
nmap <buffer><silent> -     :Dirvish %:h:h<CR>
nmap <buffer><silent> p     <Plug>(dirvish_open_in_prev_win)

nmap <buffer><silent> i     <Plug>(dirvish_open)
nmap <buffer><silent> <CR>  <Plug>(dirvish_open)
nmap <buffer><silent> a     <Plug>(dirvish_vsplit)
nmap <buffer><silent> o     <Plug>(dirvish_split)

vmap <buffer><silent> i     <Plug>(dirvish_open)
vmap <buffer><silent> <CR>  <Plug>(dirvish_open)
vmap <buffer><silent> a     <Plug>(dirvish_vsplit)
vmap <buffer><silent> o     <Plug>(dirvish_split)

nnoremap <buffer><silent> R :Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

