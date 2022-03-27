let s:icons = {}

function! fern#renderer#lsflavor#lsicon#init() abort
  let l:lsicons = s:default_lsicons() . s:get_lsicons()

  let s:icons = s:parse(l:lsicons)
endfunction

function! fern#renderer#lsflavor#lsicon#icons() abort
  return s:icons
endfunction

function! s:default_lsicons() abort
  return 'fi=:di=:ln=:pi=ﳣ:so=:bd=ﰩ:cd=:or=:ex=:'
endfunction

function! s:get_lsicons() abort
  return getenv('LS_ICONS')
endfunction

function! s:parse(lsicons) abort
  let l:icons = {}
  let l:icons.extensions = {}

  for l:entry in split(a:lsicons, ':')
    try
      let [l:name, l:icon] = split(l:entry, '=')
    catch /^Vim\%((\a\+)\)\=:E688:/
      continue
    endtry

    if l:name ==# 'no'
      let l:icons.NORMAL = l:icon
    elseif l:name ==# 'fi'
      let l:icons.FILE = l:icon
    elseif l:name ==# 'di'
      let l:icons.DIR = l:icon
    elseif l:name ==# 'ln'
      let l:icons.LINK = l:icon
    elseif l:name ==# 'or'
      let l:icons.ORPHAN = l:icon
    elseif l:name ==# 'pi'
      let l:icons.FIFO = l:icon
    elseif l:name ==# 'so'
      let l:icons.SOCK = l:icon
    elseif l:name ==# 'bd'
      let l:icons.BLK = l:icon
    elseif l:name ==# 'cd'
      let l:icons.CHR = l:icon
    elseif l:name ==# 'ex'
      let l:icons.EXEC = l:icon
    elseif l:name =~# '^*'
      let l:key = toupper(l:name[1:])
      let l:icons.extensions[l:key] = l:icon
    endif
  endfor

  return l:icons
endfunction
