# dirvish.vim :zap:

---

Status: 1.0 "Release Candidate". 1.0 release will follow after some bake-time.

---

Dirvish is a minimalist directory viewer for Vim, designed with the
philosophy that plugins should harmonize with Vim's built-in
mechanisms—and with complementary plugins such as
[eunuch](https://github.com/tpope/vim-eunuch) and
[unimpaired](https://github.com/tpope/vim-unimpaired)—instead of awkwardly
re-inventing similar yet non-reusable functions.

## Features

- original and _alternate_ buffers are preserved
- meticulous, non-intrusive defaults
- each line is literally just a filepath
- 2x faster than netrw (try a directory with 1000+ items)
- visual selection opens multiple files
- `:Shdo` performs any shell command on selected file(s)
- 97% smaller than netrw (400 lines of code vs. 11000): fewer bugs
- compatible with Vim 7.3+

Each line in a Dirvish buffer contains an absolute filepath (hidden by Vim's
_conceal_ feature). This means you can use plain old `y` to yank the path
under the cursor, then feed it to `:r` or `:e` or whatever. Instead of
netrw's super-special mappings to mark and move files, you can `:!mv
<c-r><c-a> <c-r><c-a>foo`. Each Dirvish buffer name is the _actual directory
name_, so Vim commands and plugins (fugitive.vim) that work with the buffer
name do the Right Thing.

Reuse and composition of concepts multiplies the utility of those concepts;
if a plugin does _not_ reuse a concept, both that concept _and_ the new,
redundant mechanism are made mutually _less valuable_—the sum is less than
the parts—because the user now must learn or choose from two slightly
different things instead of one augmented system. @tope's plugins demonstrate
this theme; more plugins should do so.

## FAQ

> How could I possibly create a new directory without netrw?!

`:!mkdir %/foo`. Also check out [eunuch](https://github.com/tpope/vim-eunuch).

> How do I delete files?

Vim's `delete()` function works on files (but not directories):

    :'<,'>call delete(getline('.'))

Dirvish provides the `:Shdo` command to perform any shell command on
a [range](http://neovim.org/doc/user/cmdline.html#cmdline-ranges) of lines.
Press `x` or `:Shdo` to try it.

> netrw allows me to SORT!!!!!!!!!!!

    set ma|sort i

It's totally fine to slice, dice, and smash any Dirvish buffer—it will never
modify the actual filesystem—just press `R` to get the default listing back.


## Acknowledgements

Dirvish was originally forked from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle). Thanks to @jeetsukumaran.

---

[1] "Then why is netrw included with Vim?" you might ask. Same reason,
I speculate, that Vim has `'gdefault'` and "easy mode": brief attempts to
satisfy some unmeasured sliver of use-cases, perpetuated in the name of
backwards compatibility.
