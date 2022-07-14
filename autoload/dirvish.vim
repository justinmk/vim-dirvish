let s:srcdir = expand('<sfile>:h:h:p')
let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:noswapfile = (2 == exists(':noswapfile')) ? 'noswapfile' : ''
let s:noau       = 'silent noautocmd keepjumps'
let s:cb_map = {}   " callback map
let s:rel = get(g:, 'dirvish_relative_paths', 0)

" Debug:
"     echo '' > dirvish.log ; tail -F dirvish.log
"     nvim +"let g:dirvish_dbg=1" -- b1 b2
"     :bnext
"     -
if get(g:, 'dirvish_dbg')
  func! s:log(msg, ...) abort
    call writefile([a:msg], expand('~/dirvish.log'), 'as')
  endf
else
  func! s:log(msg, ...) abort
  endf
endif

func! s:msg_error(msg) abort
  redraw | echohl ErrorMsg | echomsg 'dirvish:' a:msg | echohl None
endf

func! s:eq(dir1, dir2) abort
  return fnamemodify(a:dir1, ':p') ==# fnamemodify(a:dir2, ':p')
endf

" Gets full path, or relative if g:dirvish_relative_paths=1.
func! s:f(f) abort
  let f = fnamemodify(a:f, s:rel ? ':p:.' : ':p')
  " Special case: ":p:." yields empty for CWD.
  return !empty(f) ? f : fnamemodify(a:f, ':p')
endf

func! s:suf() abort
  let m = get(g:, 'dirvish_mode', 1)
  return type(m) == type(0) && m <= 1 ? 1 : 0
endf

