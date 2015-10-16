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
" - let &titlestring = expand(b:dirvish.dir, 1)
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
let s:noau       = 'silent noautocmd keepjumps'

function! s:msg_error(msg) abort
  redraw | echohl ErrorMsg | echomsg 'dirvish:' a:msg | echohl None
endfunction
function! s:msg_info(msg) abort
  redraw | echo 'dirvish:' a:msg
endfunction
function! s:msg_dbg(msg) abort
  call writefile([a:msg], expand('~/dirvish.log', 1), 'a')
endfunction

function! s:normalize_dir(dir) abort
  if !isdirectory(a:dir)
    call s:msg_error("invalid directory: '".a:dir."'")
    return ''
  endif
  let dir = fnamemodify(a:dir, ':p') "always full path
  let dir = substitute(a:dir, s:sep.'\+', s:sep, 'g') "replace consecutive slashes
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

function! s:list_dir(current_dir) abort
  let curdir = s:normalize_dir(a:current_dir)
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

function! s:buf_init() abort
  setlocal nobuflisted
  setlocal undolevels=-1 buftype=nofile noswapfile

  setlocal filetype=dirvish

  augroup dirvish_buflocal
    autocmd! * <buffer>
    " Ensure w:dirvish for window splits, etc.
    autocmd WinEnter  <buffer> let w:dirvish = extend(get(w:, 'dirvish', {}), b:dirvish, 'force')
    autocmd BufDelete <buffer> call <SID>on_buf_closed(expand('<abuf>'))
    autocmd BufLeave  <buffer> call <SID>restore_winlocal_settings()
  augroup END
endfunction

