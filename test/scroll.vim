vim9script

import './infra.vim' as infra

export def ScrollForward(keys: string, NextLine: func(any): any, skip_start: number = 0, skip_end: number = 0)
    var start_line = 1 + skip_start
    feedkeys(start_line .. 'G', 'xt') # Use feedkeys to ensure Pager catches the jump

    var fail = -1
    var curr_linenr = start_line

    while curr_linenr < infra.total_lines - skip_end
        # Calculate the expected next line using your lambda, with upper clamp
        var next_linenr = NextLine(curr_linenr)
        next_linenr = next_linenr > infra.total_lines ? infra.total_lines : next_linenr

        feedkeys(keys, 'xt')
        var actual_line = line('.') + get(b:, 'pager_offset', 0)

        if actual_line != next_linenr
            fail = curr_linenr
            break
        endif

        curr_linenr = actual_line
    endwhile

    if fail == -1
        add(infra.test_report, "[PASS] Progressive forward read: " .. keys)
    else
        var actual = line('.') + get(b:, 'pager_offset', 0)
        add(infra.test_report, "[FAIL] Progressive forward read: " .. keys .. " -> Failed at origin " .. fail .. ". Expected " .. NextLine(fail) .. ", Got " .. actual)
    endif
enddef

export def ScrollBackwards(keys: string, NextLine: func(any): any, skip_start: number = 0, skip_end: number = 0)
    var start_line = infra.total_lines - skip_start
    feedkeys(start_line .. 'G', 'xt') # Start at the bottom

    var fail = -1
    var curr_linenr = start_line

    while curr_linenr > 1 + skip_end
        var next_linenr = NextLine(curr_linenr)
        next_linenr = next_linenr < 1 ? 1 : next_linenr

        feedkeys(keys, 'xt')
        var actual_line = line('.') + get(b:, 'pager_offset', 0)

        if actual_line != next_linenr
            fail = curr_linenr
            break
        endif

        curr_linenr = actual_line
    endwhile

    if fail == -1
        add(infra.test_report, "[PASS] Progressive backward read: " .. keys)
    else
        var actual = line('.') + get(b:, 'pager_offset', 0)
        add(infra.test_report, "[FAIL] Progressive backward read: " .. keys .. " -> Failed at origin " .. fail .. ". Expected " .. NextLine(fail) .. ", Got " .. actual)
    endif
enddef
