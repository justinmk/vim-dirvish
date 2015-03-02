"  Copyright 2014 Jeet Sukumaran.
"  Modified by Justin M. Keyes.
"
" Things that are unnecessary when you set the buffer name:
"
" - let &titlestring = expand(self.focus_dir, 1)
" - specialized 'cd', 'cl'
"
" Things that are unnecessary when you conceal the full file paths:
" - specialized "yank" commands
" - specialized "read" commands (instead: yy and :r ...)
"
" Fixed bug: 'buffer <num>' may open buffer with actual number name.



if has("win32")
    let s:sep = '\'
    let s:sep_as_pattern = '\\'
else
    let s:sep = '/'
    let s:sep_as_pattern = '/'
endif

function! s:new_notifier(name)
    let m = {}
    let m["name"] = a:name
    let m["title"] = empty(a:name) ? "dirvish" : "dirvish (" . m["name"] . ")"

    function! m.format(leader, msg) dict
        return self.title . ": " . a:leader.a:msg
    endfunction
    function! m.error(msg) dict
        redraw
        echohl ErrorMsg
        echomsg self.format("", a:msg)
        echohl None
    endfunction
    function! m.warn(msg) dict
        redraw
        echohl WarningMsg
        echomsg self.format("", a:msg)
        echohl None
    endfunction
    function! m.info(msg) dict
        redraw
        echohl None
        echo self.format("", a:msg)
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
    return fnamemodify(a:dir, ":p:h:h")
endfunction

function! s:base_dirname(dirname)
    let l:dirname = fnamemodify(a:dirname, ":p")
    if l:dirname == s:sep
        return s:sep
    endif
    return split(l:dirname, s:sep_as_pattern)[-1] . s:sep
endfunction

function! s:discover_paths(current_dir, glob_pattern, is_include_hidden)
    if a:is_include_hidden
        let path_str = glob(a:current_dir.s:sep.'.[^.]'.a:glob_pattern, 1)."\n".glob(a:current_dir.s:sep.a:glob_pattern, 1)
    else
        let path_str = glob(a:current_dir.s:sep.a:glob_pattern, 1)
    endif
    let paths = split(path_str, '\n')
    call sort(paths)
    let dir_paths = []
    let file_paths = []

    let parent_path = s:parent_dir(a:current_dir)
    call add(dir_paths, {
                \ "full_path" : a:current_dir . s:sep . '..' . s:sep,
                \ "dirname" : fnamemodify(parent_path, ":h"),
                \ })

    for path_entry in paths
        let path_entry = substitute(path_entry, s:sep_as_pattern.'\+', s:sep, 'g')
        let full_path = fnamemodify(path_entry, ":p")
        let dirname = fnamemodify(path_entry, ":h")
        call add(
            \ isdirectory(path_entry) ? dir_paths : file_paths,
            \ { "full_path": full_path, "dirname" : dirname })
    endfor
    return [dir_paths, file_paths]
endfunction

function! s:sanity_check() abort
    if !isdirectory(bufname('%'))
        echoerr 'dirvish: fatal: buffer name is not a directory:' bufname('%')
    endif
endfunction

