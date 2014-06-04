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

" function! s:GetCurrentDirEntry(current_dir)
"     let entry = {
"                 \ "full_path" : fnamemodify(a:current_dir, ":p"),
"                 \ "basename" : ".",
"                 \ "is_dir" : 1
"                 \ }
"     return entry
" endfunction

function! s:parent_dir(current_dir)
    let l:current_dir = fnamemodify(a:current_dir, ":p")
    " if l:current_dir[-1] != "/"
    "     let l:current_dir .= "/"
    " endif
    " let d = fnamemodify(l:current_dir . "../", ":p")
    " let d = fnamemodify(l:current_dir . "../", ":p")
    let d = "/" . join(split(l:current_dir, '/')[:-2], '/')
    return d
endfunction

function! s:base_dirname(dirname)
    let l:dirname = fnamemodify(a:dirname, ":p")
    if l:dirname == '/'
        return '/'
    endif
    let d = split(l:dirname, '/')[-1] . '/'
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
        let path_str = glob(a:current_dir.'/.[^.]'.a:glob_pattern)."\n".glob(a:current_dir.'/'.a:glob_pattern)
    else
        let path_str = glob(a:current_dir.'/'.a:glob_pattern)
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
        let path_entry = substitute(path_entry, '/\+', '/', 'g')
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
            syn match FileBeagleDirectoryEntry              '^.*/$'
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
        noremap <buffer> <silent> r       :call b:filebeagle_directory_viewer.refresh()<CR>
        noremap <buffer> <silent> f       :call b:filebeagle_directory_viewer.set_filter_exp()<CR>
        noremap <buffer> <silent> F       :call b:filebeagle_directory_viewer.toggle_filter()<CR>
        noremap <buffer> <silent> gh      :call b:filebeagle_directory_viewer.toggle_hidden_and_ignored()<CR>
        noremap <buffer> <silent> q       :call b:filebeagle_directory_viewer.close()<CR>
        noremap <buffer> <silent> <ESC>   :call b:filebeagle_directory_viewer.close()<CR>

        """ Directory listing splitting
        noremap <buffer> <silent> <C-W><C-V>  :call b:filebeagle_directory_viewer.new_viewer("vert sp")<CR>
        noremap <buffer> <silent> <C-W>v  :call b:filebeagle_directory_viewer.new_viewer("vert sp")<CR>
        noremap <buffer> <silent> <C-W>V  :call b:filebeagle_directory_viewer.new_viewer("vert sp")<CR>
        noremap <buffer> <silent> <C-W><C-S>  :call b:filebeagle_directory_viewer.new_viewer("sp")<CR>
        noremap <buffer> <silent> <C-W>s  :call b:filebeagle_directory_viewer.new_viewer("sp")<CR>
        noremap <buffer> <silent> <C-W>S  :call b:filebeagle_directory_viewer.new_viewer("sp")<CR>
        noremap <buffer> <silent> <C-W><C-T>  :call b:filebeagle_directory_viewer.new_viewer("tabedit")<CR>
        noremap <buffer> <silent> <C-W>t  :call b:filebeagle_directory_viewer.new_viewer("tabedit")<CR>
        noremap <buffer> <silent> <C-W>T  :call b:filebeagle_directory_viewer.new_viewer("tabedit")<CR>

        """ Selection: show target and switch focus
        noremap <buffer> <silent> <CR>  :<C-U>call b:filebeagle_directory_viewer.visit_target("edit")<CR>
        noremap <buffer> <silent> o     :<C-U>call b:filebeagle_directory_viewer.visit_target("edit")<CR>
        noremap <buffer> <silent> v     :<C-U>call b:filebeagle_directory_viewer.visit_target("vert sp")<CR>
        noremap <buffer> <silent> <C-v> :<C-U>call b:filebeagle_directory_viewer.visit_target("vert sp")<CR>
        noremap <buffer> <silent> s     :<C-U>call b:filebeagle_directory_viewer.visit_target("sp")<CR>
        noremap <buffer> <silent> <C-s> :<C-U>call b:filebeagle_directory_viewer.visit_target("sp")<CR>
        noremap <buffer> <silent> t     :<C-U>call b:filebeagle_directory_viewer.visit_target("tabedit")<CR>
        noremap <buffer> <silent> <C-t> :<C-U>call b:filebeagle_directory_viewer.visit_target("tabedit")<CR>

        """ Focal directory changing
        noremap <buffer> <silent> -  :call b:filebeagle_directory_viewer.visit_parent_dir()<CR>
        noremap <buffer> <silent> u  :call b:filebeagle_directory_viewer.visit_parent_dir()<CR>
        noremap <buffer> <silent> <BS>  :call b:filebeagle_directory_viewer.visit_prev_dir()<CR>
        noremap <buffer> <silent> b  :call b:filebeagle_directory_viewer.visit_prev_dir()<CR>

        """ File operations
        noremap <buffer> <silent> +     :call b:filebeagle_directory_viewer.new_file(b:filebeagle_directory_viewer.focus_dir, 0, 1)<CR>
        noremap <buffer> <silent> a     :call b:filebeagle_directory_viewer.new_file(b:filebeagle_directory_viewer.focus_dir, 1, 0)<CR>

        """ Directory Operations
        noremap <buffer> <silent> cd     :call b:filebeagle_directory_viewer.change_vim_working_directory(0)<CR>
        noremap <buffer> <silent> cl     :call b:filebeagle_directory_viewer.change_vim_working_directory(1)<CR>

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
                let text .= "/"
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
                execute "bwipe " . self.buf_num
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
    function! l:directory_viewer.close() dict
        " if !isdirectory(bufname(self.prev_buf_num))
        if self.prev_buf_num == self.buf_num
            " Avoid switching back to calling buffer if it is a (FileBeagle) directory
            call s:_filebeagle_messenger.send_info("Directory buffer was created by Vim, not FileBeagle: type ':quit<ENTER>' to exit or ':bwipe<ENTER>' to delete")
        else
            execute "b " . self.prev_buf_num
        endif
        call self.wipe_and_restore()
    endfunction

    " Clears the buffer contents.
    function! l:directory_viewer.clear_buffer() dict
        call cursor(1, 1)
        exec 'silent! normal! "_dG'
    endfunction

    function! l:directory_viewer.visit_target(split_cmd) dict range
        if v:count == 0
            let l:cur_line = line(".")
        else
            let l:cur_line = v:count
        endif
        if !has_key(self.jump_map, l:cur_line)
            call s:_filebeagle_messenger.send_info("Not a valid navigation entry")
            return 0
        endif
        let l:target = self.jump_map[l:cur_line].full_path
        if self.jump_map[l:cur_line].is_dir
            if self.jump_map[l:cur_line].basename == ".."
                let new_focus_file = s:base_dirname(self.focus_dir)
            elseif a:split_cmd == "edit"
                let new_focus_file = get(self.default_targets_for_directory, l:target, "")
            else
                let new_focus_file = l:target
            endif
            if a:split_cmd == "edit"
                call self.set_focus_dir(l:target, new_focus_file,  1)
            else
                execute "silent keepalt keepjumps " . a:split_cmd . " " . bufname(self.prev_buf_num)
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
            endif
        else
            call self.visit_file(l:target, a:split_cmd)
        endif
    endfunction

    function! l:directory_viewer.new_viewer(split_cmd) dict
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


    function! l:directory_viewer.set_focus_dir(new_dir, focus_file, add_to_history) dict
        if a:add_to_history && exists("self['focus_dir']")
            if empty(self.prev_focus_dirs) || self.prev_focus_dirs[-1][0] != self.focus_dir
                call add(self.prev_focus_dirs, [self.focus_dir, self.focus_file])
            endif
        endif
        let self.focus_dir = fnamemodify(a:new_dir, ":p")
        " let self.focus_file = fnamemodify(a:focus_file, ":p:t")
        let self.focus_file = a:focus_file
        call self.refresh()
    endfunction

    function! l:directory_viewer.visit_file(full_path, split_cmd)
        execute "b " . self.prev_buf_num
        execute a:split_cmd . " " . fnameescape(a:full_path)
        call self.wipe_and_restore()
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
        let old_ignorecase = &ignorecase
        set noignorecase
        " let lnum = search("^" . a:pattern . "$", "cwn")
        call search("^" . a:pattern . "$", "cw")
        let &ignorecase = old_ignorecase
        " call cursor(lnum, 0)
    endfunction

    function! l:directory_viewer.new_file(parent_dir, create, open) dict
        let new_fname = input("Add file: ".a:parent_dir)
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
                call self.visit_file(new_fpath, "edit")
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
        let focus_dir = a:focus_dir
    endif
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
endfunction

function! filebeagle#FileBeagleOpenCurrentBufferDir()
    if exists("b:filebeagle_directory_viewer")
        call s:_filebeagle_messenger.send_info("Use 'CTRL-W CTRL-V' or 'CTRL-W CTRL-S' to spawn a new FileBeagle viewer on the current directory")
        return
    endif
    if empty(expand("%"))
        call filebeagle#FileBeagleOpen(getcwd())
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
