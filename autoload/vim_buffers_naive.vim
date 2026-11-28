scriptencoding utf-8

let s:constant_tabs = ['PWD', 'PROJECT', 'HOME', 'ALL']
let s:constant_titles = [
      \ 'Buffers List: [PWD] PROJECT HOME ALL',
      \ 'Buffers List: PWD [PROJECT] HOME ALL',
      \ 'Buffers List: PWD PROJECT [HOME] ALL',
      \ 'Buffers List: PWD PROJECT HOME [ALL]',
      \ ]
let s:constant_all_tab_idx = index(s:constant_tabs, 'ALL')
let s:constant_empty_text = 'No buffers'
let s:constant_popup_width = 60
let s:constant_popup_width_margin = 20
let s:constant_popup_height = 15

let s:constant_key_cursor = {
      \ 'j': 1,
      \ "\<Down>": 1,
      \ 'k': -1,
      \ "\<Up>": -1,
      \ }

let s:constant_key_tabs = {
      \ 't': 1,
      \ 'T': -1,
      \ }

let s:previous_buffers = []

function! s:ResetState() abort
  let s:popup_id = -1
  let s:source_winid = -1
  let s:tab_idx = s:constant_all_tab_idx
  let s:all_buffers = {}
  let s:all_lines = {}
  let s:selected_idx = 0
  let s:top_idx = 0
  " Use the default width unless the screen is narrower than it.
  let s:popup_width = &columns >= s:constant_popup_width
        \ ? s:constant_popup_width
        \ : max([1, &columns - s:constant_popup_width_margin])
endfunction

" Reloads buffers and builds rows of every tab padded to the popup width.
function! s:BuildLines() abort
  let s:all_buffers = vim_buffers_naive#buffers#GetFileBuffers(s:previous_buffers, s:source_winid)
  let s:all_lines = {}

  let s:previous_buffers = map(copy(s:all_buffers.ALL), {_, v -> v.item})

  for l:tab in s:constant_tabs
    let l:entries = get(s:all_buffers, l:tab, [])
    let l:lines = empty(l:entries) ? [s:constant_empty_text] : []

    for l:entry in l:entries
      let l:item = l:entry.item
      let l:line = printf('%s %s%s %s', l:entry.idx,
            \ l:item.is_modified ? '+' : ' ',
            \ l:item.is_active ? '*' : ' ',
            \ l:entry.path)

      " Truncate by display width: wide characters take two columns each.
      if strdisplaywidth(l:line) > s:popup_width
        let l:keep = s:popup_width - 3
        let l:line = strcharpart(l:line, 0, l:keep)
        while strdisplaywidth(l:line) > l:keep
          let l:line = strcharpart(l:line, 0, strchars(l:line) - 1)
        endwhile
        let l:line .= '...'
      endif

      call add(l:lines, l:line)
    endfor

    let s:all_lines[l:tab] = map(l:lines,
          \ {_, v -> v . repeat(' ', max([0, s:popup_width - strdisplaywidth(v)]))})
  endfor
endfunction

function! s:GetActiveBuffers() abort
  return get(s:all_buffers, s:constant_tabs[s:tab_idx], [])
endfunction

function! s:GetActiveLines() abort
  return s:all_lines[s:constant_tabs[s:tab_idx]]
endfunction

function! s:GetActivePopupOptions() abort
  return {
        \ 'title': s:constant_titles[s:tab_idx],
        \ 'minwidth': s:popup_width,
        \ 'maxwidth': s:popup_width,
        \ 'minheight': s:constant_popup_height,
        \ 'maxheight': s:constant_popup_height,
        \ }
endfunction

function! s:ActionMoveActiveTab(delta) abort
  let l:count = len(s:constant_tabs)
  let s:tab_idx = (s:tab_idx + a:delta + l:count) % l:count
  let s:selected_idx = 0
  let s:top_idx = 0
  call s:RenderPopup()
endfunction

function! s:ActionMoveActiveSelection(delta) abort
  let l:buffers = s:GetActiveBuffers()
  let l:count = len(l:buffers)
  if l:count == 0
    return
  endif

  let l:index = (s:selected_idx + a:delta + l:count) % l:count

  if l:index !=# s:selected_idx
    let s:selected_idx = l:index
    call s:RenderPopup()
  endif
endfunction

function! s:ActionOpenSelectedBuffer() abort
  let l:buffers = s:GetActiveBuffers()
  if empty(l:buffers)
    echohl WarningMsg
    echomsg 'No file buffers available'
    echohl None
    return
  endif

  let l:bufnr = l:buffers[s:selected_idx].item.bufnr
  let l:winid = s:source_winid
  call popup_close(s:popup_id)

  if l:winid > 0
    call win_gotoid(l:winid)
  endif
  execute 'buffer ' . l:bufnr