function! s:new_dirvish()
    let l:directory_viewer = { 'orig_alt_buf_num': -1, 'jump_map': {} }

    function! l:directory_viewer.open_dir(...) abort dict
        let d = self

        if a:0 > 0
            if a:0 != 8
                echoerr 'open_dir: requires exactly 8 extra args, but got '.a:0
            endif

            " Full path to the directory being viewed.
            let d.focus_dir = s:normalize_dir(a:1)
            " Full path to the file or directory that is should be the initial
            " target or focus
            let d.focus_file = fnamemodify(a:2, ':p')
            " The buffer from which dirvish was invoked. If prev_buf_num == buf_num,
            " assume it dirvish was invoked via `vim /path/to/dir`.
            let d.prev_buf_num = a:3
            " list of tuples, [ (string, string) ]
            " The history stack, with the first element of the tuple being the
            " directory previously visited and the second element of the tuple being
            " the last selected entry in that directory
            let d.prev_focus_dirs = deepcopy(a:4)
            " {string: string} dict of {directories : default targets}
            "   Determines where the cursor will be placed when returning to
            "   a previously-visited view.
            let d.default_targets = deepcopy(a:5)
            " If truthy, `filter_exp` will be applied.
            let d.is_filtered = a:6
            " Regexp used to filter entries if `is_filtered` is truthy.
            let d.filter_exp = a:7
            let d.is_include_hidden = a:8
        endif

        let bnr = bufnr('^' . d.focus_dir . '$')

        try
          if -1 == bnr
            execute 'silent noau keepalt keepjumps noswapfile edit ' . fnameescape(d.focus_dir)
          else
            execute 'silent noau keepalt keepjumps noswapfile '.bnr.'buffer'
          endif
        catch /E37:/
            call s:notifier.error("E37: No write since last change")
            return
        endtry

        let d.buf_num = bufnr('%')

        if exists('b:dirvish')
            let b:dirvish.focus_dir = d.focus_dir
            let b:dirvish.focus_file = d.focus_file
            let b:dirvish.prev_buf_num = d.prev_buf_num
            let b:dirvish.prev_focus_dirs = d.prev_focus_dirs
            let b:dirvish.default_targets = d.default_targets
            let b:dirvish.is_filtered = d.is_filtered
            let b:dirvish.filter_exp = d.filter_exp
            let b:dirvish.is_include_hidden = d.is_include_hidden
        else
            let b:dirvish = d
        endif

        echom "prevbufnum:" d.prev_buf_num 'bufnum:' d.buf_num 'origalt:' d.orig_alt_buf_num

        call b:dirvish.setup_buffer_opts()
        call b:dirvish.setup_buffer_syntax()
        call b:dirvish.setup_buffer_keymaps()

        if line('$') == 1
            call b:dirvish.render_buffer()
        endif
    endfunction

    function! l:directory_viewer.setup_buffer_opts() abort dict
        call s:sanity_check()

        setlocal nobuflisted
        setlocal bufhidden=wipe buftype=nofile noswapfile nowrap nolist cursorline

        if &l:spell
            setlocal nospell
            augroup dirvish_bufferopts
                autocmd!
                autocmd BufHidden,BufWipeout,BufUnload,BufDelete <buffer> setlocal nospell | autocmd! dirvish_bufferopts *
            augroup END
        endif

        setlocal undolevels=-1
        set filetype=dirvish
    endfunction

    function! l:directory_viewer.setup_buffer_syntax() dict
        if has("syntax")
            syntax clear
            let self.orig_concealcursor = &l:concealcursor
            let self.orig_conceallevel = &l:conceallevel
            setlocal concealcursor=nc conceallevel=3

            syntax match DirvishPathHead '\v.*\/\ze[^\/]+\/?$' conceal
            syntax match DirvishPathTail '\v[^\/]+\/$'
            highlight! link DirvishPathTail Directory

            augroup dirvish_syntaxteardown
                autocmd!
                autocmd BufHidden,BufWipeout,BufUnload,BufDelete <buffer> if exists('b:dirvish')
                    \ |     let &l:concealcursor = b:dirvish.orig_concealcursor
                    \ |     let &l:conceallevel = b:dirvish.orig_conceallevel
                    \ | endif
                    \ | autocmd! dirvish_syntaxteardown *
            augroup END
        endif
    endfunction

    function! l:directory_viewer.setup_buffer_keymaps() dict

        " Avoid 'cannot modify' error for  keys.
        for key in [".", "p", "P", "C", "x", "X", "r", "R", "i", "I", "a", "A", "D", "S", "U"]
            if !hasmapto(key, 'n')
                execute "nnoremap <buffer> " . key . " <NOP>"
            endif
        endfor

        let l:default_normal_plug_map = {}
        let l:default_visual_plug_map = {}

        """ Directory list buffer management
        nnoremap <Plug>(FileBeagleBufferRefresh)                            :call b:dirvish.render_buffer()<CR>
        let l:default_normal_plug_map['FileBeagleBufferRefresh'] = 'R'
        nnoremap <Plug>(FileBeagleBufferSetFilter)                          :call b:dirvish.set_filter_exp()<CR>
        let l:default_normal_plug_map['FileBeagleBufferSetFilter'] = 'f'
        nnoremap <Plug>(FileBeagleBufferToggleFilter)                       :call b:dirvish.toggle_filter()<CR>
        let l:default_normal_plug_map['FileBeagleBufferToggleFilter'] = 'F'
        nnoremap <Plug>(FileBeagleBufferToggleHiddenAndIgnored)             :call b:dirvish.toggle_hidden()<CR>
        let l:default_normal_plug_map['FileBeagleBufferToggleHiddenAndIgnored'] = 'gh'
        nnoremap <Plug>(FileBeagleBufferQuit)                               :call b:dirvish.quit_buffer()<CR>
        let l:default_normal_plug_map['FileBeagleBufferQuit'] = 'q'

        """ Open selected file/directory
        nnoremap <Plug>(FileBeagleBufferVisitTarget)                        :<C-U>call b:dirvish.visit_target("edit", 0)<CR>
        let l:default_normal_plug_map['FileBeagleBufferVisitTarget'] = 'o'
        vnoremap <Plug>(FileBeagleBufferVisitTarget)                        :call b:dirvish.visit_target("edit", 0)<CR>
        let l:default_visual_plug_map['FileBeagleBufferVisitTarget'] = 'o'
        nnoremap <Plug>(FileBeagleBufferBgVisitTarget)                      :<C-U>call b:dirvish.visit_target("edit", 1)<CR>
        let l:default_normal_plug_map['FileBeagleBufferBgVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 'o'
        vnoremap <Plug>(FileBeagleBufferBgVisitTarget)                      :call b:dirvish.visit_target("edit", 1)<CR>
        let l:default_visual_plug_map['FileBeagleBufferBgVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 'o'

        """ Special case: <CR>
        nmap <buffer> <silent> <CR> <Plug>(FileBeagleBufferVisitTarget)
        vmap <buffer> <silent> <CR> <Plug>(FileBeagleBufferVisitTarget)
        execute "nmap <buffer> <silent> " . g:filebeagle_buffer_background_key_map_prefix . "<CR> <Plug>(FileBeagleBufferBgVisitTarget)"
        execute "vmap <buffer> <silent> " . g:filebeagle_buffer_background_key_map_prefix . "<CR> <Plug>(FileBeagleBufferBgVisitTarget)"

        nnoremap <Plug>(FileBeagleBufferSplitVerticalVisitTarget)           :<C-U>call b:dirvish.visit_target("vert sp", 0)<CR>
        let l:default_normal_plug_map['FileBeagleBufferSplitVerticalVisitTarget'] = 'v'
        vnoremap <Plug>(FileBeagleBufferSplitVerticalVisitTarget)           :call b:dirvish.visit_target("vert sp", 0)<CR>
        let l:default_visual_plug_map['FileBeagleBufferSplitVerticalVisitTarget'] = 'v'
        nnoremap <Plug>(FileBeagleBufferBgSplitVerticalVisitTarget)         :<C-U>call b:dirvish.visit_target("rightbelow vert sp", 1)<CR>
        let l:default_normal_plug_map['FileBeagleBufferBgSplitVerticalVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 'v'
        vnoremap <Plug>(FileBeagleBufferBgSplitVerticalVisitTarget)         :call b:dirvish.visit_target("rightbelow vert sp", 1)<CR>
        let l:default_visual_plug_map['FileBeagleBufferBgSplitVerticalVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 'v'

        nnoremap <Plug>(FileBeagleBufferSplitVisitTarget)                   :<C-U>call b:dirvish.visit_target("sp", 0)<CR>
        let l:default_normal_plug_map['FileBeagleBufferSplitVisitTarget'] = 's'
        vnoremap <Plug>(FileBeagleBufferSplitVisitTarget)                   :call b:dirvish.visit_target("sp", 0)<CR>
        let l:default_visual_plug_map['FileBeagleBufferSplitVisitTarget'] = 's'
        nnoremap <Plug>(FileBeagleBufferBgSplitVisitTarget)                 :<C-U>call b:dirvish.visit_target("rightbelow sp", 1)<CR>
        let l:default_normal_plug_map['FileBeagleBufferBgSplitVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 's'
        vnoremap <Plug>(FileBeagleBufferBgSplitVisitTarget)                 :call b:dirvish.visit_target("rightbelow sp", 1)<CR>
        let l:default_visual_plug_map['FileBeagleBufferBgSplitVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 's'

        nnoremap <Plug>(FileBeagleBufferTabVisitTarget)                     :<C-U>call b:dirvish.visit_target("tabedit", 0)<CR>
        let l:default_normal_plug_map['FileBeagleBufferTabVisitTarget'] = 't'
        vnoremap <Plug>(FileBeagleBufferTabVisitTarget)                     :call b:dirvish.visit_target("tabedit", 0)<CR>
        let l:default_visual_plug_map['FileBeagleBufferTabVisitTarget'] = 't'
        nnoremap <Plug>(FileBeagleBufferBgTabVisitTarget)                   :<C-U>call b:dirvish.visit_target("tabedit", 1)<CR>
        let l:default_normal_plug_map['FileBeagleBufferBgTabVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 't'
        vnoremap <Plug>(FileBeagleBufferBgTabVisitTarget)                   :call b:dirvish.visit_target("tabedit", 1)<CR>
        let l:default_visual_plug_map['FileBeagleBufferBgTabVisitTarget'] = g:filebeagle_buffer_background_key_map_prefix . 't'

        """ Focal directory changing
        nnoremap <Plug>(FileBeagleBufferFocusOnParent)                      :call b:dirvish.visit_parent_dir()<CR>
        let l:default_normal_plug_map['FileBeagleBufferFocusOnParent'] = '-'
        nnoremap <Plug>(FileBeagleBufferFocusOnPrevious)                    :call b:dirvish.visit_prev_dir()<CR>
        let l:default_normal_plug_map['FileBeagleBufferFocusOnPrevious'] = 'b'
        nmap <buffer> <silent> <BS> <Plug>(FileBeagleBufferFocusOnPrevious)
        nmap <buffer> <silent> u    <BS>

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

    function! l:directory_viewer.render_buffer() abort dict
        call s:sanity_check()
        let w = winsaveview()


        setlocal modifiable
        %delete

        call self.setup_buffer_syntax()
        let paths = s:discover_paths(self.focus_dir, "*", self.is_include_hidden)
        for path in paths[0] + paths[1]
            let tail = fnamemodify(path["full_path"], ':t')
            if !isdirectory(path["full_path"]) && self.is_filtered && !empty(self.filter_exp) && (tail !~# self.filter_exp)
                continue
            endif
            let self.jump_map[line("$")] = {
                        \ "full_path" : path["full_path"],
                        \ "dirname" : path["dirname"],
                        \ }
            call append(line("$")-1, path["full_path"])
        endfor

        $delete " remove extra last line
        setlocal nomodifiable nomodified
        call winrestview(w)
        let self.default_targets[self.focus_dir] = self.focus_file
        call self.goto_pattern(self.focus_file)
    endfunction

    function! l:directory_viewer.quit_buffer() dict
        "tickle original 'alt' buffer
        if self.orig_alt_buf_num != bufnr('%') && bufexists(self.orig_alt_buf_num)
            exe self.orig_alt_buf_num . 'buffer'
        endif

        "restore original buffer
        if self.prev_buf_num != bufnr('%') && bufexists(self.prev_buf_num)
            exe self.prev_buf_num . 'buffer'
          elseif exists('b:dirvish')
            silent! bdelete
        endif
    endfunction

    function! l:directory_viewer.visit_target(split_cmd, open_in_background) dict range
        let l:start_line = v:count ? v:count : a:firstline
        let l:end_line   = v:count ? v:count : a:lastline

        let l:num_dir_targets = 0
        let l:selected_entries = []
        for l:cur_line in range(l:start_line, l:end_line)
            if !has_key(self.jump_map, l:cur_line)
                " call s:notifier.info("Line " . l:cur_line . " is not a valid navigation entry")
                return 0
            endif
            if isdirectory(self.jump_map[l:cur_line].full_path)
                let l:num_dir_targets += 1
            endif
            call add(l:selected_entries, self.jump_map[l:cur_line])
        endfor

        if l:num_dir_targets > 1 || (l:num_dir_targets == 1 && len(l:selected_entries) > 1)
            call s:notifier.info("Cannot open multiple selections that include directories")
            return 0
        endif

        if l:num_dir_targets == 1
            let l:cur_tab_num = tabpagenr()
            let l:entry = l:selected_entries[0]
            let l:target = l:entry.full_path
            if !isdirectory(l:target)
                call s:notifier.error("cannot open: '" . l:target . "'")
                return 0
            endif

            let isdotdot = l:entry.full_path =~# "\.\.[\\\/]$"
            let new_focus_file = isdotdot
                    \ ? s:base_dirname(self.focus_dir)
                    \ : (a:split_cmd ==# "edit"
                    \     ? get(self.default_targets, l:target, "")
                    \     : l:target)

            if a:split_cmd == "edit"
                call self.set_focus_dir(l:target, new_focus_file,  1)
            else
                if !a:open_in_background || a:split_cmd ==# "tabedit"
                    execute "silent keepalt keepjumps " . a:split_cmd . " " . bufname(self.prev_buf_num)
                else
                    execute "silent keepalt keepjumps " . a:split_cmd
                endif
                let d = s:new_dirvish()
                call d.open_dir(
                            \ l:target,
                            \ new_focus_file,
                            \ self.prev_buf_num,
                            \ self.prev_focus_dirs,
                            \ self.default_targets,
                            \ self.is_filtered,
                            \ self.filter_exp,
                            \ self.is_include_hidden,
                            \ )
                if a:open_in_background
                    execute "tabnext " . l:cur_tab_num
                    execute bufwinnr(self.buf_num) . "wincmd w"
                endif
            endif
        else
            call self.visit_files(l:selected_entries, a:split_cmd, a:open_in_background)
        endif
    endfunction

    function! l:directory_viewer.visit_files(selected_entries, split_cmd, open_in_background)
        if len(a:selected_entries) < 1
            return
        endif
        let l:cur_tab_num = tabpagenr()
        let old_lazyredraw = &lazyredraw
        set lazyredraw
        let l:split_cmd = a:split_cmd
        if !a:open_in_background
            execute 'silent keepalt keepjumps ' . self.prev_buf_num . 'buffer'
        endif
        let l:opened_files = []
        for l:entry in a:selected_entries
            let l:path_to_open = fnameescape(l:entry.full_path)
            try
                execute l:split_cmd . " " . l:path_to_open
            catch /E37:/
                call s:notifier.info("E37: No write since last change")
                return
            catch /E36:/
                " E36: no room for any new splits; open in-situ.
                let l:split_cmd = "edit"
                execute "edit " . l:path_to_open
            catch /E3/25:/
                call s:notifier.info("E325: swap file exists")
            endtry
            call add(l:opened_files, '"' . fnamemodify(l:entry.full_path, ':t') . '"')
        endfor
        if a:open_in_background
            execute "tabnext " . l:cur_tab_num
            execute bufwinnr(self.buf_num) . "wincmd w"
            if a:split_cmd == "edit"
                execute 'silent keepalt keepjumps ' . self.buf_num . 'buffer'
            endif
            redraw!
            if a:split_cmd == "edit"
                " It makes sense (to me, at least) to go to the last buffer
                " selected & opened upon closing FileBeagle when in this
                " combination of modes (i.e., split = 'edit' and in
                " background)
                let new_prev_buf_num = bufnr(a:selected_entries[-1].full_path)
                if new_prev_buf_num > 0
                    let self.prev_buf_num = new_prev_buf_num
                endif
                if len(l:opened_files) > 1
                    " Opening multiple in background of same window is a little
                    " cryptic so in this special case, we issue some feedback
                    echo join(l:opened_files, ", ")
                endif
            endif
        endif
        let &lazyredraw = l:old_lazyredraw
    endfunction

    function! l:directory_viewer.visit_parent_dir() dict
        let pdir = s:parent_dir(self.focus_dir)
        echom 'dir:' self.focus_dir 'parent:' pdir
        if pdir ==# self.focus_dir
            call s:notifier.info("no parent directory")
            return
        endif

        call filebeagle#open(pdir)
    endfunction

    function! l:directory_viewer.visit_prev_dir() dict
        echoerr 'TODO: buggy/not implemented'
        return

        if empty(self.prev_focus_dirs)
            call s:notifier.info("no previous directory")
        else
            let new_focus_file = self.prev_focus_dirs[-1][1]
            call remove(self.prev_focus_dirs, -1)
            call self.set_focus_dir(new_focus_dir, new_focus_file, 0)
        endif
    endfunction

    function! l:directory_viewer.goto_pattern(pattern) dict
        let full_pattern = '^\V\C' . escape(a:pattern, '/\') . '$'
        call search(full_pattern, "cw")
    endfunction

    function! l:directory_viewer.set_filter_exp() dict
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

    function! l:directory_viewer.toggle_filter() dict
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

    function! l:directory_viewer.toggle_hidden() dict
        if self.is_include_hidden
            let self.is_include_hidden = 0
            call s:notifier.info("excluding hidden files")
        else
            let self.is_include_hidden = 1
            call s:notifier.info("showing hidden files")
        endif
        call self.render_buffer()
    endfunction

    return l:directory_viewer
endfunction

function! filebeagle#open(dir)
    " if exists("b:dirvish")
    "   call s:notifier.info("already open")
    "   return
    " endif

    let dir = empty(a:dir)
            \ ? (empty(expand("%", 1)) ? getcwd() : expand('%:p:h', 1))
            \ : fnamemodify(a:dir, ":p")

    if !isdirectory(dir)
        call s:notifier.error("invalid directory: '" . dir . "'")
        return
    endif

    let d = s:new_dirvish()

    if !exists('b:dirvish')
        let d.orig_alt_buf_num = bufnr('#') " remember alt buffer before clobbering.
    endif

    call d.open_dir(
                \ dir,
                \ bufname("%"),
                \ bufnr("%"),
                \ [],
                \ {},
                \ 0,
                \ "",
                \ g:filebeagle_show_hidden
                \)
endfunction

unlet! s:notifier
let s:notifier = s:new_notifier("")

" vim:foldlevel=4:
