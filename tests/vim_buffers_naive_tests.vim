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

function! s:get_buffer_paths(buffers) abort
  let l:paths = []
  for l:item in a:buffers
    call add(l:paths, s:normalize_path(get(l:item, 'file_path', '')))
  endfor
  return l:paths
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

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers([], win_getid())
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

function! s:test_get_file_buffers_reverses_without_previous_and_keeps_active_first() abort
  let l:fixture_dir = s:create_fixture_directory('get-file-buffers-reverse')
  let l:file_one = l:fixture_dir . '/alpha.txt'
  let l:file_two = l:fixture_dir . '/beta.txt'
  let l:file_three = l:fixture_dir . '/gamma.txt'

  try
    call s:reset_ui_state()
    call writefile(['alpha'], l:file_one)
    call writefile(['beta'], l:file_two)
    call writefile(['gamma'], l:file_three)

    execute 'edit ' . fnameescape(l:file_one)
    execute 'badd ' . fnameescape(l:file_two)
    execute 'badd ' . fnameescape(l:file_three)
    execute 'buffer ' . bufnr(l:file_two)

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers([], win_getid())
    let l:expected = [
          \ s:normalize_path(l:file_two),
          \ s:normalize_path(l:file_three),
          \ s:normalize_path(l:file_one),
          \ ]

    call assert_equal(
          \ l:expected,
          \ s:get_buffer_paths(l:buffers),
          \ 'Expected reverse order with active buffer pinned to the first item.')
    call assert_equal(v:true, l:buffers[0].is_active, 'Expected first item to be the active buffer.')
  finally
    call s:reset_ui_state()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_get_file_buffers_merges_previous_and_prepends_new_reversed() abort
  let l:fixture_dir = s:create_fixture_directory('get-file-buffers-merge')
  let l:file_alpha = l:fixture_dir . '/alpha.txt'
  let l:file_beta = l:fixture_dir . '/beta.txt'
  let l:file_gamma = l:fixture_dir . '/gamma.txt'
  let l:file_delta = l:fixture_dir . '/delta.txt'
  let l:file_epsilon = l:fixture_dir . '/epsilon.txt'

  try
    call s:reset_ui_state()
    call writefile(['alpha'], l:file_alpha)
    call writefile(['beta'], l:file_beta)
    call writefile(['gamma'], l:file_gamma)
    call writefile(['delta'], l:file_delta)
    call writefile(['epsilon'], l:file_epsilon)

    execute 'edit ' . fnameescape(l:file_alpha)
    execute 'badd ' . fnameescape(l:file_beta)
    execute 'badd ' . fnameescape(l:file_gamma)
    execute 'buffer ' . bufnr(l:file_beta)

    let l:previous_buffers = vim_buffers_naive#buffers#GetFileBuffers([], win_getid())

    execute 'silent! bwipeout! ' . bufnr(l:file_gamma)
    execute 'badd ' . fnameescape(l:file_delta)
    execute 'badd ' . fnameescape(l:file_epsilon)
    execute 'buffer ' . bufnr(l:file_alpha)

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers(l:previous_buffers, win_getid())
    let l:expected = [
          \ s:normalize_path(l:file_alpha),
          \ s:normalize_path(l:file_epsilon),
          \ s:normalize_path(l:file_delta),
          \ s:normalize_path(l:file_beta),
          \ ]

    call assert_equal(
          \ l:expected,
          \ s:get_buffer_paths(l:buffers),
          \ 'Expected active buffer first, then new buffers reversed, then prior buffers that still exist.')
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

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers([], win_getid())
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

