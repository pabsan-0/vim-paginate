vim9script

import './infra.vim' as infra
import './scroll.vim' as scroll
import '../autoload/paginate.vim' as paginate

def RunTests()
    infra.BeginSuite()


    infra.LogHeader('Initialization')
    execute 'PagerInit'
    infra.AssertLocation(1, v:null, 'Spawn at first line by default')
    infra.ExpectEqual(infra.total_lines, b:pager_total_lines, 'Total lines recognized correctly')

    var total_chunks = exists('b:chunk_lines') ? len(b:chunk_lines) : 0
    infra.ExpectTrue(total_chunks >= 12, 'Precondition: Test file generated ' .. total_chunks .. ' chunks (Requires >= 12)')


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

    infra.LogHeader('Boundary Seams')
    for chunk_index in [0, 1, 2, 6, -3, -2, -1]
        # Normalize negative indices (e.g., -2 becomes total_chunks - 2)
        # then compute the exact seam line by summing all chunk sizes up to index `i`
        var ii = chunk_index < 0 ? total_chunks + chunk_index : chunk_index
        var seam_line = 0
        for c in range(0, ii)
            seam_line += b:chunk_lines[c]
        endfor

        if chunk_index != -1
            feedkeys(seam_line - 2 .. "G", 'xt')
            feedkeys("j", 'xt')
            infra.AssertLocation(seam_line - 1, v:null, ii .. 'th chunk: j down before seam')
            infra.AssertCursorChunk(ii, ii .. 'th chunk: Before seam')
            feedkeys("j", 'xt')
            infra.AssertLocation(seam_line, v:null, ii .. 'th chunk: j exact seam boundary')
            infra.AssertCursorChunk(ii, ii .. 'th chunk: Before seam')
            feedkeys("j", 'xt')
            infra.AssertLocation(seam_line + 1, v:null, ii .. 'th chunk: j down over seam (ShiftDown)')
            infra.AssertCursorChunk(ii + 1, ii .. 'th chunk: After seam')
            feedkeys("k", 'xt')
            infra.AssertLocation(seam_line, v:null, ii .. 'th chunk: k up over seam (ShiftUp)')
            infra.AssertCursorChunk(ii, ii .. 'th chunk: Before seam')

            feedkeys(seam_line - 5 .. "G", 'xt')
            feedkeys("10j", 'xt')
            infra.AssertLocation(seam_line + 5,     v:null, ii .. 'th chunk: 10j over seam')
            infra.AssertCursorChunk(ii + 1, ii .. 'th chunk: After seam')
            feedkeys("10k", 'xt')
            infra.AssertLocation(seam_line - 5, v:null, ii .. 'th chunk: 10k back over seam')
            infra.AssertCursorChunk(ii, ii .. 'th chunk: Before seam')

            feedkeys(seam_line - 10 .. "G", 'xt')
            feedkeys("/Line " .. (seam_line + 2) .. "\<CR>", 'xt')
            infra.AssertLocation(seam_line + 2, v:null, ii .. 'th chunk: forward search crossing seam')
            infra.AssertCursorChunk(ii + 1, ii .. 'th chunk: After seam')
            feedkeys("?Line " .. (seam_line - 2) .. "\<CR>", 'xt')
            infra.AssertLocation(seam_line - 2, v:null, ii .. 'th chunk: backward search crossing seam')
            infra.AssertCursorChunk(ii, ii .. 'th chunk: Before seam')
        else
            feedkeys(seam_line - 2 .. "G", 'xt')
            feedkeys("j", 'xt') | infra.AssertLocation(seam_line - 1, v:null, ii .. 'th chunk: j down before seam')
            feedkeys("j", 'xt') | infra.AssertLocation(seam_line,     v:null, ii .. 'th chunk: j exact seam boundary')
            feedkeys("j", 'xt') | infra.AssertLocation(seam_line,     v:null, ii .. 'th chunk: j down against EOF')
            feedkeys("k", 'xt') | infra.AssertLocation(seam_line - 1, v:null, ii .. 'th chunk: h up from EOF')

            feedkeys(seam_line - 5 .. "G", 'xt')
            feedkeys("10j", 'xt') | infra.AssertLocation(seam_line, v:null, ii .. 'th chunk: 10j over seam into EOF')
            feedkeys("10k", 'xt') | infra.AssertLocation(seam_line - 10, v:null, ii .. 'th chunk: 10k up from EOF')
        endif
    endfor


    infra.LogHeader('Absolute Jumps')
    feedkeys('gg', 'xt') | infra.AssertLocation(1, v:null, 'Jump to first line with gg')
    feedkeys('1G', 'xt') | infra.AssertLocation(1, v:null, 'Jump to first line with 1G')
    feedkeys('0G', 'xt') | infra.AssertLocation(infra.total_lines, v:null, 'Jump to last line with 0G')
    feedkeys('G', 'xt')  | infra.AssertLocation(infra.total_lines, v:null, 'Jump to last line with G')

    feedkeys(2 * infra.total_lines .. 'G', 'xt')
    infra.AssertLocation(infra.total_lines, v:null, 'Jump to last line with overflown G')

    feedkeys(infra.total_lines / 2 .. 'G', 'xt')
    infra.AssertLocation(infra.total_lines / 2, v:null, 'Jump to Middle <count>G')
    infra.AssertText('EASTER_EGG_MIDDLE', 'Middle Text matched')

    feedkeys(infra.total_lines - 1 .. "G", 'xt')
    infra.AssertLocation(infra.total_lines - 1, v:null, 'Jump to Bottom <count>G')
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


    infra.LogHeader('Marks')
    feedkeys("1500Gma12000G'a", 'xt')  | infra.AssertLocation(1500, v:null, 'Line jump to local mark "a" across chunks')
    feedkeys("3000G5lmb9000G`b", 'xt') | infra.AssertLocation(3000, v:null, 'Exact jump to local mark "b" across chunks')
    feedkeys("100G200G''", 'xt')       | infra.AssertLocation(100, v:null, 'Jump back once with '''' ')
    feedkeys("100G200G``", 'xt')       | infra.AssertLocation(100, v:null, 'Jump back once with ``')


    infra.LogHeader('Search engine: direct searches')
    feedkeys("gg/EASTER_EGG_TOP\<CR>", 'xt')    | infra.AssertLocation(1, v:null, 'Native RAM Forward Search')
    feedkeys("gg/EASTER_EGG_BOTTOM\<CR>", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, 'Cross-Chunk Forward Search (Ripgrep)')
    feedkeys("G?EASTER_EGG_TOP\<CR>", 'xt')     | infra.AssertLocation(1, v:null, 'Cross-Chunk Backward Search (Ripgrep)')
    feedkeys("G/MARK_TARGET\<CR>", 'xt')       | infra.AssertLocation(infra.total_lines / 4, v:null, 'Direct jump to 2500 with file wrap')
    feedkeys("gg?EASTER_EGG_TOP\<CR>", 'xt')   | infra.AssertLocation(1, v:null, 'Direct jump backward to 1 with file wrap')
    feedkeys("G/EASTER_EGG_BOTTOM\<CR>", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, 'Direct jump forward to bottom with file wrap')

    feedkeys("100G", 'xt')
    silent! feedkeys("/GIBBERISH_IMPOSSIBLE_STRING\<CR>", 'xt') | infra.AssertLocation(100, v:null, 'Failed forward search cleanly aborts and restores original cursor')
    silent! feedkeys("?ANOTHER_IMPOSSIBLE_STRING\<CR>", 'xt') | infra.AssertLocation(100, v:null, 'Failed backward search cleanly aborts and restores original cursor')
    silent! feedkeys("n", 'xt') | infra.AssertLocation(100, v:null, 'Pressing [n] after a failed search safely does nothing')

    feedkeys("gg/MARK_TARGET\<CR>", 'xt')          | infra.AssertLocation(infra.total_lines / 4, v:null, 'Setup: Establish last_search_pattern as MARK_TARGET')
    feedkeys("gg/\<CR>", 'xt')                     | infra.AssertLocation(infra.total_lines / 4, v:null, '[/<CR>] Empty forward prompt correctly repeats last search')
    feedkeys("14000G?\<CR>", 'xt')                 | infra.AssertLocation(infra.total_lines / 4, v:null, '[?<CR>] Empty backward prompt correctly repeats last search')
    silent! feedkeys("gg//\<CR>", 'xt')            | infra.AssertLocation(infra.total_lines / 4, v:null, '[//] Blank slash-closed pattern repeats last forward search')
    silent! feedkeys("14000G??\<CR>", 'xt')        | infra.AssertLocation(infra.total_lines / 4, v:null, '[??] Blank question-closed pattern repeats last backward search')
    silent! feedkeys("500G/EASTER_EGG_TOP/\<CR>", 'xt')    | infra.AssertLocation(1, v:null, '[/pattern/] Trailing slash is correctly ignored as a delimiter')
    silent! feedkeys("500G?EASTER_EGG_BOTTOM?\<CR>", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[?pattern?] Trailing question mark is correctly ignored as a delimiter')


    infra.LogHeader('Search engine sequence: / g/ and ? g?')
    # / and g/
    feedkeys("2G", 'xt')
    feedkeys("/EASTER_EGG\<CR>", 'xt') | infra.AssertLocation(infra.total_lines / 2, v:null, '[/] Forward search finds middle egg')
    feedkeys("n", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[n] (forward context) finds bottom egg')
    feedkeys("N", 'xt') | infra.AssertLocation(infra.total_lines / 2, v:null, '[N] (reverse context) walks back to middle egg')
    feedkeys("N", 'xt') | infra.AssertLocation(1, v:null, '[N] walks back to top egg')
    feedkeys("N", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[N] wraps around the bottom to find bottom egg')

    feedkeys("gg", 'xt') # Notice that the current line is already a match, however it is skipped so that Search navigates
    feedkeys("g/Standard\<CR>", 'xt') | infra.AssertLocation(infra.total_lines / 4, v:null, '[g/] Inverse forward search finds middle egg')
    feedkeys("n", 'xt') | infra.AssertLocation(infra.total_lines / 2, v:null, '[n] (forward context) finds bottom egg')
    feedkeys("N", 'xt') | infra.AssertLocation(infra.total_lines / 4, v:null, '[N] (reverse context) walks back to middle egg')
    feedkeys("N", 'xt') | infra.AssertLocation(1, v:null, '[N] walks back to top egg')
    feedkeys("N", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[N] wraps around the bottom to find bottom egg')

    # ? and g?
    feedkeys("2G", 'xt')
    feedkeys("?EASTER_EGG\<CR>", 'xt') | infra.AssertLocation(1, v:null, '[?] Backward search finds top egg immediately')
    feedkeys("n", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[n] (backward context!) wraps to bottom egg')
    feedkeys("n", 'xt') | infra.AssertLocation(infra.total_lines / 2, v:null, '[n] walks backward to middle egg')
    feedkeys("N", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[N] (forward context!) walks forward to bottom egg')

    feedkeys("gg", 'xt')
    feedkeys("g?Standard\<CR>", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[g?] Inverse backward search finds top egg immediately')
    feedkeys("n", 'xt') | infra.AssertLocation(infra.total_lines / 2, v:null, '[n] (backward context!) wraps to bottom egg')
    feedkeys("n", 'xt') | infra.AssertLocation(infra.total_lines / 4, v:null, '[n] walks backward to middle egg')
    feedkeys("N", 'xt') | infra.AssertLocation(infra.total_lines / 2, v:null, '[N] (forward context!) walks forward to bottom egg')


    infra.LogHeader('Search engine sequence: * g* and # g#')
    # * and g*
    feedkeys("5000G0fS", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("*", 'xt')     | infra.AssertLocation(5001, v:null, '[*] from L5000, executes forward search for word under cursor (lands on 5001)')
    feedkeys("n", 'xt')     | infra.AssertLocation(5002, v:null, '[n] continues [*] search forward to 5002')
    feedkeys("N", 'xt')     | infra.AssertLocation(5001, v:null, '[N] walks back to 5001')
    feedkeys("N", 'xt')     | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("GkfE*", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[*] on a unique word wraps the entire file and lands on itself')

    feedkeys("5000G0fS", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("g*", 'xt')    | infra.AssertLocation(infra.total_lines / 4, v:null, '[g*] from L5000, execute inverse forward search for word under cursor')
    feedkeys("n", 'xt')     | infra.AssertLocation(infra.total_lines / 2,  v:null, '[n] continues [g*] search forward')
    feedkeys("N", 'xt')     | infra.AssertLocation(infra.total_lines / 4,  v:null, '[N] walks back')
    feedkeys("N", 'xt')     | infra.AssertLocation(1, v:null, '[N] walks back')
    silent! feedkeys("1G0g*", 'xt') | infra.AssertLocation(1, v:null, '[g*] on a word in every line fails and stays')

    # # and g#
    feedkeys("5000G0fS", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("#", 'xt')     | infra.AssertLocation(4999, v:null, '[#] from L5000, executes backward search for word under cursor (lands on 4999)')
    feedkeys("n", 'xt')     | infra.AssertLocation(4998, v:null, '[n] continues [#] search forward to 4998')
    feedkeys("N", 'xt')     | infra.AssertLocation(4999, v:null, '[N] walks back to 4999')
    feedkeys("N", 'xt')     | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("GkfE#", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[#] on a unique word wraps the entire file and lands on itself')

    feedkeys("5000G0fS", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("g#", 'xt')    | infra.AssertLocation(1, v:null, '[g#] from L5000, execute inverse backward search for word under cursor')
    feedkeys("n", 'xt')     | infra.AssertLocation(infra.total_lines - 1,  v:null, '[n] continues [g#] search')
    feedkeys("N", 'xt')     | infra.AssertLocation(1,  v:null, '[N] walks back')
    feedkeys("N", 'xt')     | infra.AssertLocation(infra.total_lines / 4, v:null, '[N] walks back')
    silent! feedkeys("1G0g#", 'xt') | infra.AssertLocation(1, v:null, '[g#] on a word in every line fails and stays')


    infra.LogHeader('Search engine sequence: visual * g* and # g#')
    # * and g* (visual)
    feedkeys("5000G0fSvee", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("*", 'xt')     | infra.AssertLocation(5001, v:null, 'Visual [*] from L5000, executes forward search for word under cursor (lands on 5001)')
    feedkeys("n", 'xt')     | infra.AssertLocation(5002, v:null, '[n] continues [*] search forward to 5002')
    feedkeys("N", 'xt')     | infra.AssertLocation(5001, v:null, '[N] walks back to 5001')
    feedkeys("N", 'xt')     | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("GkfEvE*", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[*] on a unique word wraps the entire file and lands on itself')

    feedkeys("5000G0fSvee", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("g*", 'xt')    | infra.AssertLocation(infra.total_lines / 4, v:null, '[g*] from L5000, execute inverse forward search for word under cursor')
    feedkeys("n", 'xt')     | infra.AssertLocation(infra.total_lines / 2,  v:null, '[n] continues [g*] search forward')
    feedkeys("N", 'xt')     | infra.AssertLocation(infra.total_lines / 4,  v:null, '[N] walks back')
    feedkeys("N", 'xt')     | infra.AssertLocation(1, v:null, '[N] walks back')
    silent! feedkeys("1G0g*", 'xt') | infra.AssertLocation(1, v:null, '[g*] on a word in every line fails and stays')

    # # and g# (visual)
    feedkeys("5000G0fSvee", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("#", 'xt')     | infra.AssertLocation(4999, v:null, 'Visual [#] from L5000, executes backward search for word under cursor (lands on 4999)')
    feedkeys("n", 'xt')     | infra.AssertLocation(4998, v:null, '[n] continues [#] search forward to 4998')
    feedkeys("N", 'xt')     | infra.AssertLocation(4999, v:null, '[N] walks back to 4999')
    feedkeys("N", 'xt')     | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("GkfEvE#", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[#] on a unique word wraps the entire file and lands on itself')

    feedkeys("5000G0fSvee", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    feedkeys("g#", 'xt')    | infra.AssertLocation(1, v:null, '[g#] from L5000, execute inverse backward search for word under cursor')
    feedkeys("n", 'xt')     | infra.AssertLocation(infra.total_lines - 1,  v:null, '[n] continues [g#] search')
    feedkeys("N", 'xt')     | infra.AssertLocation(1,  v:null, '[N] walks back')
    feedkeys("N", 'xt')     | infra.AssertLocation(infra.total_lines / 4, v:null, '[N] walks back')
    silent! feedkeys("1G0g#", 'xt') | infra.AssertLocation(1, v:null, '[g#] on a word in every line fails and stays')


    infra.LogHeader('Search engine sequence: visual multiline * g* and # g#')
    var seam = b:chunk_lines[0]
    # * and g* (visual, multi-line)
    feedkeys("5000G$bveee", 'xt')
    feedkeys("*", 'xt')     | infra.AssertLocation(5001, v:null, 'Visual multiline [*] from L5000, executes forward search for word under cursor (lands on 5001)')
    feedkeys("n", 'xt')     | infra.AssertLocation(5002, v:null, '[n] continues [*] search forward to 5002')
    feedkeys("N", 'xt')     | infra.AssertLocation(5001, v:null, '[N] walks back to 5001')
    feedkeys("N", 'xt')     | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("Gk$BvEEE*", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[*] on a unique word wraps the entire file and lands on itself')
    feedkeys(seam .. "Gkk$bveee*nnnNN", 'xt') | infra.AssertLocation(seam, v:null, '[*n]  multiline sequence works across seams.')


    feedkeys("5000G$bveee", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    silent! feedkeys("g*", 'xt') | infra.AssertLocation(5000, v:null, '[g*] multiline visual inverse forward search unsupported, must stay in same place')

    # # and g# (visual, multi-line)
    feedkeys("5000G$bveee", 'xt')
    feedkeys("#", 'xt')     | infra.AssertLocation(4999, v:null, 'Visual multiline [#] from L5000, executes backward search for word under cursor (lands on 4999)')
    feedkeys("n", 'xt')     | infra.AssertLocation(4998, v:null, '[n] continues [#] search forward to 4998')
    feedkeys("N", 'xt')     | infra.AssertLocation(4999, v:null, '[N] walks back to 4999')
    feedkeys("N", 'xt')     | infra.AssertLocation(5000, v:null, '[N] returns exactly to the original word on 5000')
    feedkeys("Gk$BvEEE#", 'xt') | infra.AssertLocation(infra.total_lines - 1, v:null, '[#] on a unique word wraps the entire file and lands on itself')
    feedkeys(seam .. "Gjj$bveee#nnnNN", 'xt') | infra.AssertLocation(seam, v:null, '[*n]  multiline sequence works across seams.')

    feedkeys("5000G$bveee", 'xt') # Move cursor explicitly to the 'S' in 'Standard'
    silent! feedkeys("g#", 'xt') | infra.AssertLocation(5000, v:null, '[g#] multiline visual inverse backward search unsupported, must stay in same place')


    infra.LogHeader('Search Case Sensitivity (Forced Smartcase)')
    feedkeys("15000G/easter_egg_top\<CR>", 'xt') | infra.AssertLocation(1, v:null, '[smartcase] Lowercase query ignores case and finds UPPERCASE match')
    silent! feedkeys("15000G/EASTER_egg_top\<CR>", 'xt') | infra.AssertLocation(15000, v:null, '[smartcase] Mixed-case query enforces case and correctly fails to find mismatch')
    silent! feedkeys("15000G/easter_egg_bottom\\c\<CR>", 'xt') | infra.AssertLocation(15000, v:null, '[\\c] Stripped cleanly, falls back to forced smartcase')

    infra.LogHeader('Visual Selection Restoration (gv)')
    var first_seam = b:chunk_lines[0]
    feedkeys("100GV2j\<Esc>10Ggv\<Esc>", 'xt') | infra.AssertLocation(102, v:null, '[gv] correctly restores line-wise visual selection in the same chunk')
    feedkeys("100G0v5l\<Esc>20000Ggv\<Esc>", 'xt') | infra.AssertLocation(100, v:null, '[gv] forces chunk reload and restores character-wise selection across remote chunks')
    feedkeys(first_seam - 1 .. "GV2j\<Esc>15000Ggv\<Esc>", 'xt') | infra.AssertLocation(first_seam + 1, v:null, '[gv] correctly restores a visual block that straddles two chunks')

    feedkeys(":unlet! b:pager_vis_start b:pager_vis_end\<CR>", 'xt')
    silent! feedkeys("10Ggv\<Esc>", 'xt') | infra.AssertLocation(10, v:null, '[gv] fails cleanly and stays in place if visual state is completely absent')

    infra.EndSuite()
enddef

RunTests()
