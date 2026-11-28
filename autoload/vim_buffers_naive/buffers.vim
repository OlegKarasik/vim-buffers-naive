scriptencoding utf-8

let s:separator = exists('+shellslash') && !&shellslash ? '\' : '/'

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

function! s:EnrichFileBufferWithRelativePath(item) abort
  let l:file_path     = a:item.file_path
  let l:relative_path = l:file_path
  let l:relative_pcat = ''
  let l:matched_root  = ''

  let l:shortcuts = [
        \ a:item.home_path,    'HOME',
        \ a:item.cwd_path,     'PWD',
        \ a:item.project_path, 'PROJECT'
        \ ]

  let l:i = 0
  while l:i < len(l:shortcuts)
    let l:root = l:shortcuts[l:i]
    let l:name = l:shortcuts[l:i + 1]

    if !empty(l:root) && stridx(l:file_path, l:root) ==# 0 && strlen(l:root) > strlen(l:matched_root)
      let l:relative_path = l:file_path[strlen(l:root):]
      let l:relative_pcat = l:name
      let l:matched_root = l:root
    endif

    let l:i += 2
  endwhile

  let a:item.relative_path = l:relative_path
  let a:item.relative_pcat = l:relative_pcat
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
    let l:buffers[i] = s:EnrichFileBufferWithRelativePath(l:buffers[i])
    if  l:buffers[i].is_active is v:true
      let l:active = l:buffers[i]
    endif
    let l:mapping[l:buffers[i].file_path] = l:buffers[i]
  endfor

  for i in range(0, len(a:previous_buffers) - 1)
    let l:val = get(l:mapping, a:previous_buffers[i].file_path, v:null)
    if l:val isnot v:null
      if l:active is v:null || a:previous_buffers[i].file_path !=# l:active.file_path
        call add(l:output, l:val)
      endif
    endif
  endfor
  for i in range(0, len(l:buffers) - 1)
    let l:val = get(l:previous_mapping, l:buffers[i].file_path, v:null)
    if l:val is v:null
      if l:active is v:null || l:buffers[i].file_path !=# l:active.file_path
        call insert(l:output, l:buffers[i], 0)
      endif
    endif
  endfor
  if l:active isnot v:null
    call insert(l:output, l:active, 0)
  endif

  let l:pcat_idx_fmt  = '%0' . len(string(len(l:output))) . 'd'
  let l:pcat_path_fmt = '$%s' . s:separator . '%s'

  let l:pcat_output   = { 'ALL': [] }
  for i in range(0, len(l:output) - 1)
    let l:relative_pcat = l:output[i].relative_pcat
    let l:relative_path = l:output[i].relative_path

    if l:relative_pcat !=# ''
      if !has_key(l:pcat_output, l:relative_pcat)
        let l:pcat_output[l:relative_pcat] = []
      endif
      call add(
            \ l:pcat_output[l:relative_pcat],
            \ #{
            \     idx: printf(l:pcat_idx_fmt, len(l:pcat_output[l:relative_pcat]) + 1),
            \     path: l:relative_path,
            \     item: l:output[i]
            \  })
    else
      let l:relative_path = l:relative_path[1:]
    endif

    call add(
          \ l:pcat_output['ALL'], 
          \ #{
          \     idx:  printf(l:pcat_idx_fmt, i + 1), 
          \     path: printf(l:pcat_path_fmt, l:relative_pcat, l:relative_path), 
          \     item: l:output[i]
          \  })
  endfor

  return l:pcat_output
endfunction
