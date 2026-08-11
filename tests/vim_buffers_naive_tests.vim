let s:repo_root = fnamemodify(expand('<sfile>:p'), ':h:h')
set hidden

function! s:cleanup_directory(path) abort
  if isdirectory(a:path)
    call delete(a:path, 'rf')
  endif
endfunction

function! s:create_fixture_directory(name) abort
  let l:path = s:repo_root . '/tests/tmp/' . a:name
  call s:cleanup_directory(l:path)
  call mkdir(l:path, 'p')
  return l:path
endfunction

function! s:close_all_popups() abort
  if !exists('*popup_list')
    return
  endif

  for l:popup_id in popup_list()
    call popup_close(l:popup_id)
  endfor
endfunction

function! s:wipe_file_buffers() abort
  for l:info in getbufinfo({'buflisted': 1})
    if getbufvar(l:info.bufnr, '&buftype') ==# ''
      execute 'silent! bwipeout! ' . l:info.bufnr
    endif
  endfor

  enew
  setlocal buftype=nofile bufhidden=hide noswapfile
endfunction

function! s:reset_ui_state() abort
  call s:close_all_popups()
  call s:wipe_file_buffers()
endfunction

function! s:normalize_path(path) abort
  return fnamemodify(a:path, ':p')
endfunction

function! s:trim_right(text) abort
  return substitute(a:text, '\s\+$', '', '')
endfunction

function! s:get_popup_lines(popup_id) abort
  let l:popup_bufnr = winbufnr(a:popup_id)
  if l:popup_bufnr <= 0
    return []
  endif

  let l:lines = []
  for l:line in getbufline(l:popup_bufnr, 1, '$')
    call add(l:lines, s:trim_right(l:line))
  endfor
  return l:lines
endfunction

function! s:find_buffer_item_by_path(buffers, target_path) abort
  let l:target_path = s:normalize_path(a:target_path)
  for l:item in a:buffers
    if s:normalize_path(get(l:item, 'file_path', '')) ==# l:target_path
      return l:item
    endif
  endfor
  return {}
endfunction

function! s:open_buffers_list_popup() abort
  call s:close_all_popups()
  let l:before_ids = popup_list()

  silent BuffersList
  let l:after_ids = popup_list()

  for l:popup_id in l:after_ids
    if index(l:before_ids, l:popup_id) < 0
      return l:popup_id
    endif
  endfor

  call assert_false(1, 'Expected BuffersList to open a popup.')
  return -1
endfunction

function! s:autoload_script_local_function(script_local_name) abort
  call vim_buffers_naive#register_plug_mappings()
  let l:function_name = matchstr(execute('function'), '<SNR>\d\+_' . a:script_local_name)
  call assert_notequal('', l:function_name, 'Expected script-local function: ' . a:script_local_name)
  return function(l:function_name)
endfunction

function! s:test_buffers_list_command_is_defined() abort
  call assert_equal(2, exists(':BuffersList'), 'Expected :BuffersList command to be defined.')
endfunction

function! s:test_buffers_list_plug_mapping_is_defined() abort
  call assert_notequal('', maparg('<Plug>(BuffersList)', 'n'), 'Expected <Plug>(BuffersList) mapping to be defined.')
endfunction

function! s:test_buffers_list_plug_mapping_does_not_override_existing_lhs() abort
  silent! nunmap <Plug>(BuffersList)
  execute 'nnoremap <silent> <Plug>(BuffersList) :<C-U>let g:vim_buffers_naive_test_preserved_map = 1<CR>'

  let l:before_rhs = maparg('<Plug>(BuffersList)', 'n')
  call vim_buffers_naive#register_plug_mappings()
  let l:after_rhs = maparg('<Plug>(BuffersList)', 'n')

  call assert_equal(
        \ l:before_rhs,
        \ l:after_rhs,
        \ 'Expected plug mapping registration to preserve existing <Plug>(BuffersList) mapping.')

  silent! nunmap <Plug>(BuffersList)
  call vim_buffers_naive#register_plug_mappings()
  unlet! g:vim_buffers_naive_test_preserved_map
endfunction

