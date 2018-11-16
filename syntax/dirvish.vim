if 'dirvish' !=# get(b:, 'current_syntax', 'dirvish')
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

" Define once (per buffer).
if !exists('b:current_syntax')
  exe 'syntax match DirvishPathHead =.*\'.s:sep.'\ze[^\'.s:sep.']\+\'.s:sep.'\?$= conceal'
  exe 'syntax match DirvishPathTail =[^\'.s:sep.']\+\'.s:sep.'$='
  exe 'syntax match DirvishSuffix   =[^\'.s:sep.']*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$='

  function! s:path_in_arglist(path) abort
    return len(filter(copy(argv()), 'fnamemodify(v:val, ":p") ==# a:path'))
  endfunction
endif

silent! exe 'syntax clear DirvishColumnHead'
silent! exe 'syntax clear DirvishColumnSlash'
for s:column in dirvish#get_columns()
  silent! exe 'syntax clear '.s:column.hi_group
endfor

for s:path in getline(1, '$')
  let s:col = get(filter(dirvish#get_columns(), 'call(v:val.handler, [s:path])'), 0, {})
  if empty(s:col)
    continue
  endif

  let s:end = isdirectory(s:path) ? s:sep : ''
  let s:modifier = isdirectory(s:path) ? ':p:h' : ':p'

  let s:normalized_path = fnamemodify(s:path, s:modifier)
  let s:head = escape(fnamemodify(s:normalized_path, ':h'), ',*.^$~'.s:sep)
  let s:tail = escape(fnamemodify(s:normalized_path, ':t').s:end, ',*.^$~'.s:sep)

  exe 'syntax match DirvishColumnHead "^'.s:head.'\(\'.s:sep.s:tail.'$\)\@=" conceal cchar='.s:col.mark
  exe 'syntax match '.s:col.hi_group.' "\(^'.s:head.'\)\@<=\'.s:sep.s:tail.'$" contains=DirvishColumnSlash'
  exe 'syntax match DirvishColumnSlash "\(^'.s:head.'\)\@<=\'.s:sep.'\('.s:tail.'$\)\@=" conceal cchar= contained'
endfor

let b:current_syntax = 'dirvish'
