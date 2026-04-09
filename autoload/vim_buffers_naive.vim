scriptencoding utf-8

let s:state = {
      \ 'popup_id': -1,
      \ 'source_winid': -1,
      \ 'all_buffers': [],
      \ 'filtered_indices': [],
      \ 'selected_idx': 0,
      \ 'top_idx': 0,
      \ 'search_mode': 0,
      \ 'query': '',
      \ 'popup_width': 30,
      \ }

let s:min_popup_width = 10
let s:max_popup_width = 30
let s:max_visible_items = 10

function! s:ResetState() abort
  let s:state.popup_id = -1
  let s:state.source_winid = -1
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
  if empty(s:state.filtered_indices)
    if empty(s:state.query)
      let s:state.popup_width = s:ClampPopupWidth(strdisplaywidth('0   No file buffers'))
      return
    endif

    let s:state.popup_width = s:ClampPopupWidth(strdisplaywidth('0   No matches'))
    return
  endif

  let l:max_number_width = strdisplaywidth(string(len(s:state.filtered_indices)))
  let l:prefix_width = l:max_number_width + 3
  let l:max_name_width = 0

  for l:buffer_index in s:state.filtered_indices
    let l:name_width = strdisplaywidth(s:state.all_buffers[l:buffer_index].file_name)
    if l:name_width > l:max_name_width
      let l:max_name_width = l:name_width
    endif
  endfor

  let s:state.popup_width = s:ClampPopupWidth(l:prefix_width + l:max_name_width)
endfunction

function! s:GetPopupTitle() abort
  if s:state.search_mode
    return 'Buffers List (Insert)'
  endif
  return 'Buffers List'
endfunction

function! s:GetFileBuffers() abort
  let l:buffers = []

  for l:info in getbufinfo({'buflisted': 1})
    if getbufvar(l:info.bufnr, '&buftype') !=# ''
      continue
    endif

    let l:name = bufname(l:info.bufnr)
    if empty(l:name)
      continue
    endif

    call add(l:buffers, {
          \ 'bufnr': l:info.bufnr,
          \ 'file_name': fnamemodify(l:name, ':t'),
          \ })
  endfor

  return l:buffers
endfunction

function! s:GetSelectedBufnr() abort
  if empty(s:state.filtered_indices)
    return -1
  endif

  let l:buffer_index = s:state.filtered_indices[s:state.selected_idx]
  return s:state.all_buffers[l:buffer_index].bufnr
endfunction

function! s:ApplyFilter() abort
  let l:query = tolower(s:state.query)
  let l:selected_bufnr = s:GetSelectedBufnr()
  let s:state.filtered_indices = []

  for l:index in range(len(s:state.all_buffers))
    let l:item = s:state.all_buffers[l:index]
    if empty(l:query) || stridx(tolower(l:item.file_name), l:query) >= 0
      call add(s:state.filtered_indices, l:index)
    endif
  endfor

  if empty(s:state.filtered_indices)
    let s:state.selected_idx = 0
    let s:state.top_idx = 0
    call s:UpdatePopupWidth()
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

  call s:UpdatePopupWidth()
endfunction

function! s:GetVisibleLines() abort
  let l:popup_width = s:state.popup_width

  if empty(s:state.filtered_indices)
    if empty(s:state.query)
      return [s:PadToWidth('0   No file buffers', l:popup_width)]
    endif
    return [s:PadToWidth('0   No matches', l:popup_width)]
  endif

  let l:total = len(s:state.filtered_indices)
  let l:height = min([s:max_visible_items, l:total])
  let l:max_top = l:total - l:height

  if s:state.top_idx > l:max_top
    let s:state.top_idx = l:max_top
  endif
  if s:state.top_idx < 0
    let s:state.top_idx = 0
  endif
  if s:state.selected_idx < s:state.top_idx
    let s:state.top_idx = s:state.selected_idx
  endif
  if s:state.selected_idx >= (s:state.top_idx + l:height)
    let s:state.top_idx = s:state.selected_idx - l:height + 1
  endif

  let l:lines = []
  let l:last_visible = min([l:total - 1, s:state.top_idx + l:height - 1])

  for l:index in range(s:state.top_idx, l:last_visible)
    let l:buffer_index = s:state.filtered_indices[l:index]
    let l:item = s:state.all_buffers[l:buffer_index]
    let l:prefix = printf('%d %s ', l:index + 1, l:index ==# s:state.selected_idx ? '*' : ' ')
    let l:max_name_width = l:popup_width - strdisplaywidth(l:prefix)
    let l:line = l:prefix . s:Truncate(l:item.file_name, l:max_name_width)
    call add(l:lines, s:PadToWidth(l:line, l:popup_width))
  endfor

  return l:lines
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

function! s:MoveSelection(delta) abort
  if empty(s:state.filtered_indices)
    return
  endif

  let l:last_index = len(s:state.filtered_indices) - 1
  let l:new_index = s:state.selected_idx + a:delta

  if l:new_index < 0
    let l:new_index = 0
  endif
  if l:new_index > l:last_index
    let l:new_index = l:last_index
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
  call popup_close(s:state.popup_id)

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
  if a:key ==# "\<C-I>"
    let s:state.search_mode = !s:state.search_mode
    call s:RenderPopup()
    return 1
  endif

  if a:key ==# "\<Esc>" || a:key ==# 'x'
    call popup_close(a:popup_id)
    return 1
  endif

  if a:key ==# "\<CR>" || a:key ==# 'b'
    call s:OpenSelectedBuffer()
    return 1
  endif

  if index(['j', "\<Down>", "\<C-N>"], a:key) >= 0
    call s:MoveSelection(1)
    return 1
  endif

  if index(['k', "\<Up>", "\<C-P>"], a:key) >= 0
    call s:MoveSelection(-1)
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
    if a:key ==# "\<BS>" || a:key ==# "\<C-H>" || a:key ==# "\<Del>"
      let s:state.query = s:TrimLastChar(s:state.query)
      call s:ApplyFilter()
      call s:RenderPopup()
      return 1
    endif

    if strlen(a:key) ==# 1 && char2nr(a:key) >= 32
      let s:state.query .= a:key
      call s:ApplyFilter()
      call s:RenderPopup()
      return 1
    endif
  endif

  return 1
endfunction

function! s:OpenBuffersList() abort
  if !exists('*popup_create')
    echoerr 'BuffersList requires Vim popup support'
    return
  endif

  if s:state.popup_id > 0 && !empty(popup_getpos(s:state.popup_id))
    call popup_close(s:state.popup_id)
  endif

  let s:state.source_winid = win_getid()
  let s:state.all_buffers = s:GetFileBuffers()
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
  call s:RenderPopup()
endfunction

function! vim_buffers_naive#BuffersList() abort
  call s:OpenBuffersList()
endfunction

function! vim_buffers_naive#open() abort
  call vim_buffers_naive#BuffersList()
endfunction
