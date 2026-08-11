scriptencoding utf-8

let s:state = {
      \ 'popup_id': -1,
      \ 'source_winid': -1,
      \ 'source_bufnr': -1,
      \ 'all_buffers': [],
      \ 'filtered_indices': [],
      \ 'selected_idx': 0,
      \ 'top_idx': 0,
      \ 'search_mode': 0,
      \ 'query': '',
      \ 'popup_width': 100,
      \ }

let s:min_popup_width = 10
let s:max_popup_width = 100
let s:max_visible_items = 10

function! s:ResetState() abort
  let s:state.popup_id = -1
  let s:state.source_winid = -1
  let s:state.source_bufnr = -1
  let s:state.all_buffers = []
  let s:state.filtered_indices = []
  let s:state.selected_idx = 0
  let s:state.top_idx = 0
  let s:state.search_mode = 0
  let s:state.query = ''
  let s:state.popup_width = s:max_popup_width
endfunction

function! s:TrimLastChar(text) abort
  let l:length = strchars(a:text)
  if l:length <= 0
    return ''
  endif
  return strcharpart(a:text, 0, l:length - 1)
endfunction

function! s:Truncate(text, max_width) abort
  if a:max_width <= 0
    return ''
  endif

  if strdisplaywidth(a:text) <= a:max_width
    return a:text
  endif

  if a:max_width <= 3
    return strcharpart(a:text, 0, a:max_width)
  endif

  let l:target_width = a:max_width - 3
  let l:result = ''
  let l:index = 0
  let l:length = strchars(a:text)

  while l:index < l:length
    let l:char = strcharpart(a:text, l:index, 1)
    if strdisplaywidth(l:result . l:char) > l:target_width
      break
    endif
    let l:result .= l:char
    let l:index += 1
  endwhile

  return l:result . '...'
endfunction

function! s:PadToWidth(text, width) abort
  let l:padding = a:width - strdisplaywidth(a:text)
  if l:padding > 0
    return a:text . repeat(' ', l:padding)
  endif
  return a:text
endfunction

function! s:ClampPopupWidth(width) abort
  return min([s:max_popup_width, max([s:min_popup_width, a:width])])
endfunction

function! s:UpdatePopupWidth() abort
  let l:max_number_width = 0
  let l:max_name_width   = 0

  if empty(s:state.filtered_indices)
    let l:max_number_width = 1

    if empty(s:state.all_buffers)
      let l:max_name_width = strdisplaywidth('0.   No files')
    else
      let l:max_name_width = strdisplaywidth('1.   No files match')
    endif
  else
    let l:max_number_width = strdisplaywidth(string(len(s:state.filtered_indices)))
    let l:max_name_width   = 0

    for l:buffer_index in s:state.filtered_indices
      let l:name_width = strdisplaywidth(s:state.all_buffers[l:buffer_index].display_path)
      if l:name_width > l:max_name_width
        let l:max_name_width = l:name_width
      endif
    endfor
  endif

  let l:prefix_width      = l:max_number_width + 3
  let s:state.popup_width = min([s:max_popup_width, max([s:min_popup_width, l:prefix_width + l:max_name_width])])
endfunction

function! s:GetPopupTitle() abort
  let l:title = 'Buffers List'
  if !empty(s:state.query)
    let l:title .= ' [' . s:state.query . ']'
  endif
  if s:state.search_mode
    let l:title .= ' (SEARCH)'
  endif
  return l:title
endfunction

function! s:GetSelectedBufnr() abort
  if empty(s:state.filtered_indices)
    return -1
  endif

  let l:buffer_index = s:state.filtered_indices[s:state.selected_idx]
  return s:state.all_buffers[l:buffer_index].bufnr
endfunction

function! s:FindFileBuffersIndexes(query, buffers) abort
  let l:query = tolower(a:query)
  let l:filtered_indices = []

  for l:index in range(len(a:buffers))
    let l:item = a:buffers[l:index]
    if empty(l:query) || stridx(tolower(l:item.display_path), l:query) >= 0
      call add(l:filtered_indices, l:index)
    endif
  endfor

  return l:filtered_indices
endfunction

function! s:ApplyFilter() abort
  let l:selected_bufnr = s:GetSelectedBufnr()
  let s:state.filtered_indices = s:FindFileBuffersIndexes(s:state.query, s:state.all_buffers)

  if empty(s:state.filtered_indices)
    let s:state.selected_idx = 0
    let s:state.top_idx = 0
    return
  endif

  let l:found_index = -1
  if l:selected_bufnr > 0
    for l:index in range(len(s:state.filtered_indices))
      let l:buffer_index = s:state.filtered_indices[l:index]
      if s:state.all_buffers[l:buffer_index].bufnr ==# l:selected_bufnr
        let l:found_index = l:index
        break
      endif
    endfor
  endif

  if l:found_index >= 0
    let s:state.selected_idx = l:found_index
  else
    let s:state.selected_idx = min([s:state.selected_idx, len(s:state.filtered_indices) - 1])
  endif

  if s:state.selected_idx < 0
    let s:state.selected_idx = 0
  endif

