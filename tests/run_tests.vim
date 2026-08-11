set nocompatible
set nomore

let s:repo_root = fnamemodify(expand('<sfile>:p'), ':h:h')
execute 'set runtimepath^=' . fnameescape(s:repo_root)

if !hlexists('Pmenu')
  highlight Pmenu ctermfg=7 ctermbg=0
endif
if !hlexists('PmenuSel')
  highlight PmenuSel ctermfg=0 ctermbg=7
endif
if !hlexists('String')
  highlight String ctermfg=2
endif

runtime plugin/vim_buffers_naive.vim
execute 'source ' . fnameescape(s:repo_root . '/tests/vim_buffers_naive_tests.vim')

call VimBuffersNaiveTestRunAll()

if !empty(v:errors)
  for s:error in v:errors
    echom s:error
  endfor
  cquit 1
endif

quitall!
