vim9script

import './infra.vim' as infra
import './scroll.vim' as scroll

# TODO Add tests for search. Separate and combining * / then nN

def RunTests()
    infra.BeginSuite()


    infra.LogHeader('Initialization')
    execute 'PagerInit'
    infra.AssertLocation(1, v:null, 'Spawn at first line by default')
    infra.ExpectEqual(infra.total_lines, b:pager_total_lines, 'Total lines recognized correctly')


    # TODO make sure 10000j jumps over to next chunk
    infra.LogHeader('Scrolling without losing any line')

    scroll.ScrollForward("j", (current) => current + 1)
    scroll.ScrollForward("5j", (current) => current + 5)
    scroll.ScrollForward("10j5k", (current) => current + 5, 10, 10)
    scroll.ScrollForward("10000j", (current) => current + 10000)
    scroll.ScrollForward("\<C-f>", (current) => current + winheight(0))
    scroll.ScrollForward("\<C-d>", (current) => current + winheight(0) / 2)
    scroll.ScrollForward("/Line\<CR>", (current) => current + 1)

    scroll.ScrollBackwards("k", (current) => current - 1)
    scroll.ScrollBackwards("5k", (current) => current - 5)
    scroll.ScrollBackwards("10k5j", (current) => current - 5, 10, 10)
    scroll.ScrollBackwards("10000k", (current) => current - 10000)
    scroll.ScrollBackwards("\<C-b>", (current) => current - winheight(0))
    scroll.ScrollBackwards("\<C-u>", (current) => current - winheight(0) / 2)
    scroll.ScrollBackwards("?Line\<CR>", (current) => current - 1)


    infra.LogHeader('Absolute Jumps')
    feedkeys('gg', 'xt') | infra.AssertLocation(1, v:null, 'Jump to first line with gg')
    feedkeys('1G', 'xt') | infra.AssertLocation(1, v:null, 'Jump to first line with 1G')
    feedkeys('0G', 'xt') | infra.AssertLocation(infra.total_lines, v:null, 'Jump to last line with 0G')
    feedkeys('G', 'xt')  | infra.AssertLocation(infra.total_lines, v:null, 'Jump to last line with G')

    feedkeys(2 * infra.total_lines .. 'G', 'xt')
    infra.AssertLocation(infra.total_lines, v:null, 'Jump to last line with overflown G')

    feedkeys('7500G', 'xt')
    infra.AssertLocation(7500, v:null, 'Jump to Middle <count>G')
    infra.AssertText('EASTER_EGG_MIDDLE', 'Middle Text matched')

    feedkeys("14999G", 'xt')
    infra.AssertLocation(14999, v:null, 'Jump to Bottom <count>G')
    infra.AssertText('EASTER_EGG_BOTTOM', 'Bottom Text matched')


    infra.LogHeader('Custom Jump List')
    feedkeys("gg", 'xt')
    feedkeys("100G", 'xt')
    feedkeys("200G", 'xt')
    feedkeys("300G", 'xt')
    feedkeys("400G", 'xt')
    feedkeys("500G", 'xt')
    feedkeys("\<C-o>", 'xt') | infra.AssertLocation(400, v:null, '<C-o> navigates back one step (500 -> 400)')
    feedkeys("\<C-o>", 'xt') | infra.AssertLocation(300, v:null, '<C-o> navigates back again (400 -> 300)')
    feedkeys("\<C-i>", 'xt') | infra.AssertLocation(400, v:null, '<C-i> navigates forward (300 -> 400)')
    feedkeys("\<C-o>", 'xt') | infra.AssertLocation(300, v:null, '<C-o> (resume) navigate back (400 -> 300)')
    feedkeys("\<C-o>", 'xt') | infra.AssertLocation(200, v:null, '<C-o> navigate back (300 -> 200)')
    feedkeys("\<C-o>", 'xt') | infra.AssertLocation(100, v:null, '<C-o> reaches initial G jump (200 -> 100)')
    feedkeys("gg", 'xt')
    feedkeys("\<C-o>", 'xt') | infra.AssertLocation(100, v:null, '<C-o> (after gg) navigate back (1 -> 100)')
    feedkeys("\<C-i>", 'xt') | infra.AssertLocation(1, v:null, '<C-i> navigate forward (100 -> 1)')
    feedkeys("\<C-i>", 'xt') | infra.AssertLocation(1, v:null, '<C-i> no more jumps to do (remains at 1)')


    infra.LogHeader('Exit and reset lifecycle')
    feedkeys("8888G", 'xt') | infra.AssertLocation(8888, v:null, 'Pre-Quit Alignment')
    feedkeys(":PagerQuit\<CR>", 'xt')
    infra.ExpectEqual('', &buftype, 'Post-quit: Buffer returned to native (empty buftype)')
    infra.ExpectEqual(8888, line('.'), 'Post-quit: Native buffer landed on exactly line 8888')
    infra.ExpectFalse(exists('b:pager_offset'), 'Post-quit: Script-local variables wiped cleanly')

    feedkeys('3456G', 'xt') | infra.ExpectEqual(3456, line('.'), 'Pre-Init successful')
    feedkeys(":PagerInit\<CR>", 'xt')
    infra.ExpectEqual('nofile', &buftype, 'Post-init: buftype OK')
    infra.AssertLocation(3456, v:null, 'Post-init: Offset init retained line 3456')


    infra.LogHeader('Search engine')
    feedkeys("gg/EASTER_EGG_TOP\<CR>", 'xt')    | infra.AssertLocation(1, v:null, 'Native RAM Forward Search')
    feedkeys("gg/EASTER_EGG_BOTTOM\<CR>", 'xt') | infra.AssertLocation(14999, v:null, 'Cross-Chunk Forward Search (Ripgrep)')
    feedkeys("G?EASTER_EGG_TOP\<CR>", 'xt')     | infra.AssertLocation(1, v:null, 'Cross-Chunk Backward Search (Ripgrep)')
    feedkeys("7500G/EASTER_EGG_TOP\<CR>", 'xt') | infra.AssertLocation(1, v:null, 'Wrapped Forward Search (Cross-Chunk)')

    feedkeys("2G", 'xt')
    feedkeys("/EASTER_EGG\<CR>", 'xt') | infra.AssertLocation(7500, v:null, '[/] Forward search finds middle egg')
    feedkeys("n", 'xt') | infra.AssertLocation(14999, v:null, '[n] (forward context) finds bottom egg')
    feedkeys("N", 'xt') | infra.AssertLocation(7500, v:null, '[N] (reverse context) walks back to middle egg')
    feedkeys("N", 'xt') | infra.AssertLocation(1, v:null, '[N] walks back to top egg')
    feedkeys("N", 'xt') | infra.AssertLocation(14999, v:null, '[N] wraps around the bottom to find bottom egg')

    feedkeys("2G", 'xt')
    feedkeys("?EASTER_EGG\<CR>", 'xt') | infra.AssertLocation(1, v:null, '[?] Backward search finds top egg immediately')
    feedkeys("n", 'xt') | infra.AssertLocation(14999, v:null, '[n] (backward context!) wraps to bottom egg')
    feedkeys("n", 'xt') | infra.AssertLocation(7500, v:null, '[n] walks backward to middle egg')
    feedkeys("N", 'xt') | infra.AssertLocation(14999, v:null, '[N] (forward context!) walks forward to bottom egg')

    feedkeys("5000G", 'xt')
    feedkeys("0fS", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("*", 'xt')       | infra.AssertLocation(5001, v:null, '[*] executes forward search for word under cursor (lands on 5001)')
    feedkeys("n", 'xt')       | infra.AssertLocation(5002, v:null, '[n] continues [*] search forward to 5002')
    feedkeys("N", 'xt')       | infra.AssertLocation(5001, v:null, '[N] walks back to 5001')
    feedkeys("N", 'xt')       | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("14999G*", 'xt') | infra.AssertLocation(14999, v:null, '[*] on a unique word wraps the entire file and lands on itself')

    feedkeys("/MARK_TARGET\<CR>", 'xt')       | infra.AssertLocation(2500, v:null, 'Direct jump to 2500')
    feedkeys("?EASTER_EGG_TOP\<CR>", 'xt')    | infra.AssertLocation(1, v:null, 'Direct jump backward to 1')
    feedkeys("/EASTER_EGG_BOTTOM\<CR>", 'xt') | infra.AssertLocation(14999, v:null, 'Direct jump forward to 14999')

    feedkeys("100G", 'xt')
    silent! feedkeys("/GIBBERISH_IMPOSSIBLE_STRING\<CR>", 'xt')
    infra.AssertLocation(100, v:null, 'Failed forward search cleanly aborts and restores original cursor')
    silent! feedkeys("?ANOTHER_IMPOSSIBLE_STRING\<CR>", 'xt')
    infra.AssertLocation(100, v:null, 'Failed backward search cleanly aborts and restores original cursor')
    silent! feedkeys("n", 'xt')
    infra.AssertLocation(100, v:null, 'Pressing [n] after a failed search safely does nothing')

    # TO BE IMPLEMENTED
    feedkeys("gg", 'xt')
    silent! feedkeys("g/Standard filler\<CR>", 'xt')
    infra.AssertLocation(2500, v:null, 'Inverse search skips filler lines and lands on target')

    feedkeys("gg/MARK_TARGET\<CR>", 'xt')          | infra.AssertLocation(2500, v:null, 'Setup: Establish last_search_pattern as MARK_TARGET')
    feedkeys("gg/\<CR>", 'xt')                     | infra.AssertLocation(2500, v:null, '[/<CR>] Empty forward prompt correctly repeats last search')
    feedkeys("14000G?\<CR>", 'xt')                 | infra.AssertLocation(2500, v:null, '[?<CR>] Empty backward prompt correctly repeats last search')
    silent! feedkeys("gg//\<CR>", 'xt')            | infra.AssertLocation(2500, v:null, '[//] Blank slash-closed pattern repeats last forward search')
    silent! feedkeys("14000G??\<CR>", 'xt')        | infra.AssertLocation(2500, v:null, '[??] Blank question-closed pattern repeats last backward search')
    silent! feedkeys("500G/EASTER_EGG_TOP/\<CR>", 'xt')    | infra.AssertLocation(1, v:null, '[/pattern/] Trailing slash is correctly ignored as a delimiter')
    silent! feedkeys("500G?EASTER_EGG_BOTTOM?\<CR>", 'xt') | infra.AssertLocation(14999, v:null, '[?pattern?] Trailing question mark is correctly ignored as a delimiter')

    infra.EndSuite()
enddef

RunTests()
