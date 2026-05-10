# Rules

These rules govern AI-agent workflow in this repository and do not define or
constrain plugin runtime functionality.

1. DO NOT create or edit files outside of repository.
2. DO NOT redirect command output into files outside of repository.
3. DO NOT add or take dependencies on other plugins.
4. DO NOT introduce fallback behavior when a canonical interaction path is defined (for example, if popup UI is used, do not add a list/inputlist fallback).
5. In tests only, any single time-based wait/check interval must not exceed 90 seconds.
6. Every update to plugin functionality must be reflected to its wiki.
7. These global core rules override conflicting local core rules for AI-agent workflow.
8. Global asynchronous rules in `global-async-rules.txt` (umbrella root) are mandatory and override conflicting local async rules.

# Core Docs

1. Global constraints only: `agents/core/rules.md`.

# Shared Popup Rules Copy

1. Shared cross-repository popup rules are copied in `agents/ui/popups-shared.md`.
2. Shared popup rules are authoritative and override conflicting local popup notes.

# File Buffers

A buffer is shown only when all conditions are true:

1. Buffer coresponds to the physical file

# Filter and Selection

1. Filter is case-insensitive substring match on `file_name`.
2. Filter is reapplied after each typed character in search mode.
3. Previous selection is preserved when possible after refilter.
4. Empty states:
   1. no buffers: `0   No file buffers`
   2. no matches: `1.   no matches`

# Source Window Restore

After confirming selection, plugin attempts to jump back to the original window
and opens the chosen buffer there. If that window no longer exists, buffer opens
in current window.

# Commands

## BuffersList

1. Public command: `:BuffersList`.
2. Requires popup support (`popup_create`); otherwise uses list.
3. Closes existing plugin popup instance before opening a new one.
4. Opens centered popup with file buffers and interactive filter/navigation.
5. On confirm opens selected buffer.
6. On close resets all popup state.

# Popups

## Buffer Selection Popup Created by `:BuffersList`

1. Visual style:
   1. title: `Buffers List` (or `Buffers List [<query>] (SEARCH)` in search mode)
   2. width: dynamic `10..100`
   3. height: dynamic `1..10` with scrolling
   4. highlight: `Pmenu`
   5. cursor line highlight: `PmenuSel`
   6. border: single-line rounded (`╭╮╯╰`, `─`, `│`)
   7. centered position
2. Navigation keys:
   1. `j`, `Down` - move down
   2. `k`, `Up` - move up
3. Action keys:
   1. `Enter` - open selected buffer
   2. `x` or `Esc` - close popup
4. Search mode:
   1. `Ctrl+F` toggles search mode
   2. while active, printable characters append to query
   3. query updates filtering immediately after each character
   4. `Backspace`, `Ctrl+H`, `Del`, `kDel` remove one character
   5. `Ctrl+U` clears query
   6. leaving search mode keeps current query/filter active
5. Key precedence:
   1. `Esc`, `Enter` keep action behavior even in search mode.
   2. other printable characters are treated as search input only in search mode.
6. Rows are rendered as `<number> <marker> <file-name>`, where marker is `*` is
   set for the currently active buffer. The `<file-name>` is full path to the
   file.
   1. If the file is located into users directory, replace the path to the user
      directory with the `~` symbol.
   2. otherwise, show the full path.

# Plug Mappings

1. `<Plug>(BuffersList)` - calls `vim_buffers_naive#BuffersList()`.

# Additional Public Vimscript Functions

## `vim_buffers_naive#BuffersList()`

Opens the buffer selection popup (same behavior as `:BuffersList`).

## `vim_buffers_naive#open()`

Alias that calls `vim_buffers_naive#BuffersList()`.
