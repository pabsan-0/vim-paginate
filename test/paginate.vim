vim9script

# =============================================================================
# PAGER AUTOMATED TEST SUITE - 1.0 Coverage (Interactive Dashboard Mode)
# =============================================================================

var test_file = '/tmp/vim-paginate-test.log'
var total_lines = 15000

# We set a chunk size large enough to avoid jitter but small enough to test boundaries
g:pager_chunk_size = '300K'

# Script-local report state
var test_report: list<string> = []
var pass_count = 0
var fail_count = 0

# =============================================================================
# SETUP
# =============================================================================

def SetupTestFile()
    echo "Generating deterministic test file..."
    var lines = []
    for i in range(1, total_lines)
        if i == 1
            add(lines, "Line 1 - [EASTER_EGG_TOP]")
        elseif i == 2500
            add(lines, "Line 2500 - [MARK_TARGET]")
        elseif i == 7500
            add(lines, "Line 7500 - [EASTER_EGG_MIDDLE]")
        elseif i == 14999
            add(lines, "Line 14999 - [EASTER_EGG_BOTTOM]")
        else
            add(lines, "Line " .. i .. " - Standard filler data to bulk out the chunk size.")
        endif
    endfor
    writefile(lines, test_file)
enddef

# =============================================================================
# TRACEABILITY & CUSTOM ASSERTION WRAPPERS
# =============================================================================

# Cache the line number so we only read the file from the disk once
var runtests_def_line = 0

def GetCallerLocation(): string
    var stack = expand('<stack>')

    # 1. Extract the file name and path
    var file_path = matchstr(stack, 'script \zs.\{-}\ze\[')
    if empty(file_path) | return "unknown:0" | endif
    var filename = fnamemodify(file_path, ':t')

    # 2. Extract the execution offset explicitly from the RunTests block
    # Stack looks like: ...function <SNR>12_RunTests[45]..ExpectEqual[1]
    var func_offset = str2nr(matchstr(stack, 'RunTests\[\zs\d\+\ze\]'))

    # 3. Parse the file strictly to find where 'def RunTests' starts
    if runtests_def_line == 0
        silent! var lines = readfile(file_path)
        var lnum = 0
        for line in lines
            lnum += 1
            if line =~# '^\s*def\s\+RunTests\>.*'
                runtests_def_line = lnum
                break
            endif
        endfor
    endif

    # 4. Definition line + internal offset
    var abs_line = runtests_def_line > 0 ? runtests_def_line + func_offset : 0

    return filename .. ':' .. abs_line
enddef

def ExpectEqual(expected: any, actual: any, context: string)
    var loc = printf("%-20s", GetCallerLocation())
    if expected == actual
        add(test_report, "  " .. loc .. " ✅ [PASS] " .. context)
        pass_count += 1
    else
        add(test_report, "  " .. loc .. " ❌ [FAIL] " .. context .. " -> Expected: " .. string(expected) .. ", Got: " .. string(actual))
        fail_count += 1
    endif
enddef

def ExpectMatch(pattern: string, actual: string, context: string)
    var loc = printf("%-20s", GetCallerLocation())
    if actual =~ pattern
        add(test_report, "  " .. loc .. " ✅ [PASS] " .. context)
        pass_count += 1
    else
        add(test_report, "  " .. loc .. " ❌ [FAIL] " .. context .. " -> Pattern '" .. pattern .. "' not found in: '" .. actual .. "'")
        fail_count += 1
    endif
enddef

def ExpectFalse(condition: bool, context: string)
    var loc = printf("%-20s", GetCallerLocation())
    if !condition
        add(test_report, "  " .. loc .. " ✅ [PASS] " .. context)
        pass_count += 1
    else
        add(test_report, "  " .. loc .. " ❌ [FAIL] " .. context .. " -> Expected False, but was True")
        fail_count += 1
    endif
enddef

def AssertLocation(expected_line: number, expected_col: any, context: string)
    var actual_line = line('.') + b:pager_offset

    if expected_col != v:null
        var expected_str = string(expected_line) .. ':' .. string(expected_col)
        var actual_str = string(actual_line) .. ':' .. string(col('.'))
        ExpectEqual(expected_str, actual_str, context)
    else
        ExpectEqual(expected_line, actual_line, context)
    endif
enddef

def AssertText(expected: string, context: string)
    var actual = getline('.')
    ExpectMatch(expected, actual, context)
enddef

def LogHeader(title: string)
    add(test_report, "")
    add(test_report, "=== " .. title .. " ===")
enddef

# =============================================================================
# TEST RUNNER
# =============================================================================

