let s:srcdir = expand('<sfile>:h:h:p')
let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:noswapfile = (2 == exists(':noswapfile')) ? 'noswapfile' : ''
let s:noau       = 'silent noautocmd keepjumps'
let s:cb_map = {}   " callback map

function! s:msg_error(msg) abort
  redraw | echohl ErrorMsg | echomsg 'dirvish:' a:msg | echohl None
endfunction

function! s:suf() abort
  let m = get(g:, 'dirvish_mode', 1)
  return type(m) == type(0) && m <= 1 ? 1 : 0
endfunction

" Normalize slashes for safe use of fnameescape(), isdirectory(). Vim bug #541.
function! s:sl(path) abort
  return has('win32') ? tr(a:path, '\', '/') : a:path
endfunction

function! s:normalize_dir(dir, silent) abort
  let dir = s:sl(a:dir)
  if !isdirectory(dir)
    " Fallback for cygwin/MSYS paths lacking a drive letter.
    let dir = empty($SYSTEMDRIVE) ? dir : '/'.tolower($SYSTEMDRIVE[0]).(dir)
    if !isdirectory(dir)
      if !a:silent
        call s:msg_error("invalid directory: '".a:dir."'")
      endif
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
  return s:normalize_dir(fnamemodify(a:dir, mod), 0)
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

function! s:list_dir(dir) abort
  " Escape for glob().
  let dir_esc = escape(substitute(a:dir,'\[','[[]','g'),'{}')
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

function! s:info(paths, dirsize) abort
  for f in a:paths
    " Slash decides how getftype() classifies directory symlinks. #138
    let noslash = substitute(f, escape(s:sep,'\').'$', '', 'g')
    let fname = len(a:paths) < 2 ? '' : printf('%12.12s ',fnamemodify(substitute(f,'[\\/]\+$','',''),':t'))
    let size = (-1 != getfsize(f) && a:dirsize ? matchstr(system(['du','-hs',f]),'\S\+') : printf('%.2f',getfsize(f)/1000.0).'K')
    echo (-1 == getfsize(f) ? '?' : (fname.(getftype(noslash)[0]).' '.getfperm(f)
          \.' '.strftime('%Y-%m-%d.%H:%M:%S',getftime(f)).' '.size).('link'!=#getftype(noslash)?'':' -> '.fnamemodify(resolve(f),':~:.')))
  endfor
endfunction

function! s:set_args(args) abort
  if exists('*arglistid') && arglistid() == 0
    arglocal
  endif
  let normalized_argv = map(argv(), 'fnamemodify(v:val, ":p")')
  for f in a:args
    let i = index(normalized_argv, f)
    if -1 == i
      exe '$argadd '.fnameescape(fnamemodify(f, ':p'))
    elseif 1 == len(a:args)
      exe (i+1).'argdelete'
      syntax clear DirvishArg
    endif
  endfor
  echo 'arglist: '.argc().' files'

  " Define (again) DirvishArg syntax group.
  exe 'source '.fnameescape(s:srcdir.'/syntax/dirvish.vim')
endfunction

function! dirvish#shdo(paths, cmd) abort
  " Remove empty/duplicate lines.
  let lines = uniq(sort(filter(copy(a:paths), '-1!=match(v:val,"\\S")')))
  let head = fnamemodify(get(lines, 0, '')[:-2], ':h')
  let jagged = 0 != len(filter(copy(lines), 'head != fnamemodify(v:val[:-2], ":h")'))
  if empty(lines) | call s:msg_error('Shdo: no files') | return | endif

  let dirvish_bufnr = bufnr('%')
  let cmd = a:cmd =~# '\V{}' ? a:cmd : (empty(a:cmd)?'{}':(a:cmd.' {}')) "DWIM
  " Paths from argv() or non-dirvish buffers may be jagged; assume CWD then.
  let dir = !jagged && exists('b:dirvish') ? b:dirvish._dir : getcwd()
  let tmpfile = tempname().(&sh=~?'cmd.exe'?'.bat':(&sh=~'\(powershell\|pwsh\)'?'.ps1':'.sh'))

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

  nnoremap <buffer><silent> Z! :silent write<Bar>exe '!'.(has('win32')?fnameescape(escape(expand('%:p:gs?\\?/?'), '&\')):shellescape(&shell).' %')<Bar>if !v:shell_error<Bar>close<Bar>endif<CR>
endfunction

" Returns true if the buffer was modified by the user.
function! s:buf_modified() abort
  return b:changedtick > get(b:dirvish, '_c', b:changedtick)
endfunction

function! s:buf_init() abort
  augroup dirvish_buflocal
    autocmd! * <buffer>
    autocmd BufEnter,WinEnter <buffer> call <SID>on_bufenter()
    if exists('##TextChanged')
      autocmd TextChanged,TextChangedI <buffer> if <SID>buf_modified()
            \&& has('conceal')|exe 'setlocal conceallevel=0'|endif
    endif

    " BufUnload is fired for :bwipeout/:bdelete/:bunload, _even_ if
    " 'nobuflisted'. BufDelete is _not_ fired if 'nobuflisted'.
    " NOTE: For 'nohidden' we cannot reliably handle :bdelete like this.
    if &hidden
      autocmd BufUnload <buffer> call s:on_bufunload()
    endif
  augroup END

  setlocal buftype=nofile noswapfile
endfunction

function! s:on_bufenter() abort
  if bufname('%') is ''  " Something is very wrong. #136
    return
  elseif !exists('b:dirvish') || (empty(getline(1)) && 1 == line('$'))
    Dirvish %
  elseif 3 != &l:conceallevel && !s:buf_modified()
    call s:win_init()
  else
    " Ensure w:dirvish for window splits, `:b <nr>`, etc.
    let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')
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
  let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')
  setlocal nowrap cursorline

  if has('conceal')
    setlocal concealcursor=nvc conceallevel=2
  endif
endfunction

function! s:on_bufunload() abort
  call s:restore_winlocal_settings()
endfunction

function! s:buf_close() abort
  let d = get(w:, 'dirvish', {})
  if empty(d)
    return
  endif

  let [altbuf, prevbuf] = [get(d, 'altbuf', 0), get(d, 'prevbuf', 0)]
  let found_alt = s:try_visit(altbuf, 1)
  if !s:try_visit(prevbuf, 0) && !found_alt
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

function! s:open_selected(splitcmd, bg, line1, line2) abort
  let curbuf = bufnr('%')
  let [curtab, curwin, wincount] = [tabpagenr(), winnr(), winnr('$')]
  let p = (a:splitcmd ==# 'p')  " Preview-mode

  let paths = getline(a:line1, a:line2)
  for path in paths
    let path = s:sl(path)
    if !isdirectory(path) && !filereadable(path)
      call s:msg_error("invalid (access denied?): ".path)
      continue
    endif

    if p  " Go to previous window.
      exe (winnr('$') > 1 ? 'wincmd p|if winnr()=='.winnr().'|wincmd w|endif' : 'vsplit')
    endif

    if isdirectory(path)
      exe (p || a:splitcmd ==# 'edit' ? '' : a:splitcmd.'|') 'Dirvish' fnameescape(path)
    else
      exe (p ? 'edit' : a:splitcmd) fnameescape(path)
    endif

    " Return to previous window after _each_ split, else we get lost.
    if a:bg && (p || (a:splitcmd =~# 'sp' && winnr('$') > wincount))
      wincmd p
    endif
  endfor

  if a:bg "return to dirvish buffer
    if a:splitcmd ==# 'tabedit'
      exe 'tabnext' curtab '|' curwin.'wincmd w'
    elseif a:splitcmd ==# 'edit'
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
  if s:try_visit(a:bnr, 1)
    let noau = bufloaded(curbuf) ? 'noau' : ''
    " Return to the current buffer.
    execute 'silent keepjumps' noau s:noswapfile 'buffer' curbuf
  endif
endfunction

function! s:try_visit(bnr, noau) abort
  if s:is_valid_altbuf(a:bnr)
    " If _previous_ buffer is _not_ loaded (because of 'nohidden'), we must
    " allow autocmds (else no syntax highlighting; #13).
    let noau = a:noau && bufloaded(a:bnr) ? 'noau' : ''
    execute 'silent keepjumps' noau s:noswapfile 'buffer' a:bnr
    return 1
  endif
  return 0
endfunction

if exists('*win_execute')
  " Performs `cmd` in all windows showing `bname`.
  function! s:bufwin_do(cmd, bname) abort
    call map(filter(getwininfo(), {_,v -> a:bname ==# bufname(v.bufnr)}), {_,v -> win_execute(v.winid, s:noau.' '.a:cmd)})
  endfunction
else
  function! s:tab_win_do(tnr, cmd, bname) abort
    exe s:noau 'tabnext' a:tnr
    for wnr in range(1, tabpagewinnr(a:tnr, '$'))
      if a:bname ==# bufname(winbufnr(wnr))
        exe s:noau wnr.'wincmd w'
        exe a:cmd
      endif
    endfor
  endfunction

  function! s:bufwin_do(cmd, bname) abort
    let [curtab, curwin, curwinalt, curheight, curwidth, squashcmds] = [tabpagenr(), winnr(), winnr('#'), winheight(0), winwidth(0), filter(split(winrestcmd(), '|'), 'v:val =~# " 0$"')]
    for tnr in range(1, tabpagenr('$'))
      let [origwin, origwinalt] = [tabpagewinnr(tnr), tabpagewinnr(tnr, '#')]
      for bnr in tabpagebuflist(tnr)
        if a:bname ==# bufname(bnr)
          call s:tab_win_do(tnr, a:cmd, a:bname)
          exe s:noau origwinalt.'wincmd w|' s:noau origwin.'wincmd w'
          break
        endif
      endfor
    endfor
    exe s:noau 'tabnext '.curtab
    exe s:noau curwinalt.'wincmd w|' s:noau curwin.'wincmd w'
    if (&winminheight == 0 && curheight != winheight(0)) || (&winminwidth == 0 && curwidth != winwidth(0))
      for squashcmd in squashcmds
        if squashcmd =~# '^\Cvert ' && winwidth(matchstr('\d\+', squashcmd)) != 0
          \ || squashcmd =~# '^\d' && winheight(matchstr('\d\+', squashcmd)) != 0
          exe s:noau squashcmd
        endif
      endfor
    endif
  endfunction
endif

function! s:buf_render(dir, lastpath) abort
  let bname = bufname('%')
  let isnew = empty(getline(1))

  if !isdirectory(s:sl(bname))
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

function! s:apply_icons() abort
  if 0 == len(s:cb_map)
    return
  endif
  highlight clear Conceal
  for f in getline(1, '$')
    let icon = ''
    for id in sort(keys(s:cb_map))
      let icon = s:cb_map[id](f)
      if -1 != match(icon, '\S')
        break
      endif
    endfor
    if icon != ''
      let isdir = (f[-1:] == s:sep)
      let f = substitute(fnamemodify(f,':p'), escape(s:sep,'\').'$', '', 'g')  " Full path, trim slash.
      let head_esc = escape(fnamemodify(f,':h').(fnamemodify(f,':h')==s:sep?'':s:sep), '[,*.^$~\')
      let tail_esc = escape(fnamemodify(f, ':t').(isdir?(s:sep):''), '[,*.^$~\')
      exe 'syntax match DirvishColumnHead =^'.head_esc.'\ze'.tail_esc.'$= conceal cchar='.icon
    endif
  endfor
endfunction

function! s:open_dir(d, reload) abort
  let d = a:d
  let dirname_without_sep = substitute(d._dir, '[\\/]\+$', '', 'g')

  " Vim tends to 'simplify' buffer names. Examples (gvim 7.4.618):
  "     ~\foo\, ~\foo, foo\, foo
  " Try to find an existing buffer before creating a new one.
  let bnr = -1
  for pat in ['', ':~:.', ':~']
    let dir = fnamemodify(d._dir, pat)
    if dir == '' | continue | endif
    let bnr = bufnr('^'.dir.'$')
    if -1 != bnr
      break
    endif
  endfor

  if -1 == bnr
    execute 'silent' s:noswapfile 'edit' fnameescape(d._dir)
  else
    execute 'silent' s:noswapfile 'buffer' bnr
  endif

  " Use :file to force a normalized path.
  " - Avoids ".././..", ".", "./", etc. (breaks %:p, not updated on :cd).
  " - Avoids [Scratch] in some cases (":e ~/" on Windows).
  if s:sl(bufname('%')) !=# d._dir
    execute 'silent '.s:noswapfile.' file ' . fnameescape(d._dir)
  endif

  if !isdirectory(bufname('%'))  " sanity check
    throw 'invalid directory: '.bufname('%')
  endif

  if &buflisted && bufnr('$') > 1
    setlocal nobuflisted
  endif

  call s:set_altbuf(d.prevbuf) "in case of :bd, :read#, etc.

  let b:dirvish = exists('b:dirvish') ? extend(b:dirvish, d, 'force') : d

  call s:buf_init()
  call s:win_init()
  if a:reload || s:should_reload()
    call s:buf_render(b:dirvish._dir, get(b:dirvish, 'lastpath', ''))
    " Set up Dirvish before any other `FileType dirvish` handler.
    exe 'source '.fnameescape(s:srcdir.'/ftplugin/dirvish.vim')
    let curwin = winnr()
    setlocal filetype=dirvish
    if curwin != winnr() | throw 'FileType autocmd changed the window' | endif
    let b:dirvish._c = b:changedtick
    call s:apply_icons()
  endif
endfunction

function! s:should_reload() abort
  return !s:buf_modified() || (empty(getline(1)) && 1 == line('$'))
endfunction

function! s:buf_isvalid(bnr) abort
  return bufexists(a:bnr) && !isdirectory(s:sl(bufname(a:bnr)))
endfunction

function! dirvish#open(...) range abort
  if &autochdir
    call s:msg_error("'autochdir' is not supported")
    return
  endif
  if !&autowriteall && !&hidden && &modified
      \ && (!exists("*win_findbuf") || len(win_findbuf(winbufnr(0))) == 1)
    call s:msg_error("E37: No write since last change")
    return
  endif

  if a:0 > 1
    call s:open_selected(a:1, a:2, a:firstline, a:lastline)
    return
  endif

  let d = {}
  let is_uri    = -1 != match(a:1, '^\w\+:[\/][\/]')
  let from_path = fnamemodify(bufname('%'), ':p')
  let to_path   = fnamemodify(s:sl(a:1), ':p')
  "                                       ^resolves to CWD if a:1 is empty

  let d._dir = filereadable(to_path) ? fnamemodify(to_path, ':p:h') : to_path
  let d._dir = s:normalize_dir(d._dir, is_uri)
  " Fallback to CWD for URIs. #127
  let d._dir = empty(d._dir) && is_uri ? s:normalize_dir(getcwd(), is_uri) : d._dir
  if empty(d._dir)  " s:normalize_dir() already showed error.
    return
  endif

  let reloading = exists('b:dirvish') && d._dir ==# b:dirvish._dir

  if reloading
    let d.lastpath = ''         " Do not place cursor when reloading.
  elseif !is_uri && d._dir ==# s:parent_dir(from_path)
    let d.lastpath = from_path  " Save lastpath when navigating _up_.
  endif

  call s:save_state(d)
  call s:open_dir(d, reloading)
endfunction

function! dirvish#add_icon_fn(fn) abort
  if !exists('v:t_func') || type(a:fn) != v:t_func | throw 'argument must be a Funcref' | endif
  let s:cb_map[string(a:fn)] = a:fn
  return string(a:fn)
endfunction

function! dirvish#remove_icon_fn(fn_id) abort
  if has_key(s:cb_map, a:fn_id)
    call remove(s:cb_map, a:fn_id)
    return 1
  endif
  return 0
endfunction

nnoremap <silent> <Plug>(dirvish_quit) :<C-U>call <SID>buf_close()<CR>
nnoremap <silent> <Plug>(dirvish_arg) :<C-U>call <SID>set_args([getline('.')])<CR>
xnoremap <silent> <Plug>(dirvish_arg) :<C-U>call <SID>set_args(getline("'<", "'>"))<CR>
nnoremap <silent> <Plug>(dirvish_K) :<C-U>call <SID>info([getline('.')],!!v:count)<CR>
xnoremap <silent> <Plug>(dirvish_K) :<C-U>call <SID>info(getline("'<", "'>"),!!v:count)<CR>