function! s:test_get_file_buffers_collects_files_and_marks_active() abort
  let l:fixture_dir = s:create_fixture_directory('get-file-buffers')
  let l:file_one = l:fixture_dir . '/alpha.txt'
  let l:file_two = l:fixture_dir . '/beta.txt'

  try
    call s:reset_ui_state()
    call writefile(['alpha'], l:file_one)
    call writefile(['beta'], l:file_two)

    execute 'edit ' . fnameescape(l:file_one)
    execute 'badd ' . fnameescape(l:file_two)

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers(win_getid())
    let l:item_one = s:find_buffer_item_by_path(l:buffers, l:file_one)
    let l:item_two = s:find_buffer_item_by_path(l:buffers, l:file_two)

    call assert_false(empty(l:item_one), 'Expected GetFileBuffers to include the first file buffer.')
    call assert_false(empty(l:item_two), 'Expected GetFileBuffers to include the second file buffer.')
    call assert_equal(v:true, l:item_one.is_active, 'Expected current buffer to be marked active.')
    call assert_equal(v:false, l:item_two.is_active, 'Expected non-current buffer to be marked inactive.')
    call assert_equal('alpha.txt', l:item_one.file_name, 'Expected file_name to match first file basename.')
    call assert_equal('beta.txt', l:item_two.file_name, 'Expected file_name to match second file basename.')
  finally
    call s:reset_ui_state()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_get_file_buffers_rewrites_project_root_prefix() abort
  let l:fixture_dir = s:create_fixture_directory('project-label')
  let l:project_root = l:fixture_dir . '/sample-project'
  let l:file_path = l:project_root . '/src/main.txt'

  try
    call s:reset_ui_state()
    call mkdir(l:project_root . '/.git', 'p')
    call mkdir(fnamemodify(l:file_path, ':h'), 'p')
    call writefile(['main'], l:file_path)
    execute 'edit ' . fnameescape(l:file_path)

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers(win_getid())
    let l:item = s:find_buffer_item_by_path(l:buffers, l:file_path)

    let l:normalized_root = substitute(s:normalize_path(l:project_root), '[\/]\+$', '', '')
    let l:normalized_path = s:normalize_path(l:file_path)
    let l:expected_display_path = '$PROJECT' . l:normalized_path[strlen(l:normalized_root):]

    call assert_false(empty(l:item), 'Expected GetFileBuffers to include the project test file.')
    call assert_equal(
          \ l:expected_display_path,
          \ l:item.display_path,
          \ 'Expected display_path to replace the project root with $PROJECT label.')
  finally
    call s:reset_ui_state()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_buffers_list_shows_empty_state_when_no_file_buffers() abort
  try
    call s:reset_ui_state()
    let l:popup_id = s:open_buffers_list_popup()
    let l:lines = s:get_popup_lines(l:popup_id)
    let l:title = get(popup_getoptions(l:popup_id), 'title', '')

    call assert_equal(['0   No file buffers'], l:lines, 'Expected BuffersList empty state text.')
    call assert_equal('Buffers List', l:title, 'Expected BuffersList popup title.')
  finally
    call s:close_all_popups()
    call s:wipe_file_buffers()
  endtry
endfunction

function! s:test_buffers_list_filter_is_case_insensitive() abort
  let l:fixture_dir = s:create_fixture_directory('filter-case-insensitive')
  let l:file_one = l:fixture_dir . '/alpha.txt'
  let l:file_two = l:fixture_dir . '/Beta.txt'

  try
    call s:reset_ui_state()
    call writefile(['alpha'], l:file_one)
    call writefile(['beta'], l:file_two)

    execute 'edit ' . fnameescape(l:file_one)
    execute 'badd ' . fnameescape(l:file_two)

    let l:popup_id = s:open_buffers_list_popup()
    let l:PopupFilter = s:autoload_script_local_function('PopupFilter')
    call call(l:PopupFilter, [l:popup_id, "\<C-F>"])
    call call(l:PopupFilter, [l:popup_id, 'b'])
    call call(l:PopupFilter, [l:popup_id, 'E'])

    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_equal(1, len(l:lines), 'Expected one filtered match for query "bE".')
    call assert_true(
          \ stridx(tolower(l:lines[0]), 'beta.txt') >= 0,
          \ 'Expected query "bE" to match "Beta.txt" case-insensitively.')
  finally
    call s:close_all_popups()
    call s:wipe_file_buffers()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_buffers_list_enter_opens_selected_buffer() abort
  let l:fixture_dir = s:create_fixture_directory('open-selected-buffer')
  let l:file_one = l:fixture_dir . '/first.txt'
  let l:file_two = l:fixture_dir . '/second.txt'

  try
    call s:reset_ui_state()
    call writefile(['first'], l:file_one)
    call writefile(['second'], l:file_two)

    execute 'edit ' . fnameescape(l:file_one)
    execute 'badd ' . fnameescape(l:file_two)

    let l:popup_id = s:open_buffers_list_popup()
    let l:PopupFilter = s:autoload_script_local_function('PopupFilter')
    call call(l:PopupFilter, [l:popup_id, 'j'])
    call call(l:PopupFilter, [l:popup_id, "\<CR>"])

    call assert_equal(
          \ s:normalize_path(l:file_two),
          \ s:normalize_path(expand('%:p')),
          \ 'Expected <CR> on selected row to open that buffer.')
    call assert_true(index(popup_list(), l:popup_id) < 0, 'Expected popup to close after selection confirmation.')
  finally
    call s:close_all_popups()
    call s:wipe_file_buffers()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! VimBuffersNaiveTestRunAll() abort
  call s:test_buffers_list_command_is_defined()
  call s:test_buffers_list_plug_mapping_is_defined()
  call s:test_buffers_list_plug_mapping_does_not_override_existing_lhs()
  call s:test_get_file_buffers_collects_files_and_marks_active()
  call s:test_get_file_buffers_rewrites_project_root_prefix()
  call s:test_buffers_list_shows_empty_state_when_no_file_buffers()
  call s:test_buffers_list_filter_is_case_insensitive()
  call s:test_buffers_list_enter_opens_selected_buffer()
  call s:cleanup_directory(s:repo_root . '/tests/tmp')
endfunction
