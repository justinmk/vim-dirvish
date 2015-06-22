" Copyright 2014 Jeet Sukumaran.
" Modified by Justin M. Keyes.
"
" This program is free software; you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation; either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License <http://www.gnu.org/licenses/>
" for more details.
"
" Things that are unnecessary when you set the buffer name:
" - let &titlestring = expand(self.dir, 1)
" - specialized 'cd', 'cl'
"
" Things that are unnecessary when you conceal the full file paths:
" - specialized "yank" commands
" - specialized "read" commands (instead: yy and :r ...)
" - imitation CTRL-W_... mappings
"
" Fixed bug: 'buffer <num>' may open buffer with actual number name.

let s:sep = has("win32") ? '\' : '/'
let s:noswapfile = (2 == exists(':noswapfile')) ? 'noswapfile' : ''

function! s:new_notifier()
  let m = {}

  function! m.format(msg) dict
    return "dirvish: ".a:msg
  endfunction
  function! m.error(msg) dict
    redraw
    echohl ErrorMsg | echomsg self.format(a:msg) | echohl None
  endfunction
  function! m.warn(msg) dict
    redraw
    echohl WarningMsg | echomsg self.format(a:msg) | echohl None
  endfunction
  function! m.info(msg) dict
    redraw
    echohl None | echo self.format(a:msg)
  endfunction

  return m
endfunction

function! s:normalize_dir(dir)
  if !isdirectory(a:dir)
    echoerr 'not a directory:' a:dir
    return
  endif
  let dir = fnamemodify(a:dir, ':p') "always full path
  let dir = substitute(a:dir, s:sep.'\+', s:sep, 'g') "replace consecutive slashes
  if dir[-1:] !~# '[\/]' "always end with separator
    return dir . s:sep
  endif
  return dir
endfunction

function! s:parent_dir(dir)
  if !isdirectory(a:dir)
    echoerr 'not a directory:' a:dir
    return
  endif
  return s:normalize_dir(fnamemodify(a:dir, ":p:h:h"))
endfunction

