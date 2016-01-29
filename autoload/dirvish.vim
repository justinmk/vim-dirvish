let s:sep = (&shell =~? 'cmd.exe') ? '\' : '/'
let s:nowait = (v:version > 703 ? '<nowait>' : '')
let s:noswapfile = (2 == exists(':noswapfile')) ? 'noswapfile' : ''
let s:noau       = 'silent noautocmd keepjumps'

function! s:msg_error(msg) abort
  redraw | echohl ErrorMsg | echomsg 'dirvish:' a:msg | echohl None
endfunction
function! s:msg_info(msg) abort
  redraw | echo 'dirvish:' a:msg
endfunction
function! s:msg_dbg(o) abort
  call writefile([string(a:o)], expand('~/dirvish.log', 1), 'a')
endfunction

function! s:normalize_dir(dir) abort
  let dir = a:dir
  if !isdirectory(dir)
    "cygwin/MSYS fallback for paths that lack a drive letter.
    let dir = empty($SYSTEMDRIVE) ? dir : '/'.tolower($SYSTEMDRIVE[0]).(dir)
    if !isdirectory(dir)
      call s:msg_error("invalid directory: '".a:dir."'")
      return ''
    endif
  endif

  let dir = substitute(dir, s:sep.'\+', s:sep, 'g') "replace consecutive slashes
  if dir[-1:] !~# '[\/]' "always end with separator
    return dir . s:sep
  endif
  return dir
endfunction

function! s:parent_dir(dir) abort
  if !isdirectory(a:dir)
    echoerr 'not a directory:' a:dir
    return
  endif
  return s:normalize_dir(fnamemodify(a:dir, ":p:h:h"))
endfunction

if v:version > 703
function! s:globlist(pat) abort
  return glob(a:pat, 1, 1)
endfunction
else "Vim 7.3 glob() cannot handle filenames containing newlines.
function! s:globlist(pat) abort
  return split(glob(a:pat, 1), "\n")
endfunction
endif

function! s:list_dir(dir) abort
  let curdir = s:normalize_dir(a:dir)
  let paths = s:globlist(curdir.'*')
  "Append dot-prefixed files. glob() cannot do both in 1 pass.
  let paths = paths + s:globlist(curdir.'.[^.]*')

  if get(g:, 'dirvish_relative_paths', 0)
        \ && curdir != s:parent_dir(getcwd()) "avoid blank line for cwd
    return sort(map(paths, "fnamemodify(v:val, ':p:.')"))
  else
    return sort(map(paths, "fnamemodify(v:val, ':p')"))
  endif
endfunction

function! s:shdo(l1, l2, cmd)
  let dir = b:dirvish.dir
  let lines = getline(a:l1, a:l2)
  let tmpfile = tempname()

  augroup dirvish_shcmd
    autocmd! * <buffer>
    " Refresh after executing the command.
    exe 'autocmd ShellCmdPost * autocmd dirvish_shcmd BufEnter,WinEnter <buffer='.bufnr('%')
          \ .'> Dirvish %|au! dirvish_shcmd * <buffer='.bufnr('%').'>'
  augroup END

  for i in range(0, (a:l2-a:l1))
    let f = substitute(lines[i],s:sep.'$','','g') "remove trailing slash
    let f = 2==exists(':lcd') ? fnamemodify(f, ':t') : lines[i] "relative
    let lines[i] = substitute(a:cmd, '\V{}', shellescape(f), 'g')
  endfor
  execute 'split' tmpfile '|' (2==exists(':lcd')?('lcd '.dir):'')
  setlocal nobuflisted
  call append(0, lines)
  norm! G"_dd
  write
  if executable('chmod')
    call system('chmod u+x '.tmpfile)
  endif
  " if !empty(sh_ft)
  "   execute 'setlocal filetype='.sh_ft
  " endif
endfunction

