let s:sep = (&shell =~? 'cmd.exe') ? '\' : '/'
let s:noswapfile = (2 == exists(':noswapfile')) ? 'noswapfile' : ''
let s:noau       = 'silent noautocmd keepjumps'

function! s:msg_error(msg) abort
  redraw | echohl ErrorMsg | echomsg 'dirvish:' a:msg | echohl None
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
  " Escape for glob().
  let dir_esc = substitute(a:dir,'\V[','[[]','g')
  let paths = s:globlist(dir_esc.'*')
  "Append dot-prefixed files. glob() cannot do both in 1 pass.
  let paths = paths + s:globlist(dir_esc.'.[^.]*')

  if get(g:, 'dirvish_relative_paths', 0)
      \ && a:dir != s:parent_dir(getcwd()) "avoid blank CWD
    return sort(map(paths, "fnamemodify(v:val, ':p:.')"))
  else
    return sort(map(paths, "fnamemodify(v:val, ':p')"))
  endif
endfunction

function! s:shdo(l1, l2, cmd)
  let dir = b:dirvish._dir
  let lines = getline(a:l1, a:l2)
  let tmpfile = tempname().(&sh=~?'cmd.exe'?'.bat':(&sh=~'powershell'?'.ps1':'.sh'))

  augroup dirvish_shcmd
    autocmd! * <buffer>
    " Refresh after executing the command.
    exe 'autocmd ShellCmdPost * autocmd dirvish_shcmd BufEnter,WinEnter <buffer='.bufnr('%')
          \ .'> Dirvish %|au! dirvish_shcmd * <buffer='.bufnr('%').'>'
  augroup END

  for i in range(0, (a:l2-a:l1))
    let f = substitute(lines[i], escape(s:sep,'\').'$', '', 'g') "trim slash
    let f = 2==exists(':lcd') ? fnamemodify(f, ':t') : lines[i]  "relative
    let lines[i] = substitute(a:cmd, '\V{}', shellescape(f), 'g')
  endfor
  execute 'split' tmpfile '|' (2==exists(':lcd')?('lcd '.dir):'')
  setlocal nobuflisted
  silent keepmarks keepjumps call setline(1, lines)
  write
  if executable('chmod')
    call system('chmod u+x '.tmpfile)
  endif
endfunction

function! s:buf_init() abort
  augroup dirvish_buflocal
    autocmd! * <buffer>
    autocmd BufEnter,WinEnter <buffer> call <SID>on_bufenter()

    " BufUnload is fired for :bwipeout/:bdelete/:bunload, _even_ if
    " 'nobuflisted'. BufDelete is _not_ fired if 'nobuflisted'.
    " NOTE: For 'nohidden' we cannot reliably handle :bdelete like this.
    if &hidden
      autocmd BufUnload <buffer> call s:on_bufclosed()
    endif
  augroup END

  setlocal buftype=nofile noswapfile

  command! -buffer -range -bar -nargs=* Shdo call <SID>shdo(<line1>, <line2>, <q-args>)
endfunction

function! s:on_bufenter() abort
  " Ensure w:dirvish for window splits, `:b <nr>`, etc.
  let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')

  if empty(getline(1)) && 1 == line('$')
    Dirvish %
    return
  endif
  if 0 == &l:cole
    call <sid>win_init()
  endif
endfunction

function! s:save_state(d) abort
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

  " Save window-local settings.
  let w:dirvish = extend(get(w:, 'dirvish', {}), a:d, 'force')
  let [w:dirvish._w_wrap, w:dirvish._w_cul] = [&l:wrap, &l:cul]
  if has('conceal') && !exists('b:dirvish')
    let [w:dirvish._w_cocu, w:dirvish._w_cole] = [&l:concealcursor, &l:conceallevel]
  endif
endfunction

function! s:win_init() abort
  let w:dirvish = get(w:, 'dirvish', copy(b:dirvish))
  setlocal nowrap cursorline

  if has('conceal')
    setlocal concealcursor=nvc conceallevel=3
  endif
endfunction

function! s:on_bufclosed() abort
  call s:restore_winlocal_settings()
endfunction

function! s:buf_close() abort
  let d = get(w:, 'dirvish', {})
  if empty(d)
    return
  endif

  let [altbuf, prevbuf] = [get(d, 'altbuf', 0), get(d, 'prevbuf', 0)]
  let found_alt = s:try_visit(altbuf)
  if !s:try_visit(prevbuf) && !found_alt
      \ && prevbuf != bufnr('%') && altbuf != bufnr('%')
    bdelete
  endif
endfunction

function! s:restore_winlocal_settings() abort
  if !exists('w:dirvish') " can happen during VimLeave, etc.
    return
  endif
  if has('conceal') && has_key(w:dirvish, '_w_cocu')
    let [&l:cocu, &l:cole] = [w:dirvish._w_cocu, w:dirvish._w_cole]
  endif
endfunction

function! s:open_selected(split_cmd, bg, line1, line2) abort
  let curbuf = bufnr('%')
  let [curtab, curwin, wincount] = [tabpagenr(), winnr(), winnr('$')]
  let splitcmd = a:split_cmd

  let paths = getline(a:line1, a:line2)
  for path in paths
    if !isdirectory(path) && !filereadable(path)
      call s:msg_error("invalid (or access denied): ".path)
      continue
    endif

    try
      if isdirectory(path)
        exe (splitcmd ==# 'edit' ? '' : splitcmd.'|') 'Dirvish' fnameescape(path)
      else
        exe splitcmd fnameescape(path)
      endif

      " return to previous window after _each_ split, otherwise we get lost.
      if a:bg && splitcmd =~# 'sp' && winnr('$') > wincount
        wincmd p
      endif
    catch /E37:/
      call s:msg_error("E37: No write since last change")
      return
    catch /E36:/
      call s:msg_error(v:exception)
      return
    catch /E325:/
      call s:msg_error("E325: swap file exists")
    endtry
  endfor

  if a:bg "return to dirvish buffer
    if a:split_cmd ==# 'tabedit'
      exe 'tabnext' curtab '|' curwin.'wincmd w'
    elseif a:split_cmd ==# 'edit'
      execute 'silent keepalt keepjumps buffer' curbuf
    endif
  elseif !exists('b:dirvish') && exists('w:dirvish')
    call s:set_altbuf(w:dirvish.prevbuf)
  endif
endfunction

function! s:set_altbuf(bnr) abort
  let curbuf = bufnr('%')
  call s:try_visit(a:bnr)
  let noau = bufloaded(curbuf) ? 'noau' : ''
  " Return to the current buffer.
  execute 'silent keepjumps' noau s:noswapfile 'buffer' curbuf
endfunction

function! s:try_visit(bnr) abort
  if a:bnr != bufnr('%') && bufexists(a:bnr)
        \ && empty(getbufvar(a:bnr, 'dirvish'))
    " If _previous_ buffer is _not_ loaded (because of 'nohidden'), we must
    " allow autocmds (else no syntax highlighting; #13).
    let noau = bufloaded(a:bnr) ? 'noau' : ''
    execute 'silent keepjumps' noau s:noswapfile 'buffer' a:bnr
    return 1
  endif
  return 0
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

  if v:version > 704 || v:version == 704 && has("patch73")
    let ul=&g:undolevels|setlocal undolevels=-1
  endif
  silent keepmarks keepjumps %delete _
  silent keepmarks keepjumps call setline(1, s:list_dir(a:dir))
  if v:version > 704 || v:version == 704 && has("patch73")
    let &l:undolevels=ul
  endif

  call s:win_do('call winrestview(w:dirvish["_view"])', bname)

  if 1 == line('.') && !empty(a:lastpath)
    keepjumps call search('\V\^'.escape(a:lastpath, '\').'\$', 'cw')
  endif
endfunction

function! s:do_open(d, reload) abort
  let d = a:d
  let bnr = bufnr('^' . d._dir . '$')

  let dirname_without_sep = substitute(d._dir, '[\\/]\+$', '', 'g')
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
    let modified_dirname = fnamemodify(d._dir, pat)
    let modified_dirname_without_sep = substitute(modified_dirname, '[\\/]\+$', '', 'g')
    let bnr = bufnr('^'.modified_dirname.'$')
    if -1 == bnr_nonnormalized
      let bnr_nonnormalized = bufnr('^'.modified_dirname_without_sep.'$')
    endif
  endfor

  try
    if -1 == bnr
      execute 'silent noau keepjumps' s:noswapfile 'edit' fnameescape(d._dir)
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
  if bnr_nonnormalized == bufnr('#') || bufname('%') !=# d._dir
    if bufname('%') !=# d._dir
      execute 'silent noau keepjumps '.s:noswapfile.' file ' . fnameescape(d._dir)
    endif

    if bufnr('#') != bufnr('%') && isdirectory(bufname('#')) "Yes, (# == %) is possible.
      bwipeout # "Kill it with fire, it is useless.
    endif
  endif

  if bufname('%') !=# d._dir  "We have a bug or Vim has a regression.
    echoerr 'expected buffer name: "'.d._dir.'" (actual: "'.bufname('%').'")'
    return
  endif

  if &buflisted
    setlocal nobuflisted
  endif

  call s:set_altbuf(d.prevbuf) "in case of :bd, :read#, etc.

  let b:dirvish = exists('b:dirvish') ? extend(b:dirvish, d, 'force') : d

  call s:buf_init()
  call s:win_init()
  if a:reload || (empty(getline(1)) && 1 == line('$'))
    call s:buf_render(b:dirvish._dir, get(b:dirvish, 'lastpath', ''))
  endif

  setlocal filetype=dirvish
endfunction

function! s:buf_isvalid(bnr) abort
  return bufexists(a:bnr) && !isdirectory(bufname(a:bnr))
endfunction

function! dirvish#open(...) range abort
  if &autochdir
    call s:msg_error("'autochdir' is not supported")
    return
  endif

  if a:0 > 1
    call s:open_selected(a:1, a:2, a:firstline, a:lastline)
    return
  endif

  let d = {}
  let d._dir = fnamemodify(expand(fnameescape(a:1), 1), ':p')
  "                       ^      ^                      ^resolves to CWD if a:1 is empty
  "                       |      `escape chars like '$' before expand()
  "                       `expand() fixes slashes on Windows

  if filereadable(d._dir) "chop off the filename
    let d._dir = fnamemodify(d._dir, ':p:h')
  endif

  let d._dir = s:normalize_dir(d._dir)
  if '' ==# d._dir " s:normalize_dir() already showed error.
    return
  endif

  let reloading = exists('b:dirvish') && d._dir ==# s:normalize_dir(b:dirvish._dir)

  " Save lastpath when navigating _up_.
  if exists('b:dirvish') && d._dir ==# s:parent_dir(b:dirvish._dir)
    let d.lastpath = b:dirvish._dir
  endif

  call s:save_state(d)
  call s:do_open(d, reloading)
endfunction

nnoremap <silent> <Plug>(dirvish_quit) :<C-U>call <SID>buf_close()<CR>
