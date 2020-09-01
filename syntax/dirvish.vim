if 'dirvish' !=# get(b:, 'current_syntax', 'dirvish')
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\\' : '/'
let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

" Define once (per buffer).
if !exists('b:current_syntax')
  exe 'syntax match DirvishPathHead =.*'.s:sep.'\ze[^'.s:sep.']\+'.s:sep.'\?$= conceal'
  exe 'syntax match DirvishPathTail =[^'.s:sep.']\+'.s:sep.'$='
  exe 'syntax match DirvishSuffix   =[^'.s:sep.']*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$='
endif

" Define (again). Other windows (different arglists) need the old definitions.
" Do these last, else they may be overridden (see :h syn-priority).
for s:p in argv()
  exe 'syntax match DirvishArg ,'.escape(fnamemodify(s:p,':p'),'[,*.^$~\').'$, contains=DirvishPathHead'
endfor

let b:current_syntax = 'dirvish'
