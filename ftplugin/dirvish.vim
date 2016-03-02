let s:nowait = (v:version > 703 ? '<nowait>' : '')

if !hasmapto('<Plug>(dirvish_quit)', 'n')
  execute 'nmap '.s:nowait.'<buffer> q <Plug>(dirvish_quit)'
endif
if !hasmapto('<Plug>(dirvish_arg)', 'n')
  execute 'nmap '.s:nowait.'<buffer> . <Plug>(dirvish_arg)'
  execute 'xmap '.s:nowait.'<buffer> . <Plug>(dirvish_arg)'
endif

nnoremap <buffer><silent> <Plug>(dirvish_up) :<C-U>exe "Dirvish %:h".repeat(":h",v:count1)<CR>
nnoremap <buffer><silent> <Plug>(dirvish_split_up) :<C-U>exe 'split +Dirvish\ %:h'.repeat(':h',v:count1)<CR>
nnoremap <buffer><silent> <Plug>(dirvish_vsplit_up) :<C-U>exe 'vsplit +Dirvish\ %:h'.repeat(':h',v:count1)<CR>
if !hasmapto('<Plug>(dirvish_up)', 'n')
  execute 'nmap '.s:nowait.'<buffer> - <Plug>(dirvish_up)'
endif

nnoremap <buffer><silent> p   yy<c-w>p:e <c-r>=fnameescape(getreg('"',1,1)[0])<cr><cr>

execute 'nnoremap '.s:nowait.'<buffer><silent> i    :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <CR> :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> a    :<C-U>.call dirvish#open("vsplit", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> o    :<C-U>.call dirvish#open("split", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <2-LeftMouse> :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> da.  :<C-U>arglocal<Bar>silent! argdelete *<Bar>echo "arglist: cleared"<Bar>Dirvish %<CR>'

execute 'xnoremap '.s:nowait.'<buffer><silent> I    :call dirvish#open("edit", 0)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> <CR> :call dirvish#open("edit", 0)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> A    :call dirvish#open("vsplit", 1)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> O    :call dirvish#open("split", 1)<CR>'

nnoremap <buffer><silent> R :<C-U><C-R>=v:count ? ':let g:dirvish_mode='.v:count.'<Bar>' : ''<CR>Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

execute 'nnoremap '.s:nowait.'<buffer> x :Shdo  {}<Left><Left><Left>'
execute 'xnoremap '.s:nowait.'<buffer> x :Shdo  {}<Left><Left><Left>'

" Buffer-local / and ? mappings to skip the concealed path fragment.
try
  call prompter#ready()
  nnoremap <buffer> / :<c-u>call <SID>search('/')<CR>
  nnoremap <buffer> ? :<c-u>call <SID>search('?')<CR>

  function! s:search(dir)
    let s:dir = a:dir
    let s:pos = getpos('.')
    call prompter#input({
    \ 'prompt': a:dir,
    \ 'color': 'Normal',
    \ 'on_change': function('<SID>on_change'),
    \ 'on_cancel': function('<SID>on_cancel'),
    \ })
  endfunction

  function! s:on_cancel(input)
    call setpos('.', s:pos)
  endfunction

  function! s:on_change(input)
    call setpos('.', s:pos)
    call search(join(a:input, '') . '\ze[^\/]*[\/]\=$', s:dir == '/' ? '' : 'bw')
    exe "normal \<C-G>"
  endfunction
catch
  nnoremap <buffer> / /\ze[^\/]*[\/]\=$<Home>
  nnoremap <buffer> ? ?\ze[^\/]*[\/]\=$<Home>
endtry