function! s:test_get_file_buffers_rewrites_worktree_root_prefix_as_project() abort
  let l:fixture_dir = s:create_fixture_directory('worktree-label')
  let l:main_root = l:fixture_dir . '/main-project'
  let l:worktree_root = l:main_root . '/.worktrees/feature'
  let l:file_path = l:worktree_root . '/src/main.txt'

  try
    call s:reset_ui_state()
    call mkdir(l:main_root . '/.git/worktrees/feature', 'p')
    call mkdir(fnamemodify(l:file_path, ':h'), 'p')
    call writefile(['gitdir: ' . l:main_root . '/.git/worktrees/feature'], l:worktree_root . '/.git')
    call writefile(['main'], l:file_path)
    execute 'edit ' . fnameescape(l:file_path)

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers([], win_getid())
    let l:item = s:find_buffer_item_by_path(l:buffers, l:file_path)

    call assert_false(empty(l:item), 'Expected GetFileBuffers to include the worktree test file.')
    call assert_equal(
          \ '$PROJECT/src/main.txt',
          \ l:item.display_path,
          \ 'Expected display_path to replace the worktree root with $PROJECT label.')
  finally
    call s:reset_ui_state()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_get_file_buffers_prefers_cwd_prefix_inside_project() abort
  let l:fixture_dir = s:create_fixture_directory('cwd-label-inside-project')
  let l:project_root = l:fixture_dir . '/sample-project'
  let l:cwd_root = l:project_root . '/module'
  let l:file_path = l:cwd_root . '/src/main.txt'
  let l:original_cwd = getcwd()

  try
    call s:reset_ui_state()
    call mkdir(l:project_root . '/.git', 'p')
    call mkdir(fnamemodify(l:file_path, ':h'), 'p')
    call writefile(['main'], l:file_path)
    execute 'cd ' . fnameescape(l:cwd_root)
    execute 'edit ' . fnameescape(l:file_path)

    let l:buffers = vim_buffers_naive#buffers#GetFileBuffers([], win_getid())
    let l:item = s:find_buffer_item_by_path(l:buffers, l:file_path)

    let l:normalized_cwd = substitute(s:normalize_path(l:cwd_root), '[\/]\+$', '', '')
    let l:normalized_path = s:normalize_path(l:file_path)
    let l:expected_display_path = '$CWD' . l:normalized_path[strlen(l:normalized_cwd):]

    call assert_false(empty(l:item), 'Expected GetFileBuffers to include the nested project file.')
    call assert_equal(
          \ l:expected_display_path,
          \ l:item.display_path,
          \ 'Expected display_path to prefer $CWD when cwd is inside the project.')
  finally
    execute 'cd ' . fnameescape(l:original_cwd)
    call s:reset_ui_state()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_enrich_file_buffer_with_display_index_zero_pads_value() abort
  call vim_buffers_naive#buffers#GetFileBuffers([], win_getid())
  let l:EnrichFileBufferWithDisplayIndex = s:autoload_script_local_function('EnrichFileBufferWithDisplayIndex')

  let l:item = {
        \ 'bufnr': 1,
        \ 'file_path': '/tmp/example.txt',
        \ 'file_name': 'example.txt',
        \ }
  let l:enriched_item = call(l:EnrichFileBufferWithDisplayIndex, [l:item, 4, 15])

  call assert_equal(
        \ '04',
        \ l:enriched_item.display_index,
        \ 'Expected display_index to be zero-padded to total items width.')
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

function! s:test_buffers_list_x_closes_highlighted_buffer() abort
  let l:fixture_dir = s:create_fixture_directory('close-buffer-with-x')
  let l:file_one = l:fixture_dir . '/alpha.txt'
  let l:file_two = l:fixture_dir . '/beta.txt'

  try
    call s:reset_ui_state()
    call writefile(['alpha'], l:file_one)
    call writefile(['beta'], l:file_two)

    execute 'edit ' . fnameescape(l:file_one)
    execute 'badd ' . fnameescape(l:file_two)

    let l:popup_id = s:open_buffers_list_popup()
    let l:PopupFilter = s:autoload_script_local_function('PopupFilter')
    call call(l:PopupFilter, [l:popup_id, 'j'])
    call call(l:PopupFilter, [l:popup_id, 'x'])

    call assert_equal(-1, bufnr(l:file_two) > 0 ? (buflisted(bufnr(l:file_two)) ? 1 : -1) : -1, 'Expected highlighted buffer to be closed.')
    call assert_equal(1, len(getbufline(winbufnr(l:popup_id), 1, '$')), 'Expected one remaining row.')
  finally
    call s:close_all_popups()
    call s:wipe_file_buffers()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_buffers_list_capital_x_keeps_only_active_buffer() abort
  let l:fixture_dir = s:create_fixture_directory('close-others-with-x')
  let l:file_one = l:fixture_dir . '/alpha.txt'
  let l:file_two = l:fixture_dir . '/beta.txt'
  let l:file_three = l:fixture_dir . '/gamma.txt'

  try
    call s:reset_ui_state()
    call writefile(['alpha'], l:file_one)
    call writefile(['beta'], l:file_two)
    call writefile(['gamma'], l:file_three)

    execute 'edit ' . fnameescape(l:file_one)
    execute 'badd ' . fnameescape(l:file_two)
    execute 'badd ' . fnameescape(l:file_three)
    execute 'buffer ' . bufnr(l:file_three)
    call setline(1, 'changed')
    execute 'buffer ' . bufnr(l:file_one)

    let l:popup_id = s:open_buffers_list_popup()
    let l:PopupFilter = s:autoload_script_local_function('PopupFilter')
    call call(l:PopupFilter, [l:popup_id, 'j'])
    call call(l:PopupFilter, [l:popup_id, 'X'])

    call assert_equal(2, len(getbufline(winbufnr(l:popup_id), 1, '$')), 'Expected active and modified rows to remain.')
    call assert_equal(1, buflisted(bufnr(l:file_one)), 'Expected active buffer to stay.')
    call assert_equal(0, buflisted(bufnr(l:file_two)), 'Expected other buffer to be closed.')
    call assert_equal(1, buflisted(bufnr(l:file_three)), 'Expected modified buffer to be skipped.')
    call assert_equal(s:normalize_path(l:file_one), s:normalize_path(expand('%:p')), 'Expected active buffer to stay shown.')
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

function! s:open_many_buffers(fixture_dir, count) abort
  for l:i in range(1, a:count)
    let l:file = printf('%s/file%02d.txt', a:fixture_dir, l:i)
    call writefile(['x'], l:file)
    execute 'edit ' . fnameescape(l:file)
  endfor
endfunction

