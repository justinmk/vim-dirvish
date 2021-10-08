if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:nowait = (v:version > 703 ? '<nowait>' : '')
let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'

if !hasmapto('<Plug>(dirvish_quit)', 'n')
  execute 'nmap '.s:nowait.'<buffer> gq <Plug>(dirvish_quit)'
endif
if !hasmapto('<Plug>(dirvish_arg)', 'n')
  execute 'nmap '.s:nowait.'<buffer> x <Plug>(dirvish_arg)'
  execute 'xmap '.s:nowait.'<buffer> x <Plug>(dirvish_arg)'
endif
if !hasmapto('<Plug>(dirvish_K)', 'n')
  execute 'nmap '.s:nowait.'<buffer> K <Plug>(dirvish_K)'
  execute 'xmap '.s:nowait.'<buffer> K <Plug>(dirvish_K)'
endif

nnoremap <buffer><silent> <Plug>(dirvish_up) :<C-U>exe "Dirvish %:h".repeat(":h",v:count1)<CR>
nnoremap <buffer><silent> <Plug>(dirvish_split_up) :<C-U>exe 'split +Dirvish\ %:h'.repeat(':h',v:count1)<CR>
nnoremap <buffer><silent> <Plug>(dirvish_vsplit_up) :<C-U>exe 'vsplit +Dirvish\ %:h'.repeat(':h',v:count1)<CR>
if !hasmapto('<Plug>(dirvish_up)', 'n')
  execute 'nmap '.s:nowait.'<buffer> - <Plug>(dirvish_up)'
endif

execute 'nnoremap '.s:nowait.'<buffer><silent> ~    :<C-U>Dirvish ~/<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> i    :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <CR> :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> a    :<C-U>.call dirvish#open("vsplit", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> o    :<C-U>.call dirvish#open("split", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> p    :<C-U>.call dirvish#open("p", 1)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <2-LeftMouse> :<C-U>.call dirvish#open("edit", 0)<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> dax  :<C-U>arglocal<Bar>silent! argdelete *<Bar>echo "arglist: cleared"<Bar>Dirvish %<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <C-n> <C-\><C-n>j:call feedkeys("p")<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <C-p> <C-\><C-n>k:call feedkeys("p")<CR>'

execute 'xnoremap '.s:nowait.'<buffer><silent> I    :call dirvish#open("edit", 0)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> <CR> :call dirvish#open("edit", 0)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> A    :call dirvish#open("vsplit", 1)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> O    :call dirvish#open("split", 1)<CR>'
execute 'xnoremap '.s:nowait.'<buffer><silent> P    :call dirvish#open("p", 1)<CR>'

nnoremap <buffer><silent> R :<C-U><C-R>=v:count ? ':let g:dirvish_mode='.v:count.'<Bar>' : ''<CR>Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

execute 'nnoremap <expr>'.s:nowait.'<buffer> . ":<C-u>".(v:count ? "Shdo".(v:count?"!":"")." {}" : ("! ".shellescape(fnamemodify(getline("."),":."))))."<Home><C-Right>"'
execute 'xnoremap <expr>'.s:nowait.'<buffer> . ":Shdo".(v:count?"!":" ")." {}<Left><Left><Left>"'
execute 'nnoremap <expr>'.s:nowait.'<buffer> cd ":<C-u>".(v:count ? "cd" : "lcd")." %<Bar>pwd<CR>"'

" Buffer-local / and ? mappings to skip the concealed path fragment.
if s:sep == '\'
  nnoremap <buffer> / /\ze[^\/]*[\/]\=$<Home>
  nnoremap <buffer> ? ?\ze[^\/]*[\/]\=$<Home>
else
  nnoremap <buffer> / /\ze[^/]*[/]\=$<Home>
  nnoremap <buffer> ? ?\ze[^/]*[/]\=$<Home>
endif

" Force autoload if `ft=dirvish`
if !exists('*dirvish#open')|try|call dirvish#open()|catch|endtry|endif
