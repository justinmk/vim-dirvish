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

" The patch 8.2.1978 adds '<cmd>' to Vim.
if has('patch-8.2.1978')
  let s:command_prefix = '<cmd>'
  let s:call_prefix = '<cmd>'
  let s:command_suffix = ''
else
  let s:command_prefix = ':<C-U>'
  let s:call_prefix = ':<C-U>.'
  let s:command_suffix = ":echon ''<CR>"
endif
execute 'nnoremap '.s:nowait.'<buffer> ~    '.s:command_prefix.'Dirvish ~/<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer> i    '.s:call_prefix.'call dirvish#open("edit", 0)<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer> <CR> '.s:call_prefix.'call dirvish#open("edit", 0)<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer> a    '.s:call_prefix.'call dirvish#open("vsplit", 1)<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer> o    '.s:call_prefix.'call dirvish#open("split", 1)<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer> p    '.s:call_prefix.'call dirvish#open("p", 1)<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer> <2-LeftMouse> '.s:call_prefix.'call dirvish#open("edit", 0)<CR>'.s:command_suffix
execute 'nnoremap '.s:nowait.'<buffer><silent> dax  :<C-U>arglocal<Bar>silent! argdelete *<Bar>echo "arglist: cleared"<Bar>Dirvish<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <C-n> <C-\><C-n>j:call feedkeys("p")<CR>'
execute 'nnoremap '.s:nowait.'<buffer><silent> <C-p> <C-\><C-n>k:call feedkeys("p")<CR>'

" The patch 8.2.1978 adds '<cmd>' to Vim.
if !has('patch-8.2.1978')
  let s:call_prefix = ':'
endif
execute 'xnoremap '.s:nowait.'<buffer> I    '.s:call_prefix.'call dirvish#open("edit", 0)<CR>'.s:command_suffix
execute 'xnoremap '.s:nowait.'<buffer> <CR> '.s:call_prefix.'call dirvish#open("edit", 0)<CR>'.s:command_suffix
execute 'xnoremap '.s:nowait.'<buffer> A    '.s:call_prefix.'call dirvish#open("vsplit", 1)<CR>'.s:command_suffix
execute 'xnoremap '.s:nowait.'<buffer> O    '.s:call_prefix.'call dirvish#open("split", 1)<CR>'.s:command_suffix
execute 'xnoremap '.s:nowait.'<buffer> P    '.s:call_prefix.'call dirvish#open("p", 1)<CR>'.s:command_suffix

nnoremap <buffer><silent> R :<C-U><C-R>=v:count ? ':let g:dirvish_mode='.v:count.'<Bar>' : ''<CR>Dirvish<CR>
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
