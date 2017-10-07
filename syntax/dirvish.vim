if 'dirvish' !=# get(b:, 'current_syntax', 'dirvish')
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

" Define (again). Other windows may need the old definitions ...
let s:pat = join(map(argv(), 'escape(fnamemodify(v:val[-1:]==#s:sep?v:val[:-2]:v:val, ":t"), "*.^$~\\")'), '\|')
exe 'syntax match DirvishArg /\'.s:sep.'\@<=\%\('.s:pat.'\)\'.s:sep.'\?$/'

if exists('b:current_syntax')
  finish
endif

exe 'syntax match DirvishPathHead =\v.*\'.s:sep.'\ze[^\'.s:sep.']+\'.s:sep.'?$= conceal'
exe 'syntax match DirvishPathTail =\v[^\'.s:sep.']+\'.s:sep.'$='
exe 'syntax match DirvishSuffix   =[^\'.s:sep.']*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$='

let b:current_syntax = "dirvish"
