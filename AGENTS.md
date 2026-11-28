# Rules

These rules govern AI-agent workflow in this repository and define
cross-repository plugin API conventions where explicitly stated.

1. DO NOT create or edit files outside of repository.
2. DO NOT redirect command output into files outside of repository.
3. DO NOT add or take dependencies on other plugins.
4. DO NOT introduce fallback behavior when a canonical interaction path is defined (for example, if popup UI is used, do not add a list/inputlist fallback).
5. Every public user-facing Ex command must expose a `<Plug>(...)` mapping target.
6. Plugin startup mapping registration must not override an existing `<Plug>(...)` mapping with the same left-hand side.
7. In tests only, any single time-based wait/check interval must not exceed 90 seconds.
8. Every update to plugin functionality must be reflected to its wiki.
9. These global core rules override conflicting local core rules for AI-agent workflow.
10. Global asynchronous rules in `global-async-rules.txt` (umbrella root) are mandatory and override conflicting local async rules.

# Core Docs

1. Global constraints only: `agents/core/rules.md`.

# Shared Popup Rules Copy

1. Shared cross-repository popup rules are copied in `agents/ui/popups-shared.md`.
2. Shared popup rules are authoritative and override conflicting local popup notes.

# File Buffers

A buffer is shown only when all conditions are true:

1. Buffer coresponds to the physical file

# Selection

1. Empty state:
   1. no buffers: `No buffers`

# Source Window Restore

After confirming selection, plugin attempts to jump back to the original window
and opens the chosen buffer there. If that window no longer exists, buffer opens
in current window.

# Commands

## BuffersList

1. Public command: `:BuffersList`.
2. Requires popup support (`popup_create`); if unavailable, command errors and stops.
3. Closes existing plugin popup instance before opening a new one.
4. Opens centered popup with file buffers and navigation.
5. On confirm opens selected buffer.
6. On close resets all popup state.

# Popups

## Buffer Selection Popup Created by `:BuffersList`

1. Visual style:
   1. title: `Buffers List: <tabs>`, where `<tabs>` is `PWD PROJECT HOME ALL`
      with the active tab wrapped in brackets (for example
      `Buffers List: PWD PROJECT [HOME] ALL`); titles of all tabs are
      predefined, so switching tabs does not rebuild them
   2. width: `60` columns; if the screen (`&columns`) is narrower than
      `60`, width is `&columns - 20`. Width is computed once when the popup
      opens, so switching tabs or closing buffers does not resize it.
   3. height: fixed `15` rows with scrolling; it is never recalculated
   4. highlight: `Pmenu`
   5. cursor line highlight: `PmenuSel`
   6. border: single-line square (`┌┐┘└`, `─`, `│`)
   7. centered position
   8. `$PWD`, `$PROJECT`, and `$HOME` labels are highlighted with `String`
2. Navigation keys:
   1. `j`, `Down` - move down
   2. `k`, `Up` - move up
   3. navigation is cyclic: on the first row, `k`/`Up` jumps to the last row;
      on the last row, `j`/`Down` jumps to the first row
   4. `t` - switch to the next tab, `T` - switch to the previous tab; tab
      switching is cyclic and resets the selection to the first row
3. Action keys (all operate on the active tab only):
   1. `Enter` - open selected buffer
   2. `Esc` - close popup
   3. `x` - close (`:bdelete`) the highlighted buffer and refresh the list;
      popup stays open. If the buffer cannot be closed (for example, it has
      unsaved changes), a warning is shown and the list is unchanged.
   4. `X` - close (`:bdelete`) all buffers of the active tab except the
      active one (marked `*`); popup stays open. Buffers
      with unsaved changes are silently skipped; if any other buffer cannot
      be closed, a warning is shown.
4. Rows are rendered as `<number> <flags> <file-name>`, where `<flags>` is two
   fixed columns: `+` in the first column for a modified buffer and `*` in the
   second for the currently active buffer (unset columns are spaces, so a
   modified active buffer shows `+*`). Rows wider than the popup are truncated
   at the end. The `<file-name>` is full path to the file.
   1. Candidate label roots are the user home directory (`$HOME`),
      `getcwd()` (`$PWD`), and the project root (`$PROJECT`). The project
      root is the nearest parent directory of the file containing a `.git`
      directory or a `.git` file with a `gitdir:` line (git worktree).
   2. Among the candidate roots that prefix the file path, the longest one is
      chosen; on equal length the earlier one in the order `$HOME`, `$PWD`,
      `$PROJECT` wins.
   3. On the `ALL` tab a labeled path is shown as
      `$<LABEL>/<path-relative-to-root>`.
   4. If no candidate root matches, the path is shown on the `ALL` tab as
      `$` followed by the full path (for example `$/etc/hosts`).
5. Tabs:
   1. The popup opens on the tab of the active file (`PWD`, `PROJECT`, or
      `HOME`); if the active file has no label or there is no active file
      buffer, it opens on `ALL` (the last tab). `t` from `ALL` wraps to `PWD`.
   2. `ALL` lists every file buffer with labels as described above.
   3. `HOME`, `PWD`, and `PROJECT` list only buffers whose label (as shown
      on `ALL`) is `$HOME`, `$PWD`, or `$PROJECT` respectively; a buffer
      belongs to exactly one of these tabs. Buffers without a label appear
      only on `ALL`.
   4. On `HOME`, `PWD`, and `PROJECT` tabs, `<file-name>` is shown relative to
      the label root, without the `$*` prefix and leading separator.
   5. Row numbers restart from `1` within each tab.
   6. An empty tab shows `No buffers`.

# Plug Mappings

1. `<Plug>(BuffersList)` - calls `vim_buffers_naive#BuffersList()`.
2. Startup registration is non-overriding: plugin defines this mapping only when
   the same `<Plug>(BuffersList)` left-hand side is not already mapped.

# Additional Public Vimscript Functions

## `vim_buffers_naive#BuffersList()`

Opens the buffer selection popup (same behavior as `:BuffersList`).
