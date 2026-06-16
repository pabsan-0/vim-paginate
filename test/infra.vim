vim9script

g:pager_chunk_size = '300K'

export var test_file = '/tmp/vim-paginate-test.log'
export var total_lines = 60000
export var test_report: list<string> = []
export var pass_count = 0
export var fail_count = 0

var root_dir = fnamemodify(expand('<sfile>:p'), ':h:h')

export def BeginSuite()
    execute 'set runtimepath^=' .. fnameescape(root_dir)
    filetype plugin on
    test_report = []
    pass_count = 0
    fail_count = 0

    SetupTestFile()
    execute 'source ' .. fnameescape(root_dir .. '/plugin/paginate.vim')
    execute 'edit ' .. test_file
enddef

export def EndSuite()
    delete(test_file)

    var summary = []
    add(summary, '==========================================================')
    add(summary, ' PAGINATE TEST RESULTS')
    add(summary, '==========================================================')
    add(summary, ' Total Tests: ' .. (pass_count + fail_count))
    add(summary, ' Passes:      ' .. pass_count)
    add(summary, ' Fails:       ' .. fail_count)
    add(summary, '==========================================================')

    var final_output = summary + test_report
    execute 'enew'
    setlocal buftype=nofile bufhidden=wipe noswapfile
    setline(1, final_output)

    syntax match TestPass /\[PASS\]/
    syntax match TestFail /\[FAIL\]/
    highlight TestPass ctermfg=green guifg=green
    highlight TestFail ctermfg=red guifg=red
enddef

export def SetupTestFile()
    var lines = []
    for i in range(1, total_lines)
        if i == 1
            add(lines, 'Line 1 - [EASTER_EGG_TOP]')
        elseif i == (total_lines / 4)
            add(lines, 'Line 2500 - [MARK_TARGET]')
        elseif i == (total_lines / 2)
            add(lines, 'Line 7500 - [EASTER_EGG_MIDDLE]')
        elseif i == (total_lines - 1)
            add(lines, 'Line 14999 - [EASTER_EGG_BOTTOM]')
        else
            add(lines, 'Line ' .. i .. ' - Standard filler data to bulk out the chunk size.')
        endif
    endfor
    writefile(lines, test_file)
enddef

export def LogHeader(title: string)
    add(test_report, '')
    add(test_report, '=== ' .. title .. ' ===')
enddef

export def ExpectEqual(expected: any, actual: any, context: string)
    if expected == actual
        add(test_report, '[PASS] ' .. context)
        pass_count += 1
    else
        add(test_report, '[FAIL] ' .. context .. ' -> Expected: ' .. string(expected) .. ', Got: ' .. string(actual))
        fail_count += 1
    endif
enddef

export def ExpectMatch(pattern: string, actual: string, context: string)
    if actual =~ pattern
        add(test_report, '[PASS] ' .. context)
        pass_count += 1
    else
        add(test_report, "[FAIL] " .. context .. " -> Pattern '" .. pattern .. "' not found in: '" .. actual .. "'")
        fail_count += 1
    endif
enddef

export def ExpectFalse(condition: bool, context: string)
    if !condition
        add(test_report, '[PASS] ' .. context)
        pass_count += 1
    else
        add(test_report, '[FAIL] ' .. context .. ' -> Expected False, but was True')
        fail_count += 1
    endif
enddef

export def ExpectTrue(condition: bool, context: string)
    if condition
        add(test_report, '[PASS] ' .. context)
        pass_count += 1
    else
        add(test_report, '[FAIL] ' .. context .. ' -> Expected False, but was True')
        fail_count += 1
    endif
enddef

export def AssertLocation(expected_line: number, expected_col: any, context: string)
    var actual_line = line('.') + b:pager_offset
    if expected_col != v:null
        var expected_str = string(expected_line) .. ':' .. string(expected_col)
        var actual_str = string(actual_line) .. ':' .. string(col('.'))
        ExpectEqual(expected_str, actual_str, context)
    else
        ExpectEqual(expected_line, actual_line, context)
    endif
enddef

export def AssertText(expected: string, context: string)
    var actual = getline('.')
    ExpectMatch(expected, actual, context)
enddef
