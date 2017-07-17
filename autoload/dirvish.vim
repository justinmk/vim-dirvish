let s:srcdir = expand('<sfile>:h:h:p')
let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:noswapfile = (2 == exists(':noswapfile')) ? 'noswapfile' : ''
let s:noau       = 'silent noautocmd keepjumps'

function! s:msg_error(msg) abort
  redraw | echohl ErrorMsg | echomsg 'dirvish:' a:msg | echohl None
endfunction

function! s:suf() abort
  let m = get(g:, 'dirvish_mode', 1)
  return type(m) == type(0) && m <= 1 ? 1 : 0
endfunction

" Normalize slashes for safe use of fnameescape(), isdirectory(). Vim bug #541.
function! s:sl(path) abort
  return tr(a:path, '\', '/')
endfunction

function! s:normalize_dir(dir) abort
  let dir = s:sl(a:dir)
  if !isdirectory(dir)
    "cygwin/MSYS fallback for paths that lack a drive letter.
    let dir = empty($SYSTEMDRIVE) ? dir : '/'.tolower($SYSTEMDRIVE[0]).(dir)
    if !isdirectory(dir)
      call s:msg_error("invalid directory: '".a:dir."'")
      return ''
    endif
  endif
  " Collapse slashes (except UNC-style \\foo\bar).
  let dir = dir[0] . substitute(dir[1:], '/\+', '/', 'g')
  " Always end with separator.
  return (dir[-1:] ==# '/') ? dir : dir.'/'
endfunction

function! s:parent_dir(dir) abort
  let mod = isdirectory(s:sl(a:dir)) ? ':p:h:h' : ':p:h'
  return s:normalize_dir(fnamemodify(a:dir, mod))
endfunction

if v:version > 703
function! s:globlist(pat) abort
  return glob(a:pat, !s:suf(), 1)
endfunction
else "Vim 7.3 glob() cannot handle filenames containing newlines.
function! s:globlist(pat) abort
  return split(glob(a:pat, !s:suf()), "\n")
endfunction
endif

function! s:sortP(...)
  return a:1 =~ '^\.' && a:2 =~ '^\.' ? 0 : tr(stridx(a:2[0].' '.a:1[0],'.') - 1,2,0)
endfunction

function! s:list_dir(dir) abort
  if has_key(b:dirvish,'remote')
    " make a curl request
    let paths = systemlist('curl -s '.a:dir.' -X MLSD')
    " get %:p:h
    let cdir = substitute(matchstr(paths,'\c^type=cdir;'),'^\S*\s*','','')
    " filter response
    call filter(paths,'v:val =~? "^type=\\%(dir\\|file\\);"')
    " obtain paths relative to server
    call map(paths,'substitute(v:val,"^\\S*\\s*","","").(v:val =~? "^type=dir" ? "/" : "")')
    " sort dotfiles lower
    call sort(paths,'s:sortP')
    " make a full path using cdir
    call map(paths,string(cdir).".'/'.v:val")
    " unsilent echom string(paths)
    return paths
  endif

  " Escape for glob().
  let dir_esc = substitute(a:dir,'\V[','[[]','g')
  let paths = s:globlist(dir_esc.'*')
  "Append dot-prefixed files. glob() cannot do both in 1 pass.
  let paths = paths + s:globlist(dir_esc.'.[^.]*')

  if get(g:, 'dirvish_relative_paths', 0)
      \ && a:dir != s:parent_dir(getcwd()) "avoid blank CWD
    return map(paths, "fnamemodify(v:val, ':p:.')")
  else
    return map(paths, "fnamemodify(v:val, ':p')")
  endif
endfunction

function! s:set_args(args) abort
  if arglistid() == 0
    arglocal
  endif
  for f in a:args
    if -1 == index(argv(), f)
      exe '$argadd '.fnameescape(fnamemodify(f, ':p'))
    endif
  endfor
  echo 'arglist: '.argc().' files'
  " Force recalculation of DirvishArg syntax group.
  unlet b:current_syntax
  exe 'source '.fnameescape(s:srcdir.'/syntax/dirvish.vim')
endfunction

function! dirvish#shdo(paths, cmd)
  " Remove empty/duplicate lines.
  let lines = uniq(sort(filter(copy(a:paths), '-1!=match(v:val,"\\S")')))
  let head = fnamemodify(get(lines, 0, '')[:-2], ':h')
  let jagged = 0 != len(filter(copy(lines), 'head != fnamemodify(v:val[:-2], ":h")'))
  if empty(lines) | call s:msg_error('Shdo: no files') | return | endif

  let dirvish_bufnr = bufnr('%')
  let cmd = a:cmd =~# '\V{}' ? a:cmd : (empty(a:cmd)?'{}':(a:cmd.' {}')) "DWIM
  " Paths from argv() or non-dirvish buffers may be jagged; assume CWD then.
  let dir = !jagged && exists('b:dirvish') ? b:dirvish._dir : getcwd()
  let tmpfile = tempname().(&sh=~?'cmd.exe'?'.bat':(&sh=~'powershell'?'.ps1':'.sh'))

  for i in range(0, len(lines)-1)
    let f = substitute(lines[i], escape(s:sep,'\').'$', '', 'g') "trim slash
    if !filereadable(f) && !isdirectory(f)
      let lines[i] = '#invalid path: '.shellescape(f)
      continue
    endif
    let f = !jagged && 2==exists(':lcd') ? fnamemodify(f, ':t') : lines[i]
    let lines[i] = substitute(cmd, '\V{}', escape(shellescape(f),'&\'), 'g')
  endfor
  execute 'silent split' tmpfile '|' (2==exists(':lcd')?('lcd '.dir):'')
  setlocal bufhidden=wipe
  silent keepmarks keepjumps call setline(1, lines)
  silent write
  if executable('chmod')
    call system('chmod u+x '.tmpfile)
    silent edit
  endif

  augroup dirvish_shcmd
    autocmd! * <buffer>
    " Refresh Dirvish after executing a shell command.
    exe 'autocmd ShellCmdPost <buffer> nested if !v:shell_error && bufexists('.dirvish_bufnr.')'
      \.'|setlocal bufhidden=hide|buffer '.dirvish_bufnr.'|silent! Dirvish %'
      \.'|buffer '.bufnr('%').'|setlocal bufhidden=wipe|endif'
  augroup END

  nnoremap <buffer><silent> Z! :silent write<Bar>exe '!'.(has('win32')?'':shellescape(&shell)).' %'<Bar>if !v:shell_error<Bar>close<Bar>endif<CR>
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
endfunction

function! s:on_bufenter() abort
  " Ensure w:dirvish for window splits, `:b <nr>`, etc.
  let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')

  if empty(getline(1)) && 1 == line('$')
    Dirvish %
    return
  endif
  if 0 == &l:cole
    call s:win_init()
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
  if a:d.altbuf == a:d.prevbuf || !s:buf_isvalid(a:d.altbuf)
    let a:d.altbuf = exists('b:dirvish') ? b:dirvish.altbuf : a:d.prevbuf
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
      \ && (1 == bufnr('%') || (prevbuf != bufnr('%') && altbuf != bufnr('%')))
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
    let path = s:sl(path)
    if !isdirectory(path) && !filereadable(path)
      call s:msg_error("invalid (or access denied): ".path)
      continue
    endif

    if isdirectory(path)
      exe (splitcmd ==# 'edit' ? '' : splitcmd.'|') 'Dirvish' fnameescape(path)
    else
      exe splitcmd fnameescape(path)
    endif

    " return to previous window after _each_ split, otherwise we get lost.
    if a:bg && splitcmd =~# 'sp' && winnr('$') > wincount
      wincmd p
    endif
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

function! s:is_valid_altbuf(bnr) abort
  return a:bnr != bufnr('%') && bufexists(a:bnr) && empty(getbufvar(a:bnr, 'dirvish'))
endfunction

function! s:set_altbuf(bnr) abort
  if !s:is_valid_altbuf(a:bnr) | return | endif

  if has('patch-7.4.605') | let @# = a:bnr | return | endif

  let curbuf = bufnr('%')
  if s:try_visit(a:bnr)
    let noau = bufloaded(curbuf) ? 'noau' : ''
    " Return to the current buffer.
    execute 'silent keepjumps' noau s:noswapfile 'buffer' curbuf
  endif
endfunction

function! s:try_visit(bnr) abort
  if s:is_valid_altbuf(a:bnr)
    " If _previous_ buffer is _not_ loaded (because of 'nohidden'), we must
    " allow autocmds (else no syntax highlighting; #13).
    let noau = bufloaded(a:bnr) ? 'noau' : ''
    execute 'silent keepjumps' noau s:noswapfile 'buffer' a:bnr
    return 1
  endif
  return 0
endfunction

function! s:tab_win_do(tnr, cmd, bname) abort
  exe s:noau 'tabnext' a:tnr
  for wnr in range(1, tabpagewinnr(a:tnr, '$'))
    if a:bname ==# bufname(winbufnr(wnr))
      exe s:noau wnr.'wincmd w'
      exe a:cmd
    endif
  endfor
endfunction

" Performs `cmd` in all windows showing `bname`.
function! s:bufwin_do(cmd, bname) abort
  let [curtab, curwin, curwinalt] = [tabpagenr(), winnr(), winnr('#')]
  for tnr in range(1, tabpagenr('$'))
    let [origwin, origwinalt] = [tabpagewinnr(tnr), tabpagewinnr(tnr, '#')]
    for bnr in tabpagebuflist(tnr)
      if a:bname ==# bufname(bnr) " tab has at least 1 matching window
        call s:tab_win_do(tnr, a:cmd, a:bname)
        exe s:noau origwinalt.'wincmd w|' s:noau origwin.'wincmd w'
        break
      endif
    endfor
  endfor
  exe s:noau 'tabnext '.curtab
  exe s:noau curwinalt.'wincmd w|' s:noau curwin.'wincmd w'
endfunction

function! s:buf_render(dir, lastpath,...) abort
  let bname = bufname('%')
  let isnew = empty(getline(1))

  if !a:0 && !isdirectory(s:sl(bname))
    echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
    return
  endif

  if !isnew
    call s:bufwin_do('let w:dirvish["_view"] = winsaveview()', bname)
  endif

  if v:version > 704 || v:version == 704 && has("patch73")
    setlocal undolevels=-1
  endif
  silent keepmarks keepjumps %delete _
  silent keepmarks keepjumps call setline(1, s:list_dir(a:dir))
  if type("") == type(get(g:, 'dirvish_mode'))  " Apply user's filter.
    execute get(g:, 'dirvish_mode')
  endif
  if v:version > 704 || v:version == 704 && has("patch73")
    setlocal undolevels<
  endif

  if !isnew
    call s:bufwin_do('call winrestview(w:dirvish["_view"])', bname)
  endif

  if !empty(a:lastpath)
    let pat = get(g:, 'dirvish_relative_paths', 0) ? fnamemodify(a:lastpath, ':p:.') : a:lastpath
    let pat = empty(pat) ? a:lastpath : pat  " no longer in CWD
    call search('\V\^'.escape(pat, '\').'\$', 'cw')
  endif
  " Place cursor on the tail (last path segment).
  call search('\'.s:sep.'\zs[^\'.s:sep.']\+\'.s:sep.'\?$', 'c', line('.'))
endfunction

function! s:do_open(d, reload) abort
  let d = a:d

  let bnr = bufnr('^' . d._dir . '$')
  if has_key(d,'remote')
    let bnr_nonnormalized = '\'
  else
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
  endif


  if !&hidden && bnr == -1
    let bnr = bufnr(d._dir,1)
  endif
  if -1 == bnr 
    execute 'silent noau ' s:noswapfile 'edit' fnameescape(d._dir)
  else
    execute 'silent noau ' s:noswapfile 'buffer' bnr
  endif

  "If the directory is relative to CWD, :edit refuses to create a buffer
  "with the expanded name (it may be _relative_ instead); this will cause
  "problems when the user navigates. Use :file to force the expanded path.
  if bnr_nonnormalized == bufnr('#') || s:sl(bufname('%')) !=# d._dir
    if s:sl(bufname('%')) !=# d._dir
      execute 'silent noau keepjumps '.s:noswapfile.' file ' . fnameescape(d._dir)
    endif

    if bufnr('#') != bufnr('%') && isdirectory(s:sl(bufname('#'))) "Yes, (# == %) is possible.
      bwipeout # "Kill it with fire, it is useless.
    endif
  endif

  if s:sl(bufname('%')) !=# d._dir  "We have a bug or Vim has a regression.
    echoerr 'expected buffer name: "'.d._dir.'" (actual: "'.bufname('%').'")'
    return
  endif

  if -1 == bnr && exists("#BufNew") " Fire BufNew with the normalized file name.
    exe 'doautocmd <nomodeline> BufNew' bufname('%')
  endif

  if &buflisted && bufnr('$') > 1
    setlocal nobuflisted
  endif

  call s:set_altbuf(d.prevbuf) "in case of :bd, :read#, etc.

  let b:dirvish = exists('b:dirvish') ? extend(b:dirvish, d, 'force') : d

  call s:buf_init()
  call s:win_init()
  if a:reload || s:should_reload()
    call call('s:buf_render',[b:dirvish._dir, get(b:dirvish, 'lastpath', '')]
          \ + (has_key(b:dirvish,'remote') ? [1] : []))
  endif

  setlocal filetype=dirvish
endfunction

function! s:should_reload() abort
  if line('$') < 1000 || '' ==# glob(getline('$'),1)
    return 1
  endif
  redraw | echo 'dirvish: too many files; showing cached listing'
  return 0
endfunction

function! s:buf_isvalid(bnr) abort
  return !&hidden && a:bnr != -1 || bufexists(a:bnr) && !isdirectory(s:sl(bufname(a:bnr)))
endfunction

function! dirvish#open(...) range abort
  if &autochdir
    call s:msg_error("'autochdir' is not supported")
    return
  endif
  if !&hidden && &modified
      \ && (!exists("*win_findbuf") || len(win_findbuf(winbufnr(0))) == 1)
    call s:msg_error("E37: No write since last change")
    return
  endif

  if a:0 > 1
    call s:open_selected(a:1, a:2, a:firstline, a:lastline)
    return
  endif

  let d = {}
  let trp       = s:sl(a:1)
  if a:1 =~ '^\w\+:\/\/'
    let [d.remote; d._dir] = matchlist(a:1,'\(^\w\+:\/\/[^/]\+\)\/\=\(.*\)')[1:]
    let d._dir = d.remote .  '/' . matchstr(d._dir,'.')
    let from_path = fnamemodify(bufname('%'), ':p')
  else
    let from_path = fnamemodify(bufname('%'), ':p')
    let to_path   = fnamemodify(trp, ':p')
    "                                 ^resolves to CWD if a:1 is empty
    let d._dir = filereadable(to_path) ? fnamemodify(to_path, ':p:h') : to_path
    let d._dir = s:normalize_dir(d._dir)
    if '' ==# d._dir " s:normalize_dir() already showed error.
      return
    endif
  endif

  let reloading = exists('b:dirvish') && d._dir ==# b:dirvish._dir

  if reloading
    let d.lastpath = ''         " Do not place cursor when reloading.
  elseif has_key(d,'remote')
    if d._dir ==# substitute(from_path,'\/[^/]*$','','')
      let d.lastpath = from_path  " Save lastpath when navigating _up_.
    elseif from_path is ''
      let d.prevbuf = bufnr('')
    endif
  elseif d._dir ==# s:parent_dir(from_path)
    let d.lastpath = from_path  " Save lastpath when navigating _up_.
  endif

  call s:save_state(d)
  call s:do_open(d, reloading)
endfunction

nnoremap <silent> <Plug>(dirvish_quit) :<C-U>call <SID>buf_close()<CR>
nnoremap <silent> <Plug>(dirvish_arg) :<C-U>call <SID>set_args([getline('.')])<CR>
xnoremap <silent> <Plug>(dirvish_arg) :<C-U>call <SID>set_args(getline("'<", "'>"))<CR>
