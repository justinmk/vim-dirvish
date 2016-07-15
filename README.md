dirvish.vim :zap:
=================

Minimalist "path navigator" designed to work with Vim's built-in mechanisms and
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired).

- _Status:_ 1.0 "Release Candidate".

Features
--------

- _simple:_ each line is literally just a filepath
- _flexible:_ mash up the buffer with `:g` and friends
- _safe:_ never modifies the filesystem
- original and alternate buffers are preserved
- meticulous, non-intrusive defaults
- 2x faster than netrw (try a directory with 1000+ items)
- visual selection opens multiple files
- `:Shdo` performs any shell command on selected files
- less code, fewer bugs (96% smaller than netrw)
- compatible with Vim 7.2+

Concepts
--------

Each line is an absolute filepath (hidden by
[conceal](https://neovim.io/doc/user/syntax.html#conceal)).

- Use plain old `y` to yank the path under the cursor, then feed it to `:r` or
  `:e` or whatever.
- Sort with `:sort` and filter with `:global`. Press `R` to reload.
- Instead of netrw's special mark/move commands, you can:
  `:!mv <c-r><c-a> <c-r><c-a>foo`
    - Or add lines to the quickfix list (`:'<,'>caddb`) and iterate them
      (`:cdo`, `:cfdo`).
- `:set ft=dirvish` on _any_ text to enable Dirvish features. Try this:
  `git ls-files|vim +'setf dirvish' -`

Each Dirvish buffer name is the _actual directory name_, so commands and
plugins (fugitive.vim) that work with `@%` and `@#` do the Right Thing.

- Create directories with `:!mkdir %foo`.
- Create files with `:e %foo.txt`
- Enable fugitive: `autocmd FileType dirvish call fugitive#detect(@%)`

Credits
-------

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle). Thanks to @jeetsukumaran.
