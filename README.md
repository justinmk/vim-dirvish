# dirvish.vim :zap:

---

This plugin is in "beta", though it's quite stable. The 1.0 release will follow
after some final polishing.

---

Dirvish is minimalist directory browser for Vim. I call it
"[dired](http://en.wikipedia.org/wiki/Dired) on a diet", though in some ways it
is more powerful than netrw and NERDTree. It
does very little: only a few things that aren't already provided by Vim or its
ecosystem.

Dirvish is designed with the philosophy that Vim (combined with complementary
plugins such as [eunuch](https://github.com/tpope/vim-eunuch) and
[unimpaired](https://github.com/tpope/vim-unimpaired)) *already* provides
mechanisms for file and path manipulation tasks that are re-invented by netrw
and NERDTree[1].

Dirvish is for  _viewing_, not _editing_. Each line in a Dirvish buffer
contains the _full path_ of the respective file/directory (abbreviated by Vim's
_conceal_ feature). This means you can use plain old `y` to yank the path under
the cursor, then feed it to `:r` or `:e` or whatever. Instead of figuring out
netrw's super special mapping to move a file, you can
`:!mv <c-r><c-a> <c-r><c-a>foo`. The buffer name is set to the name of the
directory, so Vim commands and plugins that work with the buffer name do the
Right Thing.

Vim users are better off if they build on composable concepts instead of having
an all-in-one solution for each particular task. @tope's plugins demonstrate
this theme, more plugins should do so.

### Features

- isn't netrw
- _original_ and _alternate_ buffers are always preserved
- each line is literally just an absolute path to a file or directory
- 2x faster than netrw (try a directory with 1000+ items)
- visual-select to open multiple files at once
- press `x` (or `:Shdo`) to perform any shell command on the selected file(s)

### FAQ

> How could I possibly create a new directory without netrw?!

`:!mkdir %/foo`. Also check out [eunuch](https://github.com/tpope/vim-eunuch).

> But how do I delete files?

The Vim `delete()` function works on files (but not directories):

    :'<,'>call delete(getline('.'))

Dirvish also provides `:Shdo` to perform any shell command on
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