function! s:sort_paths(p1, p2)
  let isdir1 = (a:p1[-1:] ==# s:sep) "3x faster than isdirectory().
  let isdir2 = (a:p2[-1:] ==# s:sep)
  if isdir1 && !isdir2
    return -1
  elseif !isdir1 && isdir2
    return 1
  endif
  return a:p1 ==# a:p2 ? 0 : a:p1 ># a:p2 ? 1 : -1
endfunction

function! s:discover_paths(current_dir, glob_pattern, showhidden)
  let curdir = s:normalize_dir(a:current_dir)
  let paths = glob(curdir.a:glob_pattern, 1, 1)
  let paths = paths + (a:showhidden ? glob(curdir.'.[^.]'.a:glob_pattern, 1, 1) : [])

  if get(g:, 'dirvish_relative_paths', 0)
        \ && curdir != s:parent_dir(getcwd()) "avoid blank line for cwd
    return sort(map(paths, "fnamemodify(v:val, ':.')"), '<sid>sort_paths')
  else
    return sort(map(paths, "fnamemodify(v:val, ':p')"), '<sid>sort_paths')
  endif
endfunction

function! s:new_dirvish()
  let l:obj = { 'altbuf': -1, 'prevbuf': -1, 'showhidden': 0 }

  function! l:obj.open_dir(...) abort dict
    let d = self

    if a:0 > 0
      let d.dir = s:normalize_dir(a:1)  " full path to the directory
      let d.is_filtered = a:2           " if truthy, apply `filter_exp`
      let d.filter_exp = a:3            " :g// filter
    endif

    let bnr = bufnr('^' . d.dir . '$')

    " Vim tends to name the directory buffer using its relative path.
    " Examples (observed on Win32 gvim 7.4.618):
    "     ~\AppData\Local\Temp\
    "     ~\AppData\Local\Temp
    "     AppData\Local\Temp\
    "     AppData\Local\Temp
    " Try to find the existing relative-path name before creating a new one.
    for pat in [':~:.', ':~']
      if -1 != bnr
        break
      endif

      let modified_dirname = fnamemodify(d.dir, pat)
      let modified_dirname_without_sep = substitute(modified_dirname, '[\\/]\+$', '', 'g')

      let bnr = bufnr('^'.modified_dirname.'$')
      if -1 == bnr
        let bnr = bufnr('^'.modified_dirname_without_sep.'$')
      endif
    endfor

    try
      if -1 == bnr
        execute 'silent noau keepjumps '.s:noswapfile.' edit ' . fnameescape(d.dir)
      else
        execute 'silent noau keepjumps '.s:noswapfile.' '.bnr.'buffer'
      endif
    catch /E37:/
      call s:notifier.error("E37: No write since last change")
      return
    endtry

    "HACK: If the directory was visited via an alias like '.', '..',
    "      'foo/../..', then Vim refuses to create a buffer with the expanded
    "      name even though we told it to in our :edit command above--instead,
    "      Vim resolves to the aliased name. We _could_ rename to the
    "      fully-expanded path via :file, but instead we just update our state
    "      to match Vim's preferred buffer name, because:
    "         - it avoids an extra buffer
    "         - it avoids incrementing the buffer number
    "         - it avoids a spurious *alternate* buffer
    if bufname('%') !=# d.dir
      if isdirectory(bufname('%'))
        " Just use the name Vim wants (avoid incrementing the buffer number).
        let d.dir = bufname('%')
      else " [This should never happen] Rename to the fully-expanded path.
        execute 'silent noau keepjumps '.s:noswapfile.' file ' . fnameescape(d.dir)
      endif
    endif

    if bufname('%') !=# d.dir  "sanity check. If this fails, we have a bug.
      echoerr 'expected buffer name: "'.d.dir.'" (actual: "'.bufname('%').'")'
      return
    endif

    let d.buf_num = bufnr('%')

    if exists('b:dirvish')
      call extend(b:dirvish, d, 'force')
    else
      let b:dirvish = d
    endif

    if exists('#User#DirvishEnter')
      doautocmd User DirvishEnter
    endif

    call b:dirvish.setup_buffer_opts()
    call b:dirvish.setup_buffer_syntax()
    call b:dirvish.setup_buffer_keymaps()

    call b:dirvish.render_buffer()

    "clear our 'loading...' message
    redraw | echo ''
  endfunction

  function! l:obj.setup_buffer_opts() abort dict
    setlocal filetype=dirvish
    setlocal bufhidden=unload undolevels=-1 nobuflisted
    setlocal buftype=nofile noswapfile nowrap nolist cursorline

    if &l:spell
      setlocal nospell
      augroup dirvish_bufferopts
        "Delete buffer-local events for this augroup.
        autocmd! * <buffer>
        "Restore window-local settings.
        autocmd BufLeave,BufHidden,BufWipeout,BufUnload,BufDelete <buffer>
              \ setlocal spell
      augroup END
    endif
  endfunction

  function! l:obj.setup_buffer_syntax() dict
    if has("syntax")
      syntax clear
      let w:dirvish = get(w:, 'dirvish', {})
      let w:dirvish.orig_concealcursor = &l:concealcursor
      let w:dirvish.orig_conceallevel = &l:conceallevel
      setlocal concealcursor=nvc conceallevel=3

      let sep = escape(s:sep, '/\')
      exe 'syntax match DirvishPathHead ''\v.*'.sep.'\ze[^'.sep.']+'.sep.'?$'' conceal'
      exe 'syntax match DirvishPathTail ''\v[^'.sep.']+'.sep.'$'''
      highlight! link DirvishPathTail Directory

      augroup dirvish_syntaxteardown
        "Delete buffer-local events for this augroup.
        autocmd! * <buffer>
        "Restore window-local settings.
        autocmd BufLeave,BufHidden,BufWipeout,BufUnload,BufDelete <buffer> if exists('w:dirvish')
              \ |   let &l:concealcursor = w:dirvish.orig_concealcursor
              \ |   let &l:conceallevel = w:dirvish.orig_conceallevel
              \ | endif
      augroup END
    endif
  endfunction

  function! l:obj.setup_buffer_keymaps() dict
    let popout_key = get(g:, 'dirvish_popout_key', 'p')
    let normal_map = {}
    let visual_map = {}

    let normal_map['dirvish_setFilter'] = 'f'
    let normal_map['dirvish_toggleFilter'] = 'F'
    let normal_map['dirvish_toggleHidden'] = 'gh'
    let normal_map['dirvish_quit'] = 'q'

    let normal_map['dirvish_visitTarget'] = 'i'
    let visual_map['dirvish_visitTarget'] = 'i'
    let normal_map['dirvish_bgVisitTarget'] = popout_key . 'i'
    let visual_map['dirvish_bgVisitTarget'] = popout_key . 'i'

    let normal_map['dirvish_splitVerticalVisitTarget'] = 'v'
    let visual_map['dirvish_splitVerticalVisitTarget'] = 'v'
    let normal_map['dirvish_bgSplitVerticalVisitTarget'] = popout_key . 'v'
    let visual_map['dirvish_bgSplitVerticalVisitTarget'] = popout_key . 'v'

    let normal_map['dirvish_splitVisitTarget'] = 'o'
    let visual_map['dirvish_splitVisitTarget'] = 'o'
    let normal_map['dirvish_bgSplitVisitTarget'] = popout_key . 'o'
    let visual_map['dirvish_bgSplitVisitTarget'] = popout_key . 'o'

    let normal_map['dirvish_tabVisitTarget'] = 't'
    let visual_map['dirvish_tabVisitTarget'] = 't'
    let normal_map['dirvish_bgTabVisitTarget'] = popout_key . 't'
    let visual_map['dirvish_bgTabVisitTarget'] = popout_key . 't'

    let normal_map['dirvish_focusOnParent'] = '-'

    for k in keys(normal_map)
      let v = normal_map[k]
      let mapname = "<Plug>(".k.")"
      if !empty(v) && !hasmapto(mapname, 'n')
        execute "nmap <nowait><buffer><silent> ".v." ".mapname
      endif
    endfor

    for k in keys(visual_map)
      let v = visual_map[k]
      let mapname = "<Plug>(".k.")"
      if !empty(v) && !hasmapto(mapname, 'v')
        execute "vmap <nowait><buffer><silent> ".v." ".mapname
      endif
    endfor

    " HACK: do these extra mappings after the for-loops to avoid false
    "       positives for hasmapto()

    nmap <nowait><buffer><silent> <CR> <Plug>(dirvish_visitTarget)
    vmap <nowait><buffer><silent> <CR> <Plug>(dirvish_visitTarget)
    execute "nmap <nowait><buffer><silent> " . popout_key . "<CR> <Plug>(dirvish_bgVisitTarget)"

    nmap <nowait><buffer><silent> u <Plug>(dirvish_focusOnParent)
  endfunction

  function! l:obj.render_buffer() abort dict
    if !isdirectory(bufname('%'))
      echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
      return
    endif

    let old_lazyredraw = &lazyredraw
    set lazyredraw
    let w = winsaveview()

    " DEBUG
    " echom localtime() 'prev:'.self.prevbuf 'buf:'.self.buf_num 'alt:'.self.altbuf

    setlocal modifiable

    silent keepmarks keepjumps %delete

    call self.setup_buffer_syntax()
    let paths = s:discover_paths(self.dir, '*', self.showhidden)
    silent call append(0, paths)

    if self.is_filtered && !empty(self.filter_exp)
      let sep = escape(s:sep, '\') "only \ should be escaped in []
      "delete non-matches
      "TODO: do not match before first path separator.
      exe 'silent g!/\v'.self.filter_exp.'/d'
    endif

    keepmarks keepjumps $delete " remove extra last line

    setlocal nomodifiable nomodified
    call winrestview(w)
    let &lazyredraw = old_lazyredraw
  endfunction

  " returns 1 on success, 0 on failure
  function! l:obj.visit_prevbuf() abort dict
    if self.prevbuf != bufnr('%') && bufexists(self.prevbuf)
          \ && type({}) != type(getbufvar(self.prevbuf, 'dirvish'))
      exe s:noswapfile.' '.self.prevbuf.'buffer'
      return 1
    endif

    "find a buffer that is _not_ a dirvish buffer.
    let validbufs = filter(range(1, bufnr('$')),
          \ 'buflisted(v:val)
          \  && type({}) ==# type(getbufvar(v:val, "dirvish"))
          \  && "help"  !=# getbufvar(v:val, "&buftype")
          \  && v:val   !=  bufnr("%")
          \  && !isdirectory(bufname(v:val))
          \ ')
    if len(validbufs) > 0
      exe validbufs[0] . 'buffer'
      return 1
    endif
    return 0
  endfunction

  function! l:obj.visit_altbuf() abort dict
    if bufexists(self.altbuf) && type({}) != type(getbufvar(self.altbuf, 'dirvish'))
      exe s:noswapfile.' '.self.altbuf.'buffer'
    endif
  endfunction

  function! l:obj.quit_buffer() dict
    call self.visit_altbuf() "tickle original alt buffer to restore @#
    if !self.visit_prevbuf() && exists('b:dirvish') "altbuf _and_ prevbuf failed
      if winnr('$') > 1
        wincmd c
      else
        bdelete
      endif
    endif
  endfunction

  function! l:obj.visit(split_cmd, open_in_background) dict range
    let startline = v:count ? v:count : a:firstline
    let endline   = v:count ? v:count : a:lastline

    let curtab = tabpagenr()
    let curwin = winnr()
    let wincount = winnr('$')
    let old_lazyredraw = &lazyredraw
    set lazyredraw
    let splitcmd = a:split_cmd

    let paths = getline(startline, endline)
    for path in paths
      if !isdirectory(path) && !filereadable(path)
        call s:notifier.warn("invalid path: '" . path . "'")
        continue
      elseif isdirectory(path) && startline > endline && splitcmd ==# 'edit'
        " opening a bunch of directories in the _same_ window is not useful.
        continue
      endif

      try
        if isdirectory(path)
          exe (splitcmd ==# 'edit' ? '' : splitcmd.'|') 'Dirvish' fnameescape(path)
        else
          exe splitcmd fnameescape(path)
        endif
      catch /E37:/
        call s:notifier.info("E37: No write since last change")
        return
      catch /E36:/
        " E36: no room for any new splits; open in-situ.
        let splitcmd = 'edit'
        if isdirectory(path)
          exe 'Dirvish' fnameescape(path)
        else
          exe splitcmd fnameescape(path)
        endif
      catch /E325:/
        call s:notifier.info("E325: swap file exists")
      endtry
    endfor

    if a:open_in_background "return to dirvish buffer
      if a:split_cmd ==# 'tabedit'
        exe 'tabnext' curtab '|' curwin.'wincmd w'
      elseif winnr('$') > wincount
        exe 'wincmd p'
      elseif a:split_cmd ==# 'edit'
        execute 'silent keepalt keepjumps ' . self.buf_num . 'buffer'
      endif
    elseif !exists('b:dirvish')
      if self.visit_prevbuf() "tickle original buffer to make it the altbuf.
        "return to the opened file.
        b#
      endif
    endif

    let &lazyredraw = old_lazyredraw
  endfunction

  function! l:obj.visit_parent_dir() dict
    let pdir = s:parent_dir(self.dir)
    if pdir ==# self.dir
      call s:notifier.info("no parent directory")
      return
    endif

    call dirvish#open(pdir)
  endfunction

  function! l:obj.set_filter_exp() dict
    let self.filter_exp = input("filter: /\v", self.filter_exp)
    if empty(self.filter_exp)
      let self.is_filtered = 0
      call s:notifier.info("filter disabled")
    else
      let self.is_filtered = 1
      call s:notifier.info("filter enabled")
    endif
    call self.render_buffer()
  endfunction

  function! l:obj.toggle_filter() dict
    if self.is_filtered
      let self.is_filtered = 0
      call s:notifier.info("filter disabled")
      call self.render_buffer()
    else
      if !empty(self.filter_exp)
        let self.is_filtered = 1
        call s:notifier.info("filter enabled")
        call self.render_buffer()
      else
        call self.set_filter_exp()
      endif
    endif
  endfunction

  function! l:obj.toggle_hidden() dict
    if self.showhidden
      call s:notifier.info("excluding hidden files")
    else
      call s:notifier.info("showing hidden files")
    endif
    let self.showhidden = !self.showhidden
    call self.render_buffer()
  endfunction

  return l:obj
endfunction

function! dirvish#open(dir)
  let dir = fnamemodify(expand(a:dir, 1), ':p') "Resolves to getcwd() if a:dir is empty.

  if !isdirectory(dir) "If '%' was passed (for example), chop off the filename.
    let dir = fnamemodify(dir, ':p:h')
  endif

  let dir = s:normalize_dir(dir)

  if !isdirectory(dir)
    call s:notifier.error("invalid directory: '" . dir . "'")
    return
  endif

  if exists('b:dirvish') && dir ==# s:normalize_dir(b:dirvish.dir)
    "current buffer is already showing that directory.
    call s:notifier.info('reloading...')
  else
    call s:notifier.info('loading...')
  endif

  let d = s:new_dirvish()

  " remember alt buffer before clobbering.
  let d.altbuf = exists('b:dirvish')
        \ ? b:dirvish.altbuf
        \ : getbufvar('#', 'dirvish', {'altbuf':bufnr('#')}).altbuf

  " transfer previous ('original') buffer
  let d.prevbuf = exists('b:dirvish') ? b:dirvish.prevbuf : bufnr('%')

  call d.open_dir(dir, 0, "")
endfunction

unlet! s:notifier
let s:notifier = s:new_notifier()

" vim:foldlevel=4:
