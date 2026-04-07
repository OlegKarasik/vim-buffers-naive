if exists('g:loaded_buffers_naive') || &compatible
  finish
endif
let g:loaded_buffers_naive = 1

command! -nargs=0 BuffersList call buffers_naive#open()