function! s:win_init() abort
  let wd = w:dirvish
  let [wd._w_wrap, wd._w_cul] = [&l:wrap, &l:cul]
  setlocal nowrap cursorline

  if has("syntax")
    syntax clear
    let sep = escape(s:sep, '/\')
    exe 'syntax match DirvishPathHead ''\v.*'.sep.'\ze[^'.sep.']+'.sep.'?$'' conceal'
    exe 'syntax match DirvishPathTail ''\v[^'.sep.']+'.sep.'$'''
    highlight! link DirvishPathTail Directory
  endif

  if has('conceal')
    let [wd._w_cocu, wd._w_cole] = [&l:concealcursor, &l:conceallevel]
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

function! s:on_buf_closed(...) abort
  let d = get(w:, 'dirvish', {})
  if empty(d)
    return
  endif

  augroup dirvish_after
    autocmd!
    for i in [d.altbuf, d.prevbuf]
      if bufexists(i)
        exe 'autocmd CursorMoved <buffer='.i.
          \ '> exe "autocmd! dirvish_after"|call <SID>restore_alt_prev()'
      endif
    endfor
  augroup END

  if d.prevbuf != bufnr('%') && !s:visit_prevbuf(d.prevbuf)
    call s:msg_info('no other buffers')
  endif

endfunction

function! s:restore_winlocal_settings()
  if !exists('w:dirvish')
    return
  endif
  if has('conceal') && has_key(w:dirvish, '_w_cocu')
    let [&l:cocu, &l:cole] = [w:dirvish._w_cocu, w:dirvish._w_cole]
    unlet w:dirvish._w_cocu w:dirvish._w_cole
  endif
endfunction

function! s:restore_alt_prev()
  if !exists('w:dirvish')
    return
  endif
  call s:visit_altbuf(get(w:dirvish, 'altbuf', 0))
  call s:visit_prevbuf(get(w:dirvish, 'prevbuf', 0))
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
      execute 'silent keepalt keepjumps buffer' w:dirvish.buf_num
    endif
  elseif !exists('b:dirvish')
    if s:visit_prevbuf(w:dirvish.prevbuf) "tickle original buffer to make it the altbuf.
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

  "find a buffer that is _not_ a dirvish buffer.
  let validbufs = filter(range(1, bufnr('$')),
        \ 'buflisted(v:val)
        \  && empty(getbufvar(v:val, "dirvish"))
        \  && "help"  !=# getbufvar(v:val, "&buftype")
        \  && v:val   !=  bufnr("%")
        \  && !isdirectory(bufname(v:val))
        \ ')
  if len(validbufs) > 0
    execute 'silent noau keepjumps' s:noswapfile 'buffer' validbufs[0]
    return 1
  endif
  return 0
endfunction

function! s:visit_altbuf(altbuf) abort
  if bufexists(a:altbuf) && empty(getbufvar(a:altbuf, 'dirvish'))
    execute 'silent noau keepjumps' s:noswapfile 'buffer' a:altbuf
  endif
endfunction

" Saves or restores the view of all windows showing `bname`.
function! s:windo_save_or_restore(save, bname)
  let [curtab, curwin, curaltwin] = [tabpagenr(), winnr(), winnr('#')]
  for tnr in range(1, tabpagenr('$'))
    for wnr in range(1, tabpagewinnr(tnr, '$'))
      if a:bname ==# bufname(winbufnr(wnr))
        exe s:noau 'tabnext' tnr '|' s:noau wnr.'wincmd w'
        if a:save
          let w:dirvish['_view'] = winsaveview()
        else
          call winrestview(w:dirvish['_view'])
        endif
      endif
    endfor
  endfor
  exe s:noau 'tabnext '.curtab
  exe s:noau curaltwin.'wincmd w|' s:noau curwin.'wincmd w'
endfunction

function! s:buf_render(dir, lastpath) abort
  let bname = bufname('%')
  if !isdirectory(bname)
    echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
    return
  endif

  call s:windo_save_or_restore(1, bname)
  setlocal modifiable

  silent keepmarks keepjumps %delete _
  silent call append(0, s:list_dir(a:dir))
  keepmarks keepjumps $delete _ " remove extra last line

  setlocal nomodifiable nomodified
  call s:windo_save_or_restore(0, bname)

  if !empty(a:lastpath)
    keepjumps call search('\V\^'.escape(a:lastpath, '\').'\$', 'cw')
  endif
endfunction

function! s:new_dirvish() abort
  let l:obj = {}

  function! l:obj.do_open(dir) abort dict
    let d = self
    let d.dir = s:normalize_dir(a:dir)  " full path to the directory
    let bnr = bufnr('^' . d.dir . '$')

    " Vim tends to name the directory buffer using its reduced path.
    " Examples (Win32 gvim 7.4.618):
    "     ~\AppData\Local\Temp\
    "     ~\AppData\Local\Temp
    "     AppData\Local\Temp\
    "     AppData\Local\Temp
    " Try to find an existing reduced-path name before creating a new one.
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
      call s:msg_error("E37: No write since last change")
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
      call s:visit_altbuf(d.altbuf) "tickle original alt-buffer to restore @#
      execute 'silent noau keepjumps' s:noswapfile 'buffer' bnr
    endif

    if bufname('%') !=# d.dir  "We have a bug or Vim has a regression.
      echoerr 'expected buffer name: "'.d.dir.'" (actual: "'.bufname('%').'")'
      return
    endif

    let d.buf_num = bufnr('%')

    let b:dirvish = exists('b:dirvish') ? extend(b:dirvish, d, 'force') : d

    call s:buf_init()
    call s:win_init()
    call s:buf_render(b:dirvish.dir, get(b:dirvish, 'lastpath', ''))

    "clear our 'loading...' message
    redraw | echo ''
  endfunction

  return l:obj
endfunction

function! s:buf_isvalid(bnr) abort
  return bufexists(a:bnr) && !isdirectory(bufname(a:bnr))
endfunction

function! dirvish#open(dir) abort
  if &autochdir
    call s:msg_error("'autochdir' is not supported")
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
  if '' ==# dir " s:normalize_dir() already displayed error message.
    return
  endif

  if exists('b:dirvish') && dir ==# s:normalize_dir(b:dirvish.dir)
    call s:msg_info('reloading...')
  else
    call s:msg_info('loading...')
  endif

  let d = s:new_dirvish()

  " Save lastpath when navigating _up_.
  if exists('b:dirvish') && dir ==# s:parent_dir(b:dirvish.dir)
    let d.lastpath = b:dirvish.dir
  endif

  " Remember previous ('original') buffer.
  let d.prevbuf = s:buf_isvalid(bufnr('%')) || !exists('w:dirvish')
        \ ? 0+bufnr('%') : w:dirvish.prevbuf
  if exists('b:dirvish') && !s:buf_isvalid(d.prevbuf)
    let d.prevbuf = b:dirvish.prevbuf
  endif

  " Remember alternate buffer.
  let d.altbuf = s:buf_isvalid(bufnr('#')) || !exists('w:dirvish')
        \ ? 0+bufnr('#') : w:dirvish.altbuf
  if exists('b:dirvish') && (d.altbuf == d.prevbuf || !s:buf_isvalid(d.altbuf))
    let d.altbuf = b:dirvish.altbuf
  endif

  let w:dirvish = extend(get(w:, 'dirvish', {}), d, 'force')

  call d.do_open(dir)
endfunction
