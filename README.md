# dirvish.vim :cyclone:

Dirvish is to [dired](http://en.wikipedia.org/wiki/Dired) as ed is to vi. It
does very little: only a few things that aren't already provided by Vim or the
Vim ecosystem.

Dirvish is designed with the philosophy that Vim (combined with complementary
plugins such as [eunuch](https://github.com/tpope/vim-eunuch) and
[unimpaired](https://github.com/tpope/vim-unimpaired)) *already* provides
mechanisms for file and path manipulation tasks that are re-invented by netrw
and NERDTree. "Then why is netrw included with Vim?" you ask. Same reason,
I speculate, that Vim has `'gdefault'` and "easy mode": brief attempts to
satisfy some unmeasured sliver of use-cases, perpetuated in the name of
backwards compatibility.

Dirvish is for  _viewing_, not _editing_. Each line in a Dirvish buffer
contains the _full path_ of the respective file/directory (abbreviated by Vim's
_conceal_ feature). This means you can use plain old `y` to yank the path under
the cursor, then feed it to `:r` or `:e` or whatever.


Dirvish is a heavily modified (57% smaller) fork of
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle). Thanks to
@jeetsukumaran.
