vim9script

if exists('g:loaded_paginate_plugin')
    finish
endif
g:loaded_paginate_plugin = 1

import '../autoload/paginate.vim' as paginate

augroup PaginateGlobalAutocmds
    autocmd!
    autocmd ModeChanged [vV\x16]*:* call paginate.SaveVisualState()
    autocmd VimLeavePre * call paginate.CleanupAllPagers()
augroup END

command! -nargs=0 PagerInit call paginate.InitPager()
command! -nargs=0 PagerFreeAll call paginate.CleanupAllPagers()
