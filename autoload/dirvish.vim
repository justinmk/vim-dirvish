""  Copyright 2014 Jeet Sukumaran.
""  Modified by Justin M. Keyes.
""
""  This program is free software; you can redistribute it and/or modify
""  it under the terms of the GNU General Public License as published by
""  the Free Software Foundation; either version 3 of the License, or
""  (at your option) any later version.
""
""  This program is distributed in the hope that it will be useful,
""  but WITHOUT ANY WARRANTY; without even the implied warranty of
""  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
""  GNU General Public License <http://www.gnu.org/licenses/>
""  for more details.
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
let s:sep_as_pattern = has("win32") ? '\\' : '/'

function! s:new_notifier()
  let m = {}

  function! m.format(leader, msg) dict
    return "dirvish: " . a:leader.a:msg
  endfunction
  function! m.error(msg) dict
    redraw
    echohl ErrorMsg | echomsg self.format("", a:msg) | echohl None
  endfunction
  function! m.warn(msg) dict
    redraw
    echohl WarningMsg | echomsg self.format("", a:msg) | echohl None
  endfunction
  function! m.info(msg) dict
    redraw
    echohl None | echo self.format("", a:msg)
  endfunction

  return m
endfunction

function! s:normalize_dir(dir)
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
  endif
  return fnamemodify(a:dir, ":p:h:h")
endfunction

function! s:sort_paths(p1, p2)
  if isdirectory(a:p1) && !isdirectory(a:p2)
    return -1
  elseif !isdirectory(a:p1) && isdirectory(a:p2)
    return 1
  endif
  return a:p1 ==# a:p2 ? 0 : a:p1 ># a:p2 ? 1 : -1
endfunction

function! s:discover_paths(current_dir, glob_pattern, showhidden)
  let curdir = s:normalize_dir(a:current_dir)
  let path_str = a:showhidden
        \ ? glob(curdir.'.[^.]'.a:glob_pattern, 1)."\n".glob(curdir.a:glob_pattern, 1)
        \ : glob(curdir.a:glob_pattern, 1)
  let paths = split(path_str, '\n')
  call sort(paths, '<sid>sort_paths')
  return map(paths, "fnamemodify(substitute(v:val, s:sep_as_pattern.'\+', s:sep, 'g'), ':p')")
endfunction

function! s:sanity_check() abort
  if !isdirectory(bufname('%'))
    echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
  endif
endfunction