endfunction

function! s:GetVisibleLinesCount(filtered_indices, all_buffers, max_visible_items) abort
  if empty(a:filtered_indices) && empty(a:all_buffers)
    return 1
  endif
  if empty(a:filtered_indices)
    return 1
  endif

  return min([a:max_visible_items, len(a:filtered_indices)])
endfunction

function! s:CalculatePopupHeight(visible_lines_count) abort
  return max([1, a:visible_lines_count])
endfunction

function! s:RecalculateTopIndex(top_idx, selected_idx, filtered_indices, popup_height) abort
  if empty(a:filtered_indices)
    return 0
  endif

  let l:top_idx = a:top_idx
  let l:total = len(a:filtered_indices)
  let l:max_top = l:total - a:popup_height

  if l:top_idx > l:max_top
    let l:top_idx = l:max_top
  endif
  if l:top_idx < 0
    let l:top_idx = 0
  endif
  if a:selected_idx < l:top_idx
    let l:top_idx = a:selected_idx
  endif
  if a:selected_idx >= (l:top_idx + a:popup_height)
    let l:top_idx = a:selected_idx - a:popup_height + 1
  endif

  return l:top_idx
endfunction

function! s:BuildVisibleLines(filtered_indices, all_buffers, top_idx, popup_height, popup_width) abort
  if empty(a:filtered_indices)
    if empty(a:all_buffers)
      return [s:PadToWidth('0   No file buffers', a:popup_width)]
    endif
    return [s:PadToWidth('1.   no matches', a:popup_width)]
  endif

  let l:lines = []
  let l:last_visible = min([len(a:filtered_indices) - 1, a:top_idx + a:popup_height - 1])

  for l:index in range(a:top_idx, l:last_visible)
    let l:buffer_index = a:filtered_indices[l:index]
    let l:item = a:all_buffers[l:buffer_index]
    let l:prefix = printf('%d %s ', l:index + 1, l:item.is_active ? '*' : ' ')
    let l:max_name_width = a:popup_width - strdisplaywidth(l:prefix)
    let l:line = l:prefix . s:Truncate(l:item.display_path, l:max_name_width)
    call add(l:lines, s:PadToWidth(l:line, a:popup_width))
  endfor

  return l:lines
endfunction

function! s:GetVisibleLines() abort
  let l:visible_lines_count = s:GetVisibleLinesCount(
        \ s:state.filtered_indices,
        \ s:state.all_buffers,
        \ s:max_visible_items)
  let l:popup_height = s:CalculatePopupHeight(l:visible_lines_count)

  let s:state.top_idx = s:RecalculateTopIndex(
        \ s:state.top_idx,
        \ s:state.selected_idx,
        \ s:state.filtered_indices,
        \ l:popup_height)

  return s:BuildVisibleLines(
        \ s:state.filtered_indices,
        \ s:state.all_buffers,
        \ s:state.top_idx,
        \ l:popup_height,
        \ s:state.popup_width)
endfunction

function! s:RenderPopup() abort
  if s:state.popup_id <= 0
    return
  endif

  let l:lines = s:GetVisibleLines()
  let l:height = len(l:lines)
  let l:cursorline = 1

  if !empty(s:state.filtered_indices)
    let l:cursorline = (s:state.selected_idx - s:state.top_idx) + 1
  endif

  call popup_settext(s:state.popup_id, l:lines)
  call popup_setoptions(s:state.popup_id, {
        \ 'title': s:GetPopupTitle(),
        \ 'minwidth': s:state.popup_width,
        \ 'maxwidth': s:state.popup_width,
        \ 'minheight': l:height,
        \ 'maxheight': l:height,
        \ })
  call win_execute(s:state.popup_id, printf('call cursor(%d, 1)', l:cursorline))
endfunction

function! s:MoveSelection(delta, ...) abort
  if empty(s:state.filtered_indices)
    return
  endif

  let l:cyclic = a:0 > 0 ? a:1 : 0
  let l:last_index = len(s:state.filtered_indices) - 1
  let l:new_index = s:state.selected_idx + a:delta

  if l:cyclic
    if l:new_index < 0
      let l:new_index = l:last_index
    elseif l:new_index > l:last_index
      let l:new_index = 0
    endif
  else
    if l:new_index < 0
      let l:new_index = 0
    endif
    if l:new_index > l:last_index
      let l:new_index = l:last_index
    endif
  endif

  if l:new_index !=# s:state.selected_idx
    let s:state.selected_idx = l:new_index
    call s:RenderPopup()
  endif
endfunction

