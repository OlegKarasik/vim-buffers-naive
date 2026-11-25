scriptencoding utf-8

function! s:IsProjectBoundary(path) abort
  let l:type = getftype(a:path)
  if l:type ==# 'dir'
    return v:true
  endif
  if l:type ==# 'file'
    let l:name = fnamemodify(a:path, ':t')
    if l:name ==# '.git'
      let l:lines = readfile(a:path, '', 1)
      return !empty(l:lines) && l:lines[0] =~# '^gitdir:'
    endif
    return v:false
  endif
  return v:false
endfunction

function! s:FindProjectRoot(path) abort
  let l:current_path = fnamemodify(a:path, ':p')
  let l:directory = getftype(l:current_path) ==# 'dir' 
      \ ? l:current_path 
      \ : fnamemodify(l:current_path, ':h')

  while !empty(l:directory)
    if s:IsProjectBoundary(fnamemodify(l:directory . '/.git', ':p'))
      return fnamemodify(l:directory, ':p')
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
  let l:buffers  = []

  let l:cwd_path  = fnamemodify(getcwd(), ':p')
  let l:home_path = fnamemodify(expand('~'), ':p')

  for l:info in getbufinfo({'buflisted': 1})
    if getbufvar(l:info.bufnr, '&buftype') !=# ''
      continue
    endif

    let l:name = bufname(l:info.bufnr)
    if empty(l:name)
      continue
    endif

    let l:file_path = fnamemodify(l:name, ':p')
    let l:file_type = getftype(l:file_path)

    if l:file_type !=# 'file' && l:file_type !=# 'link'
      continue
    endif

    let l:project_path = s:FindProjectRoot(l:file_path)

    call add(l:buffers, {
          \ 'bufnr': l:info.bufnr,
          \ 'cwd_path': l:cwd_path,
          \ 'home_path': l:home_path,
          \ 'project_path': l:project_path,
          \ 'file_path': l:file_path,
          \ 'file_name': fnamemodify(l:file_path, ':t'),
          \ })
  endfor

  return l:buffers
endfunction

function! s:EnrichFileBufferWithDisplayPath(item) abort
  let l:cwd_path     = a:item.cwd_path
  let l:home_path    = a:item.home_path
  let l:project_path = a:item.project_path
  let l:file_path    = a:item.file_path
  let l:display_path = a:item.file_path
  let l:display_pcut = ''

  let l:shortcuts = [
        \ l:home_path,    "$HOME",
        \ l:cwd_path,     "$CWD",
        \ l:project_path, "$PROJECT"
        \ ]

  let l:i = 0
  while l:i < len(l:shortcuts)
    let path = l:shortcuts[i]
    let pcut = l:shortcuts[i + 1]

    if !empty(path) && stridx(l:file_path, path) ==# 0 && strlen(path) > strlen(l:display_pcut)
      let l:display_path = pcut . l:file_path[strlen(path) - 1:]
      let l:display_pcut = path
    endif

    let l:i += 2
  endwhile

  let a:item.display_path = l:display_path
  let a:item.display_pcut = l:display_pcut
  return a:item
endfunction

function! s:EnrichFileBufferWithDisplayIndex(item, item_index, total_items) abort
  let l:display_index_len = len(string(a:total_items))
  let l:display_index_fmt = '%0' . string(l:display_index_len) . 'd'
  let l:display_index     = printf(l:display_index_fmt, a:item_index)

  let a:item.display_index = l:display_index
  return a:item
endfunction

function! s:EnrichFileBufferWithActiveFlag(item, source_winid) abort
  let l:active_bufnr = winbufnr(a:source_winid)

  let a:item.is_active = a:item.bufnr ==# l:active_bufnr ? v:true : v:false
  return a:item
endfunction

function! s:EnrichFileBufferWithModifiedFlag(item) abort
  let a:item.is_modified = getbufvar(a:item.bufnr, '&modified') == 1 ? v:true : v:false
  return a:item
endfunction

function! vim_buffers_naive#buffers#GetFileBuffers(previous_buffers, source_winid) abort
  let l:buffers = s:FindFileBuffers()

  let l:active = v:null

  let l:output = []

  let l:mapping = {}
  let l:previous_mapping = {}
  for i in range(0, len(a:previous_buffers) - 1)
    let l:previous_mapping[a:previous_buffers[i].file_path] = a:previous_buffers[i]
  endfor
  for i in range(0, len(l:buffers) - 1)
    let l:buffers[i] = s:EnrichFileBufferWithActiveFlag(l:buffers[i], a:source_winid)
    let l:buffers[i] = s:EnrichFileBufferWithModifiedFlag(l:buffers[i])
    if  l:buffers[i].is_active is v:true
      let l:active = l:buffers[i]
    endif
    let l:mapping[l:buffers[i].file_path] = l:buffers[i]
  endfor

  for i in range(0, len(a:previous_buffers) - 1)
    let l:val = get(l:mapping, a:previous_buffers[i].file_path, v:null)
    if l:val isnot v:null
      if l:active is v:null || a:previous_buffers[i].file_path !=? l:active.file_path
        call add(l:output, l:val)
      endif
    endif
  endfor
  for i in range(0, len(l:buffers) - 1)
    let l:val = get(l:previous_mapping, l:buffers[i].file_path, v:null)
    if l:val is v:null
      if l:active is v:null || l:buffers[i].file_path !=? l:active.file_path
        call insert(l:output, l:buffers[i], 0)
      endif
    endif
  endfor
  if l:active isnot v:null
    call insert(l:output, l:active, 0)
  endif

  for i in range(0, len(l:output) - 1)
    let l:output[i] = s:EnrichFileBufferWithDisplayPath (l:output[i])
    let l:output[i] = s:EnrichFileBufferWithDisplayIndex(l:output[i], i + 1, len(l:output))
  endfor

  return l:output
endfunction