endfunction

function! s:ActionCloseSelectedBuffer() abort
  let l:buffers = s:GetActiveBuffers()
  if empty(l:buffers)
    return
  endif

  let l:bufnr = l:buffers[s:selected_idx].item.bufnr
  try
    execute 'bdelete ' . l:bufnr
  catch
    echohl WarningMsg
    echomsg substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
    echohl None
    return
  endtry

  call s:BuildLines()
  let s:selected_idx = max([0, min([s:selected_idx, len(s:GetActiveBuffers()) - 1])])
  call s:RenderPopup()
endfunction

function! s:ActionCloseOtherBuffers() abort
  let l:failed = 0
  for l:entry in s:GetActiveBuffers()
    let l:buf = l:entry.item
    if l:buf.is_active || l:buf.is_modified
      continue
    endif
    try
      execute 'bdelete ' . l:buf.bufnr
    catch
      let l:failed += 1
    endtry
  endfor

  if l:failed > 0
    echohl WarningMsg
    echomsg printf('%d buffer(s) could not be closed', l:failed)
    echohl None
  endif

  call s:BuildLines()
  let s:selected_idx = 0
  call s:RenderPopup()
endfunction

function! s:OnPopupClosed(id, result) abort
  call s:ResetState()
endfunction

function! s:OnPopupKeyPress(id, key) abort
  if a:key ==# "\<Esc>"
    call popup_close(a:id)
  elseif a:key ==# 'x'
    call s:ActionCloseSelectedBuffer()
  elseif a:key ==# 'X'
    call s:ActionCloseOtherBuffers()
  elseif a:key ==# "\<CR>"
    call s:ActionOpenSelectedBuffer()
  elseif has_key(s:constant_key_tabs, a:key)
    call s:ActionMoveActiveTab(s:constant_key_tabs[a:key])
  elseif has_key(s:constant_key_cursor, a:key)
    call s:ActionMoveActiveSelection(s:constant_key_cursor[a:key])
  endif

  return 1
endfunction

function! s:RenderPopup() abort
  if s:popup_id <= 0
    return
  endif

  " Scroll so the selected row is visible.
  let l:top = min([s:top_idx, s:selected_idx])
  let l:top = max([l:top, s:selected_idx - s:constant_popup_height + 1])
  let s:top_idx = max([0, l:top])

  let l:lines = s:GetActiveLines()[s:top_idx : s:top_idx + s:constant_popup_height - 1]
  let l:cursorline = empty(s:GetActiveBuffers()) ? 1 : s:selected_idx - s:top_idx + 1

  call popup_settext(s:popup_id, l:lines)
  call popup_setoptions(s:popup_id, s:GetActivePopupOptions())
  call win_execute(s:popup_id, printf('call cursor(%d, 1)', l:cursorline))
endfunction

function! s:OpenPopup() abort
  if !exists('*popup_create')
    echoerr 'vim-buffers-naive: popup support is required (missing popup_create())'
    return
  endif

  if s:popup_id > 0
    call popup_close(s:popup_id)
  endif

  call s:ResetState()

  let s:source_winid = win_getid()
  let s:popup_id = popup_create([], extend(s:GetActivePopupOptions(), {
        \ 'pos': 'center',
        \ 'padding': [0, 0, 0, 0],
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'mapping': 0,
        \ 'filter': function('s:OnPopupKeyPress'),
        \ 'callback': function('s:OnPopupClosed'),
        \ 'highlight': 'Pmenu',
        \ 'cursorline': 1,
        \ 'zindex': 200,
        \ }))

  call win_execute(s:popup_id, 'setlocal winhighlight=Normal:Pmenu,CursorLine:PmenuSel')
  call win_execute(s:popup_id, "call matchadd('String', '\\v\\$(PROJECT|PWD|HOME)')")

  call s:BuildLines()

  " Open on the tab of the active file (always first on ALL); unlabeled opens ALL.
  if !empty(s:all_buffers.ALL)
    let l:pcat = s:all_buffers.ALL[0].item.relative_pcat
    if !empty(l:pcat)
      let s:tab_idx = index(s:constant_tabs, l:pcat)
    endif
  endif

  call s:RenderPopup()
endfunction

function! vim_buffers_naive#BuffersList() abort
  call s:OpenPopup()
endfunction

function! vim_buffers_naive#register_plug_mappings() abort
  call s:register_plug_mapping('<Plug>(BuffersList)', ':<C-U>call vim_buffers_naive#BuffersList()<CR>')
endfunction

function! s:register_plug_mapping(lhs, rhs) abort
  if empty(maparg(a:lhs, 'n'))
    execute 'nnoremap <silent> ' . a:lhs . ' ' . a:rhs
  endif
endfunction

" Initial state reset, so we start clean when plugin loads 
call s:ResetState()