" Normalizes slashes:
" - Replace "\" with "/", for safe use of fnameescape(), isdirectory(). Vim bug #541.
" - Collapse slashes (except UNC-style \\foo\bar).
" - Always end dir with "/".
" - Special case: empty string (CWD) => "./".
func! s:sl(f) abort
  let f = has('win32') ? tr(a:f, '\', '/') : a:f
  " Collapse slashes (except UNC-style \\foo\bar).
  let f = f[0] . substitute(f[1:], '/\+', '/', 'g')
  " End with separator.
  return empty(f) ? './' : (f[-1:] !=# '/' && isdirectory(f) ? f.'/' : f)
endf

" Workaround for platform quirks, and shows an error if dir is invalid.
func! s:fix_dir(dir, silent) abort
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
  return dir
endf

func! s:parent_dir(f) abort
  let f_noslash = substitute(a:f, escape(s:sep == '\'?'[/\]':'/','\').'\+$', '', 'g')
  return s:fix_dir(fnamemodify(f_noslash, ':h'), 0)
endf

if v:version > 704 || v:version == 704 && has('patch279')
func! s:globlist(dir_esc, pat) abort
  return globpath(a:dir_esc, a:pat, !s:suf(), 1)
endf
else " Older versions cannot handle filenames containing newlines.
func! s:globlist(dir_esc, pat) abort
  return split(globpath(a:dir_esc, a:pat, !s:suf()), "\n")
endf
endif

func! s:list_dir(dir) abort
  let s:rel = get(g:, 'dirvish_relative_paths', 0)
  " Escape for globpath().
  let dir_esc = escape(substitute(a:dir,'\[','[[]','g'), ',;*?{}^$\')
  let paths = s:globlist(dir_esc, '*')
  "Append dot-prefixed files. globpath() cannot do both in 1 pass.
  let paths = paths + s:globlist(dir_esc, '.[^.]*')

  if s:rel && !s:eq(a:dir, s:parent_dir(s:sl(getcwd())))  " Avoid blank CWD.
    return map(paths, "fnamemodify(v:val, ':p:.')")
  else
    return map(paths, "fnamemodify(v:val, ':p')")
  endif
endf

func! s:info(paths, dirsize) abort
  for f in a:paths
    " Slash decides how getftype() classifies directory symlinks. #138
    let noslash = substitute(f, escape(s:sep,'\').'$', '', 'g')
    let fname = len(a:paths) < 2 ? '' : printf('%12.12s ',fnamemodify(substitute(f,'[\\/]\+$','',''),':t'))
    let size = (-1 != getfsize(f) && a:dirsize ? matchstr(system('du -hs '.shellescape(f)),'\S\+') : printf('%.2f',getfsize(f)/1000.0).'K')
    echo (-1 == getfsize(f) ? '?' : (fname.(getftype(noslash)[0]).' '.getfperm(f)
          \.' '.strftime('%Y-%m-%d.%H:%M:%S',getftime(f)).' '.size).('link'!=#getftype(noslash)?'':' -> '.fnamemodify(resolve(f),':~:.')))
  endfor
endf

func! s:set_args(args) abort
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
endf

func! dirvish#shdo(paths, cmd) abort
  " Remove empty/duplicate lines.
  let lines = uniq(sort(filter(copy(a:paths), '-1!=match(v:val,"\\S")')))
  let head = fnamemodify(get(lines, 0, '')[:-2], ':h')
  let jagged = 0 != len(filter(copy(lines), 'head != fnamemodify(v:val[:-2], ":h")'))
  if empty(lines) | call s:msg_error('Shdo: no files') | return | endif

  let dirvish_bufnr = bufnr('%')
  let cmd = a:cmd =~# '\V{}' ? a:cmd : (empty(a:cmd)?'{}':(a:cmd.' {}')) "DWIM
  " Paths from argv() or non-dirvish buffers may be jagged; assume CWD then.
  let dir = jagged ? getcwd() : head
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
      \.'|setlocal bufhidden=hide|buffer '.dirvish_bufnr.'|silent! Dirvish'
      \.'|buffer '.bufnr('%').'|setlocal bufhidden=wipe|endif'
  augroup END

  nnoremap <buffer><silent> Z! :silent write<Bar>exe '!'.(has('win32')?fnameescape(escape(expand('%:p:gs?\\?/?'), '&\')):join(map(split(&shell), 'shellescape(v:val)')).' %')<Bar>if !v:shell_error<Bar>close<Bar>endif<CR>
endf

" Returns true if the buffer was modified by the user.
func! s:buf_modified() abort
  return b:changedtick > get(b:dirvish, '_c', b:changedtick)
endf

func! s:buf_init() abort
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
endf

func! s:on_bufenter() abort
  if bufname('%') is ''  " Something is very wrong. #136
    return
  elseif !exists('b:dirvish') || (empty(getline(1)) && 1 == line('$'))
    Dirvish
  elseif 3 != &l:conceallevel && !s:buf_modified()
    call s:win_init()
  else
    " Ensure w:dirvish for window splits, `:b <nr>`, etc.
    let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')
  endif
endf

func! s:save_state(d) abort
  " Remember previous ('original') buffer.
  let p = s:buf_valid(bufnr('%')) || !exists('w:dirvish') ? 0+bufnr('%') : w:dirvish.prevbuf
  if !s:buf_valid(p)
    "If reached via :edit/:buffer/etc. we cannot get the (former) altbuf.
    let p = exists('b:dirvish') && s:buf_valid(b:dirvish.prevbuf) ? b:dirvish.prevbuf : bufnr('#')
  endif

  " Remember alternate buffer.
  let a = (p != bufnr('#') && s:buf_valid(bufnr('#'))) || !exists('w:dirvish') ? 0+bufnr('#') : w:dirvish.altbuf
  if !s:buf_valid(a) || a == p
    let a = exists('b:dirvish') && s:buf_valid(b:dirvish.altbuf) ? b:dirvish.altbuf : -1
  endif

  " Save window-local settings.
  let a:d.altbuf = a
  let a:d.prevbuf = p
  let w:dirvish = extend(get(w:, 'dirvish', {}), a:d, 'force')
  let [w:dirvish._w_wrap, w:dirvish._w_cul] = [&l:wrap, &l:cul]
  if has('conceal') && !exists('b:dirvish')
    let [w:dirvish._w_cocu, w:dirvish._w_cole] = [&l:concealcursor, &l:conceallevel]
  endif

  call s:log(printf('save_state: bufnr=%d altbuf=%d prevbuf=%d', bufnr(''), a:d.altbuf, a:d.prevbuf))
endf

func! s:win_init() abort
  let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'keep')
  setlocal nowrap cursorline

  if has('conceal')
    setlocal concealcursor=nvc conceallevel=2
  endif
endf

func! s:on_bufunload() abort
  call s:restore_winlocal_settings()
endf

func! s:buf_close() abort
  let d = get(w:, 'dirvish', {})
  if empty(d)
    return
  endif

  let [altbuf, prevbuf] = [get(d, 'altbuf', 0), get(d, 'prevbuf', 0)]
  call s:log(printf('buf_close: bufnr=%d altbuf=%d prevbuf=%d', bufnr(''), altbuf, prevbuf))
  let found_alt = s:try_visit(altbuf, 0)
  if !s:try_visit(prevbuf, 0) && !found_alt
      \ && (1 == bufnr('%') || (prevbuf != bufnr('%') && altbuf != bufnr('%')))
    bdelete
  endif
endf

func! s:restore_winlocal_settings() abort
  if !exists('w:dirvish') " can happen during VimLeave, etc.
    return
  endif
  if has('conceal') && has_key(w:dirvish, '_w_cocu')
    let [&l:cocu, &l:cole] = [w:dirvish._w_cocu, w:dirvish._w_cole]
  endif
endf

func! s:open_selected(splitcmd, bg, line1, line2) abort
  let curbuf = bufnr('%')
  let [curtab, curwin, wincount] = [tabpagenr(), winnr(), winnr('$')]
  let p = (a:splitcmd ==# 'p')  " Preview-mode

  let paths = getline(a:line1, a:line2)
  for path in paths
    let isdir = path[-1:] == s:sep
    if !isdirectory(path) && !filereadable(path)
      call s:msg_error(printf('invalid (access denied?): %s', path))
      continue
    endif
    " Open files (not dirs) using relative paths.
    let shortname = fnamemodify(path, isdir ? ':p:~' : ':~:.')

    if p  " Go to previous window.
      exe (winnr('$') > 1 ? 'wincmd p|if winnr()=='.winnr().'|wincmd w|endif' : 'vsplit')
    endif

    if isdir
      exe (p || a:splitcmd ==# 'edit' ? '' : a:splitcmd.'|') 'Dirvish' fnameescape(shortname)
    else
      exe (p ? 'edit' : a:splitcmd) fnameescape(shortname)
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
endf

func! s:set_altbuf(bnr) abort
  if !s:buf_valid(a:bnr) | return | endif

  if has('patch-7.4.605') | let @# = a:bnr | return | endif

  let curbuf = bufnr('%')
  if s:try_visit(a:bnr, 1)
    let noau = bufloaded(curbuf) ? 'noau' : ''
    " Return to the current buffer.
    execute 'silent keepjumps' noau s:noswapfile 'buffer' curbuf
  endif
endf

func! s:try_visit(bnr, noau) abort
  if s:buf_valid(a:bnr)
    " If _previous_ buffer is _not_ loaded (because of 'nohidden'), we must
    " allow autocmds (else no syntax highlighting; #13).
    let noau = a:noau && bufloaded(a:bnr) ? 'noau' : ''
    execute 'silent keepjumps' noau s:noswapfile 'buffer' a:bnr
    return 1
  endif
  return 0
endf

if exists('*win_execute')
  " Performs `cmd` in all windows showing `bnr`.
  func! s:bufwin_do(cmd, bnr) abort
    call map(filter(getwininfo(), {_,v -> a:bnr ==# v.bufnr}), {_,v -> win_execute(v.winid, s:noau.' '.a:cmd)})
  endf
else
  func! s:tab_win_do(tnr, cmd, bnr) abort
    exe s:noau 'tabnext' a:tnr
    for wnr in range(1, tabpagewinnr(a:tnr, '$'))
      if a:bnr ==# winbufnr(wnr)
        exe s:noau wnr.'wincmd w'
        exe a:cmd
      endif
    endfor
  endf

  func! s:bufwin_do(cmd, bnr) abort
    let [curtab, curwin, curwinalt, curheight, curwidth, squashcmds] = [tabpagenr(), winnr(), winnr('#'), winheight(0), winwidth(0), filter(split(winrestcmd(), '|'), 'v:val =~# " 0$"')]
    for tnr in range(1, tabpagenr('$'))
      let [origwin, origwinalt] = [tabpagewinnr(tnr), tabpagewinnr(tnr, '#')]
      for bnr in tabpagebuflist(tnr)
        if a:bnr == bnr
          call s:tab_win_do(tnr, a:cmd, a:bnr)
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
  endf
endif

func! s:buf_render(dir, lastpath) abort
  let bnr = bufnr('%')
  let isnew = empty(getline(1))

  if !isdirectory(a:dir)
    echoerr 'dirvish: not a directory:' a:dir
    return
  endif

  if !isnew
    call s:bufwin_do('let w:dirvish["_view"] = winsaveview()', bnr)
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
    call s:bufwin_do('call winrestview(w:dirvish["_view"])', bnr)
  endif

  if !empty(a:lastpath)
    let pat = tr(s:f(a:lastpath), '/', s:sep)  " platform slashes
    call search('\V\^'.escape(pat, '\').'\$', 'cw')
  endif
  " Place cursor on the tail (last path segment).
  call search('\'.s:sep.'\zs[^\'.s:sep.']\+\'.s:sep.'\?$', 'c', line('.'))
endf

func! s:apply_icons() abort
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
      let f = substitute(s:f(f), escape(s:sep,'\').'$', '', 'g')  " Full path, trim slash.
      let tail_esc = escape(fnamemodify(f,':t').(isdir?(s:sep):''), '[,*.^$~\')
      exe 'syntax match DirvishColumnHead =^.\{-}\ze'.tail_esc.'$= conceal cchar='.icon
    endif
  endfor
endf

let s:recursive = ''
func! s:open_dir(d, reload) abort
  if s:recursive ==# a:d._dir
    return
  endif
  let s:recursive = a:d._dir
  call s:log(printf('open_dir ENTER: %d %s', bufnr('%'), a:d._dir))
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

  " Note: :noautocmd not used here, to allow BufEnter/BufNew. 61282f2453af
  " Thus s:recursive guards against recursion (for performance).
  if -1 == bnr
    execute 'silent' s:noswapfile 'keepalt edit' fnameescape(d._dir)
  else
    execute 'silent' s:noswapfile 'buffer' bnr
  endif

  " Force a normalized directory path.
  " - Starts with "~/" or "/", ie absolute (important for ":h").
  " - Ends with "/".
  " - Avoids ".././..", ".", "./", etc. (breaks %:p, not updated on :cd).
  " - Avoids [Scratch] in some cases (":e ~/" on Windows).
  if bufname('%')[-1:] != '/' ||  bufname('%')[0:1] !=# d._dir[0:1]
    execute 'silent' s:noswapfile 'file' fnameescape(d._dir)
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
  let s:recursive = ''
  call s:log(printf('open_dir EXIT : %d %s', bufnr('%'), a:d._dir))
endf

func! s:should_reload() abort
  return !s:buf_modified() || (empty(getline(1)) && 1 == line('$'))
endf

func! s:buf_valid(bnr) abort
  return bufexists(a:bnr) && (empty(bufname(a:bnr)) || !isdirectory(s:sl(bufname(a:bnr))))
endf

func! dirvish#open(...) range abort
  if &autochdir
    call s:msg_error("'autochdir' is not supported")
    return
  endif
  if (&bufhidden =~# '\vunload|delete|wipe' || (!&autowriteall && !&hidden && &modified))
      \ && (!exists("*win_findbuf") || len(win_findbuf(winbufnr(0))) == 1)
    call s:msg_error(&modified ? 'E37: No write since last change' : 'E37: Buffer would be deleted')
    return
  endif

  if a:0 > 1
    call s:open_selected(a:1, a:2, a:firstline, a:lastline)
    return
  endif

  let d = {}
  let is_uri    = -1 != match(a:1, '^\w\+:[\/][\/]')
  let from_path = s:sl(fnamemodify(bufname('%'), ':p'))
  let to_path   = s:sl(fnamemodify(!empty(a:1) || empty(@%) ? a:1 : @%, ':p'))

  let d._dir = s:fix_dir(filereadable(to_path) ? fnamemodify(to_path, ':p:h') : to_path, is_uri)
  " Fallback to CWD for URIs. #127
  let d._dir = empty(d._dir) && is_uri ? s:fix_dir(getcwd(), is_uri) : d._dir
  if empty(d._dir)  " s:fix_dir() already showed error.
    return
  endif

  let reloading = exists('b:dirvish') && d._dir ==# b:dirvish._dir && s:recursive !=# d._dir

  if reloading
    let d.lastpath = ''         " Do not place cursor when reloading.
  elseif !is_uri && s:eq(d._dir, s:parent_dir(from_path))
    let d.lastpath = from_path  " Save lastpath when navigating _up_.
  endif

  call s:save_state(d)
  call s:open_dir(d, reloading)
endf

func! dirvish#add_icon_fn(fn) abort
  if !exists('v:t_func') || type(a:fn) != v:t_func | throw 'argument must be a Funcref' | endif
  let s:cb_map[string(a:fn)] = a:fn
  return string(a:fn)
endf

func! dirvish#remove_icon_fn(fn_id) abort
  if has_key(s:cb_map, a:fn_id)
    call remove(s:cb_map, a:fn_id)
    return 1
  endif
  return 0
endf

nnoremap <silent> <Plug>(dirvish_quit) :<C-U>call <SID>buf_close()<CR>
nnoremap <silent> <Plug>(dirvish_arg) :<C-U>call <SID>set_args([getline('.')])<CR>
xnoremap <silent> <Plug>(dirvish_arg) :<C-U>call <SID>set_args(getline("'<", "'>"))<CR>
nnoremap <silent> <Plug>(dirvish_K) :<C-U>call <SID>info([getline('.')],!!v:count)<CR>
xnoremap <silent> <Plug>(dirvish_K) :<C-U>call <SID>info(getline("'<", "'>"),!!v:count)<CR>
