scriptencoding utf-8

let s:title = 'Buffers List'
let s:empty_text = '0   No file buffers'
let s:min_popup_width = 10
let s:max_popup_width = 100
let s:max_visible_items = 10
let s:previous_buffers = []

let s:key_moves = {
      \ 'j': 1,
      \ "\<Down>": 1,
      \ 'k': -1,
      \ "\<Up>": -1,
      \ }

function! s:NewState() abort
  return {
        \ 'popup_id': -1,
        \ 'source_winid': -1,
        \ 'all_buffers': [],
        \ 'lines': [],
        \ 'selected_idx': 0,
        \ 'top_idx': 0,
        \ 'popup_width': s:max_popup_width,
        \ 'popup_height': 1,
        \ }
endfunction

let s:state = s:NewState()

" Reloads buffers and rebuilds the rows (not yet padded).
function! s:LoadLines() abort
  let s:state.all_buffers = vim_buffers_naive#buffers#GetFileBuffers(s:previous_buffers, s:state.source_winid)
  let s:previous_buffers = s:state.all_buffers

  if empty(s:state.all_buffers)
    let s:state.lines = [s:empty_text]
    return
  endif

  let l:lines = []
  for l:item in s:state.all_buffers
    let l:line = printf('%s %s%s %s', l:item.display_index,
          \ l:item.is_modified ? '+' : ' ',
          \ l:item.is_active ? '*' : ' ',
          \ l:item.display_path)

    " Truncate by display width: wide characters take two columns each.
    if strdisplaywidth(l:line) > s:max_popup_width
      let l:keep = s:max_popup_width - 3
      let l:line = strcharpart(l:line, 0, l:keep)
      while strdisplaywidth(l:line) > l:keep
        let l:line = strcharpart(l:line, 0, strchars(l:line) - 1)
      endwhile
      let l:line .= '...'
    endif

    call add(l:lines, l:line)
  endfor

  let s:state.lines = l:lines
endfunction

" Calculates the popup size from the cached rows and pads the rows to the width.
function! s:FitLines() abort
  let l:content_width = max(map(copy(s:state.lines), 'strdisplaywidth(v:val)'))
  let l:width = min([s:max_popup_width, max([s:min_popup_width, l:content_width])])

  let s:state.popup_width = l:width
  let s:state.popup_height = max([1, min([s:max_visible_items, len(s:state.all_buffers)])])
  let s:state.lines = map(s:state.lines, {_, v -> v . repeat(' ', max([0, l:width - strdisplaywidth(v)]))})
endfunction

" Scrolls the window so the selected row is visible and returns the visible rows.
function! s:GetVisibleLines() abort
  let l:height = s:state.popup_height
  let l:top = min([s:state.top_idx, s:state.selected_idx])
  let l:top = max([l:top, s:state.selected_idx - l:height + 1])
  let s:state.top_idx = max([0, l:top])

  return s:state.lines[s:state.top_idx : s:state.top_idx + l:height - 1]
endfunction

function! s:SizeOptions() abort
  return {
        \ 'title': s:title,
        \ 'minwidth': s:state.popup_width,
        \ 'maxwidth': s:state.popup_width,
        \ 'minheight': s:state.popup_height,
        \ 'maxheight': s:state.popup_height,
        \ }
endfunction

function! s:RenderPopup() abort
  if s:state.popup_id <= 0
    return
  endif

  let l:lines = s:GetVisibleLines()
  let l:cursorline = empty(s:state.all_buffers) ? 1 : s:state.selected_idx - s:state.top_idx + 1

  call popup_settext(s:state.popup_id, l:lines)
  call popup_setoptions(s:state.popup_id, s:SizeOptions())
  call win_execute(s:state.popup_id, printf('call cursor(%d, 1)', l:cursorline))
endfunction

function! s:MoveSelection(delta) abort
  let l:count = len(s:state.all_buffers)
  if l:count == 0
    return
  endif

  let l:index = (s:state.selected_idx + a:delta + l:count) % l:count

  if l:index !=# s:state.selected_idx
    let s:state.selected_idx = l:index
    call s:RenderPopup()
  endif
endfunction

function! s:OpenSelectedBuffer() abort
  if empty(s:state.all_buffers)
    echohl WarningMsg
    echomsg 'No file buffers available'
    echohl None
    return
  endif

  let l:bufnr = s:state.all_buffers[s:state.selected_idx].bufnr
  let l:winid = s:state.source_winid
  call popup_close(s:state.popup_id)

  if l:winid > 0
    call win_gotoid(l:winid)
  endif
  execute 'buffer ' . l:bufnr
endfunction

function! s:CloseSelectedBuffer() abort
  if empty(s:state.all_buffers)
    return
  endif

  let l:bufnr = s:state.all_buffers[s:state.selected_idx].bufnr
  try
    execute 'bdelete ' . l:bufnr
  catch
    echohl WarningMsg
    echomsg substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
    echohl None
    return
  endtry

  call s:LoadLines()
  call s:FitLines()
  let s:state.selected_idx = max([0, min([s:state.selected_idx, len(s:state.all_buffers) - 1])])
  call s:RenderPopup()
endfunction

function! s:CloseOtherBuffers() abort
  let l:failed = 0
  for l:buf in s:state.all_buffers
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

  call s:LoadLines()
  call s:FitLines()
  let s:state.selected_idx = 0
  call s:RenderPopup()
endfunction

function! s:OnPopupClosed(id, result) abort
  let s:state = s:NewState()
endfunction

function! s:PopupFilter(popup_id, key) abort
  if a:key ==# "\<Esc>"
    call popup_close(a:popup_id)
  elseif a:key ==# 'x'
    call s:CloseSelectedBuffer()
  elseif a:key ==# 'X'
    call s:CloseOtherBuffers()
  elseif a:key ==# "\<CR>"
    call s:OpenSelectedBuffer()
  elseif has_key(s:key_moves, a:key)
    call s:MoveSelection(s:key_moves[a:key])
  endif

  return 1
endfunction

function! s:OpenBuffersList() abort
  if !exists('*popup_create')
    echoerr 'vim-buffers-naive: popup support is required (missing popup_create())'
    return
  endif

  if s:state.popup_id > 0
    call popup_close(s:state.popup_id)
  endif

  let s:state = s:NewState()
  let s:state.source_winid = win_getid()
  call s:LoadLines()
  call s:FitLines()
  let s:state.popup_id = popup_create(s:GetVisibleLines(), extend(s:SizeOptions(), {
        \ 'pos': 'center',
        \ 'padding': [0, 0, 0, 0],
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'mapping': 0,
        \ 'filter': function('s:PopupFilter'),
        \ 'callback': function('s:OnPopupClosed'),
        \ 'highlight': 'Pmenu',
        \ 'cursorline': 1,
        \ 'zindex': 200,
        \ }))

  call win_execute(s:state.popup_id, 'setlocal winhighlight=Normal:Pmenu,CursorLine:PmenuSel')
  call win_execute(s:state.popup_id, "call matchadd('String', '\\v\\$(PROJECT|CWD|HOME)')")
  call s:RenderPopup()
endfunction

function! vim_buffers_naive#BuffersList() abort
  call s:OpenBuffersList()
endfunction

function! vim_buffers_naive#register_plug_mappings() abort
  call s:register_plug_mapping('<Plug>(BuffersList)', ':<C-U>call vim_buffers_naive#BuffersList()<CR>')
endfunction

function! s:register_plug_mapping(lhs, rhs) abort
  if empty(maparg(a:lhs, 'n'))
    execute 'nnoremap <silent> ' . a:lhs . ' ' . a:rhs
  endif
endfunction
