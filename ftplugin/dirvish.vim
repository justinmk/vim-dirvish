let s:nowait = (v:version > 703 ? '<nowait>' : '')
execute 'nmap '    .s:nowait.'<buffer><silent> q    <Plug>(dirvish_quit)'
execute 'nnoremap '.s:nowait.'<buffer><silent> -    :<C-U>exe "Dirvish %:h".repeat(":h",v:count1)<CR>'
nnoremap <buffer><silent> p   yy<c-w>p:e <c-r>=fnameescape(getreg('"',1,1)[0])<cr><cr>

execute 'nnoremap '.s:nowait.'<buffer><silent> i    :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <CR> :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> a    :<C-U>.call dirvish#open("vsplit", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> o    :<C-U>.call dirvish#open("split", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <2-LeftMouse> :<C-U>.call dirvish#open("edit", 0)<CR>'

execute 'xnoremap '.s:nowait.'<buffer><silent> I    :call dirvish#open("edit", 0)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> <CR> :call dirvish#open("edit", 0)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> A    :call dirvish#open("vsplit", 1)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> O    :call dirvish#open("split", 1)<CR>'

nnoremap <buffer><silent> R :Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

execute 'nnoremap '.s:nowait.'<buffer> x :Shdo  {}<Left><Left><Left>'
execute 'xnoremap '.s:nowait.'<buffer> x :Shdo  {}<Left><Left><Left>'

" Buffer-local / and ? mappings to skip the concealed path fragment.
nnoremap <buffer> / /\ze[^\/]*[\/]\=$<Home>
nnoremap <buffer> ? ?\ze[^\/]*[\/]\=$<Home>
