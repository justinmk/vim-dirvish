let s:sep = (&shell =~? 'cmd.exe') ? '\' : '/'
let s:nowait = (v:version > 703 ? '<nowait>' : '')
execute 'nnoremap '.s:nowait.'<buffer><silent> q :doautocmd dirvish_buflocal BufUnload<CR>'
nnoremap <buffer><silent> -   :Dirvish %:h:h<CR>
nnoremap <buffer><silent> p   yy<c-w>p:e <c-r>=fnameescape(getreg('"',1,1)[0])<cr><cr>

execute 'nnoremap '.s:nowait.'<buffer><silent> i    :<C-U>call dirvish#visit("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <CR> :<C-U>call dirvish#visit("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> a    :<C-U>call dirvish#visit("vsplit", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> o    :<C-U>call dirvish#visit("split", 1)<CR>'

execute 'vnoremap '.s:nowait.'<buffer><silent> I    :call dirvish#visit("edit", 0)<CR>'
execute 'vnoremap '.s:nowait.'<buffer><silent> <CR> :call dirvish#visit("edit", 0)<CR>'
execute 'vnoremap '.s:nowait.'<buffer><silent> A    :call dirvish#visit("vsplit", 1)<CR>'
execute 'vnoremap '.s:nowait.'<buffer><silent> O    :call dirvish#visit("split", 1)<CR>'

nnoremap <buffer><silent> R :Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

" Buffer-local / and ? mappings to skip the concealed path fragment.
let sep_cnt = strlen(substitute(b:dirvish.dir, '\v[^\'.s:sep.']{-}\'.s:sep, s:sep, 'g'))
execute 'nnoremap <buffer> / /\v(([^\'.s:sep.']*\'.s:sep.'){'.sep_cnt.'}.*\zs)'
execute 'nnoremap <buffer> ? ?\v(([^\'.s:sep.']*\'.s:sep.'){'.sep_cnt.'}.*\zs)'
