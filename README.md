# dirvish.vim :zap:

---

Status: 1.0 "Release Candidate". 1.0 release will follow after some bake-time.

---

Dirvish is a minimalist _path navigator_ for Vim, designed with the philosophy
that plugins should harmonize with Vim's built-in mechanisms and with
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired) instead of re-inventing
dead-end imitations.

Re-use and composition of concepts multiplies the utility of those concepts;
if a plugin does _not_ reuse a concept, both that concept _and_ the new,
redundant mechanism are made mutually _less valuable_—the sum is less than
the parts—because the user now must learn or choose from two slightly
different things instead of one augmented system. @tpope's plugins demonstrate
this theme; more plugins should too.

## Features

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

Each line in a Dirvish buffer is an absolute filepath (hidden by Vim's
_conceal_ feature). Each Dirvish buffer name is the _actual directory name_, so
Vim commands and plugins (fugitive.vim) that work with the buffer name do the
Right Thing.

- Create directories with `:!mkdir %foo`.
- Create files with `:e %foo.txt`
- Use plain old `y` to yank the path under the cursor, then feed it to `:r` or
  `:e` or whatever.
- Instead of netrw's super-special mark/move commands, you can `:!mv <c-r><c-a>
  <c-r><c-a>foo`.
    - Or add lines to the quickfix list (`:'<,'>caddb`) and iterate them
      (`:cdo`, `:cfdo`).
- `:set ft=dirvish` works on _any_ list of files. Try
  `git ls-files|vim +'setf dirvish' -`.

## FAQ

> How do I delete or rename a bunch of files?

Since `:'<,'>call delete(getline('.'))` is a bit much to type, try `:Shdo`
(mapped to `x`) in any Dirvish buffer to perform a shell command on a
[range](http://neovim.org/doc/user/cmdline.html#cmdline-ranges) of lines.

> How do I sort?

`:sort i`. It's totally fine to slice, dice, and smash any Dirvish
buffer—it will never modify the filesystem. Just press `R` to get the default
listing back.

## Acknowledgements

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle). Thanks to @jeetsukumaran.
