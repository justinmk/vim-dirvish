if 'dirvish' !=# get(b:, 'current_syntax', 'dirvish')
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

exe 'syntax match DirvishPathHead =\v.*\'.s:sep.'\ze[^\'.s:sep.']+\'.s:sep.'?$= conceal'
exe 'syntax match DirvishPathTail =\v[^\'.s:sep.']+\'.s:sep.'$='
exe 'syntax match DirvishSuffix   =[^\'.s:sep.']*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$='

" Define (again). Other windows may need the old definitions ...
for p in argv()
  let s:base = escape(fnamemodify(p[-1:] ==# s:sep ? p[:-2] : p, ":t"), "@*.^$~\\")
  exe 'syntax match DirvishFullPath @^'.escape(p, "@*.^$~\\").'$@ contains=DirvishPathHead,DirvishArg'
  exe 'syntax match DirvishArg @'.s:base.s:sep.'\?$@ contained'
endfor

if exists('b:current_syntax')
  finish
endif

let b:current_syntax = "dirvish"
