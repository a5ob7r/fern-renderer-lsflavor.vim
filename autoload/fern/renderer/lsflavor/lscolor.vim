let s:Color = vital#lsflavor#import('Color')

let s:syntax_parameters = {}
let s:highlight_parameters = {}

function! fern#renderer#lsflavor#lscolor#init() abort
  let l:lscolors = s:default_lscolors() . s:get_lscolors()

  let [s:syntax_parameters, s:highlight_parameters] = s:parse(l:lscolors)
endfunction

function! fern#renderer#lsflavor#lscolor#highlight_parameters() abort
  return s:highlight_parameters
endfunction

function! fern#renderer#lsflavor#lscolor#syntax_parameters() abort
  return s:syntax_parameters
endfunction

function! s:default_lscolors() abort
  return 'rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:'
endfunction

function! s:get_lscolors() abort
  return getenv('LS_COLORS')
endfunction

function! s:parse(lscolors) abort
  let l:syntax = {}
  let l:syntax.extensions = {}
  let l:highlight = {}
  let l:highlight.extensions = {}

  for l:param in split(a:lscolors, ':')
    try
      let [l:name, l:params] = split(l:param, '=')
    catch /^Vim\%((\a\+)\)\=:E688:/
      continue
    endtry

    if [l:name, l:params] == ['ln', 'target']
      continue
    endif

    let l:colors = s:parse_sgr_params(l:params)

    if l:colors is# v:null
      continue
    endif

    if l:name ==# 'no'
      let l:syntax.NORMAL = l:params
      let l:highlight.NORMAL = l:colors
    elseif l:name ==# 'fi'
      let l:syntax.FILE = l:params
      let l:highlight.FILE = l:colors
    elseif l:name ==# 'di'
      let l:syntax.DIR = l:params
      let l:highlight.DIR = l:colors
    elseif l:name ==# 'ln'
      let l:syntax.LINK = l:params
      let l:highlight.LINK = l:colors
    elseif l:name ==# 'or'
      let l:syntax.ORPHAN = l:params
      let l:highlight.ORPHAN = l:colors
    elseif l:name ==# 'pi'
      let l:syntax.FIFO = l:params
      let l:highlight.FIFO = l:colors
    elseif l:name ==# 'so'
      let l:syntax.SOCK = l:params
      let l:highlight.SOCK = l:colors
    elseif l:name ==# 'bd'
      let l:syntax.BLK = l:params
      let l:highlight.BLK = l:colors
    elseif l:name ==# 'cd'
      let l:syntax.CHR = l:params
      let l:highlight.CHR = l:colors
    elseif l:name ==# 'ex'
      let l:syntax.EXEC = l:params
      let l:highlight.EXEC = l:colors
    elseif l:name =~# '^*'
      let l:key = toupper(l:name[1:])
      let l:syntax.extensions[l:key] = l:params
      let l:highlight.extensions[l:key] = l:colors
    endif
  endfor

  return [l:syntax, l:highlight]
endfunction

" SGR parameters to :highlight command's them.
function! s:parse_sgr_params(params) abort
  let l:iter = s:iterator(a:params)

  let l:params = {
        \ 'cterm': [],
        \ 'ctermfg': [],
        \ 'ctermbg': [],
        \ 'ctermul': [],
        \ 'gui': [],
        \ 'guifg': [],
        \ 'guibg': [],
        \ 'guisp': []
        \ }

  " -1: Initial.
  " 0: Reset.
  " 4: Underline.
  " 30-37: Set foreground.
  " 38: Set foreground with params.
  " 40-47: Set background.
  " 48: Set background wtih params.
  let l:state = -1

  while 1
    if l:state == -1
      let l:n = l:iter.next()

      if l:n is# v:null
        break
      endif

      let l:state = l:n
    elseif l:state == 0
      let l:state = -1
    elseif l:state == 1
      let l:params.cterm += ['bold']
      let l:params.gui += ['bold']

      let l:state = -1
    elseif l:state == 3
      let l:params.cterm += ['italic']
      let l:params.gui += ['italic']

      let l:state = -1
    elseif l:state == 4
      let l:params.cterm += ['underline']
      let l:params.gui += ['underline']

      let l:state = -1
    elseif l:state == 7
      let l:params.cterm += ['reverse']
      let l:params.gui += ['reverse']

      let l:state = -1
    elseif 30 <= l:state && l:state <= 37
      let l:n = l:state - 30
      let l:params.ctermfg = [l:n]

      let l:state = -1
    elseif 40 <= l:state && l:state <= 47
      let l:n = l:state - 40
      let l:params.ctermbg = [l:n]

      let l:state = -1
    elseif l:state == 38 || l:state == 48
      let l:rgb = ''

      let l:n = l:iter.next()

      if l:n is# v:null
        return v:null
      elseif l:n == 5
        let l:n = l:iter.next()

        if l:n is# v:null
          return v:null
        endif

        if l:state == 38
          let l:params.ctermfg = [l:n]
        elseif l:state == 48
          let l:params.ctermbg = [l:n]
        else
          return v:null
        endif

        let l:rgb = s:Color.xterm(l:n).as_rgb_hex()
      elseif l:n == 2
        let l:rrggbb = []

        for _ in range(3)
          let l:n = l:iter.next()

          if l:n is# v:null
            return v:null
          endif

          let l:rrggbb += [l:n]
        endfor

        let l:rgb = s:Color.rbg(l:rrggbb[0], l:rrggbb[1], l:rrggbb[2]).as_rgb_hex()
      else
        return v:null
      endif

      if l:state == 38
        let l:params.guifg = [l:rgb]
      elseif l:state == 48
        let l:params.guibg = [l:rgb]
      else
        return v:null
      endif

      let l:state = -1
    else
      return v:null
    endif
  endwhile

  return map(l:params, { _, v -> join(v, '') })
endfunction

function! s:iterator(params) abort
  return {
        \ 'idx': 0,
        \ 'array': split(a:params, ';'),
        \ 'next': function('s:next')
        \ }
endfunction

function! s:next() dict abort
  if -1 < l:self.idx && l:self.idx < len(l:self.array)
    let l:idx = l:self.idx
    let l:self.idx += 1
    return str2nr(l:self.array[l:idx])
  else
    return v:null
  endif
endfunction
