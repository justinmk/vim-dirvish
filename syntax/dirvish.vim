if exists("b:current_syntax")
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\' : '/'
let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

exe 'syntax match DirvishPathHead =\v.*\'.s:sep.'\ze[^\'.s:sep.']+\'.s:sep.'?$= conceal'
exe 'syntax match DirvishPathTail =\v[^\'.s:sep.']+\'.s:sep.'$='
exe 'syntax match DirvishSuffix   =[^\'.s:sep.']*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$='

let pat = join(map(argv(), 'escape(fnamemodify(v:val[-1:]==#s:sep?v:val[:-2]:v:val, ":t"), "*.^$~\\")'), '\|')
exe 'syntax match DirvishArg /\'.s:sep.'\@<=\%\('.pat.'\)\'.s:sep.'\?$/'

let b:current_syntax = "dirvish"
