dirvish.vim :zap:
=================

Path navigator designed to work with Vim's built-in mechanisms and
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired).

Features
--------

- _Simple:_ Each line is just a filepath
- _Flexible:_ Mash up the buffer with `:g`, automate it with `g:dirvish_mode`
- _Safe:_ Never modifies the filesystem
- Preserves the alternate buffer `@#` (and original buffer)
- Non-intrusive defaults
- 2x faster than netrw
- Visual selection opens multiple files
- `:Shdo` generates a shell script on selected files
- `:Shdo!` generates a shell script on the Vim arglist
- Less code, fewer bugs (96% smaller than netrw)
- Compatible with Vim 7.2+

Concepts
--------

Each line is a filepath (hidden by
[conceal](https://neovim.io/doc/user/syntax.html#conceal)).

- Use plain old `y` to yank the path under the cursor, then feed it to `:r` or
  `:e` or whatever.
- Sort with `:sort`, filter with `:global`. Press `R` to reload.
- Instead of special "mark" commands, just add to the arglist, then `:Shdo!`.
    - Or add lines to quickfix (`:'<,'>caddb`) and iterate them (`:cdo`).
- `:set ft=dirvish` on any buffer to enable Dirvish features. Try this:
  ```
  git ls-files | vim +'setf dirvish' -
  ```
- Built-in commands like `gf` and `CTRL-W f` work.

Each Dirvish buffer name is the _actual directory name_, so commands and
plugins that work with `@%` and `@#` do the Right Thing.

- Create directories: `:!mkdir %foo`
- Create files: `:e %foo.txt`
- Enable fugitive (so `:Gstatus` works): `autocmd FileType dirvish call fugitive#detect(@%)`

Credits
-------

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle) (and completely
rewritten). Thanks to @jeetsukumaran.

Screenshots
-------
##### Using [Goyo](https://github.com/junegunn/goyo.vim)
<a href="https://imgur.com/XctfyOF"><img src="https://i.imgur.com/XctfyOF.png" title="source: imgur.com" /></a>
##### Normal
<a href="https://imgur.com/VD9sVLK"><img src="https://i.imgur.com/VD9sVLK.png" title="source: imgur.com" /></a>