function! s:buf_init() abort
  augroup dirvish_buflocal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call <SID>on_bufenter()
    " Ensure w:dirvish for window splits, `:b <nr>`, etc.
    autocmd BufEnter,WinEnter <buffer> 
          \ let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')
    " BufUnload is fired for :bwipeout, :bdelete, and :bunload, _even_ if
    " 'nobuflisted'. BufDelete is _not_ fired if 'nobuflisted'.
    autocmd BufUnload <buffer> call <SID>on_bufclosed()
  augroup END

  setlocal undolevels=-1 buftype=nofile noswapfile

  setlocal filetype=dirvish
  command! -buffer -range -bar -nargs=* Shdo call <SID>shdo(<line1>, <line2>, <q-args>)
  execute 'nnoremap '.s:nowait.'<buffer> x :Shdo  {}<Left><Left><Left>'
  execute 'xnoremap '.s:nowait.'<buffer> x :Shdo  {}<Left><Left><Left>'
endfunction

function! s:on_bufenter() abort
  if empty(getline(1)) && 1 == line('$')
    Dirvish %
    return
  endif
  if 0 == &l:cole
    call <sid>win_init()
  endif
endfunction

function! s:set_alt_prev_bufs(d) abort
  " Remember previous ('original') buffer.
  let a:d.prevbuf = s:buf_isvalid(bufnr('%')) || !exists('w:dirvish')
        \ ? 0+bufnr('%') : w:dirvish.prevbuf
  if !s:buf_isvalid(a:d.prevbuf)
    "If reached via :edit/:buffer/etc. we cannot get the (former) altbuf.
    let a:d.prevbuf = exists('b:dirvish') && s:buf_isvalid(b:dirvish.prevbuf)
        \ ? b:dirvish.prevbuf : bufnr('#')
  endif

  " Remember alternate buffer.
  let a:d.altbuf = s:buf_isvalid(bufnr('#')) || !exists('w:dirvish')
        \ ? 0+bufnr('#') : w:dirvish.altbuf
  if exists('b:dirvish') && (a:d.altbuf == a:d.prevbuf || !s:buf_isvalid(a:d.altbuf))
    let a:d.altbuf = b:dirvish.altbuf
  endif

  let w:dirvish = extend(get(w:, 'dirvish', {}), a:d, 'force')
endfunction

