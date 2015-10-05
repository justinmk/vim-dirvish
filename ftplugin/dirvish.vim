nmap <nowait><buffer><silent> q     <Plug>(dirvish_quit)
nmap <nowait><buffer><silent> -     <Plug>(dirvish_focusOnParent)
nmap <nowait><buffer><silent> p     <Plug>(dirvish_focusOnParent)

nmap <nowait><buffer><silent> i     <Plug>(dirvish_visitTarget)
nmap <nowait><buffer><silent> <CR>  <Plug>(dirvish_visitTarget)
nmap <nowait><buffer><silent> a     <Plug>(dirvish_splitVerticalVisitTarget)
nmap <nowait><buffer><silent> o     <Plug>(dirvish_splitVisitTarget)

vmap <nowait><buffer><silent> i     <Plug>(dirvish_visitTarget)
vmap <nowait><buffer><silent> <CR>  <Plug>(dirvish_visitTarget)
vmap <nowait><buffer><silent> a     <Plug>(dirvish_splitVerticalVisitTarget)
vmap <nowait><buffer><silent> o     <Plug>(dirvish_splitVisitTarget)

nnoremap <nowait><buffer><silent> R :Dirvish %<CR>

