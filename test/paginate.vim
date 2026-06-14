vim9script

import './infra.vim' as infra

def RunTests()
    infra.BeginSuite()

    infra.LogHeader('TEST 1: Initialization')
    execute 'PagerInit'
    infra.AssertLocation(1, v:null, 'Initialized at Line 1')
    infra.ExpectEqual(infra.total_lines, b:pager_total_lines, 'Total lines recognized correctly')

    infra.LogHeader('TEST 2: Absolute Jumps')
    feedkeys('7500G', 'xt')
    infra.AssertLocation(7500, v:null, 'Jump to Middle (G mapping)')
    infra.AssertText('EASTER_EGG_MIDDLE', 'Middle Text matched')

    feedkeys(":J 14999\<CR>", 'xt')
    infra.AssertLocation(14999, v:null, 'Jump to Bottom (:J command)')
    infra.AssertText('EASTER_EGG_BOTTOM', 'Bottom Text matched')

    infra.LogHeader('TEST 3: Relative Movement')
    feedkeys('gg', 'xt')
    feedkeys('2499j', 'xt')
    infra.AssertLocation(2500, v:null, 'Move Down 2499 lines (j mapping)')
    infra.AssertText('MARK_TARGET', 'Moved Text matched')

    infra.LogHeader('TEST 4: Custom Jump List')
    feedkeys(":J 100\<CR>", 'xt')
    feedkeys(":J 500\<CR>", 'xt')
    feedkeys("\<C-o>", 'xt')
    infra.AssertLocation(100, v:null, 'Jump List Back 1 (<C-o>)')
    feedkeys("\<C-o>", 'xt')
    infra.AssertLocation(2500, v:null, 'Jump List Back 2 (<C-o>)')
    feedkeys("\<C-i>", 'xt')
    infra.AssertLocation(100, v:null, 'Jump List Forward 1 (<C-i>)')

    infra.LogHeader('TEST 5: Exit Lifecycle')
    feedkeys(":J 8888\<CR>", 'xt')
    infra.AssertLocation(8888, v:null, 'Pre-Quit Alignment')
    feedkeys(":PagerQuit\<CR>", 'xt')
    infra.ExpectEqual('', &buftype, 'Buffer returned to native (empty buftype)')
    infra.ExpectEqual(8888, line('.'), 'Native buffer landed on exactly line 8888')
    infra.ExpectFalse(exists('b:pager_offset'), 'Script-local variables wiped cleanly')

    infra.LogHeader('TEST 6: Init from Offset Line')
    feedkeys('3456G', 'xt')
    infra.ExpectEqual(3456, line('.'), 'Native Move pre-Init successful')
    feedkeys(":PagerInit\<CR>", 'xt')
    infra.ExpectEqual('nofile', &buftype, 'Offset Init triggered Pager mode')
    infra.AssertLocation(3456, v:null, 'Offset Init retained line 3456')

    infra.EndSuite()
enddef

RunTests()
