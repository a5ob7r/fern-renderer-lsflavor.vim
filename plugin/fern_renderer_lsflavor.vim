if exists('g:fern_renderer_lsflavor_loaded')
  finish
endif

let g:fern_renderer_lsflavor_loaded = 1

call extend(g:fern#renderers, {
      \ 'lsflavor': function('fern#renderer#lsflavor#new'),
      \ })
