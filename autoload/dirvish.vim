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

let s:sep = (&shell =~? 'cmd.exe') ? '\' : '/'
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

function! s:discover_paths(current_dir, glob_pattern)
  let curdir = s:normalize_dir(a:current_dir)
  let paths = glob(curdir.a:glob_pattern, 1, 1)
  "Append dot-prefixed files. glob() cannot do both in 1 pass.
  let paths = paths + glob(curdir.'.[^.]'.a:glob_pattern, 1, 1)

  if get(g:, 'dirvish_relative_paths', 0)
        \ && curdir != s:parent_dir(getcwd()) "avoid blank line for cwd
    return sort(map(paths, "fnamemodify(v:val, ':.')"))
  else
    return sort(map(paths, "fnamemodify(v:val, ':p')"))
  endif
endfunction

function! s:buf_init() abort
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

  augroup dirvish_bufclosed
    autocmd! * <buffer>
    autocmd BufWipeout,BufUnload,BufDelete <buffer>
          \ call <sid>on_buf_closed(expand('<abuf>'))
  augroup END
endfunction

function! s:buf_syntax()
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

function! s:buf_keymaps()
  let normal_map = {}
  let visual_map = {}

  let normal_map['dirvish_quit'] = 'q'


  let normal_map['dirvish_visitTarget'] = 'i'

  let normal_map['dirvish_splitVerticalVisitTarget'] = 'a'
  let normal_map['dirvish_focusOnParent'] = '-'
  let normal_map['dirvish_tabVisitTarget'] = 't'
  let normal_map['dirvish_splitVisitTarget'] = 'o'

  let visual_map['dirvish_visitTarget'] = 'i'
  let visual_map['dirvish_splitVerticalVisitTarget'] = 'a'
  let visual_map['dirvish_splitVisitTarget'] = 'o'
  let visual_map['dirvish_tabVisitTarget'] = 't'


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

  nmap <nowait><buffer><silent> p <Plug>(dirvish_focusOnParent)
  nnoremap <nowait><buffer><silent> R :Dirvish %<CR>
endfunction

function! s:buf_isvisible(bnr)
  for i in range(1, tabpagenr('$'))
    for tbnr in tabpagebuflist(i)
      if tbnr == a:bnr
        return 1
      endif
    endfor
  endfor
  return 0
endfunction

function! s:on_buf_closed(...)
  if a:0 <= 0
    return
  endif
  let bnr = 0 + a:1
  let d = getbufvar(bnr, 'dirvish', {})
  if empty(d) "BufDelete etc. may be raised after b:dirvish is gone.
    return
  endif
  "Do we need to bother cleaning up buffer-local autocmds?
  "silent! autocmd! dirvish_bufclosed * <buffer>

  call d.visit_altbuf() "tickle original alt-buffer to restore @#
  if !d.visit_prevbuf() "return to original buffer
    call s:notifier.warn('no other buffers')
  endif
  if bufexists(bnr) && buflisted(bnr) && !s:buf_isvisible(bnr)
    execute 'bdelete' bnr
  endif
endfunction

function! s:new_dirvish()
  let l:obj = { 'altbuf': -1, 'prevbuf': -1 }

  function! l:obj.open_dir(...) abort dict
    let d = self

    if a:0 > 0
      let d.dir = s:normalize_dir(a:1)  " full path to the directory
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
        execute 'silent noau keepjumps' s:noswapfile 'edit' fnameescape(d.dir)
      else
        execute 'silent noau keepjumps' s:noswapfile 'buffer' bnr
      endif
    catch /E37:/
      call s:notifier.error("E37: No write since last change")
      return
    endtry

    "If the directory is relative to CWD, :edit refuses to create a buffer
    "with the expanded name (it may be _relative_ instead); this will cause
    "problems when the user navigates. Use :file to force the expanded path.
    if bufname('%') !=# d.dir
      execute 'silent noau keepjumps '.s:noswapfile.' file ' . fnameescape(d.dir)
      if bufnr('#') != bufnr('%') && isdirectory(bufname('#')) "Yes, (# == %) is possible.
        bwipeout # "Kill it with fire, it is useless.
      endif
      let bnr = bufnr('%')
      call self.visit_altbuf() "tickle original alt-buffer to restore @#
      execute 'silent noau keepjumps' s:noswapfile bnr.'buffer'
    endif

    if bufname('%') !=# d.dir  "We have a bug or Vim has a regression.
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

    call s:buf_init()
    call s:buf_syntax()
    call s:buf_keymaps()

    call b:dirvish.render_buffer()

    "clear our 'loading...' message
    redraw | echo ''
  endfunction

  function! l:obj.render_buffer() abort dict
    if !isdirectory(bufname('%'))
      echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
      return
    endif

    let old_lazyredraw = &lazyredraw
    set lazyredraw
    let w = winsaveview()

    setlocal modifiable

    silent keepmarks keepjumps %delete _

    call s:buf_syntax()
    let paths = s:discover_paths(self.dir, '*')
    silent call append(0, paths)

    keepmarks keepjumps $delete _ " remove extra last line

    setlocal nomodifiable nomodified
    call winrestview(w)
    let &lazyredraw = old_lazyredraw
  endfunction

  " returns 1 on success, 0 on failure
  function! l:obj.visit_prevbuf() abort dict
    if self.prevbuf != bufnr('%') && bufexists(self.prevbuf)
          \ && empty(getbufvar(self.prevbuf, 'dirvish'))
      execute 'silent keepjumps' s:noswapfile 'buffer' self.prevbuf
      return 1
    endif

    "find a buffer that is _not_ a dirvish buffer.
    let validbufs = filter(range(1, bufnr('$')),
          \ 'buflisted(v:val)
          \  && empty(getbufvar(v:val, "dirvish"))
          \  && "help"  !=# getbufvar(v:val, "&buftype")
          \  && v:val   !=  bufnr("%")
          \  && !isdirectory(bufname(v:val))
          \ ')
    if len(validbufs) > 0
      execute 'buffer' validbufs[0]
      return 1
    endif
    return 0
  endfunction

  function! l:obj.visit_altbuf() abort dict
    if bufexists(self.altbuf) && empty(getbufvar(self.altbuf, 'dirvish'))
      execute 'silent noau keepjumps' s:noswapfile 'buffer' self.altbuf
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

  return l:obj
endfunction

function! dirvish#open(dir)
  if &autochdir
    call s:notifier.error("'autochdir' is not supported")
    return
  endif

  let dir = fnamemodify(expand(fnameescape(a:dir), 1), ':p')
  "                     ^      ^                        ^resolves to CWD if a:dir is empty
  "                     |      `escape chars like '$' before expand()
  "                     `expand() fixes slashes on Windows

  if filereadable(dir) "chop off the filename
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
  let d.prevbuf = exists('b:dirvish') ? b:dirvish.prevbuf : 0 + bufnr('%')

  call d.open_dir(dir, 0, "")
endfunction

unlet! s:notifier
let s:notifier = s:new_notifier()

" vim:foldlevel=4:
