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

" Global Plugin Options {{{1
" =============================================================================
if !exists("g:filebeagle_autodismiss_on_select")
    let g:filebeagle_autodismiss_on_select = 1
endif
if !exists("g:filebeagle_sort_regime")
    let g:filebeagle_sort_regime = 'fl'
endif
if !exists("g:filebeagle_context_size")
    let g:filebeagle_context_size = [4, 4]
endif
if !exists("g:filebeagle_viewport_split_policy")
    let g:filebeagle_viewport_split_policy = "B"
endif
if !exists("g:filebeagle_move_wrap")
    let g:filebeagle_move_wrap  = 1
endif
if !exists("g:filebeagle_flash_jumped_line")
    let g:filebeagle_flash_jumped_line  = 1
endif
" }}}1

" Script Data and Variables {{{1
" =============================================================================

"  Display column sizes {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" Display columns.
let s:filebeagle_lnum_field_width = 6
let s:filebeagle_entry_label_field_width = 4
" TODO: populate the following based on user setting, as well as allow
" abstraction from the actual Vim command (e.g., option "top" => "zt")
let s:filebeagle_post_move_cmd = "normal! zz"

" }}}2

" Split Modes {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" Split modes are indicated by a single letter. Upper-case letters indicate
" that the SCREEN (i.e., the entire application "window" from the operating
" system's perspective) should be split, while lower-case letters indicate
" that the VIEWPORT (i.e., the "window" in Vim's terminology, referring to the
" various subpanels or splits within Vim) should be split.
" Split policy indicators and their corresponding modes are:
"   ``/`d`/`D'  : use default splitting mode
"   `n`/`N`     : NO split, use existing window.
"   `L`         : split SCREEN vertically, with new split on the left
"   `l`         : split VIEWPORT vertically, with new split on the left
"   `R`         : split SCREEN vertically, with new split on the right
"   `r`         : split VIEWPORT vertically, with new split on the right
"   `T`         : split SCREEN horizontally, with new split on the top
"   `t`         : split VIEWPORT horizontally, with new split on the top
"   `B`         : split SCREEN horizontally, with new split on the bottom
"   `b`         : split VIEWPORT horizontally, with new split on the bottom
let s:filebeagle_viewport_split_modes = {
            \ "d"   : "sp",
            \ "D"   : "sp",
            \ "N"   : "buffer",
            \ "n"   : "buffer",
            \ "L"   : "topleft vert sbuffer",
            \ "l"   : "leftabove vert sbuffer",
            \ "R"   : "botright vert sbuffer",
            \ "r"   : "rightbelow vert sbuffer",
            \ "T"   : "topleft sbuffer",
            \ "t"   : "leftabove sbuffer",
            \ "B"   : "botright sbuffer",
            \ "b"   : "rightbelow sbuffer",
            \ }
" }}}2

" }}}1

" Utilities {{{1
" ==============================================================================

" Text Formatting {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function! s:Format_AlignLeft(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return a:text . l:fill
endfunction