function! s:new_dirvish()
  let l:obj = { 'altbuf': -1, 'prevbuf': -1, 'showhidden': 0 }

  function! l:obj.open_dir(...) abort dict
    let d = self

    if a:0 > 0
      " Full path to the directory being viewed.
      let d.dir = s:normalize_dir(a:1)

      " list of tuples, [ (string, string) ]
      " The history stack, with the first element of the tuple being the
      " directory previously visited and the second element of the tuple being
      " the last selected entry in that directory
      let d.prev_dirs = deepcopy(a:2)
      " {string: string} dict of {directories : default targets}
      "   Determines where the cursor will be placed when returning to
      "   a previously-visited view.
      let d.default_targets = deepcopy(a:3)
      " If truthy, `filter_exp` will be applied.
      let d.is_filtered = a:4
      " Regexp used to filter entries if `is_filtered` is truthy.
      let d.filter_exp = a:5
    endif

    let bnr = bufnr('^' . d.dir . '$')

    try
      if -1 == bnr
        execute 'silent noau keepalt keepjumps noswapfile edit ' . fnameescape(d.dir)
      else
        execute 'silent noau keepalt keepjumps noswapfile '.bnr.'buffer'
      endif
    catch /E37:/
      call s:notifier.error("E37: No write since last change")
      return
    endtry

    let d.buf_num = bufnr('%')

    if exists('b:dirvish')
      let b:dirvish.dir = d.dir
      let b:dirvish.prevbuf = d.prevbuf
      let b:dirvish.prev_dirs = d.prev_dirs
      let b:dirvish.default_targets = d.default_targets
      let b:dirvish.is_filtered = d.is_filtered
      let b:dirvish.filter_exp = d.filter_exp
      let b:dirvish.showhidden = d.showhidden
    else
      let b:dirvish = d
    endif

    if exists('#User#DirvishEnter')
      doautocmd User DirvishEnter
    endif

    call b:dirvish.setup_buffer_opts()
    call b:dirvish.setup_buffer_syntax()
    call b:dirvish.setup_buffer_keymaps()

    if line('$') == 1
      call b:dirvish.render_buffer()
    endif
  endfunction

  function! l:obj.setup_buffer_opts() abort dict
    call s:sanity_check()

    setlocal nobuflisted
    setlocal bufhidden=unload
    setlocal buftype=nofile noswapfile nowrap nolist cursorline

    if &l:spell
      setlocal nospell
      augroup dirvish_bufferopts
        autocmd!
        "restore window-local settings
        autocmd BufHidden,BufWipeout,BufUnload,BufDelete <buffer>
              \ setlocal spell | autocmd! dirvish_bufferopts *
      augroup END
    endif

    setlocal undolevels=-1
    set filetype=dirvish
  endfunction

  function! l:obj.setup_buffer_syntax() dict
    if has("syntax")
      syntax clear
      let w:dirvish = get(w:, 'dirvish', {})
      let w:dirvish.orig_concealcursor = &l:concealcursor
      let w:dirvish.orig_conceallevel = &l:conceallevel
      setlocal concealcursor=nvc conceallevel=3

      syntax match DirvishPathHead '\v.*\/\ze[^\/]+\/?$' conceal
      syntax match DirvishPathTail '\v[^\/]+\/$'
      highlight! link DirvishPathTail Directory

      augroup dirvish_syntaxteardown
        autocmd!
        "restore window-local settings
        autocmd BufHidden,BufWipeout,BufUnload,BufDelete <buffer> if exists('w:dirvish')
              \ |   let &l:concealcursor = w:dirvish.orig_concealcursor
              \ |   let &l:conceallevel = w:dirvish.orig_conceallevel
              \ | endif
            \ | autocmd! dirvish_syntaxteardown *
      augroup END
    endif
  endfunction

  function! l:obj.setup_buffer_keymaps() dict

    " Avoid 'cannot modify' error for  keys.
    for key in [".", "p", "P", "C", "x", "X", "r", "R", "i", "I", "a", "A", "D", "S", "U"]
      if !hasmapto(key, 'n')
        execute "nnoremap <buffer> " . key . " <NOP>"
      endif
    endfor

    let popout_key = get(g:, 'dirvish_popout_key', 'p')
    let l:default_normal_plug_map = {}
    let l:default_visual_plug_map = {}

    nnoremap <Plug>(dirvish_refresh)                            :call b:dirvish.render_buffer()<CR>
    let l:default_normal_plug_map['dirvish_refresh'] = 'R'
    nnoremap <Plug>(dirvish_setFilter)                          :call b:dirvish.set_filter_exp()<CR>
    let l:default_normal_plug_map['dirvish_setFilter'] = 'f'
    nnoremap <Plug>(dirvish_toggleFilter)                       :call b:dirvish.toggle_filter()<CR>
    let l:default_normal_plug_map['dirvish_toggleFilter'] = 'F'
    nnoremap <Plug>(dirvish_toggleHiddenAndIgnored)             :call b:dirvish.toggle_hidden()<CR>
    let l:default_normal_plug_map['dirvish_toggleHiddenAndIgnored'] = 'gh'
    nnoremap <Plug>(dirvish_quit)                               :call b:dirvish.quit_buffer()<CR>
    let l:default_normal_plug_map['dirvish_quit'] = 'q'

    nnoremap <Plug>(dirvish_visitTarget)                        :<C-U>call b:dirvish.visit("edit", 0)<CR>
    let l:default_normal_plug_map['dirvish_visitTarget'] = 'o'
    vnoremap <Plug>(dirvish_visitTarget)                        :call b:dirvish.visit("edit", 0)<CR>
    let l:default_visual_plug_map['dirvish_visitTarget'] = 'o'
    nnoremap <Plug>(dirvish_bgVisitTarget)                      :<C-U>call b:dirvish.visit("edit", 1)<CR>
    let l:default_normal_plug_map['dirvish_bgVisitTarget'] = popout_key . 'o'
    vnoremap <Plug>(dirvish_bgVisitTarget)                      :call b:dirvish.visit("edit", 1)<CR>
    let l:default_visual_plug_map['dirvish_bgVisitTarget'] = popout_key . 'o'

    nmap <buffer> <silent> <CR> <Plug>(dirvish_visitTarget)
    vmap <buffer> <silent> <CR> <Plug>(dirvish_visitTarget)
    execute "nmap <buffer> <silent> " . popout_key . "<CR> <Plug>(dirvish_bgVisitTarget)"
    execute "vmap <buffer> <silent> " . popout_key . "<CR> <Plug>(dirvish_bgVisitTarget)"

    nnoremap <Plug>(dirvish_splitVerticalVisitTarget)           :<C-U>call b:dirvish.visit("vert sp", 0)<CR>
    let l:default_normal_plug_map['dirvish_splitVerticalVisitTarget'] = 'v'
    vnoremap <Plug>(dirvish_splitVerticalVisitTarget)           :call b:dirvish.visit("vert sp", 0)<CR>
    let l:default_visual_plug_map['dirvish_splitVerticalVisitTarget'] = 'v'
    nnoremap <Plug>(dirvish_bgSplitVerticalVisitTarget)         :<C-U>call b:dirvish.visit("rightbelow vert sp", 1)<CR>
    let l:default_normal_plug_map['dirvish_bgSplitVerticalVisitTarget'] = popout_key . 'v'
    vnoremap <Plug>(dirvish_bgSplitVerticalVisitTarget)         :call b:dirvish.visit("rightbelow vert sp", 1)<CR>
    let l:default_visual_plug_map['dirvish_bgSplitVerticalVisitTarget'] = popout_key . 'v'

    nnoremap <Plug>(dirvish_splitVisitTarget)                   :<C-U>call b:dirvish.visit("sp", 0)<CR>
    let l:default_normal_plug_map['dirvish_splitVisitTarget'] = 's'
    vnoremap <Plug>(dirvish_splitVisitTarget)                   :call b:dirvish.visit("sp", 0)<CR>
    let l:default_visual_plug_map['dirvish_splitVisitTarget'] = 's'
    nnoremap <Plug>(dirvish_bgSplitVisitTarget)                 :<C-U>call b:dirvish.visit("rightbelow sp", 1)<CR>
    let l:default_normal_plug_map['dirvish_bgSplitVisitTarget'] = popout_key . 's'
    vnoremap <Plug>(dirvish_bgSplitVisitTarget)                 :call b:dirvish.visit("rightbelow sp", 1)<CR>
    let l:default_visual_plug_map['dirvish_bgSplitVisitTarget'] = popout_key . 's'

    nnoremap <Plug>(dirvish_tabVisitTarget)                     :<C-U>call b:dirvish.visit("tabedit", 0)<CR>
    let l:default_normal_plug_map['dirvish_tabVisitTarget'] = 't'
    vnoremap <Plug>(dirvish_tabVisitTarget)                     :call b:dirvish.visit("tabedit", 0)<CR>
    let l:default_visual_plug_map['dirvish_tabVisitTarget'] = 't'
    nnoremap <Plug>(dirvish_bgTabVisitTarget)                   :<C-U>call b:dirvish.visit("tabedit", 1)<CR>
    let l:default_normal_plug_map['dirvish_bgTabVisitTarget'] = popout_key . 't'
    vnoremap <Plug>(dirvish_bgTabVisitTarget)                   :call b:dirvish.visit("tabedit", 1)<CR>
    let l:default_visual_plug_map['dirvish_bgTabVisitTarget'] = popout_key . 't'

    nnoremap <Plug>(dirvish_focusOnParent)                      :call b:dirvish.visit_parent_dir()<CR>
    let l:default_normal_plug_map['dirvish_focusOnParent'] = '-'

    for plug_name in keys(l:default_normal_plug_map)
      let plug_key = l:default_normal_plug_map[plug_name]
      if !empty(plug_key)
        execute "nmap <buffer> <silent> " . plug_key . " <Plug>(".plug_name.")"
      endif
    endfor

    for plug_name in keys(l:default_visual_plug_map)
      let plug_key = l:default_visual_plug_map[plug_name]
      if !empty(plug_key)
        execute "vmap <buffer> <silent> " . plug_key . " <Plug>(".plug_name.")"
      endif
    endfor

  endfunction

  function! l:obj.render_buffer() abort dict
    call s:sanity_check()
    let w = winsaveview()

    echom localtime() 'prev:'.self.prevbuf 'buf:'.self.buf_num 'alt:'.self.altbuf

    setlocal modifiable
    %delete

    call self.setup_buffer_syntax()
    let paths = s:discover_paths(self.dir, "*", self.showhidden)
    for path in paths
      let tail = fnamemodify(path, ':t')
      if !isdirectory(path) && self.is_filtered && !empty(self.filter_exp) && (tail !~# self.filter_exp)
        continue
      endif
      call append(line("$")-1, path)
    endfor

    $delete " remove extra last line
    setlocal nomodifiable nomodified
    call winrestview(w)
  endfunction

  function! l:obj.visit_prevbuf() abort dict
    if self.prevbuf != bufnr('%') && bufexists(self.prevbuf)
          \ && type({}) != type(getbufvar(self.prevbuf, 'dirvish'))
      exe self.prevbuf . 'buffer'
    else
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
      endif
    endif
  endfunction

  function! l:obj.visit_altbuf() abort dict
    let altbufnr = self.altbuf
    if bufexists(altbufnr) && type({}) != type(getbufvar(altbufnr, 'dirvish'))
      exe 'noau ' . altbufnr . 'buffer'
    endif
  endfunction

  function! l:obj.quit_buffer() dict
    call self.visit_altbuf() "tickle original alt buffer to restore @#
    call self.visit_prevbuf()
  endfunction

  function! l:obj.visit(split_cmd, open_in_background) dict range
    let startline = v:count ? v:count : a:firstline
    let endline   = v:count ? v:count : a:lastline

    let l:cur_tab_num = tabpagenr()
    let old_lazyredraw = &lazyredraw
    set lazyredraw
    let l:split_cmd = a:split_cmd

    let opened = []
    let paths = map(range(startline, endline), 'getline(v:val)')
    for path in paths
      if !isdirectory(path) && !filereadable(path)
        call s:notifier.warn("invalid path: '" . path . "'")
        continue
      endif

      if isdirectory(path) && startline > endline && l:split_cmd ==# 'edit'
        " opening a bunch of directories in the same window is not useful.
        continue
      endif

      try
        if isdirectory(path)
          exe l:split_cmd '| Dirvish' path
        else
          exe l:split_cmd fnameescape(path)
        endif
      catch /E37:/
        call s:notifier.info("E37: No write since last change")
        return
      catch /E36:/
        " E36: no room for any new splits; open in-situ.
        let l:split_cmd = 'edit'
        if isdirectory(path)
          exe 'Dirvish' path
        else
          exe l:split_cmd fnameescape(path)
        endif
      catch /E325:/
        call s:notifier.info("E325: swap file exists")
      endtry
      call add(opened, '"' . fnamemodify(path, ':t') . '"')
    endfor

    if a:open_in_background
      "return to dirvish buffer
      exe 'tabnext' l:cur_tab_num '|' bufwinnr(self.buf_num) . 'wincmd w'
      if a:split_cmd ==# 'edit'
        execute 'silent keepalt keepjumps ' . self.buf_num . 'buffer'
      endif
      " redraw!

      if a:split_cmd ==# 'edit'
        if len(opened) > 1
          " Opening multiple files in background of same window is a little
          " cryptic so in this special case, we issue some feedback
          echo join(opened, ', ')
        endif
      endif
    elseif !exists('b:dirvish')
      "tickle original buffer so that it is now the altbuf.
      call self.visit_prevbuf()
      "return to the opened file.
      b#
    endif

    let &lazyredraw = l:old_lazyredraw
  endfunction

  function! l:obj.visit_parent_dir() dict
    let pdir = s:parent_dir(self.dir)
    if pdir ==# self.dir
      call s:notifier.info("no parent directory")
      return
    endif

    call dirvish#open(pdir)
  endfunction

  function! l:obj.goto_pattern(pattern) dict
    let full_pattern = '^\V\C' . escape(a:pattern, '/\') . '$'
    call search(full_pattern, "cw")
  endfunction

  function! l:obj.set_filter_exp() dict
    let self.filter_exp = input("filter (regex): ", self.filter_exp)
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
  let dir = fnamemodify(expand(a:dir), ':p')

  if !isdirectory(dir)
    "If, for example, '%' was passed, try chopping off the file part.
    let dir = fnamemodify(expand(a:dir), ':p:h')
  endif

  let dir = s:normalize_dir(empty(dir)
        \ ? (empty(expand("%", 1)) ? getcwd() : expand('%:p:h', 1))
        \ : fnamemodify(dir, ':p'))

  if !isdirectory(dir)
    call s:notifier.error("invalid directory: '" . dir . "'")
    return
  endif

  if exists('b:dirvish') && dir ==# s:normalize_dir(b:dirvish.dir)
    "current buffer is already viewing that directory.
    return
  endif

  let d = s:new_dirvish()

  " remember alt buffer before clobbering.
  let d.altbuf = exists('b:dirvish')
        \ ? b:dirvish.altbuf
        \ : getbufvar('#', 'dirvish', {'altbuf':bufnr('#')}).altbuf

  " transfer previous ('original') buffer
  let d.prevbuf = exists('b:dirvish') ? b:dirvish.prevbuf : bufnr('%')

  call d.open_dir(
        \ dir,
        \ [],
        \ {},
        \ 0,
        \ ""
        \)
endfunction

unlet! s:notifier
let s:notifier = s:new_notifier()

" vim:foldlevel=4:
