scriptencoding utf-8

function! s:FindProjectRoot(path) abort
  let l:current_path = fnamemodify(a:path, ':p')
  let l:directory = getftype(l:current_path) ==# 'dir' ? l:current_path : fnamemodify(l:current_path, ':h')

  while !empty(l:directory)
    if getftype(fnamemodify(l:directory . '/.git', ':p')) ==# 'dir'
      return substitute(fnamemodify(l:directory, ':p'), '[\/]\+$', '', '')
    endif

    let l:parent = fnamemodify(l:directory, ':h')
    if l:parent ==# l:directory
      break
    endif
    let l:directory = l:parent
  endwhile

  return ''
endfunction

function! s:FindFileBuffers() abort
  let l:buffers = []

  for l:info in getbufinfo({'buflisted': 1})
    if getbufvar(l:info.bufnr, '&buftype') !=# ''
      continue
    endif

    let l:name = bufname(l:info.bufnr)
    if empty(l:name)
      continue
    endif

    let l:absolute_path = fnamemodify(l:name, ':p')
    let l:file_type     = getftype(l:absolute_path)
    if l:file_type !=# 'file' && l:file_type !=# 'link'
      continue
    endif

    call add(l:buffers, {
          \ 'bufnr': l:info.bufnr,
          \ 'file_path': l:absolute_path,
          \ 'file_name': fnamemodify(l:absolute_path, ':t'),
          \ })
  endfor

  return l:buffers
endfunction

function! s:EnrichFileBufferWithDisplayPath(item) abort
  let l:enriched_item = copy(a:item)
  let l:absolute_path = l:enriched_item.file_path
  let l:display_path  = l:absolute_path

  let l:home_path = substitute(fnamemodify(expand('~'), ':p'), '[\/]\+$', '', '')
  if !empty(l:home_path) && stridx(l:absolute_path, l:home_path) ==# 0
    let l:display_path = '$HOME' . l:absolute_path[strlen(l:home_path):]
  endif

  let l:project_root = s:FindProjectRoot(l:absolute_path)
  if !empty(l:project_root) && stridx(l:absolute_path, l:project_root) ==# 0
    let l:cwd_path = substitute(fnamemodify(getcwd(), ':p'), '[\/]\+$', '', '')
    if stridx(l:cwd_path, l:project_root) ==# 0
      let l:display_path = '$CWD' . l:absolute_path[strlen(l:cwd_path):]
    else
      let l:display_path = '$PROJECT' . l:absolute_path[strlen(l:project_root):]
    endif
  endif

  let l:enriched_item.display_path = l:display_path
  return l:enriched_item
endfunction

function! s:EnrichFileBufferWithActiveFlag(item, source_winid) abort
  let l:enriched_item = copy(a:item)
  let l:active_bufnr = winbufnr(a:source_winid)

  let l:enriched_item.is_active = l:enriched_item.bufnr ==# l:active_bufnr ? v:true : v:false
  return l:enriched_item
endfunction

function! s:EnrichFileBufferWithDisplayIndex(item, item_index, total_items) abort
  let l:enriched_item = copy(a:item)

  let l:display_index_len = len(string(a:total_items))
  let l:display_index_fmt = '%0' . string(l:display_index_len) . 'd'
  let l:display_index     = printf(l:display_index_fmt, a:item_index)

  let l:enriched_item.display_index = l:display_index
  return l:enriched_item
endfunction

function! vim_buffers_naive#buffers#GetFileBuffers(source_winid) abort
  let l:file_buffers = s:FindFileBuffers()

  let l:buffers = []

  for i in range(0, len(l:file_buffers) - 1)
    let l:file_buffer = l:file_buffers[i]

    let l:enriched_buffer = s:EnrichFileBufferWithDisplayPath(l:file_buffer)
    let l:enriched_buffer = s:EnrichFileBufferWithDisplayIndex(l:enriched_buffer, i + 1, len(l:file_buffers))
    let l:enriched_buffer = s:EnrichFileBufferWithActiveFlag(l:enriched_buffer, a:source_winid)

    call add(l:buffers, l:enriched_buffer)
  endfor

  return l:buffers
endfunction