function! s:win_init() abort
  let w:dirvish = get(w:, 'dirvish', copy(b:dirvish))
  let [w:dirvish._w_wrap, w:dirvish._w_cul] = [&l:wrap, &l:cul]
  setlocal nowrap cursorline

  if has("syntax")
    syntax clear
    let sep = escape(s:sep, '/\')
    exe 'syntax match DirvishPathHead ''\v.*'.sep.'\ze[^'.sep.']+'.sep.'?$'' conceal'
    exe 'syntax match DirvishPathTail ''\v[^'.sep.']+'.sep.'$'''
    highlight! link DirvishPathTail Directory
  endif

  if has('conceal')
    let [w:dirvish._w_cocu, w:dirvish._w_cole] = [&l:concealcursor, &l:conceallevel]
    setlocal concealcursor=nvc conceallevel=3
  endif
endfunction

function! s:buf_isvisible(bnr) abort
  for i in range(1, tabpagenr('$'))
    for tbnr in tabpagebuflist(i)
      if tbnr == a:bnr
        return 1
      endif
    endfor
  endfor
  return 0
endfunction

function! s:on_bufclosed() abort
  let d = get(w:, 'dirvish', {})
  if empty(d)
    return
  endif

  let [altbuf, prevbuf] = [get(d, 'altbuf', 0), get(d, 'prevbuf', 0)]
  call s:visit_altbuf(altbuf)
  if !s:visit_prevbuf(prevbuf)
    call s:msg_info('no other buffers')
  endif

  if !exists('b:dirvish')
    call s:restore_winlocal_settings()
  endif
endfunction

function! s:restore_winlocal_settings()
  if has('conceal') && has_key(w:dirvish, '_w_cocu')
    let [&l:cocu, &l:cole] = [w:dirvish._w_cocu, w:dirvish._w_cole]
    unlet w:dirvish._w_cocu w:dirvish._w_cole
  endif
endfunction

function! dirvish#visit(split_cmd, open_in_background) range abort
  let startline = v:count ? v:count : a:firstline
  let endline   = v:count ? v:count : a:lastline
  let [curtab, curwin, wincount] = [tabpagenr(), winnr(), winnr('$')]
  let splitcmd = a:split_cmd

  let paths = getline(startline, endline)
  for path in paths
    if !isdirectory(path) && !filereadable(path)
      call s:msg_info("invalid (or access denied): ".path)
      continue
    endif

    try
      if isdirectory(path)
        exe (splitcmd ==# 'edit' ? '' : splitcmd.'|') 'Dirvish' fnameescape(path)
      else
        exe splitcmd fnameescape(path)
      endif

      " return to previous window after _each_ split, otherwise we get lost.
      if a:open_in_background && splitcmd =~# 'sp' && winnr('$') > wincount
        wincmd p
      endif
    catch /E37:/
      call s:msg_info("E37: No write since last change")
      return
    catch /E36:/
      call s:msg_info(v:exception)
      return
    catch /E325:/
      call s:msg_info("E325: swap file exists")
    endtry
  endfor

  if a:open_in_background "return to dirvish buffer
    if a:split_cmd ==# 'tabedit'
      exe 'tabnext' curtab '|' curwin.'wincmd w'
    elseif a:split_cmd ==# 'edit'
      execute 'silent keepalt keepjumps buffer' w:dirvish._bufnr
    endif
  elseif !exists('b:dirvish')
    if s:visit_prevbuf(w:dirvish.prevbuf) "make prevbuf the altbuf.
      "return to the opened file.
      b#
    endif
  endif
endfunction

" Returns 1 on success, 0 on failure
function! s:visit_prevbuf(prevbuf) abort
  if a:prevbuf != bufnr('%') && bufexists(a:prevbuf)
        \ && empty(getbufvar(a:prevbuf, 'dirvish'))
    execute 'silent noau keepjumps' s:noswapfile 'buffer' a:prevbuf
    return 1
  endif
  return 0
endfunction

function! s:visit_altbuf(altbuf) abort
  if bufexists(a:altbuf) && empty(getbufvar(a:altbuf, 'dirvish'))
    execute 'silent noau keepjumps' s:noswapfile 'buffer' a:altbuf
  endif
endfunction

" Performs `cmd` in all windows showing `bname`.
function! s:win_do(cmd, bname)
  let [curtab, curwin, curwinalt] = [tabpagenr(), winnr(), winnr('#')]
  for tnr in range(1, tabpagenr('$'))
    exe s:noau 'tabnext' tnr
    let [origwin, origwinalt] = [winnr(), winnr('#')]
    for wnr in range(1, tabpagewinnr(tnr, '$'))
      if a:bname ==# bufname(winbufnr(wnr))
        exe s:noau wnr.'wincmd w'
        exe a:cmd
      endif
    endfor
    exe s:noau origwinalt.'wincmd w|' s:noau origwin.'wincmd w'
  endfor
  exe s:noau 'tabnext '.curtab
  exe s:noau curwinalt.'wincmd w|' s:noau curwin.'wincmd w'
endfunction

function! s:buf_render(dir, lastpath) abort
  let bname = bufname('%')
  if !isdirectory(bname)
    echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
    return
  endif

  call s:win_do('let w:dirvish["_view"] = winsaveview()', bname)
  setlocal modifiable

  silent keepmarks keepjumps %delete _
  silent call append(0, s:list_dir(a:dir))
  keepmarks keepjumps $delete _ " remove extra last line

  setlocal nomodifiable nomodified
  call s:win_do('call winrestview(w:dirvish["_view"])', bname)

  if !empty(a:lastpath)
    keepjumps call search('\V\^'.escape(a:lastpath, '\').'\$', 'cw')
  endif
endfunction

function! s:do_open(d, reload) abort
  let d = a:d
  let bnr = bufnr('^' . d.dir . '$')

  let dirname_without_sep = substitute(d.dir, '[\\/]\+$', '', 'g')
  let bnr_nonnormalized = bufnr('^'.dirname_without_sep.'$')
   
  " Vim tends to name the buffer using its reduced path.
  " Examples (Win32 gvim 7.4.618):
  "     ~\AppData\Local\Temp\
  "     ~\AppData\Local\Temp
  "     AppData\Local\Temp\
  "     AppData\Local\Temp
  " Try to find an existing normalized-path name before creating a new one.
  for pat in [':~:.', ':~']
    if -1 != bnr
      break
    endif
    let modified_dirname = fnamemodify(d.dir, pat)
    let modified_dirname_without_sep = substitute(modified_dirname, '[\\/]\+$', '', 'g')
    let bnr = bufnr('^'.modified_dirname.'$')
    if -1 == bnr_nonnormalized
      let bnr_nonnormalized = bufnr('^'.modified_dirname_without_sep.'$')
    endif
  endfor

  try
    if -1 == bnr
      execute 'silent noau keepjumps' s:noswapfile 'edit' fnameescape(d.dir)
    else
      execute 'silent noau keepjumps' s:noswapfile 'buffer' bnr
    endif
  catch /E37:/
    call s:msg_error("E37: No write since last change")
    return
  endtry

  "If the directory is relative to CWD, :edit refuses to create a buffer
  "with the expanded name (it may be _relative_ instead); this will cause
  "problems when the user navigates. Use :file to force the expanded path.
  if bnr_nonnormalized == bufnr('#') || bufname('%') !=# d.dir
    if bufname('%') !=# d.dir
      try
      execute 'silent noau keepjumps '.s:noswapfile.' file ' . fnameescape(d.dir)
      catch /^E95:/
        echom printf('!!!!!!!!!!!!!! [caught E95] bufname="%s" d.dir="%s"', bufname('%'), d.dir)
      endtry
    endif

    if bufnr('#') != bufnr('%') && isdirectory(bufname('#')) "Yes, (# == %) is possible.
      bwipeout # "Kill it with fire, it is useless.
    endif
  endif

  if bufname('%') !=# d.dir  "We have a bug or Vim has a regression.
    echoerr 'expected buffer name: "'.d.dir.'" (actual: "'.bufname('%').'")'
    return
  endif

  if &buflisted
    setlocal nobuflisted
  endif

  let d._bufnr = bufnr('%')
  call s:visit_prevbuf(d.prevbuf) "in case of :bd, :read#, etc.
  execute s:noau s:noswapfile 'buffer' d._bufnr

  let b:dirvish = exists('b:dirvish') ? extend(b:dirvish, d, 'force') : d

  call s:buf_init()
  call s:win_init()
  if a:reload || (empty(getline(1)) && 1 == line('$'))
    call s:buf_render(b:dirvish.dir, get(b:dirvish, 'lastpath', ''))
  endif
endfunction

function! s:buf_isvalid(bnr) abort
  return bufexists(a:bnr) && !isdirectory(bufname(a:bnr))
endfunction

function! dirvish#open(dir) abort
  if &autochdir
    call s:msg_error("'autochdir' is not supported")
    return
  endif

  let d = {}
  let d.dir = fnamemodify(expand(fnameescape(a:dir), 1), ':p')
  "                     ^      ^                        ^resolves to CWD if a:dir is empty
  "                     |      `escape chars like '$' before expand()
  "                     `expand() fixes slashes on Windows

  if filereadable(d.dir) "chop off the filename
    let d.dir = fnamemodify(d.dir, ':p:h')
  endif

  let d.dir = s:normalize_dir(d.dir)
  if '' ==# d.dir " s:normalize_dir() already displayed error message.
    return
  endif

  let reloading = exists('b:dirvish') && d.dir ==# s:normalize_dir(b:dirvish.dir)

  " Save lastpath when navigating _up_.
  if exists('b:dirvish') && d.dir ==# s:parent_dir(b:dirvish.dir)
    let d.lastpath = b:dirvish.dir
  endif

  call s:set_alt_prev_bufs(d)
  call s:do_open(d, reloading)
endfunction
