# FileBeagle

![FileBeagle screen](http://jeetworks.org/wp-content/uploads/filebeagle2.png)

## Introduction

FileBeagle is a utility to display a directory listing and select a file for
editing. You can change directories and, if necessary, create new files. Files
can be opened in new splits or tabs, and new directory catalogs can be spawned.

And that is about it.

FileBeagle is "VINE-spired": that is, inspired by the design principle of "Vim
Is Not Emacs".

Vim is a text editor, *not* an operating system that can edit text. FileBeagle
respects this, and attempts to conform to this both in spirit and in practice.

If you are looking for a plugin to serve as a filesystem manager from within
Vim, FileBeagle is not it. FileBeagle does not support copying, deleting,
moving/renaming, or any other filesystem operations. FileBeagle lists and opens
files.

If you are looking for a plugin to replicate an operating system shell in Vim,
FileBeagle is not it. FileBeagle does not support `grep`-ing, `find`-ing, or
any of other the other functionality provided by (the *excellent*) programs in
your operating system environment dedicated to these tasks. FileBeagles lists
and opens files.

If you are looking for a plugin that makes Vim resemble some bloated
bells-and-whistles IDE with a billion open "drawers", panels, toolbars, and
windows, FileBeagle is not it. FileBeagle does not provide for fancy
splits or project drawers. FileBeagle lists and opens files.

## Overview of Basic Usage

Type '`-`' to open the FileBeagle directory viewer on the directory of the
current buffer. Alternatively, you can use '`<Leader>f`' to open the FileBeagle
directory viewer on the current working directory. This latter key is mapped to
the command "`:FileBeagle`": if the command is used directly, it can actually
take an optional argument which specifies the path of the directory to open
instead of the current working directory.

In either case, once a directory viewer is open, you can use any of your normal
navigation keys/commands to move to a file or directory of your choice. Once
you have selected a file or directory, you can type `<ENTER>` or "`o`" to open
it for editing in the current window. Or you can type `CTRL-V` to edit it in a
new vertical split, `CTRL-S` to edit it in a new horizontal split, or `CTRL-T`
to edit it in a new tab. Even better, if you make sure that line numbers are
enabled, you can simply type the line number followed by '`o`' or any of the
other maps to instantly open the file or directory listed at the given line
number. So, for example, '`42o`' will open the file or directory at line 42 in
the same window, while '`42v`' will open it in a new
vertical split, and '`42t`' will open it in a new tab, etc.

You can navigate to a directory by selecting it using the same key maps that
you use to select files. In addition, you can use "`-`" to go a parent
directory or backspace ("`<BS>`") to go back to the previous directory.

For each independent invocation of FileBeagle, it remembers the entry which you
last selected in each directory as your enter or leave directories. Each time
you return to a directory that you have visited before, the cursor is
automatically placed at the entry which you selected the just before leaving
that directory. This means that you can quickly traverse up and down a
directory chain by typing "`-`" and/or "`<ENTER>`". Use "`-`" to move up and
up, until you get to the root, and then "`<ENTER>`" to drill seamlessly back
down the same path you just traversed until you hit the file from which you
came. Once you have tried it, you will not want to traverse directories in any
other way (well, except for fuzzy-querying to "teleport" you directly where you
want to go).

The only file management functionality provided is to create a new file ('`%`'
or '`+`'). For everything else, use the operating system.

At any time, you can type "`q`" to close FileBeagle and restore the previous
buffer.

## Acknowledgements

FileBeagle is inspired by [Tim Pope](http://tpo.pe/)'s [Vinegar plugin for Vim](https://github.com/tpope/vim-vinegar.git), which, in turn, was inspired by [Drew Neil](http://drewneil.com/)'s assertion that ["project drawers" are unidiomatic in Vim](http://vimcasts.org/blog/2013/01/oil-and-vinegar-split-windows-and-project-drawer/).
