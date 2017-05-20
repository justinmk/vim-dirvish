if exists("b:current_syntax")
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\\' : '\/'
let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

exe 'syntax match DirvishPathHead ''\v.*'.s:sep.'\ze[^'.s:sep.']+'.s:sep.'?$'' conceal'
exe 'syntax match DirvishPathTail ''\v[^'.s:sep.']+'.s:sep.'$'''
exe 'syntax match DirvishSuffix   =[^'.s:sep.']*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$='

highlight default link DirvishSuffix   SpecialKey
highlight default link DirvishPathTail Directory

let b:current_syntax = "dirvish"
