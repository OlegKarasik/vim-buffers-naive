# Command Reference

## `:BuffersList`

Opens the popup file-buffer picker.
The popup is list-and-select only: no interactive search/filter mode.

### Row format

Rows are rendered as `<number> <flags> <file-name>`. `<flags>` is two fixed columns: `+` (first) marks a modified buffer and `*` (second) marks the active buffer, so a modified active buffer shows `+*`. Rows wider than the popup are truncated at the end.

### Popup size

The popup is `60` columns wide; on screens narrower than `60` columns it is the screen width minus `20`. The width is computed when the popup opens. The height is always `15` rows; longer lists scroll.

### Display path labels

Rows show the buffer file path with a label prefix:

1. Candidate label roots are the user home directory (`$HOME`), `getcwd()` (`$PWD`), and the project root (`$PROJECT`). The project root is the nearest parent directory containing a `.git` directory or a `.git` file with a `gitdir:` line (git worktree).
2. Among the candidate roots that prefix the file path, the longest one is chosen; on equal length the earlier one in the order `$HOME`, `$PWD`, `$PROJECT` wins.
3. On `ALL`, a labeled path is shown as `$<LABEL>/<path-relative-to-root>`.
4. If no candidate root matches, the path is shown on `ALL` as `$` followed by the full path (for example `$/etc/hosts`).

### Tabs

The popup title shows the tabs `PWD PROJECT HOME ALL`; the active one is wrapped in brackets, for example `Buffers List: PWD PROJECT [HOME] ALL`. The popup opens on the tab of the active file (`PWD`, `PROJECT`, or `HOME`); if the active file has no label or there is no active file buffer, it opens on `ALL` (the last tab). `t` from `ALL` wraps to `PWD`.

- `ALL` - every file buffer, with `$HOME` / `$PWD` / `$PROJECT` labels.
- `HOME`, `PWD`, `PROJECT` - only buffers whose label on `ALL` is `$HOME`, `$PWD`, or `$PROJECT`. Each buffer belongs to exactly one of these tabs; unlabeled buffers appear only on `ALL`. Paths are shown relative to the label root without the `$*` prefix, and row numbers restart from `1`.

All action keys operate on the active tab only.

### Popup keys

- `j` / `Down`, `k` / `Up` - move selection (cyclic).
- `t` / `T` - switch to the next / previous tab (cyclic); selection resets to the first row.
- `Enter` - open the selected buffer.
- `x` - close (`:bdelete`) the highlighted buffer and refresh the list; the popup stays open. Buffers with unsaved changes are not closed and a warning is shown.
- `X` - close (`:bdelete`) all buffers of the active tab except the active one (marked `*`); the popup stays open. Buffers with unsaved changes are skipped silently; if any other buffer cannot be closed, a warning is shown.
- `Esc` - close the popup.
