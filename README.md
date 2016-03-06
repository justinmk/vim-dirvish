dirvish.vim :zap:
=================

Minimalist "path navigator" designed to work with Vim's built-in mechanisms and
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired).

---

Status: 1.0 "Release Candidate". 1.0 release will follow after some bake-time.

---

Features
--------

- _simple:_ each line is literally just a filepath
- _flexible:_ mash up the buffer with `:g` and friends
- _safe:_ never modifies the filesystem
- original and _alternate_ buffers are preserved
- meticulous, non-intrusive defaults
- 2x faster than netrw (try a directory with 1000+ items)
- visual selection opens multiple files
- `:Shdo` performs any shell command on selected file(s)
- fewer bugs: 400 lines of code (netrw: 11000)
- compatible with Vim 7.2+

Each line is an absolute filepath (hidden by Vim's
[conceal](https://neovim.io/doc/user/syntax.html#conceal) feature).

- Create directories with `:!mkdir %foo`.
- Create files with `:e %foo.txt`
- Sort with `:sort` and filter with `:global`. Press `R` to reload.

Each Dirvish buffer name is the _actual directory name_, so commands and
plugins (fugitive.vim) that work with `@%` and `@#` do the Right Thing.

- Use plain old `y` to yank the path under the cursor, then feed it to `:r` or
  `:e` or whatever.
- Instead of netrw's super-special mark/move commands, you can `:!mv <c-r><c-a>
  <c-r><c-a>foo`.
    - Or add lines to the quickfix list (`:'<,'>caddb`) and iterate them
      (`:cdo`, `:cfdo`).
- `:set ft=dirvish` works on any text you throw at it.
  Try `git ls-files|vim +'setf dirvish' -`.

Acknowledgements
----------------

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle). Thanks to @jeetsukumaran.