function! s:OpenSelectedBuffer() abort
  let l:buffer_number = s:GetSelectedBufnr()
  if l:buffer_number <= 0
    echohl WarningMsg
    echomsg 'No buffer matches the current filter'
    echohl None
    return
  endif

  let l:target_winid = s:state.source_winid
  if s:state.popup_id > 0
    call popup_close(s:state.popup_id)
  endif

  if l:target_winid > 0 && win_gotoid(l:target_winid)
    execute 'buffer ' . l:buffer_number
    return
  endif

  execute 'buffer ' . l:buffer_number
endfunction

function! s:OnPopupClosed(id, result) abort
  call s:ResetState()
endfunction

function! s:PopupFilter(popup_id, key) abort
  if a:key ==# "\<C-F>"
    let s:state.search_mode = !s:state.search_mode
    call s:RenderPopup()
    return 1
  endif

  if a:key ==# "\<Esc>" || (!s:state.search_mode && a:key ==# 'x')
    call popup_close(a:popup_id)
    return 1
  endif

  if a:key ==# "\<CR>"
    call s:OpenSelectedBuffer()
    return 1
  endif

  if index(['j', "\<Down>"], a:key) >= 0
    call s:MoveSelection(1, 1)
    return 1
  endif

  if index(['k', "\<Up>"], a:key) >= 0
    call s:MoveSelection(-1, 1)
    return 1
  endif

  if a:key ==# "\<PageDown>"
    call s:MoveSelection(s:max_visible_items)
    return 1
  endif

  if a:key ==# "\<PageUp>"
    call s:MoveSelection(-s:max_visible_items)
    return 1
  endif

  if s:state.search_mode
    if a:key ==# "\<C-U>"
      let s:state.query = ''
      call s:ApplyFilter()
      call s:UpdatePopupWidth()
      call s:RenderPopup()
      return 1
    endif

    if a:key ==# "\<BS>" || a:key ==# "\<C-H>" || a:key ==# "\<Del>" || a:key ==# "\<kDel>"
      let s:state.query = s:TrimLastChar(s:state.query)
      call s:ApplyFilter()
      call s:UpdatePopupWidth()
      call s:RenderPopup()
      return 1
    endif

    if strlen(a:key) ==# 1 && char2nr(a:key) >= 32
      let s:state.query .= a:key
      call s:ApplyFilter()
      call s:UpdatePopupWidth()
      call s:RenderPopup()
      return 1
    endif
  endif

  return 1
endfunction

function! s:OpenBuffersList() abort
  if s:state.popup_id > 0 && exists('*popup_getpos') && !empty(popup_getpos(s:state.popup_id))
    call popup_close(s:state.popup_id)
  endif

  if !exists('*popup_create')
    call s:ResetState()
    echoerr 'vim-buffers-naive: popup support is required (missing popup_create())'
    return
  endif

  let s:state.source_winid = win_getid()
  let s:state.source_bufnr = bufnr('%')
  let s:state.all_buffers = vim_buffers_naive#buffers#GetFileBuffers(s:state.source_winid)
  let s:state.filtered_indices = []
  let s:state.selected_idx = 0
  let s:state.top_idx = 0
  let s:state.search_mode = 0
  let s:state.query = ''
  let s:state.popup_width = s:max_popup_width

  call s:ApplyFilter()
  let l:lines = s:GetVisibleLines()
  let l:height = len(l:lines)

  let s:state.popup_id = popup_create(l:lines, {
        \ 'title': s:GetPopupTitle(),
        \ 'pos': 'center',
        \ 'minwidth': s:state.popup_width,
        \ 'maxwidth': s:state.popup_width,
        \ 'minheight': l:height,
        \ 'maxheight': l:height,
        \ 'padding': [0, 0, 0, 0],
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'mapping': 0,
        \ 'filter': function('s:PopupFilter'),
        \ 'callback': function('s:OnPopupClosed'),
        \ 'highlight': 'Pmenu',
        \ 'cursorline': 1,
        \ 'zindex': 200,
        \ })

  call win_execute(s:state.popup_id, 'setlocal winhighlight=Normal:Pmenu,CursorLine:PmenuSel')
  call win_execute(s:state.popup_id, "call matchadd('String', '\\v\\$(PROJECT|CWD|HOME)')")

  call s:UpdatePopupWidth()
  call s:RenderPopup()
endfunction

function! vim_buffers_naive#BuffersList() abort
  call s:OpenBuffersList()
endfunction

function! vim_buffers_naive#open() abort
  call vim_buffers_naive#BuffersList()
endfunction

function! vim_buffers_naive#register_plug_mappings() abort
  call s:register_plug_mapping('<Plug>(BuffersList)', ':<C-U>call vim_buffers_naive#BuffersList()<CR>')
endfunction

function! s:register_plug_mapping(lhs, rhs) abort
  if empty(maparg(a:lhs, 'n'))
    execute 'nnoremap <silent> ' . a:lhs . ' ' . a:rhs
  endif
endfunction
