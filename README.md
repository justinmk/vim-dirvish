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
- `:Shdo!` generates a shell script on the local [arglist](https://neovim.io/doc/user/editing.html#arglist)
- Less code, fewer bugs (96% smaller than netrw)
- Compatible with Vim 7.2+

Concepts
--------

**Lines are filepaths** (hidden by [conceal](https://neovim.io/doc/user/syntax.html#conceal)).

- Use plain old `y` to yank a path, then feed it to `:r` or `:e` or whatever.
- Sort with `:sort`, filter with `:global`. Hit `R` to reload.
- For complex scripting, `:Shdo!` (with `!`) operates on the local arglist.
- Add lines to quickfix (`:'<,'>caddb`) and iterate (`:cdo`).
- `:set ft=dirvish` on any buffer to enable Dirvish features:
  ```
  git ls-files | vim +'setf dirvish' -
  ```

**Buffer name is the directory name.**  So commands and plugins that work with
`@%` and `@#` do the Right Thing.

- Create directories:
  ```
  :!mkdir %foo
  ```
- Create files:
  ```
  :e %foo.txt
  ```
- Use `@#` to get the Dirvish buffer from a `:Shdo` buffer:
  ```
  :Shdo
  mkdir <C-R>#.bk
  Z!
  ```

**Edit Dirvish buffers** for any purpose. It's safe and reversible.

- Use `:sort` or `:global` to re-arrange the view, delete lines with `d`, etc.
  Then `:%Shdo` the result.
- Pipe to `:!` to see inline results:
  ```
  :'<,'>!xargs du -hs
  ```
- Type `u` to undo, or `R` to reload.


Extensions
----------

Some people have created plugins that extend Dirvish.

- [remote-viewer](https://github.com/bounceme/remote-viewer) - Browse `ssh://` and other remote paths
- [vim-dirvish-git](https://github.com/kristijanhusak/vim-dirvish-git) - Show git status of each file
- [vim-dirvinist](https://github.com/fsharpasharp/vim-dirvinist) - List files defined by projections


Credits
-------

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle) (and completely
rewritten). Thanks to @jeetsukumaran.
