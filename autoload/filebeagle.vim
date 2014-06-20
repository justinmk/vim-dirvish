""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""  FileBeagle
""
""  VINE (Vim Is Not Emacs) file system explorer.
""
""  Copyright 2014 Jeet Sukumaran.
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Compatibility Guard {{{1
" ============================================================================
let g:did_filebeagle = 1
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim
" }}}1

" Script Globals {{{1
" ============================================================================
if has("win32")
    let s:sep = '\'
    let s:sep_as_pattern = '\\'
else
    let s:sep = '/'
    let s:sep_as_pattern = '/'
endif
" }}}1

" Utilities {{{1
" ==============================================================================

" Messaging {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function! s:NewMessenger(name)

    " allocate a new pseudo-object
    let l:messenger = {}
    let l:messenger["name"] = a:name
    if empty(a:name)
        let l:messenger["title"] = "FileBeagle"
    else
        let l:messenger["title"] = "FileBeagle (" . l:messenger["name"] . ")"
    endif

    function! l:messenger.format_message(leader, msg) dict
        return self.title . ": " . a:leader.a:msg
    endfunction

    function! l:messenger.format_exception( msg) dict
        return a:msg
    endfunction

    function! l:messenger.send_error(msg) dict
        redraw
        echohl ErrorMsg
        echomsg self.format_message("[ERROR] ", a:msg)
        echohl None
    endfunction

    function! l:messenger.send_warning(msg) dict
        redraw
        echohl WarningMsg
        echomsg self.format_message("[WARNING] ", a:msg)
        echohl None
    endfunction

    function! l:messenger.send_status(msg) dict
        redraw
        echohl None
        echomsg self.format_message("", a:msg)
    endfunction

    function! l:messenger.send_info(msg) dict
        redraw
        echohl None
        echo self.format_message("", a:msg)
    endfunction

    return l:messenger

endfunction
" }}}2

" Path Discovery {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function! s:parent_dir(current_dir)
    let l:current_dir = fnamemodify(a:current_dir, ":p")
    if has("win32")
        let d = join(split(l:current_dir, s:sep_as_pattern)[:-2], s:sep)
        if empty(d)
            let d = a:current_dir
        endif
        if d =~ ":$"
            let d = d . s:sep
        endif
    else
        let d = s:sep . join(split(l:current_dir, s:sep_as_pattern)[:-2], s:sep)
    endif
    return d
endfunction

function! s:base_dirname(dirname)
    let l:dirname = fnamemodify(a:dirname, ":p")
    if l:dirname == s:sep
        return s:sep
    endif
    let d = split(l:dirname, s:sep_as_pattern)[-1] . s:sep
    return d
endfunction

function! s:is_path_exists(path)
    if filereadable(a:path) || !empty(glob(a:path))
        return 1
    else
        return 0
    endif
endfunction

function! s:build_current_parent_dir_entry(current_dir)
    let parent = s:parent_dir(a:current_dir)
    let entry = {
                \ "full_path" : parent,
                \ "basename" : "..",
                \ "dirname" : fnamemodify(parent, ":h"),
                \ "is_dir" : 1
                \ }
    return entry
endfunction

function! s:discover_paths(current_dir, glob_pattern, is_include_hidden, is_include_ignored)
    let old_wildignore = &wildignore
    let old_suffixes = &suffixes
    if a:is_include_ignored
        let &wildignore = ""
        let &suffixes = ""
    endif
    if a:is_include_hidden
        let path_str = glob(a:current_dir.s:sep.'.[^.]'.a:glob_pattern)."\n".glob(a:current_dir.s:sep.a:glob_pattern)
    else
        let path_str = glob(a:current_dir.s:sep.a:glob_pattern)
    endif
    let paths = split(path_str, '\n')
    call sort(paths)
    let &wildignore = old_wildignore
    let &suffixes = old_suffixes
    let dir_paths = []
    let file_paths = []
    " call add(dir_paths, s:GetCurrentDirEntry(a:current_dir))
    call add(dir_paths, s:build_current_parent_dir_entry(a:current_dir))
    for path_entry in paths
        let path_entry = substitute(path_entry, s:sep_as_pattern.'\+', s:sep, 'g')
        let full_path = fnamemodify(path_entry, ":p")
        let basename = fnamemodify(path_entry, ":t")
        let dirname = fnamemodify(path_entry, ":h")
        let entry = { "full_path": full_path, "basename" : basename, "dirname" : dirname}
        if isdirectory(path_entry)
            let entry["is_dir"] = 1
            call add(dir_paths, entry)
        else
            let entry["is_dir"] = 0
            call add(file_paths, entry)
        endif
    endfor
    return [dir_paths, file_paths]
endfunction
" }}}2

" FileBeagle Buffer Management {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function! s:get_filebeagle_buffer_name()
    let stemname = "filebeagle"
    let idx = 1
    let bname = stemname
    while bufnr(bname, 0) != -1
        let idx = idx + 1
        let bname = stemname . "-" . string(idx)
    endwhile
    return bname
endfunction
" }}}2

" Global Support Functions {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function! FileBeagleCompleteNewFileName(A, L, P)
    if !exists("b:filebeagle_directory_viewer")
        return ""
    endif
    let basenames = []
    for key in keys(b:filebeagle_directory_viewer.jump_map)
        let entry = b:filebeagle_directory_viewer.jump_map[key]
        if !entry.is_dir
            call add(basenames, entry.basename)
        endif
    endfor
    return join(basenames, "\n")
endfunction
" }}}2


" }}}1

" DirectoryViewer {{{1
" ==============================================================================

" Display the catalog.
function! s:NewDirectoryViewer()

    " initialize
    let l:directory_viewer = {}

    " Initialize object state.
    if has("title")
        let l:directory_viewer["old_titlestring"] = &titlestring
    else
        let l:directory_viewer["old_titlestring"] = ""
    endif

    " filebeagle_buf_num, int
    "   - The buffer number to use, or -1 if we should generate and use our
    "     own buffer.
    " focus_dir, string
    "   - The full path to the directory being listed/viewed
    " focus_file, string
    "   - The full path to the file or directory that is should be the initial
    "     target or focus
    " calling_buf_num, int
    "   - The buffer number of the buffer from which FileBeagle was invoked.
    "     If `filebeagle_buf_num` > -1, and `calling_buf_num` ==
    "     `filebeagle_buf_num`, generally it is because FileBeagle was
    "     automagically invoked as a result of Vim being called upon to edit a
    "     directory.
    " prev_focus_dirs, list of tuples, [ (string, string) ]
    "   - The history stack, with the first element of the tuple being the
    "     directory previously visited and the second element of the tuple being
    "     the last selected entry in that directory
    " default_targets_for_directory, dictionary {string: string}
    "   - Keys are directories and values are the correspondign default target
    "     or selected item when that directory will be visited again.
    " is_filtered, boolean
    "   - If 1, then entries will be filtered following `filter_exp` if
    "     `filter_exp` is not empty; otherwise, entries will not be filtered
    " filter_exp, regular expression pattern string
    "   - Regular expression pattern to be used to filter entries if
    "     `is_filtered` is 1
    " is_include_hidden, boolean
    "   -  If 1, hidden files and directories (paths beginning with '.') will
    "      be listed; otherwise, they will not be shown.
    " is_include_ignored, boolean
    "   -  If 1, files and directories matching patterns in ``wildignore``
    "      will be listed; otherwise, they will not be shown.
    function! l:directory_viewer.open_dir(
                \ filebeagle_buf_num,
                \ focus_dir,
                \ focus_file,
                \ calling_buf_num,
                \ prev_focus_dirs,
                \ default_targets_for_directory,
                \ is_filtered,
                \ filter_exp,
                \ is_include_hidden,
                \ is_include_ignored
                \) dict
        if a:filebeagle_buf_num == -1
            let self.buf_name = s:get_filebeagle_buffer_name()
            let self.buf_num = bufnr(self.buf_name, 1)
        else
            let self.buf_num = a:filebeagle_buf_num
            let self.buf_name = bufname(self.buf_num)
        endif
        let self.focus_dir = fnamemodify(a:focus_dir, ":p")
        let self.focus_file = fnamemodify(a:focus_file, ":p:t")
        if empty(a:calling_buf_num)
            let self.prev_buf_num = bufnr('%')
        else
            let self.prev_buf_num = a:calling_buf_num
        endif
        let self.prev_focus_dirs = deepcopy(a:prev_focus_dirs)
        let self.default_targets_for_directory = deepcopy(a:default_targets_for_directory)
        let self.is_include_hidden = a:is_include_hidden
        let self.is_include_ignored = a:is_include_ignored
        " get a new buf reference
        " get a viewport onto it
        execute "silent keepalt keepjumps buffer " . self.buf_num
        " Sets up buffer environment.
        let b:filebeagle_directory_viewer = self
        call self.setup_buffer_opts()
        call self.setup_buffer_syntax()
        call self.setup_buffer_commands()
        call self.setup_buffer_keymaps()
        call self.setup_buffer_statusline()
        " let self.prev_buf_num = prev_buf_num
        " set up filters
        let self.is_filtered = a:is_filtered
        let self.filter_exp = a:filter_exp
        " render it
        call self.render_buffer()
    endfunction

    " Sets buffer options.
    function! l:directory_viewer.setup_buffer_opts() dict

        if self.prev_buf_num != self.buf_num
            " Only set these if not directly editing a directory (i.e.,
            " replacing netrw)
            set bufhidden=hide
            setlocal nobuflisted
        endif

        if g:filebeagle_show_line_numbers == 0
            setlocal nonumber
        elseif g:filebeagle_show_line_numbers == 1
            setlocal number
        endif
        if g:filebeagle_show_line_relativenumbers == 0
            setlocal nornu
        elseif g:filebeagle_show_line_relativenumbers == 1
            setlocal rnu
        endif

        setlocal buftype=nofile
        setlocal noswapfile
        setlocal nowrap
        setlocal nolist
        setlocal noinsertmode
        setlocal cursorline
        setlocal nospell
        set ft=filebeagle
    endfunction

    " Sets buffer syntax.
    function! l:directory_viewer.setup_buffer_syntax() dict
        if has("syntax")
            syntax clear
            syn match FileBeagleDirectoryEntry              '^.*[/\\]$'
            highlight! link FileBeagleDirectoryEntry        Directory
        endif
    endfunction

    " Sets buffer commands.
    function! l:directory_viewer.setup_buffer_commands() dict
        command! -buffer -nargs=0 ClipPathname   :call b:filebeagle_directory_viewer.yank_target_name("full_path", "+")
        command! -buffer -nargs=0 ClipDirname    :call b:filebeagle_directory_viewer.yank_current_dirname("+")
    endfunction

    " Sets buffer key maps.
    function! l:directory_viewer.setup_buffer_keymaps() dict

        """" Disabling of unused modification keys
        for key in [".", "p", "P", "C", "x", "X", "r", "R", "i", "I", "a", "A", "D", "S", "U"]
            try
                execute "nnoremap <buffer> " . key . " <NOP>"
            catch //
            endtry
        endfor

        """ Directory listing buffer management
        nnoremap <buffer> <silent> r             :call b:filebeagle_directory_viewer.refresh()<CR>
        nnoremap <buffer> <silent> f             :call b:filebeagle_directory_viewer.set_filter_exp()<CR>
        nnoremap <buffer> <silent> F             :call b:filebeagle_directory_viewer.toggle_filter()<CR>
        nnoremap <buffer> <silent> gh            :call b:filebeagle_directory_viewer.toggle_hidden_and_ignored()<CR>
        nnoremap <buffer> <silent> q             :call b:filebeagle_directory_viewer.quit_buffer()<CR>
        nnoremap <buffer> <silent> <C-W>c        :call b:filebeagle_directory_viewer.close_window()<CR>
        nnoremap <buffer> <silent> <C-W><C-C>    :call b:filebeagle_directory_viewer.close_window()<CR>

        """ Directory listing splitting
        nnoremap <buffer> <silent> <C-W><C-V>    :call b:filebeagle_directory_viewer.new_viewer("vert sp")<CR>
        nnoremap <buffer> <silent> <C-W>v        :call b:filebeagle_directory_viewer.new_viewer("vert sp")<CR>
        nnoremap <buffer> <silent> <C-W>V        :call b:filebeagle_directory_viewer.new_viewer("vert sp")<CR>
        nnoremap <buffer> <silent> <C-W><C-S>    :call b:filebeagle_directory_viewer.new_viewer("sp")<CR>
        nnoremap <buffer> <silent> <C-W>s        :call b:filebeagle_directory_viewer.new_viewer("sp")<CR>
        nnoremap <buffer> <silent> <C-W>S        :call b:filebeagle_directory_viewer.new_viewer("sp")<CR>
        nnoremap <buffer> <silent> <C-W><C-T>    :call b:filebeagle_directory_viewer.new_viewer("tabedit")<CR>
        nnoremap <buffer> <silent> <C-W>t        :call b:filebeagle_directory_viewer.new_viewer("tabedit")<CR>
        nnoremap <buffer> <silent> <C-W>T        :call b:filebeagle_directory_viewer.new_viewer("tabedit")<CR>

        """ Open selected file/directory
        nnoremap <buffer> <silent> <CR>          :<C-U>call b:filebeagle_directory_viewer.visit_target("edit", 0)<CR>
        vnoremap <buffer> <silent> <CR>          :call b:filebeagle_directory_viewer.visit_target("edit", 0)<CR>
        nnoremap <buffer> <silent> o             :<C-U>call b:filebeagle_directory_viewer.visit_target("edit", 0)<CR>
        vnoremap <buffer> <silent> o             :call b:filebeagle_directory_viewer.visit_target("edit", 0)<CR>
        nnoremap <buffer> <silent> g<CR>         :<C-U>call b:filebeagle_directory_viewer.visit_target("edit", 1)<CR>
        vnoremap <buffer> <silent> g<CR>         :call b:filebeagle_directory_viewer.visit_target("edit", 1)<CR>
        nnoremap <buffer> <silent> go            :<C-U>call b:filebeagle_directory_viewer.visit_target("edit", 1)<CR>
        vnoremap <buffer> <silent> go            :call b:filebeagle_directory_viewer.visit_target("edit", 1)<CR>

        nnoremap <buffer> <silent> v             :<C-U>call b:filebeagle_directory_viewer.visit_target("vert sp", 0)<CR>
        vnoremap <buffer> <silent> v             :call b:filebeagle_directory_viewer.visit_target("vert sp", 0)<CR>
        nnoremap <buffer> <silent> <C-V>         :<C-U>call b:filebeagle_directory_viewer.visit_target("vert sp", 0)<CR>
        vnoremap <buffer> <silent> <C-V>         :call b:filebeagle_directory_viewer.visit_target("vert sp", 0)<CR>
        nnoremap <buffer> <silent> gv            :<C-U>call b:filebeagle_directory_viewer.visit_target("rightbelow vert sp", 1)<CR>
        vnoremap <buffer> <silent> gv            :call b:filebeagle_directory_viewer.visit_target("rightbelow vert sp", 1)<CR>
        nnoremap <buffer> <silent> g<C-V>        :<C-U>call b:filebeagle_directory_viewer.visit_target("rightbelow vert sp", 1)<CR>
        vnoremap <buffer> <silent> g<C-V>        :call b:filebeagle_directory_viewer.visit_target("rightbelow vert sp", 1)<CR>

        nnoremap <buffer> <silent> s             :<C-U>call b:filebeagle_directory_viewer.visit_target("sp", 0)<CR>
        vnoremap <buffer> <silent> s             :call b:filebeagle_directory_viewer.visit_target("sp", 0)<CR>
        nnoremap <buffer> <silent> <C-s>         :<C-U>call b:filebeagle_directory_viewer.visit_target("sp", 0)<CR>
        vnoremap <buffer> <silent> <C-s>         :call b:filebeagle_directory_viewer.visit_target("sp", 0)<CR>
        nnoremap <buffer> <silent> gs            :<C-U>call b:filebeagle_directory_viewer.visit_target("rightbelow sp", 1)<CR>
        vnoremap <buffer> <silent> gs            :call b:filebeagle_directory_viewer.visit_target("rightbelow sp", 1)<CR>
        nnoremap <buffer> <silent> g<C-s>        :<C-U>call b:filebeagle_directory_viewer.visit_target("rightbelow sp", 1)<CR>
        vnoremap <buffer> <silent> g<C-s>        :call b:filebeagle_directory_viewer.visit_target("rightbelow sp", 1)<CR>

        nnoremap <buffer> <silent> t             :<C-U>call b:filebeagle_directory_viewer.visit_target("tabedit", 0)<CR>
        vnoremap <buffer> <silent> t             :call b:filebeagle_directory_viewer.visit_target("tabedit", 0)<CR>
        nnoremap <buffer> <silent> <C-t>         :<C-U>call b:filebeagle_directory_viewer.visit_target("tabedit", 0)<CR>
        vnoremap <buffer> <silent> <C-t>         :call b:filebeagle_directory_viewer.visit_target("tabedit", 0)<CR>
        nnoremap <buffer> <silent> g<C-t>        :<C-U>call b:filebeagle_directory_viewer.visit_target("tabedit", 1)<CR>
        vnoremap <buffer> <silent> g<C-t>        :call b:filebeagle_directory_viewer.visit_target("tabedit", 1)<CR>

        """ Focal directory changing
        nnoremap <buffer> <silent> -             :call b:filebeagle_directory_viewer.visit_parent_dir()<CR>
        nnoremap <buffer> <silent> u             :call b:filebeagle_directory_viewer.visit_parent_dir()<CR>
        nnoremap <buffer> <silent> <BS>          :call b:filebeagle_directory_viewer.visit_prev_dir()<CR>
        nnoremap <buffer> <silent> b             :call b:filebeagle_directory_viewer.visit_prev_dir()<CR>

        """ File operations
        nnoremap <buffer> <silent> +             :call b:filebeagle_directory_viewer.new_file(b:filebeagle_directory_viewer.focus_dir, 1, 0)<CR>
        nnoremap <buffer> <silent> %             :call b:filebeagle_directory_viewer.new_file(b:filebeagle_directory_viewer.focus_dir, 0, 1)<CR>
        nnoremap <buffer> <silent> R             :<C-U>call b:filebeagle_directory_viewer.read_target("", 0)<CR>
        vnoremap <buffer> <silent> R             :call b:filebeagle_directory_viewer.read_target("", 0)<CR>
        nnoremap <buffer> <silent> 0r            :<C-U>call b:filebeagle_directory_viewer.read_target("0", 0)<CR>
        vnoremap <buffer> <silent> 0r            :call b:filebeagle_directory_viewer.read_target("0", 0)<CR>
        nnoremap <buffer> <silent> $r            :<C-U>call b:filebeagle_directory_viewer.read_target("$", 0)<CR>
        vnoremap <buffer> <silent> $r            :call b:filebeagle_directory_viewer.read_target("$", 0)<CR>
        nnoremap <buffer> <silent> g0r           :<C-U>call b:filebeagle_directory_viewer.read_target("0", 1)<CR>
        vnoremap <buffer> <silent> g0r           :call b:filebeagle_directory_viewer.read_target("0", 1)<CR>
        nnoremap <buffer> <silent> g$r           :<C-U>call b:filebeagle_directory_viewer.read_target("$", 1)<CR>
        vnoremap <buffer> <silent> g$r           :call b:filebeagle_directory_viewer.read_target("$", 1)<CR>
        nnoremap <buffer> <silent> gr            :<C-U>call b:filebeagle_directory_viewer.read_target("", 1)<CR>
        vnoremap <buffer> <silent> gr            :call b:filebeagle_directory_viewer.read_target("", 1)<CR>

        """ Directory Operations
        nnoremap <buffer> <silent> cd            :call b:filebeagle_directory_viewer.change_vim_working_directory(0)<CR>
        nnoremap <buffer> <silent> cl            :call b:filebeagle_directory_viewer.change_vim_working_directory(1)<CR>

    endfunction

    " Sets buffer status line.
    function! l:directory_viewer.setup_buffer_statusline() dict
        if has("statusline")
            let self.old_statusline=&l:statusline
            setlocal statusline=%{FileBeagleStatusLineCurrentDirInfo()}%=%{FileBeagleStatusLineFilterAndHiddenInfo()}
        else
            let self.old_statusline=""
        endif
    endfunction

    " Populates the buffer with the catalog index.
    function! l:directory_viewer.render_buffer() dict
        setlocal modifiable
        call self.clear_buffer()
        let self.jump_map = {}
        call self.setup_buffer_syntax()
        let paths = s:discover_paths(self.focus_dir, "*", self.is_include_hidden, self.is_include_ignored)
        for path in paths[0] + paths[1]
            if !path.is_dir && self.is_filtered && !empty(self.filter_exp) && (path["basename"] !~# self.filter_exp)
                continue
            endif
            let l:line_map = {
                        \ "full_path" : path["full_path"],
                        \ "basename" : path["basename"],
                        \ "dirname" : path["dirname"],
                        \ "is_dir" : path["is_dir"]
                        \ }
            let text = path["basename"]
            if path["is_dir"]
                let text .= s:sep
            endif
            let self.jump_map[line("$")] = l:line_map
            call append(line("$")-1, text)
        endfor
        let b:filebeagle_last_render_time = localtime()
        try
            " remove extra last line
            execute('normal! GV"_X')
        catch //
        endtry
        setlocal nomodifiable
        call cursor(1, 1)
        if has("title")
            let &titlestring = expand(self.focus_dir)
        endif
        let self.default_targets_for_directory[self.focus_dir] = self.focus_file
        call self.goto_pattern(self.focus_file)
    endfunction

    " Restore title and anything else changed
    function! l:directory_viewer.wipe_and_restore() dict
        if self.prev_buf_num != self.buf_num
            try
                execute "bwipe! " . self.buf_num
            catch // " E517: No buffers were wiped out
            endtry
            if has("statusline") && exists("self['old_statusline']")
                try
                    let &l:statusline=self.old_statusline
                catch //
                endtry
            endif
            " if has("title")
            "     let &titlestring = self.old_titlestring
            " endif
        endif
    endfunction

    " Close and quit the viewer.
    function! l:directory_viewer.quit_buffer() dict
        " if !isdirectory(bufname(self.prev_buf_num))
        if self.prev_buf_num == self.buf_num
            " Avoid switching back to calling buffer if it is a (FileBeagle) directory
            call s:_filebeagle_messenger.send_info("Directory buffer was created by Vim, not FileBeagle: type ':quit<ENTER>' to exit or ':bwipe<ENTER>' to delete")
        else
            execute "b " . self.prev_buf_num
        endif
        call self.wipe_and_restore()
    endfunction

    " Close and quit the viewer.
    function! l:directory_viewer.close_window() dict
        execute "bwipe"
        " if self.prev_buf_num != self.buf_num
        "     execute "b " . self.prev_buf_num
        " endif
        " call self.wipe_and_restore()
        " :close
    endfunction

    " Clears the buffer contents.
    function! l:directory_viewer.clear_buffer() dict
        call cursor(1, 1)
        exec 'silent! normal! "_dG'
    endfunction

    function! l:directory_viewer.read_target(pos, read_in_background) dict range
        if self.prev_buf_num == self.buf_num || isdirectory(bufname(self.prev_buf_num))
            call s:_filebeagle_messenger.send_error("Cannot read into a directory buffer")
            return 0
        endif
        if v:count == 0
            let l:start_line = a:firstline
            let l:end_line = a:lastline
        else
            let l:start_line = v:count
            let l:end_line = v:count
        endif
        let l:selected_entries = []
        for l:cur_line in range(l:start_line, l:end_line)
            if !has_key(self.jump_map, l:cur_line)
                call s:_filebeagle_messenger.send_info("Line " . l:cur_line . " is not a valid navigation entry")
                return 0
            endif
            if self.jump_map[l:cur_line].is_dir
                call s:_filebeagle_messenger.send_info("Reading directories into the current buffer is not supported at the current time")
                return 0
            endif
            call add(l:selected_entries, self.jump_map[l:cur_line])
        endfor
        if a:pos == "0"
            call reverse(l:selected_entries)
        endif
        let old_lazyredraw = &lazyredraw
        set lazyredraw
        execute "silent keepalt keepjumps buffer " . self.prev_buf_num
        for l:entry in l:selected_entries
            let l:path_to_open = fnameescape(l:entry.full_path)
            execute a:pos . "r " . l:path_to_open
        endfor
        if a:read_in_background
            execute "silent keepalt keepjumps buffer " .self.buf_num
        else
            call self.wipe_and_restore()
        endif
        let &lazyredraw = l:old_lazyredraw
    endfunction

    function! l:directory_viewer.new_viewer(split_cmd) dict
        let l:cur_tab_num = tabpagenr()
        execute "silent keepalt keepjumps " . a:split_cmd . " " . bufname(self.prev_buf_num)
        let directory_viewer = s:NewDirectoryViewer()
        call directory_viewer.open_dir(
                    \ -1,
                    \ self.focus_dir,
                    \ self.focus_file,
                    \ self.prev_buf_num,
                    \ self.prev_focus_dirs,
                    \ self.default_targets_for_directory,
                    \ self.is_filtered,
                    \ self.filter_exp,
                    \ self.is_include_hidden,
                    \ self.is_include_ignored
                    \ )
    endfunction

    function! l:directory_viewer.visit_target(split_cmd, open_in_background) dict range
        if v:count == 0
            let l:start_line = a:firstline
            let l:end_line = a:lastline
        else
            let l:start_line = v:count
            let l:end_line = v:count
        endif

        let l:num_dir_targets = 0
        let l:selected_entries = []
        for l:cur_line in range(l:start_line, l:end_line)
            if !has_key(self.jump_map, l:cur_line)
                call s:_filebeagle_messenger.send_info("Line " . l:cur_line . " is not a valid navigation entry")
                return 0
            endif
            if self.jump_map[l:cur_line].is_dir
                let l:num_dir_targets += 1
            endif
            call add(l:selected_entries, self.jump_map[l:cur_line])
        endfor

        if l:num_dir_targets > 1 || (l:num_dir_targets == 1 && len(l:selected_entries) > 1)
            call s:_filebeagle_messenger.send_info("Cannot open multiple selections that include directories")
            return 0
        endif

        if l:num_dir_targets == 1
            let l:cur_tab_num = tabpagenr()
            let l:entry = l:selected_entries[0]
            let l:target = l:entry.full_path
            if !isdirectory(l:target)
                call s:_filebeagle_messenger.send_error("Cannot open directory: '" . l:target . "'")
                return 0
            endif
            if l:entry.basename == ".."
                let new_focus_file = s:base_dirname(self.focus_dir)
            elseif a:split_cmd == "edit"
                let new_focus_file = get(self.default_targets_for_directory, l:target, "")
                " echo "Current (" . l:target . "): " . new_focus_file
                " for key in keys(self.default_targets_for_directory)
                "     echo "'".key."':'".self.default_targets_for_directory[key]."'"
                " endfor
            else
                let new_focus_file = l:target
            endif
            if a:split_cmd == "edit"
                call self.set_focus_dir(l:target, new_focus_file,  1)
            else
                if a:open_in_background
                    if a:split_cmd == "tabedit"
                        " execute "silent keepalt keepjumps " . a:split_cmd . " " . self.buf_name
                        execute "silent keepalt keepjumps " . a:split_cmd . " " . bufname(self.prev_buf_num)
                    else
                        execute "silent keepalt keepjumps " . a:split_cmd
                    endif
                else
                    execute "silent keepalt keepjumps " . a:split_cmd . " " . bufname(self.prev_buf_num)
                endif
                let directory_viewer = s:NewDirectoryViewer()
                call directory_viewer.open_dir(
                            \ -1,
                            \ l:target,
                            \ new_focus_file,
                            \ self.prev_buf_num,
                            \ self.prev_focus_dirs,
                            \ self.default_targets_for_directory,
                            \ self.is_filtered,
                            \ self.filter_exp,
                            \ self.is_include_hidden,
                            \ self.is_include_ignored
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

    function! l:directory_viewer.set_focus_dir(new_dir, focus_file, add_to_history) dict
        if a:add_to_history && exists("self['focus_dir']")
            if empty(self.prev_focus_dirs) || self.prev_focus_dirs[-1][0] != self.focus_dir
                call add(self.prev_focus_dirs, [self.focus_dir, self.focus_file])
            endif
        endif
        let self.focus_dir = fnamemodify(a:new_dir, ":p")
        let self.focus_file = a:focus_file
        call self.refresh()
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
            execute "silent keepalt keepjumps buffer " . self.prev_buf_num
        endif
        let l:opened_basenames = []
        for l:entry in a:selected_entries
            let l:path_to_open = fnameescape(l:entry.full_path)
            try
                execute l:split_cmd . " " . l:path_to_open
            catch /E36:/
                " E36: not enough room for any new splits: switch to
                " opening in-situ
                let l:split_cmd = "edit"
                try
                    execute l:split_cmd . " " . l:path_to_open
                catch /E325:/ "swap file exists
                endtry
            catch /E325:/ "swap file exists
            endtry
            call add(l:opened_basenames, '"' . fnameescape(l:entry.basename) . '"')
        endfor
        if a:open_in_background
            execute "tabnext " . l:cur_tab_num
            execute bufwinnr(self.buf_num) . "wincmd w"
            if a:split_cmd == "edit"
                execute "silent keepalt keepjumps buffer " .self.buf_num
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
                if len(l:opened_basenames) > 1
                    " Opening multiple in background of same window is a little
                    " cryptic so in this special case, we issue some feedback
                    echo join(l:opened_basenames, ", ")
                endif
            endif
        else
            call self.wipe_and_restore()
            redraw!
        endif
        let &lazyredraw = l:old_lazyredraw
    endfunction

    function! l:directory_viewer.visit_parent_dir() dict
        let pdir = s:parent_dir(self.focus_dir)
        if pdir != self.focus_dir
            let new_focus_file = s:base_dirname(self.focus_dir)
            call self.set_focus_dir(pdir, new_focus_file, 1)
        else
            call s:_filebeagle_messenger.send_info("No parent directory available")
        endif
    endfunction

    function! l:directory_viewer.visit_prev_dir() dict
        " if len(self.prev_focus_dirs) == 0
        if empty(self.prev_focus_dirs)
            call s:_filebeagle_messenger.send_info("No previous directory available")
        else
            let new_focus_dir = self.prev_focus_dirs[-1][0]
            let new_focus_file = self.prev_focus_dirs[-1][1]
            call remove(self.prev_focus_dirs, -1)
            call self.set_focus_dir(new_focus_dir, new_focus_file, 0)
        endif
    endfunction

    function! l:directory_viewer.yank_target_name(part, register) dict
        let l:cur_line = line(".")
        if !has_key(self.jump_map, l:cur_line)
            call s:_filebeagle_messenger.send_info("Not a valid path")
            return 0
        endif
        if a:part == "dirname"
            let l:target = self.jump_map[line(".")].dirname
        elseif a:part == "basename"
            let l:target = self.jump_map[line(".")].basename
        else
            let l:target = self.jump_map[line(".")].full_path
        endif
        execute "let @" . a:register . " = '" . fnameescape(l:target) . "'"
    endfunction

    function! l:directory_viewer.yank_current_dirname(register) dict
        execute "let @" . a:register . " = '" . fnameescape(self.focus_dir) . "'"
    endfunction

    function! l:directory_viewer.change_vim_working_directory(local) dict
        let l:target = self.focus_dir
        if a:local
            let l:cmd = "lcd"
        else
            let l:cmd = "cd"
        endif
        execute "b " . self.prev_buf_num
        call self.wipe_and_restore()
        execute l:cmd . " " . fnameescape(l:target)
        echomsg l:target
    endfunction

    function! l:directory_viewer.yank_current_dirname(register) dict
        execute "let @" . a:register . " = '" . fnameescape(self.focus_dir) . "'"
    endfunction

    function! l:directory_viewer.refresh() dict
        call self.render_buffer()
    endfunction

    function! l:directory_viewer.goto_pattern(pattern) dict
        " call cursor(1, 0)
        " let old_ignorecase = &ignorecase
        " set noignorecase
        let full_pattern = '^\V\C' . escape(a:pattern, '/\') . '\$'
        call search(full_pattern, "cw")
        " let &ignorecase = old_ignorecase
        " call cursor(lnum, 0)
    endfunction

    function! l:directory_viewer.new_file(parent_dir, create, open) dict
        call inputsave()
        let new_fname = input("Add file: ".a:parent_dir, "", "custom,FileBeagleCompleteNewFileName")
        call inputrestore()
        if !empty(new_fname)
            let new_fpath = a:parent_dir . new_fname
            if a:create
                if isdirectory(new_fpath)
                    call s:_filebeagle_messenger.send_error("Directory already exists: '" . new_fpath . "'")
                elseif s:is_path_exists(new_fpath)
                    call s:_filebeagle_messenger.send_error("File already exists: '" . new_fpath . "'")
                else
                    call writefile([], new_fpath)
                    call self.refresh()
                endif
            endif
            if a:open
                let entry = { "full_path": new_fpath, "basename" : new_fname, "dirname" : a:parent_dir, "is_dir": 0}
                call self.visit_files([entry], "edit", 0)
            else
                call self.goto_pattern(new_fname)
            endif
        endif
    endfunction

    function! l:directory_viewer.set_filter_exp() dict
        let self.filter_exp = input("Filter expression: ", self.filter_exp)
        if empty(self.filter_exp)
            let self.is_filtered = 0
            call s:_filebeagle_messenger.send_info("Filter OFF")
        else
            let self.is_filtered = 1
            call s:_filebeagle_messenger.send_info("Filter ON")
        endif
        call self.refresh()
    endfunction

    function! l:directory_viewer.toggle_filter() dict
        if self.is_filtered
            let self.is_filtered = 0
            call s:_filebeagle_messenger.send_info("Filter OFF")
            call self.refresh()
        else
            if !empty(self.filter_exp)
                let self.is_filtered = 1
                call s:_filebeagle_messenger.send_info("Filter ON")
                call self.refresh()
            else
                call self.set_filter_exp()
            endif
        endif
    endfunction

    function! l:directory_viewer.toggle_hidden_and_ignored() dict
        if self.is_include_hidden || self.is_include_ignored
            let self.is_include_hidden = 0
            let self.is_include_ignored = 0
            call s:_filebeagle_messenger.send_info("Not showing hidden/ignored files")
        else
            let self.is_include_hidden = 1
            let self.is_include_ignored = 1
            call s:_filebeagle_messenger.send_info("Showing hidden/ignored files")
        endif
        call self.refresh()
    endfunction

    " return object
    return l:directory_viewer

endfunction

" }}}1

" Status Line Functions {{{1
" ==============================================================================

function! FileBeagleStatusLineCurrentDirInfo()
    if !exists("b:filebeagle_directory_viewer")
        return ""
    endif
    let l:status_line = ' "' . b:filebeagle_directory_viewer.focus_dir . '" '
    return l:status_line
endfunction

function! FileBeagleStatusLineFilterAndHiddenInfo()
    if !exists("b:filebeagle_directory_viewer")
        return ""
    endif
    let l:status_line = ""
    if b:filebeagle_directory_viewer.is_include_hidden || b:filebeagle_directory_viewer.is_include_ignored
    else
        let l:status_line .= "[+HIDE]"
    endif
    if b:filebeagle_directory_viewer.is_filtered && !empty(b:filebeagle_directory_viewer.filter_exp)
        let l:status_line .= "[+FILTER:".b:filebeagle_directory_viewer.filter_exp . "]"
    endif
    return l:status_line
endfunction
" }}}1

" Command Interface {{{1
" =============================================================================

function! filebeagle#FileBeagleOpen(focus_dir, filebeagle_buf_num)
    if exists("b:filebeagle_directory_viewer")
        call s:_filebeagle_messenger.send_info("Use 'CTRL-W CTRL-V' or 'CTRL-W CTRL-S' to spawn a new FileBeagle viewer on the current directory")
        return
    endif
    let directory_viewer = s:NewDirectoryViewer()
    if empty(a:focus_dir)
        let focus_dir = getcwd()
    else
        let focus_dir = fnamemodify(a:focus_dir, ":p")
    endif
    if !isdirectory(focus_dir)
        call s:_filebeagle_messenger.send_error("Not a valid directory: '" . focus_dir . "'")
    else
        call directory_viewer.open_dir(
                    \ a:filebeagle_buf_num,
                    \ focus_dir,
                    \ bufname("%"),
                    \ bufnr("%"),
                    \ [],
                    \ {},
                    \ 0,
                    \ "",
                    \ g:filebeagle_show_hidden,
                    \ g:filebeagle_show_hidden
                    \)
    endif
endfunction

function! filebeagle#FileBeagleOpenCurrentBufferDir()
    if exists("b:filebeagle_directory_viewer")
        call s:_filebeagle_messenger.send_info("Use 'CTRL-W CTRL-V' or 'CTRL-W CTRL-S' to spawn a new FileBeagle viewer on the current directory")
        return
    endif
    if empty(expand("%"))
        call filebeagle#FileBeagleOpen(getcwd(), -1)
    else
        let directory_viewer = s:NewDirectoryViewer()
        let focus_dir = expand('%:p:h')
        call directory_viewer.open_dir(
                    \ -1,
                    \ focus_dir,
                    \ bufname("%"),
                    \ bufnr("%"),
                    \ [],
                    \ {},
                    \ 0,
                    \ "",
                    \ g:filebeagle_show_hidden,
                    \ g:filebeagle_show_hidden
                    \)
    endif
endfunction

" }}}1

" Global Initialization {{{1
" ==============================================================================
if exists("s:_filebeagle_messenger")
    unlet s:_filebeagle_messenger
endif
let s:_filebeagle_messenger = s:NewMessenger("")
" }}}1

" Restore State {{{1
" ============================================================================
" restore options
let &cpo = s:save_cpo
" }}}1

" vim:foldlevel=4:
