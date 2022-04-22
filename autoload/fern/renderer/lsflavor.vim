let s:AsyncLambda = vital#fern#import('Async.Lambda')
let s:Promise = vital#fern#import('Async.Promise')
let s:Config = vital#fern#import('Config')

call s:Config.config(expand('<sfile>:p'), {
      \ 'branch#root': ' ',
      \ 'branch#init_node': '├── ',
      \ 'branch#last_node': '└── ',
      \ 'branch#parent_init_node': '│  ',
      \ 'branch#parent_last_node': '   ',
      \ })

call fern#renderer#lsflavor#lscolor#init()
call fern#renderer#lsflavor#lsicon#init()

function! fern#renderer#lsflavor#new() abort
  let l:default = fern#renderer#default#new()

  return extend(copy(default), {
        \ 'render': funcref('s:render'),
        \ 'syntax': funcref('s:syntax'),
        \ 'highlight': funcref('s:highlight')
        \ })
endfunction

function! s:render(nodes) abort
  let l:helper = fern#helper#new()
  let l:nodes = copy(a:nodes)

  let l:node_helper = s:node_helper(l:nodes, l:helper)

  return s:AsyncLambda.map(copy(a:nodes), { v, -> s:render_node(v, l:node_helper) })
endfunction

" Return promise list to sort nodes.
function! s:sort_jobs(nodes, helper) abort
  let l:jobs = []
  let l:checked = {}

  let l:include = get(a:helper.fern, 'include', '')
  let l:exclude = get(a:helper.fern, 'exclude', '')
  let l:Comparator = a:helper.fern.comparator.compare

  for l:node in a:nodes
    let l:parent = s:get_parent_node(l:node, a:helper)

    if l:parent is# v:null
      continue
    endif

    let l:path = l:parent._path

    if has_key(l:checked, l:path)
      continue
    endif

    let l:checked[l:path] = 1

    let l:siblings = s:get_sibling_nodes(l:node, a:helper)

    let l:job = s:Promise.resolve(l:siblings)
          \.then({ nodes -> filter(nodes, printf("v:val._path !~# '%s' || v:val._path =~# '%s'", l:exclude, l:include)) })
          \.then({ nodes -> s:max_node(nodes, l:Comparator) })
    let l:jobs += [l:job]
  endfor

  return l:jobs
endfunction

" A "max()" for fern node list. Return "v:null" if the list is empty.
function! s:max_node(nodes, cmp) abort
  return reduce(a:nodes, { acc, val -> acc isnot# v:null && a:cmp(acc, val) >= 0 ? acc : val }, v:null)
endfunction

function! s:is_last_node(node) dict abort
  if has_key(l:self.last_node_memo, a:node._path)
    return l:self.last_node_memo[a:node._path]
  else
    return v:false
  endif
endfunction

function! s:node_helper(nodes, helper) abort
  let l:jobs = s:sort_jobs(a:nodes, a:helper)
  let [l:nodes, l:e] = s:Promise.wait(s:Promise.all(l:jobs))

  let l:memo = {}

  for l:node in l:nodes
    if l:node is# v:null
      continue
    endif

    let l:memo[l:node._path] = v:true
  endfor

  return {
        \ 'helper': a:helper,
        \ 'last_node_memo': l:memo,
        \ 'is_last_node': function('s:is_last_node')
        \ }
endfunction

" Return sibling nodes, which contain the source node selve.
function! s:get_sibling_nodes(node, helper) abort
  let l:parent = s:get_parent_node(a:node, a:helper)

  if l:parent is# v:null
    return v:null
  endif

  return get(l:parent.concealed, '__cache_children', v:null)
endfunction

" Return a parent node of a source node.
"
" TODO: Really need to use helper?
function! s:get_parent_node(node, helper) abort
  return a:node.__owner
endfunction

" Return whether or not the file is a executable one.
function! s:is_executable(path) abort
  return getfperm(a:path) =~# 'x'
endfunction

" A "getftype()" with extras, especially for symlinks.
"
" 1. If the file path points symlink,
"   a. Return 'cyclic' if it is a cyclic link.
"   b. Return 'orphan' if it is a orphaned link.
"   c. Return 'link' otherwise.
" 2. If the file path doesn't exist, return "v:null".
" 3. Fallback to "getftype()" otherwise.
function! s:get_filetype(path) abort
  let l:ftype = getftype(a:path)

  if l:ftype ==# 'link'
    try
      if empty(glob(resolve(a:path)))
        return 'orphan'
      else
        return l:ftype
      endif
    catch /^Vim\%((\a\+)\)\=:E655:/
      return 'cyclic'
    endtry
  elseif empty(l:ftype)
    return v:null
  endif

  return l:ftype
endfunction

" Similar to the '-F|--classify=[WHEN]' option of 'ls(1)'.
function! s:filetype_indicator(path) abort
  let l:filetype = s:get_filetype(a:path)

  if l:filetype ==# 'dir'
    return '/'
  elseif index(['link', 'orphan', 'cyclic'], l:filetype) >= 0
    return '@'
  elseif l:filetype ==# 'socket'
    return '='
  elseif l:filetype ==# 'fifo'
    return '|'
  elseif s:is_executable(a:path)
    return '*'
  else
    return ''
  endif
endfunction

" s:tails('abc') == ['abc', 'bc', 'c', '']
"
" https://hackage.haskell.org/package/base-4.16.1.0/docs/Data-List.html#v:tails
function! s:tails(s) abort
  return map(range(len(a:s) + 1), { v -> slice(a:s, v) })
endfunction

function! s:render_label(label, path) abort
  let l:ftype = s:get_filetype(a:path)
  let l:indicator = s:filetype_indicator(a:path)
  let l:params = fern#renderer#lsflavor#lscolor#syntax_parameters()

  if l:ftype ==# 'dir'
    return printf('[%sm%s[m', l:params.DIR, a:label) . l:indicator
  elseif l:ftype ==# 'link'
    return printf('[%sm%s[m', l:params.LINK, a:label) . l:indicator
  elseif l:ftype ==# 'bdev'
    return printf('[%sm%s[m', l:params.BLK, a:label) . l:indicator
  elseif l:ftype ==# 'cdev'
    return printf('[%sm%s[m', l:params.CHR, a:label) . l:indicator
  elseif l:ftype ==# 'socket'
    return printf('[%sm%s[m', l:params.SOCK, a:label) . l:indicator
  elseif l:ftype ==# 'fifo'
    return printf('[%sm%s[m', l:params.FIFO, a:label) . l:indicator
  elseif index(['orphan', 'cyclic'], l:ftype) >= 0
    return printf('[%sm%s[m', l:params.ORPHAN, a:label) . l:indicator
  elseif s:is_executable(a:path)
    return printf('[%sm%s[m', l:params.EXEC, a:label) . l:indicator
  else
    for l:query in s:tails(toupper(a:label))
      if has_key(l:params.extensions, l:query)
        return printf('[%sm%s[m', l:params.extensions[l:query], a:label) . l:indicator
      endif
    endfor

    return printf('[%sm%s[m', l:params.FILE, a:label) . l:indicator
  endif
endfunction

function! s:get_icon(path) abort
  let l:ftype = s:get_filetype(a:path)

  let l:icons = fern#renderer#lsflavor#lsicon#icons()

  if l:ftype ==# 'dir'
    return l:icons.DIR
  elseif l:ftype ==# 'link'
    return l:icons.LINK
  elseif l:ftype ==# 'bdev'
    return l:icons.BLK
  elseif l:ftype ==# 'cdev'
    return l:icons.CHR
  elseif l:ftype ==# 'socket'
    return l:icons.SOCK
  elseif l:ftype ==# 'fifo'
    return l:icons.FIFO
  elseif l:ftype ==# 'orphan'
    return l:icons.ORPHAN
  elseif s:is_executable(a:path)
    return l:icons.EXEC
  else
    for l:query in s:tails(toupper(fnamemodify(a:path, ':t')))
      if has_key(l:icons.extensions, l:query)
        return l:icons.extensions[l:query]
      endif
    endfor

    return l:icons.FILE
  endif
endfunction

function! s:render_tree_branch(node, helper) abort
  let l:child = a:node
  let l:parent = s:get_parent_node(l:child, a:helper.helper)

  if l:parent is# v:null
    return g:fern#renderer#lsflavor#branch#root
  endif

  if a:helper.is_last_node(l:child)
    let l:branch = g:fern#renderer#lsflavor#branch#last_node
  else
    let l:branch = g:fern#renderer#lsflavor#branch#init_node
  endif

  while l:parent isnot# v:null
    let l:child = l:parent
    let l:parent = s:get_parent_node(l:child, a:helper.helper)

    if l:parent is# v:null
      break
    endif

    if a:helper.is_last_node(l:child)
      let l:branch = g:fern#renderer#lsflavor#branch#parent_last_node . l:branch
    else
      let l:branch = g:fern#renderer#lsflavor#branch#parent_init_node . l:branch
    endif
  endwhile

  return l:branch
endfunction

function! s:render_branch(node, helper) abort
  return s:render_tree_branch(a:node, a:helper)
endfunction

function! s:render_node(node, helper) abort
  let l:branch = s:render_branch(a:node, a:helper)

  let l:params = fern#renderer#lsflavor#lscolor#syntax_parameters()

  let l:path = a:node._path
  let l:icon = s:get_icon(l:path)
  let l:filetype = s:get_filetype(l:path)

  if index(['link', 'orphan', 'cyclic'], l:filetype) >= 0
    let l:pnode = s:get_parent_node(a:node, a:helper.helper)

    if l:pnode is# v:null
      let l:parent = ''
    else
      let l:parent = resolve(l:pnode._path)
    endif

    if l:filetype ==# 'cyclic'
      let l:symlink = l:path
      let l:llabel = substitute(l:symlink, '^' . l:parent . '/', '', '')
    elseif l:filetype ==# 'orphan'
      let l:symlink = l:path
      let l:llabel = substitute(resolve(l:path), '^' . l:parent . '/', '', '')
    else
      let l:symlink = resolve(l:path)
      let l:llabel = substitute(l:symlink, '^' . l:parent . '/', '', '')
    endif

    return printf('%s', l:branch) . l:icon . ' ' . s:render_label(a:node.label, l:path) . printf('%s', a:node.badge) . ' -> ' . s:render_label(l:llabel, l:symlink)
  else
    return printf('%s', l:branch) . l:icon . ' ' . s:render_label(a:node.label, l:path) . printf('%s', a:node.badge)
  endif
endfunction

function! s:syntax() abort
  syntax region FernBranch matchgroup=FernMarker start=/^/ end=// concealends keepend oneline display
  syntax match FernSymlinkArrow / -> / display

  syntax region FernBadge matchgroup=FernMarker start=// end=// concealends keepend oneline display

  let l:params = fern#renderer#lsflavor#lscolor#syntax_parameters()

  execute printf('syntax region FernFile matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.FILE)
  execute printf('syntax region FernDirectory matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.DIR)
  execute printf('syntax region FernSymlink matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.LINK)
  execute printf('syntax region FernBlockDevice matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.BLK)
  execute printf('syntax region FernCharDevice matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.CHR)
  execute printf('syntax region FernSocket matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.SOCK)
  execute printf('syntax region FernFifo matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.FIFO)
  execute printf('syntax region FernOrphan matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.ORPHAN)
  execute printf('syntax region FernExecutable matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', l:params.EXEC)

  for l:k in keys(l:params.extensions)
    execute printf('syntax region FernExtension_%s matchgroup=FernEscapeSequence start=/\[%sm/ end=/\[m/ concealends oneline display', substitute(l:k, '[^[:alnum:]]', '_', 'g'), l:params.extensions[l:k])
  endfor

  setlocal conceallevel=3
  setlocal concealcursor=nvic
endfunction

" :highlight helper.
function! s:hl_helper(name, param) abort
  " The "NONE" is applied by default if no other argument, otherwise it is
  " probably ignored.
  let l:words = ['highlight', 'default', a:name, 'NONE']
  let l:keys = ['cterm', 'ctermfg', 'ctermbg', 'ctermul', 'gui', 'guifg', 'guibg', 'guisp']

  for l:k in l:keys
    let l:v = get(a:param, l:k, '')

    if l:v !=# ''
      let l:words += [printf('%s=%s', l:k, l:v)]
    endif
  endfor

  return join(l:words)
endfunction

function! s:highlight() abort
  highlight default link FernBranch Comment
  highlight default link FernSymlinkArrow Comment

  let l:params = fern#renderer#lsflavor#lscolor#highlight_parameters()

  execute s:hl_helper('FernFile', l:params.FILE)
  execute s:hl_helper('FernDirectory', l:params.DIR)
  execute s:hl_helper('FernSymlink', l:params.LINK)
  execute s:hl_helper('FernBlockDevice', l:params.BLK)
  execute s:hl_helper('FernCharDevice', l:params.CHR)
  execute s:hl_helper('FernSocket', l:params.SOCK)
  execute s:hl_helper('FernFifo', l:params.FIFO)
  execute s:hl_helper('FernOrphan', l:params.ORPHAN)
  execute s:hl_helper('FernExecutable', l:params.EXEC)

  for l:k in keys(l:params.extensions)
    execute s:hl_helper(printf('FernExtension_%s', substitute(l:k, '[^[:alnum:]]', '_', 'g')), l:params.extensions[l:k])
  endfor
endfunction
