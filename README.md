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
- `:Shdo` performs any shell command on selected files
- Less code, fewer bugs (96% smaller than netrw)
- Compatible with Vim 7.2+

Concepts
--------

Each line is a filepath (hidden by
[conceal](https://neovim.io/doc/user/syntax.html#conceal)).

- Use plain old `y` to yank the path under the cursor, then feed it to `:r` or
  `:e` or whatever.
- Sort with `:sort`, filter with `:global`. Press `R` to reload.
- Instead of special mark/move commands, you can
  `:!mv <c-r><c-a> <c-r><c-a>foo`
    - Or add lines to the quickfix list (`:'<,'>caddb`) and iterate them
      (`:cdo`).
- `:set ft=dirvish` on _any_ text to enable Dirvish features. Try this:
  ```
  git ls-files | vim +'setf dirvish' -
  ```

Each Dirvish buffer name is the _actual directory name_, so commands and
plugins that work with `@%` and `@#` do the Right Thing.

- Create directories: `:!mkdir %foo`
- Create files: `:e %foo.txt`
- Enable fugitive: `autocmd FileType dirvish call fugitive#detect(@%)`

Credits
-------

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle) (and completely
rewritten). Thanks to @jeetsukumaran.
