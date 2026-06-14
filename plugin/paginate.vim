vim9script

if exists('g:loaded_paginate_plugin')
    finish
endif
g:loaded_paginate_plugin = 1

import '../autoload/paginate.vim' as paginate

command! -nargs=0 PagerInit call paginate.InitPager()
