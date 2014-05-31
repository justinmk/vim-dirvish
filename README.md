# FileBeagle

FileBeagle is a utility to open a view on directories and select a file for
editing within Vim. It deliberately avoids trying to make Vim what it is not,
i.e., an IDE or, worse, Emacs.

The FileBeagle interface is simple by design: it does not provide for fancy
splits or project drawers, opening the directory viewer in the window of the
current buffer.

Invoking the command "`:FileBeagle`" (by default, mapped to "`<Leader>f`") opens the FileBeagle directory viewer on the current working directory. This command can take an optional argument which specifies the path of the directory to open instead of the current working directory.

Alternatively, the command "`:FileBeagleBufferDir`" (by default, ampped to "`-`") opens the FileBeagle directory viewer on the directory of the current buffer.

In either case, once a directory viewer is open, you can use any of your normal navigation keys/commands to move to a file or directory of your choice.

Once you have selected a file, you can type `<ENTER>` or "`o`" to open it for editing in the current window. Or you can type `<C-V>` to edit it in a new vertical split, `<C-S>` to edit it in a new horizontal split, or `<C-T>` to edit it in a new tab.

If you select a directory hitting, e.g. `<ENTER>` or "`o`" will open it in FileBeagle. In this case, `<BS>` (backspace) will take you back to the previous directory.

At any time, you can type "`q`" to close FileBeagle.
