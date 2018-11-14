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
endif

" Define (again). Other windows (different arglists) need the old definitions.
" Do these last, else they may be overridden (see :h syn-priority).
for s:p in argv()
  let s:f = fnamemodify(s:p, ':p')  " Full path.
  let s:base = escape(fnamemodify(s:f[-1:] ==# s:sep ? s:f[:-2] : s:f, ':t'), '@*.^$~\')
  exe 'syntax match DirvishArgFullPath @^'.escape(s:f, '@*.^$~\').'$@ contains=DirvishPathHead,DirvishArg'
  exe 'syntax match DirvishArg @'.s:base.'\'.s:sep.'\?$@ contained'
endfor

let b:current_syntax = 'dirvish'
