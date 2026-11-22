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
        \ 'selected_idx': 0,
        \ 'top_idx': 0,
        \ 'popup_width': s:max_popup_width,
        \ 'popup_height': 1,
        \ }
endfunction

let s:state = s:NewState()

function! s:Truncate(text, max_width) abort
  if a:max_width <= 0
    return ''
  endif
  if strdisplaywidth(a:text) <= a:max_width
    return a:text
  endif

  let l:keep = max([0, a:max_width - 3])
  let l:result = strcharpart(a:text, 0, l:keep)
  while strdisplaywidth(l:result) > l:keep
    let l:result = strcharpart(l:result, 0, strchars(l:result) - 1)
  endwhile

  return a:max_width <= 3 ? l:result : l:result . '...'
endfunction

function! s:PadToWidth(text, width) abort
  return a:text . repeat(' ', max([0, a:width - strdisplaywidth(a:text)]))
endfunction

function! s:CalculateWidth() abort
  let l:buffers = s:state.all_buffers
  if empty(l:buffers)
    let l:content_width = strdisplaywidth(s:empty_text)
  else
    let l:number_width = strdisplaywidth(string(len(l:buffers)))
    let l:name_width = max(map(copy(l:buffers), 'strdisplaywidth(v:val.display_path)'))
    let l:content_width = l:number_width + 3 + l:name_width
  endif

  return min([s:max_popup_width, max([s:min_popup_width, l:content_width])])
endfunction

function! s:CalculateHeight() abort
  return max([1, min([s:max_visible_items, len(s:state.all_buffers)])])
endfunction

" Scrolls the window so the selected row is visible and returns visible lines.
function! s:BuildLines() abort
  let l:buffers = s:state.all_buffers
  let l:width = s:state.popup_width
  let l:height = s:state.popup_height

  if empty(l:buffers)
    return [s:PadToWidth(s:empty_text, l:width)]
  endif

  let l:top = min([s:state.top_idx, s:state.selected_idx])
  let l:top = max([l:top, s:state.selected_idx - l:height + 1])
  let s:state.top_idx = max([0, l:top])

  let l:lines = []
  for l:item in l:buffers[s:state.top_idx : s:state.top_idx + l:height - 1]
    let l:prefix = printf('%s %s ', l:item.display_index, l:item.is_active ? '*' : ' ')
    let l:name = s:Truncate(l:item.display_path, l:width - strdisplaywidth(l:prefix))
    call add(l:lines, s:PadToWidth(l:prefix . l:name, l:width))
  endfor

  return l:lines
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

  let l:lines = s:BuildLines()
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

  let s:state.all_buffers = vim_buffers_naive#buffers#GetFileBuffers(s:previous_buffers, s:state.source_winid)
  let s:previous_buffers = s:state.all_buffers
  let s:state.selected_idx = max([0, min([s:state.selected_idx, len(s:state.all_buffers) - 1])])
  let s:state.popup_height = s:CalculateHeight()
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

  let s:state.all_buffers = vim_buffers_naive#buffers#GetFileBuffers(s:previous_buffers, s:state.source_winid)
  let s:previous_buffers = s:state.all_buffers
  let s:state.selected_idx = 0
  let s:state.popup_height = s:CalculateHeight()
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
  let s:state.all_buffers = vim_buffers_naive#buffers#GetFileBuffers(s:previous_buffers, s:state.source_winid)
  let s:previous_buffers = s:state.all_buffers
  let s:state.popup_width = s:CalculateWidth()
  let s:state.popup_height = s:CalculateHeight()
  let s:state.popup_id = popup_create(s:BuildLines(), extend(s:SizeOptions(), {
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