def RunTests()
    # Reset State
    test_report = []
    pass_count = 0
    fail_count = 0

    SetupTestFile()

    # Load the plugin and the test file
    execute 'source ~/.vim/plugin/pager.vim'
    execute 'edit ' .. test_file

    echo "Running tests..."

    # --- TEST 1: Initialization ---
    LogHeader("TEST 1: Initialization")
    execute 'PagerInit'
    AssertLocation(1, v:null, "Initialized at Line 1")
    ExpectEqual(total_lines, b:pager_total_lines, "Total lines recognized correctly")

    # --- TEST 2: Absolute Jumps (G and :J) ---
    LogHeader("TEST 2: Absolute Jumps")
    feedkeys("7500G", 'xt')
    AssertLocation(7500, v:null, "Jump to Middle (G mapping)")
    AssertText("EASTER_EGG_MIDDLE", "Middle Text matched")

    feedkeys(":J 14999\<CR>", 'xt')
    AssertLocation(14999, v:null, "Jump to Bottom (:J command)")
    AssertText("EASTER_EGG_BOTTOM", "Bottom Text matched")

    # --- TEST 3: Smart Movement & Paging (j mapping) ---
    LogHeader("TEST 3: Relative Movement")
    feedkeys("gg", 'xt')
    feedkeys("2499j", 'xt')
    AssertLocation(2500, v:null, "Move Down 2499 lines (j mapping)")
    AssertText("MARK_TARGET", "Moved Text matched")

    # --- TEST 4: Jump List Engine (<C-o> / <C-i>) ---
    LogHeader("TEST 4: Custom Jump List")
    feedkeys(":J 100\<CR>", 'xt')
    feedkeys(":J 500\<CR>", 'xt')

    feedkeys("\<C-o>", 'xt')
    AssertLocation(100, v:null, "Jump List Back 1 (<C-o>)")

    feedkeys("\<C-o>", 'xt')
    AssertLocation(2500, v:null, "Jump List Back 2 (<C-o>)")

    feedkeys("\<C-i>", 'xt')
    AssertLocation(100, v:null, "Jump List Forward 1 (<C-i>)")

    # --- TEST 5: Bookmarking Engine (m and ') ---
    LogHeader("TEST 5: Bookmarks")
    feedkeys("100Gma", 'xt')
    feedkeys("200Gmb", 'xt')

    feedkeys("10000G", 'xt')
    feedkeys("'a", 'xt')
    AssertLocation(100, v:null, "Bookmark Retrieval ('a mapping)")

    feedkeys("10000G", 'xt')
    feedkeys("`a", 'xt')
    AssertLocation(100, 1, "Bookmark Retrieval (`a mapping)")

    feedkeys("`b", 'xt')
    AssertLocation(200, 1, "Bookmark Retrieval (`b mapping)")

    # --- TEST 6: Forward Search (/) ---
    LogHeader("TEST 6: Forward Search")
    feedkeys("gg", 'xt')
    feedkeys("/EASTER_EGG_BOTTOM\<CR>", 'xt')
    AssertLocation(14999, v:null, "Forward Search Location matched")
    AssertText("EASTER_EGG_BOTTOM", "Forward Search Text matched")

    # --- TEST 7: Wrapped Backward Search (?) ---
    LogHeader("TEST 7: Wrapped Backward Search")
    feedkeys("?EASTER_EGG_TOP\<CR>", 'xt')
    AssertLocation(1, v:null, "Wrapped Backward Search Location matched")
    AssertText("EASTER_EGG_TOP", "Wrapped Backward Search Text matched")

    # --- TEST 8: PagerQuit and Native Verification ---
    LogHeader("TEST 8: Exit Lifecycle")
    feedkeys(":J 8888\<CR>", 'xt')
    AssertLocation(8888, v:null, "Pre-Quit Alignment")
    feedkeys(":PagerQuit\<CR>", 'xt')

    ExpectEqual('', &buftype, "Buffer returned to native (empty buftype)")
    ExpectEqual(8888, line('.'), "Native buffer landed on exactly line 8888")
    ExpectFalse(exists('b:pager_offset'), "Script-local variables wiped cleanly")

    # --- TEST 9: Init from an Offset Line ---
    LogHeader("TEST 9: Init from Offset Line")
    feedkeys("3456G", 'xt')
    ExpectEqual(3456, line('.'), "Native Move pre-Init successful")
    feedkeys(":PagerInit\<CR>", 'xt')

    ExpectEqual('nofile', &buftype, "Offset Init triggered Pager mode")
    AssertLocation(3456, v:null, "Offset Init retained line 3456")

    # =========================================================================
    # TEARDOWN & REPORTING UI
    # =========================================================================

    delete(test_file)

    # Compile the final summary block
    var summary = []
    add(summary, "==========================================================")
    add(summary, " PAGER TEST RESULTS")
    add(summary, "==========================================================")
    add(summary, " Total Tests: " .. (pass_count + fail_count))
    add(summary, " Passes:      " .. pass_count)
    add(summary, " Fails:       " .. fail_count)
    add(summary, "==========================================================")

    var final_output = summary + test_report

    # Open a brand new scratch buffer to display the results
    execute 'enew'
    setlocal buftype=nofile bufhidden=wipe noswapfile
    setline(1, final_output)

    # Highlight passing, failing text, and trace links
    syntax match TestPass /✅ \[PASS\]/
    syntax match TestFail /❌ \[FAIL\]/
    syntax match TestTrace /test_pager\.vim:\d\+/

    highlight TestPass ctermfg=green guifg=green
    highlight TestFail ctermfg=red guifg=red
    highlight TestTrace ctermfg=blue guifg=#5e81ac cterm=underline gui=underline

    echo "Tests completed! Displaying results."
enddef

# Execute the suite
RunTests()
