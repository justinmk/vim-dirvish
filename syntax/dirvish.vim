if exists("b:current_syntax")
  finish
endif

let s:sep = exists('+shellslash') && !&shellslash ? '\\' : '\/'

exe 'syntax match DirvishPathHead ''\v.*'.s:sep.'\ze[^'.s:sep.']+'.s:sep.'?$'' conceal'
exe 'syntax match DirvishPathTail ''\v[^'.s:sep.']+'.s:sep.'$'''

let b:current_syntax = "dirvish"
