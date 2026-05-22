if exists('g:loaded_vim_buffers_naive') || &compatible
  finish
endif
let g:loaded_vim_buffers_naive = 1

command! -nargs=0 BuffersList call vim_buffers_naive#BuffersList()
call vim_buffers_naive#register_plug_mappings()
