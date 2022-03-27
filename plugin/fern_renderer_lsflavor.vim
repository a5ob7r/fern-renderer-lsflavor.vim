if exists('g:fern_renderer_lsflavor_loaded')
  finish
endif

let g:fern_renderer_lsflavor_loaded = 1

call fern#renderer#lsflavor#lscolor#init()
call fern#renderer#lsflavor#lsicon#init()

call extend(g:fern#renderers, {
      \ 'lsflavor': function('fern#renderer#lsflavor#new'),
      \ })