function! s:test_buffers_list_marks_modified_buffers() abort
  let l:fixture_dir = s:create_fixture_directory('modified')

  try
    call s:reset_ui_state()
    call s:open_many_buffers(l:fixture_dir, 2)
    call setline(1, 'changed')
    let l:popup_id = s:open_buffers_list_popup()

    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_match('^1 +\* .*file02\.txt', l:lines[0], 'Expected modified active row to show +*.')
    call assert_match('^2    .*file01\.txt', l:lines[1], 'Expected unmodified row to have no flags.')
    call popup_close(l:popup_id)
  finally
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_buffers_list_aligns_rows_with_multi_digit_indexes() abort
  let l:fixture_dir = s:create_fixture_directory('alignment')

  try
    call s:reset_ui_state()
    call s:open_many_buffers(l:fixture_dir, 12)
    call setline(1, 'changed')
    let l:popup_id = s:open_buffers_list_popup()

    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_equal(10, len(l:lines), 'Expected at most 10 visible rows.')
    for l:line in l:lines
      call assert_match('^\d\d [ +][ *] \$CWD', l:line, 'Expected zero-padded index, flags column and path.')
    endfor
    call assert_match('^01 +\* ', l:lines[0], 'Expected modified active row to show +*.')
    call assert_equal(1, len(uniq(map(copy(l:lines), 'stridx(v:val, "$CWD")'))), 'Expected paths to start in the same column.')
    call popup_close(l:popup_id)
  finally
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_buffers_list_navigation_wraps_and_scrolls() abort
  let l:fixture_dir = s:create_fixture_directory('navigation')

  try
    call s:reset_ui_state()
    call s:open_many_buffers(l:fixture_dir, 13)

    let l:popup_id = s:open_buffers_list_popup()
    let l:PopupFilter = s:autoload_script_local_function('PopupFilter')

    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_equal(10, len(l:lines), 'Expected at most 10 visible rows.')
    call assert_match('^01  \* .*file13\.txt$', l:lines[0])
    call assert_equal(1, line('.', l:popup_id))

    call call(l:PopupFilter, [l:popup_id, 'k'])
    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_match('^13   .*file01\.txt$', l:lines[-1], 'Expected k on first row to wrap to last row.')
    call assert_equal(10, line('.', l:popup_id))

    call call(l:PopupFilter, [l:popup_id, "\<Down>"])
    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_match('^01  \* ', l:lines[0], 'Expected Down on last row to wrap to first row.')
    call assert_equal(1, line('.', l:popup_id))

    call call(l:PopupFilter, [l:popup_id, "\<PageDown>"])
    let l:lines = s:get_popup_lines(l:popup_id)
    call assert_match('^01  \* ', l:lines[0], 'Expected PageDown to be ignored.')
    call assert_equal(1, line('.', l:popup_id))
  finally
    call s:close_all_popups()
    call s:wipe_file_buffers()
    call s:cleanup_directory(l:fixture_dir)
  endtry
endfunction

function! s:test_buffers_list_esc_closes_popup_and_enter_opens_scrolled_selection() abort
  let l:fixture_dir = s:create_fixture_directory('esc-and-enter')

  try
    call s:reset_ui_state()
    call s:open_many_buffers(l:fixture_dir, 13)

    let l:popup_id = s:open_buffers_list_popup()
    let l:PopupFilter = s:autoload_script_local_function('PopupFilter')
    call call(l:PopupFilter, [l:popup_id, "\<Esc>"])
    call assert_true(index(popup_list(), l:popup_id) < 0, 'Expected Esc to close popup.')

    let l:popup_id = s:open_buffers_list_popup()
    call call(l:PopupFilter, [l:popup_id, 'k'])
    call call(l:PopupFilter, [l:popup_id, "\<CR>"])
    call assert_equal('file01.txt', expand('%:t'), 'Expected Enter to open the buffer selected after scrolling.')
    call assert_equal([], popup_list(), 'Expected popup to close after Enter.')
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
  call s:test_get_file_buffers_reverses_without_previous_and_keeps_active_first()
  call s:test_get_file_buffers_merges_previous_and_prepends_new_reversed()
  call s:test_get_file_buffers_rewrites_project_root_prefix()
  call s:test_get_file_buffers_rewrites_worktree_root_prefix_as_project()
  call s:test_get_file_buffers_prefers_cwd_prefix_inside_project()
  call s:test_enrich_file_buffer_with_display_index_zero_pads_value()
  call s:test_buffers_list_shows_empty_state_when_no_file_buffers()
  call s:test_buffers_list_x_closes_highlighted_buffer()
  call s:test_buffers_list_capital_x_keeps_only_active_buffer()
  call s:test_buffers_list_enter_opens_selected_buffer()
  call s:test_buffers_list_marks_modified_buffers()
  call s:test_buffers_list_aligns_rows_with_multi_digit_indexes()
  call s:test_buffers_list_navigation_wraps_and_scrolls()
  call s:test_buffers_list_esc_closes_popup_and_enter_opens_scrolled_selection()
  call s:cleanup_directory(s:repo_root . '/tests/tmp')
endfunction