function! s:Format_AlignRight(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return l:fill . a:text
endfunction

function! s:Format_Time(secs)
    if exists("*strftime")
        return strftime("%Y-%m-%d %H:%M:%S", a:secs)
    else
        return (localtime() - a:secs) . " secs ago"
    endif
endfunction

function! s:Format_EscapedFilename(file)
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

" trunc: -1 = truncate left, 0 = no truncate, +1 = truncate right
function! s:Format_Truncate(str, max_len, trunc)
    if len(a:str) > a:max_len
        if a:trunc > 0
            return strpart(a:str, a:max_len - 4) . " ..."
        elseif a:trunc < 0
            return '... ' . strpart(a:str, len(a:str) - a:max_len + 4)
        endif
    else
        return a:str
    endif
endfunction

" Pads/truncates text to fit a given width.
" align: -1/0 = align left, 0 = no align, 1 = align right
" trunc: -1 = truncate left, 0 = no truncate, +1 = truncate right
function! s:Format_Fill(str, width, align, trunc)
    let l:prepped = a:str
    if a:trunc != 0
        let l:prepped = s:Format_Truncate(a:str, a:width, a:trunc)
    endif
    if len(l:prepped) < a:width
        if a:align > 0
            let l:prepped = s:Format_AlignRight(l:prepped, a:width, " ")
        elseif a:align < 0
            let l:prepped = s:Format_AlignLeft(l:prepped, a:width, " ")
        endif
    endif
    return l:prepped
endfunction

" }}}2

" Messaging {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function! s:NewMessenger(name)

    " allocate a new pseudo-object
    let l:messenger = {}
    let l:messenger["name"] = a:name
    if empty(a:name)
        let l:messenger["title"] = "filebeagle"
    else
        let l:messenger["title"] = "filebeagle (" . l:messenger["name"] . ")"
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
    let d = fnamemodify(a:current_dir . "/..", ":p")
    return d
endfunction

function! s:GetCurrentParentDirEntry(current_dir)
    let entry = {
                \ "full_path" : s:parent_dir(a:current_dir),
                \ "basename" : "..",
                \ "is_dir" : 1
                \ }
    return entry
endfunction

function! s:DiscoverPaths(current_dir, glob_pattern)
    let paths = split(globpath(a:current_dir, a:glob_pattern), '\n')
    let dir_paths = []
    let file_paths = []
    " call add(dir_paths, s:GetCurrentDirEntry(a:current_dir))
    call add(dir_paths, s:GetCurrentParentDirEntry(a:current_dir))
    for path in paths
        let full_path = fnamemodify(path, ":p")
        let basename = fnamemodify(path, ":t")
        let entry = { "full_path": full_path, "basename" : basename }
        if isdirectory(path)
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

" }}}1

" DirectoryViewer {{{1
" ==============================================================================

function! s:GetNewBufferName()
    let stemname = "filebeagle"
    let idx = 1
    let bname = stemname
    while bufnr(bname, 0) != -1
        let idx = idx + 1
        let bname = stemname . "-" . string(idx)
    endwhile
    return bname
endfunction

" Display the catalog.
function! s:NewDirectoryViewer()

    " initialize
    let l:directory_viewer = {}

    " Initialize object state.
    let l:directory_viewer["buf_name"] = s:GetNewBufferName()
    let l:directory_viewer["buf_num"] = bufnr(l:directory_viewer["buf_name"], 1)

    " Opens the buffer for viewing, creating it if needed. If non-empty first
    " argument is given, forces re-rendering of buffer.
    function! l:directory_viewer.open(...) dict
        " save previous buffer
        let prev_buf_num = bufnr('%')
        if a:0 == 0
            let root_dir = expand('%:p:h')
        else
            let root_dir = fnamemodify(a:1, ":p")
        endif
        if exists("self['root_dir']")
            let self.prev_root_dir = self.root_dir
        else
            let self.prev_root_dir = root_dir
        endif
        let self.root_dir = root_dir
        " get a new buf reference
        " get a viewport onto it
        execute("silent keepalt keepjumps buffer " . self.buf_num)
        " Sets up buffer environment.
        let b:filebeagle_directory_viewer = self
        call self.setup_buffer_opts()
        call self.setup_buffer_syntax()
        call self.setup_buffer_commands()
        call self.setup_buffer_keymaps()
        call self.setup_buffer_statusline()
        let self.prev_buf_num = prev_buf_num
        " render it
        call self.render_buffer()
    endfunction

    " Sets buffer options.
    function! l:directory_viewer.setup_buffer_opts() dict
        setlocal buftype=nofile
        setlocal noswapfile
        setlocal nowrap
        set bufhidden=hide
        setlocal nobuflisted
        setlocal nolist
        setlocal noinsertmode
        " setlocal nonumber
        setlocal cursorline
        setlocal nospell
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

        """ Index buffer management
        noremap <buffer> <silent> r       :call b:filebeagle_directory_viewer.refresh()<CR>
        noremap <buffer> <silent> q       :call b:filebeagle_directory_viewer.close()<CR>
        noremap <buffer> <silent> <ESC>   :call b:filebeagle_directory_viewer.close()<CR>

        """ Selection: show target and switch focus
        noremap <buffer> <silent> <CR>  :call b:filebeagle_directory_viewer.visit_target("edit")<CR>
        noremap <buffer> <silent> o     :call b:filebeagle_directory_viewer.visit_target("edit")<CR>
        noremap <buffer> <silent> s     :call b:filebeagle_directory_viewer.visit_target("vert sp")<CR>
        noremap <buffer> <silent> <C-v> :call b:filebeagle_directory_viewer.visit_target("vert sp")<CR>
        noremap <buffer> <silent> i     :call b:filebeagle_directory_viewer.visit_target("sp")<CR>
        noremap <buffer> <silent> <C-s> :call b:filebeagle_directory_viewer.visit_target("sp")<CR>
        noremap <buffer> <silent> t     :call b:filebeagle_directory_viewer.visit_target("tabedit")<CR>
        noremap <buffer> <silent> <C-t> :call b:filebeagle_directory_viewer.visit_target("tabedit")<CR>

        """ Directory changing
        noremap <buffer> <silent> -  :call b:filebeagle_directory_viewer.visit_parent_dir()<CR>
        noremap <buffer> <silent> <BS>  :call b:filebeagle_directory_viewer.visit_prev_dir()<CR>

        """ File operations
        noremap <buffer> <silent> +     :call b:filebeagle_directory_viewer.new_file(b:filebeagle_directory_viewer.root_dir, 0, 1)<CR>
        noremap <buffer> <silent> a     :call b:filebeagle_directory_viewer.new_file(b:filebeagle_directory_viewer.root_dir, 1, 0)<CR>

    endfunction

    " Sets buffer status line.
    function! l:directory_viewer.setup_buffer_statusline() dict
        setlocal statusline=%{FileBeagleStatusLineCurrentLineInfo()}
    endfunction

    " Populates the buffer with the catalog index.
    function! l:directory_viewer.render_buffer() dict
        setlocal modifiable
        call self.clear_buffer()
        let self.jump_map = {}
        call self.setup_buffer_syntax()
        let paths = s:DiscoverPaths(self.root_dir, "*")
        for path in paths[0] + paths[1]
            let l:line_map = {
                        \ "full_path" : path["full_path"],
                        \ "basename" : path["basename"],
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
        " call self.goto_index_entry("n", 0, 1)
    endfunction

    " Close and quit the viewer.
    function! l:directory_viewer.close() dict
        execute "b " . self.prev_buf_num
        execute "bwipe " . self.buf_num
    endfunction

    " Clears the buffer contents.
    function! l:directory_viewer.clear_buffer() dict
        call cursor(1, 1)
        exec 'silent! normal! "_dG'
    endfunction

    " from NERD_Tree, via VTreeExplorer: determine the number of windows open
    " to this buffer number.
    function! l:directory_viewer.num_viewports_on_buffer(bnum) dict
        let cnt = 0
        let winnum = 1
        while 1
            let bufnum = winbufnr(winnum)
            if bufnum < 0
                break
            endif
            if bufnum ==# a:bnum
                let cnt = cnt + 1
            endif
            let winnum = winnum + 1
        endwhile
        return cnt
    endfunction

    " Go to the line mapped to by the current line/index of the catalog
    " viewer.
    function! l:directory_viewer.visit_target(split_cmd) dict
        let l:cur_line = line(".")
        if !has_key(self.jump_map, l:cur_line)
            call s:_filebeagle_messenger.send_info("Not a valid navigation entry")
            return 0
        endif
        let l:target = self.jump_map[line(".")].full_path
        if self.jump_map[line(".")].is_dir
            call self.open(l:target)
        else
            call self.visit_path(l:target, a:split_cmd)
        endif
    endfunction

    function! l:directory_viewer.visit_path(full_path, split_cmd)
        execute "b " . self.prev_buf_num
        execute a:split_cmd . " " . fnameescape(a:full_path)
        execute "bwipe " . self.buf_num
    endfunction

    function! l:directory_viewer.visit_parent_dir() dict
        call self.open(s:parent_dir(self.root_dir))
    endfunction

    function! l:directory_viewer.visit_prev_dir() dict
        call self.open(self.prev_root_dir)
    endfunction

    function! l:directory_viewer.refresh() dict
        call self.render_buffer()
    endfunction

    function! l:directory_viewer.new_file(parent_dir, create, open) dict
        let new_fname = input("Add file: ".a:parent_dir)
        if !empty(new_fname)
            let new_fpath = a:parent_dir . new_fname
            if a:create
                if isdirectory(new_fpath)
                    call s:_filebeagle_messenger.send_error("Directory already exists: '" . new_fpath . "'")
                elseif filereadable(new_fpath) || !empty(glob(new_fpath))
                    call s:_filebeagle_messenger.send_error("File already exists: '" . new_fpath . "'")
                else
                    call writefile([], new_fpath)
                    call self.refresh()
                endif
            endif
            if a:open
                call self.visit_path(new_fpath, "edit")
            endif
        endif
    endfunction

    " return object
    return l:directory_viewer

endfunction

" }}}1

" Global Functions {{{1
" ==============================================================================

function! FileBeagleStatusLineCurrentLineInfo()
    if !exists("b:filebeagle_directory_viewer")
        return "[not a valid FileBeagle viewer]"
    endif
    let l:status_line = '[[FileBeagle]] "' . b:filebeagle_directory_viewer.root_dir . '" '
    " if b:buffersaurus_catalog_viewer.filter_regime && !empty(b:buffersaurus_catalog_viewer.filter_pattern)
    "     let l:status_line .= "*filtered* | "
    " endif
    " if has_key(b:buffersaurus_catalog_viewer.jump_map, l:line)
    "     let l:jump_line = b:buffersaurus_catalog_viewer.jump_map[l:line]
    "     if l:jump_line.entry_index >= 0
    "         let l:status_line .= string(l:jump_line.entry_index + 1) . " of " . b:buffersaurus_catalog_viewer.catalog.size()
    "         let l:status_line .= " | "
    "         let l:status_line .= 'File: "' . expand(bufname(l:jump_line.target[0]))
    "         let l:status_line .= '" (L:' . l:jump_line.target[1] . ', C:' . l:jump_line.target[2] . ')'
    "     else
    "         let l:status_line .= '(Indexed File) | "' . expand(bufname(l:jump_line.target[0])) . '"'
    "     endif
    " else
    "     let l:status_line .= "(not a valid indexed line)"
    " endif
    return l:status_line
endfunction
" }}}1

" Command Interface {{{1
" =============================================================================

function! filebeagle#FileBeagleOpen(root_dir)
    if exists("b:filebeagle_directory_viewer")
        " Do not open nested filebeagle viewers
        return
    endif
    let directory_viewer = s:NewDirectoryViewer()
    if empty(a:root_dir)
        let root_dir = getcwd()
    else
        let root_dir = a:root_dir
    endif
    call directory_viewer.open(root_dir)
endfunction

function! filebeagle#FileBeagleOpenCurrentBufferDir()
    if exists("b:filebeagle_directory_viewer")
        " Do not open nested filebeagle viewers
        return
    endif
    let directory_viewer = s:NewDirectoryViewer()
    let root_dir = expand('%:p:h')
    call directory_viewer.open(root_dir)
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
