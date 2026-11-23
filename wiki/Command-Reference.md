# Command Reference

## `:BuffersList`

Opens the popup file-buffer picker.
The popup is list-and-select only: no interactive search/filter mode.

### Row format

Rows are rendered as `<number> <flags> <file-name>`. `<flags>` is two fixed columns: `+` (first) marks a modified buffer and `*` (second) marks the active buffer, so a modified active buffer shows `+*`. Rows wider than the popup are truncated at the end.

### Display path labels

Rows show the buffer file path with prefix rewriting in this order:

1. If a `.git` directory is found in parent directories, `getcwd()` starts with that project-root path, and the file path starts with `getcwd()`, the `getcwd()` prefix is replaced with `$CWD`.
2. Otherwise, if a `.git` directory is found in parent directories, the project-root prefix is replaced with `$PROJECT`.
3. If no project root is found and the file is under the user home directory, the home prefix is replaced with `$HOME`.
4. Otherwise the full absolute path is shown.

### Popup keys

- `j` / `Down`, `k` / `Up` - move selection (cyclic).
- `Enter` - open the selected buffer.
- `x` - close (`:bdelete`) the highlighted buffer and refresh the list; the popup stays open. Buffers with unsaved changes are not closed and a warning is shown.
- `X` - close (`:bdelete`) all buffers except the active one (marked `*`); the popup stays open. Buffers with unsaved changes are skipped silently; if any other buffer cannot be closed, a warning is shown.
- `Esc` - close the popup.
