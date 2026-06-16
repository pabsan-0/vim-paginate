vim9script

# Script-local state for search
var last_search_pattern: string = ''
var last_search_forward: bool = v:true

# =============================================================================
# Utils & helpers
# =============================================================================

# Formats an integer like 1000000 into "1_000_000", for readable user display
def FormatNum(n: number): string
    var s = string(n)
    var result = ''
    var length = len(s)
    for i in range(length)
        result ..= s[i]
        var remaining = length - i - 1
        if remaining > 0 && remaining % 3 == 0
            result ..= '_'
        endif
    endfor
    return result
enddef

# FIXME keep?
# Global function for the statusline evaluation
export def GetPagerRealLineFormatted(): string
    var real_line = exists('b:pager_offset') ? line('.') + b:pager_offset : line('.')
    return FormatNum(real_line)
enddef

# =============================================================================
# Initialization and Quitting
# =============================================================================

export def InitPager()
    # Fetch initial file and location
    var original_buf = bufnr('%')
    var original_line = line('.')
    var filepath = expand('%:p')
    if empty(filepath)
        echoerr 'No file currently loaded.'
        return
    endif

    # Setup temporary directory to dump file chunks
    var dirname = fnamemodify(filepath, ':h')
    var filename = fnamemodify(filepath, ':t')
    var tmp_dir = '/tmp/vim-pager' .. dirname
    var prefix = tmp_dir .. '/' .. filename .. '.parts_'
    mkdir(tmp_dir, 'p')

    # Split file in chunks using UNIX split
    # Splitting by even memory is way faster than splitting by even lines
    # A memory-based split still does keep sane first & last lines
    var chunk_size = get(g:, 'pager_chunk_size', '100M')
    var safe_filepath = shellescape(filepath)
    var safe_prefix = shellescape(prefix)
    echom 'Splitting file into ' .. chunk_size .. ' raw chunks...'
    system('split -C ' .. chunk_size .. ' -d -a 5 ' .. safe_filepath .. ' ' .. safe_prefix)

    # Index the lines where the splits just happened
    # First run wc on every chunk, verify sane output, then add lines
    # FIXME one-off error when pressing G
    echom 'Counting lines && indexing chunk lines...'
    var total_lines = 0
    var chunk_lines: list<number> = []
    var wc_output = systemlist('wc -l ' .. safe_prefix .. '*')
    for line in wc_output
        var fields = split(line)
        if len(fields) >= 2 && fields[1] != 'total'
            var count = str2nr(fields[0])
            add(chunk_lines, count)
            total_lines += count
        endif
    endfor

    # Create a buffer for our pager view and set variables for record
    enew
    b:pager_prefix = prefix
    b:pager_filepath = filepath
    b:chunk_size = chunk_size
    b:chunk_lines = chunk_lines
    b:pager_total_lines = total_lines
    b:pager_total_formatted = FormatNum(total_lines)
    b:current_chunk_idx = 0
    b:pager_offset = 0

    # Load the first chunks view and assign the Paginate filetype
    LoadChunks(0)
    GoToRealLine(original_line)
    setlocal filetype=paginate

    # Delete the original buffer. Not awesome but covers a relevant edge case:
    #  Typically, when opening a very large file that you're going to paginate
    #  you needn't wait for it to load, which may take a lot. You can press ^C
    #  to early-quit then paginate it from disk. This prevents that this
    #  half-file is loaded when doing PagerQuit, which will reload the file
    #  instead.
    execute 'bd ' .. original_buf

    echom 'Pager initialized! Ready to view ' .. filename
enddef

export def QuitPager()
    # FIXME check for filetype paginate instead?
    if !exists('b:pager_filepath')
        return
    endif

    var target_line = exists('b:pager_offset') ? line('.') + b:pager_offset : line('.')
    var filepath = b:pager_filepath

    # Open the original file in the current window
    # Because we use bufhidden=wipe, this replaces the pager and triggers CleanupPager
    execute 'edit ' .. fnameescape(filepath)

    # FIXME recover column too
    cursor(target_line, 1)
    silent! norm! zz
    echom 'Pager closed. The full file is now loaded natively and is editable.'
enddef

# FIXME Do not need the prefix, since the variable is buffer-local
# FIXME Get rid of needing to press Enter after all these messages
export def CleanupPager(prefix: string)
    var chunk_files = glob(prefix .. '*', 1, 1)
    for file in chunk_files
        delete(file)
    endfor
    echom 'Pager cleaned up. Temporary chunks removed.'
enddef

# =============================================================================
# Buffer & variable chunk logic
# =============================================================================

# Loads a chunked view in the current buffer. This view consists of 3 chunks,
# so that at user can always see the main body plus before/after context.
def LoadChunks(start_chunk_idx: number)
    setlocal modifiable

    # Purge current buffer contents
    silent! :%delete _

    # Keeping this logic here on purpose. Using a 3-chunk window, we
    # anticipate the previous / next chunk index that needs to be
    # loaded into the buffer.
    b:current_chunk_idx = start_chunk_idx
    b:current_chunk_prev_idx = start_chunk_idx - 1
    b:current_chunk_next_idx = start_chunk_idx + 3

    # Calculate b:pager_offset: sum of all lines prior to our loaded window
    var offset = 0
    for chunk_idx in range(start_chunk_idx)
        offset += b:chunk_lines[chunk_idx]
    endfor
    b:pager_offset = offset

    # Read the three next chunks into the buffer
    for seq_chunk_idx in [0, 1, 2]
        var idx = start_chunk_idx + seq_chunk_idx
        if idx < len(b:chunk_lines)
            var chunk_file = b:pager_prefix .. printf('%05d', idx)
            if filereadable(chunk_file)
                silent execute ':$read ' .. fnameescape(chunk_file)
            endif
        endif
    endfor

    silent! :1delete _
    setlocal nomodifiable
enddef

# FIXME rename to CheckShiftBoundaries
# FIXME TEST surgically change boundary and verify the chunks change
export def CheckBoundaries()
    var current_line = line('.')
    var total_lines = line('$')

    var prev_thresh = 100000
    var next_thresh = total_lines - 100000

    if current_line < prev_thresh && b:current_chunk_prev_idx > 0
        ShiftUp()
    elseif current_line > next_thresh && (b:current_chunk_next_idx) < len(b:chunk_lines)
        ShiftDown()
    endif
enddef

def ShiftDown()
    setlocal modifiable

    # Purge the first chunk from the top of the buffer
    var lines_to_delete = b:chunk_lines[b:current_chunk_idx]
    silent execute ':1,' .. lines_to_delete .. 'delete _'

    # Add the next chunk at the bottom of the buffer
    var next_idx = b:current_chunk_next_idx
    if next_idx < len(b:chunk_lines)
        var chunk_file = b:pager_prefix .. printf('%05d', next_idx)
        if filereadable(chunk_file)
            silent execute ':$read ' .. fnameescape(chunk_file)
        endif
    endif

    # Keep cursor in the proper line
    var pos = getpos('.')
    pos[1] -= lines_to_delete
    setpos('.', pos)

    b:pager_offset += lines_to_delete
    b:current_chunk_idx += 1

    setlocal nomodifiable
enddef

def ShiftUp()
    setlocal modifiable

    # Purge the last chunk from the bottom of the buffer
    var bottom_chunk_lines = b:chunk_lines[b:current_chunk_idx + 2]
    var bottom_start = line('$') - bottom_chunk_lines + 1
    silent execute ':' .. bottom_start .. ',$delete _'

    # Add the prev chunk at the top of the buffer
    var prev_idx = b:current_chunk_prev_idx
    if prev_idx >= 0
        var chunk_file = b:pager_prefix .. printf('%05d', prev_idx)
        if filereadable(chunk_file)
            silent execute ':0read ' .. fnameescape(chunk_file)
        endif
    endif
    var lines_added = prev_idx >= 0 ? b:chunk_lines[prev_idx] : 0

    # Keep cursor in the proper line
    var pos = getpos('.')
    pos[1] += lines_added
    setpos('.', pos)

    b:current_chunk_idx -= 1
    b:pager_offset -= lines_added

    setlocal nomodifiable
enddef

export def GoToRealLine(count: any, record_jump: bool = v:true)
    var target = b:pager_total_lines
    if count != v:null && count > 0
        target = count
    endif

    if record_jump
        PushJump()
    endif

    # Protect against under/overflow natively
    if target < 1
        target = 1
    elseif target > b:pager_total_lines
        target = b:pager_total_lines
    endif

    # Find out which chunk holds the current line
    var accumulated_lines = 0
    var target_chunk_idx = 0
    for i in range(len(b:chunk_lines))
        accumulated_lines += b:chunk_lines[i]
        if target <= accumulated_lines
            target_chunk_idx = i
            break
        endif
    endfor

    # Position the target chunk into the center of our 3-chunk window
    # FIXME Don't like that this number-hardcoding logic is spread
    var start_chunk_idx = target_chunk_idx - 1
    if start_chunk_idx < 0
        start_chunk_idx = 0
    endif

    # Prevent buffer overflow past the total chunk limits
    # FIXME This should be the job of LoadChunks
    # FIXME Don't like that this number-hardcoding logic is spread
    if start_chunk_idx + 2 >= len(b:chunk_lines)
        start_chunk_idx = len(b:chunk_lines) - 3
        if start_chunk_idx < 0
            start_chunk_idx = 0
        endif
    endif

    LoadChunks(start_chunk_idx)
    cursor(target - b:pager_offset, 1)
enddef

# This protects against large moves that may move out of the buffer directly
# without allowing CheckBoundaries to catch up
export def MoveUpDown(is_down: bool, count: number)
    if count == 0
        # No count provided, perform a standard single-line native movement
        execute 'normal! ' .. (is_down ? 'j' : 'k')
        return
    endif

    # Calculate where the user wants to go in the real file
    var current_real = line('.') + b:pager_offset
    var target_real = is_down ? current_real + count : current_real - count

    # Clamp the target to file boundaries
    if target_real < 1 | target_real = 1 | endif
    if target_real > b:pager_total_lines | target_real = b:pager_total_lines | endif

    # Translate the real target back to a local buffer line
    var buffer_target = target_real - b:pager_offset

    # Check if that line is already sitting inside our loaded 3-chunk window
    if buffer_target > 0 && buffer_target <= line('$')
        # Safe! The text is already in RAM. Jump there natively.
        cursor(buffer_target, col('.'))
    else
        # Danger! The user is jumping out of the buffer. Force an absolute reload.
        GoToRealLine(target_real)
    endif
enddef

# =============================================================================
# Search logic (two-phase native + ripgrep)
# =============================================================================

export def PromptSearch(forward: bool)
    var input_pattern = input(forward ? '/' : '?')
    echo "\r"
    if empty(input_pattern)
        return
    endif

    # FIXME these are custom variables? No scope?
    last_search_pattern = input_pattern
    last_search_forward = forward
    ExecuteSearch(forward)
enddef

# FIXME This is for asterisk. Add a visual variant here.
export def SearchWordUnderCursor()
    last_search_pattern = expand('<cword>')
    last_search_forward = v:true
    ExecuteSearch(v:true)
enddef

export def RepeatSearch(forward: bool)
    if empty(last_search_pattern)
        echoerr 'No previous regular expression'
        return
    endif

    var execute_forward = last_search_forward
    if !forward
        execute_forward = !last_search_forward
    endif
    ExecuteSearch(execute_forward)
enddef

# FIXME: refactor into smaller functions
# FIXME: phase 4 could be done with ripgrep, worth it?
# FIXME: substitute-count commands should work over the whole file
# FIXME: TEST add tests for all phases, n, N, *, /, ?
def ExecuteSearch(forward: bool)
    try
        @/ = last_search_pattern
        set hlsearch
    catch
    endtry

    var original_pos = getpos('.')
    var safe_pattern = shellescape(last_search_pattern)
    var has_notified_wrap = v:false

    # Phase 1: Vim native search in current buffer
    var native_match = search(last_search_pattern, forward ? 'W' : 'bW')
    if native_match > 0
        PushJump(original_pos[1] + b:pager_offset)
        CheckBoundaries()
        silent! norm! zz
        return
    endif

    echom "No matches in buffer: Scanning unloaded chunks for '" .. last_search_pattern .. "'..."
    redraw

    # Phase 2: Search from the start of next chunk to the end of chunks
    # Phase 3: (implicit via wrapping) Search from the first chunk up to the current.
    var chunk_starts = []
    var start_line = 1
    for lines in b:chunk_lines
        add(chunk_starts, start_line)
        start_line += lines
    endfor

    for is_wrapped in [v:false, v:true]
        var files_to_search = []

        if forward
            if !is_wrapped
                var scan_start = b:current_chunk_idx + 3
                if scan_start < len(b:chunk_lines)
                    for i in range(scan_start, len(b:chunk_lines) - 1)
                        var chunk_file = b:pager_prefix .. printf('%05d', i)
                        if filereadable(chunk_file)
                            add(files_to_search, shellescape(chunk_file))
                        endif
                    endfor
                endif
            else
                var scan_end = b:current_chunk_idx - 1
                if scan_end >= 0
                    for i in range(0, scan_end)
                        var chunk_file = b:pager_prefix .. printf('%05d', i)
                        if filereadable(chunk_file)
                            add(files_to_search, shellescape(chunk_file))
                        endif
                    endfor
                endif
            endif
        else
            if !is_wrapped
                var scan_start = b:current_chunk_idx - 1
                if scan_start >= 0
                    for i in range(scan_start, 0, -1)
                        var chunk_file = b:pager_prefix .. printf('%05d', i)
                        if filereadable(chunk_file)
                            add(files_to_search, shellescape(chunk_file))
                        endif
                    endfor
                endif
            else
                var scan_start = len(b:chunk_lines) - 1
                var scan_end = b:current_chunk_idx + 3
                if scan_start >= scan_end
                    for i in range(scan_start, scan_end, -1)
                        var chunk_file = b:pager_prefix .. printf('%05d', i)
                        if filereadable(chunk_file)
                            add(files_to_search, shellescape(chunk_file))
                        endif
                    endfor
                endif
            endif
        endif

        if !empty(files_to_search)
            if is_wrapped && !has_notified_wrap
                echo 'search hit ' .. (forward ? 'BOTTOM' : 'TOP') .. ', continuing at ' .. (forward ? 'TOP' : 'BOTTOM')
                redraw
                has_notified_wrap = v:true
            endif

            var cmd = ''
            if forward
                cmd = 'for f in ' .. join(files_to_search, ' ') .. '; do out=$(rg --vimgrep -m 1 -e ' .. safe_pattern .. ' "$f" 2>/dev/null); if [ -n "$out" ]; then echo "$out"; break; fi; done'
            else
                cmd = 'for f in ' .. join(files_to_search, ' ') .. '; do out=$(rg --vimgrep -e ' .. safe_pattern .. ' "$f" 2>/dev/null | tail -n 1); if [ -n "$out" ]; then echo "$out"; break; fi; done'
            endif

            var res = trim(system(cmd))
            if !empty(res)
                var parts = split(res, ':')
                if len(parts) >= 3
                    var suffix = matchstr(parts[0], '\d\{5}$')
                    if !empty(suffix)
                        var match_chunk_idx = str2nr(suffix)
                        var found_real_line = chunk_starts[match_chunk_idx] + str2nr(parts[1]) - 1
                        var found_column = str2nr(parts[2])
                        GoToRealLine(found_real_line)
                        cursor(line('.'), found_column)
                        silent! norm! zz
                        return
                    endif
                endif
            endif
        endif
    endfor

    if !has_notified_wrap
        echo 'search hit ' .. (forward ? 'BOTTOM' : 'TOP') .. ', continuing at ' .. (forward ? 'TOP' : 'BOTTOM')
        redraw
    endif

    # Phase 4: Native search in the remaining buffer
    if forward
        cursor(1, 1)
        native_match = search(last_search_pattern, 'W', original_pos[1])
    else
        cursor(line('$'), 1)
        normal! $
        native_match = search(last_search_pattern, 'bW', original_pos[1])
    endif

    if native_match > 0
        PushJump(original_pos[1] + b:pager_offset)
        CheckBoundaries()
        silent! norm! zz
        return
    endif

    setpos('.', original_pos)
    echoerr 'Pattern not found: ' .. last_search_pattern
enddef

# =============================================================================
# Custom jump list engine
# =============================================================================

def PushJump(from_real_line: number = -1)
    if !exists('b:pager_jumps')
        b:pager_jumps = []
        b:pager_jump_idx = -1
    endif

    var current_real = from_real_line > -1 ? from_real_line : line('.') + b:pager_offset

    # If we jumped back in time and are initiating a NEW jump, truncate the future jumps
    if b:pager_jump_idx > -1 && b:pager_jump_idx < len(b:pager_jumps) - 1
        b:pager_jumps = b:pager_jumps[0 : b:pager_jump_idx]
    endif

    # Prevent duplicate sequential entries
    if empty(b:pager_jumps) || b:pager_jumps[-1] != current_real
        add(b:pager_jumps, current_real)
        b:pager_jump_idx = len(b:pager_jumps) - 1
    endif
enddef

# FIXME all errors should be paginate errors: override but don't lie
export def NavigateJump(is_back: bool)
    if !exists('b:pager_jumps') || empty(b:pager_jumps)
        echoerr 'E73: tag stack empty'
        return
    endif

    var current_real = line('.') + b:pager_offset
    if is_back
        if b:pager_jump_idx == len(b:pager_jumps) - 1
            # Jumping back from the first time: record current spot to ^I back
            # FIXME should be a PushJump rather than code?
            if b:pager_jumps[-1] != current_real
                add(b:pager_jumps, current_real)
            endif
        else
            b:pager_jump_idx -= 1
        endif

        if b:pager_jump_idx >= 0
            GoToRealLine(b:pager_jumps[b:pager_jump_idx], v:false)
        else
            b:pager_jump_idx = 0
            echo "At oldest jump"
        endif
    else
        if b:pager_jump_idx < len(b:pager_jumps) - 1
            b:pager_jump_idx += 1
            GoToRealLine(b:pager_jumps[b:pager_jump_idx], v:false)
        else
            echo "At newest jump"
        endif
    endif
enddef

# =============================================================================
# Bookmarking system
# =============================================================================

# FIXME Why not cover for CAPS marks? We have the bufwipe but would it make sense?
export def SetMark(char: string)
    if char =~# '^[a-z]$'
        if !exists('b:pager_marks')
            b:pager_marks = {}
        endif
        b:pager_marks[char] = line('.') + b:pager_offset
        echo "Pager mark '" .. char .. "' set."
    else
        # Fallback to normal behavior for non [a-z] marks
        execute 'normal! m' .. char
    endif
enddef

# FIXME '' or "", but uniform?
export def JumpMark(use_column: bool, char: string)
    if char =~# '^[a-z]$'
        if exists('b:pager_marks') && has_key(b:pager_marks, char)
            GoToRealLine(b:pager_marks[char])
            if use_column
                cursor(line('.'), 1)
            endif
        else
            echoerr 'E20: Mark not set'
        endif
    else
        # Fallback to normal behavior for non [a-z] marks
        try
            execute 'normal! ' .. (use_column ? '`' : "'") .. char
        catch
            echoerr v:errmsg
        endtry
    endif
enddef

# =============================================================================
# Info and debugging conveniences
# =============================================================================

export def ShowPagerInfo()
    if !exists('b:pager_offset')
        echoerr 'Pager is not initialized in this buffer.'
        return
    endif

    var total_chunks = len(b:chunk_lines) - 1
    echohl Title
    echo '=== Pager Debug Info ==='
    echohl None

    echo 'Original File:   ' .. b:pager_filepath
    echo 'Chunk Mode:      Byte-split (' .. b:chunk_size .. ' Chunks)'
    echo 'Total Chunks:    ' .. FormatNum(total_chunks)
    echo 'Temp Prefix:     ' .. b:pager_prefix

    echo '---'
    echo 'Current Offset:  ' .. FormatNum(b:pager_offset)
    echo 'Real Line:       ' .. GetPagerRealLineFormatted() .. ' / ' .. FormatNum(b:pager_total_lines)
    echo 'Buffer Line:     ' .. FormatNum(line('.')) .. ' / ' .. FormatNum(line('$'))
    # FIXME show list of loaded chunks instead
    echo 'Window Base Chk: [' .. b:current_chunk_idx .. ']'

    echo '---'
    echo 'Loaded Chunks in Memory:'
    for i in [0, 1, 2]
        var idx = b:current_chunk_idx + i
        if idx < total_chunks
            var chunk_file = b:pager_prefix .. printf('%05d', idx)
            echo '  [' .. idx .. '] -> ' .. chunk_file .. ' (' .. FormatNum(b:chunk_lines[idx]) .. ' lines)'
        else
            echo '  [' .. idx .. '] -> (Empty / End of File)'
        endif
    endfor

    echo '---'
    echo 'Chunk Starting Lines:'
    var start_line = 1
    for idx in range(len(b:chunk_lines))
        var chunk_len = b:chunk_lines[idx]
        echo printf('  Chunk [%03d] starts at line: %s  (%s lines)', idx, FormatNum(start_line), FormatNum(chunk_len))
        start_line += chunk_len
    endfor
    echo '========================'
enddef


# Returns a list acting as a tuple: [start_line, end_line]
export def GetCurrentChunkBoundaries(): list<number>
    if !exists('b:pager_offset') || !exists('b:chunk_lines')
        return [1, get(b:, 'pager_total_lines', line('$'))]
    endif

    var current_abs_line = line('.') + b:pager_offset
    var cumulative_lines = 0

    for lines_in_chunk in b:chunk_lines
        var chunk_start = cumulative_lines + 1
        cumulative_lines += lines_in_chunk
        var chunk_end = cumulative_lines

        # If the cursor falls within this mathematical window, return the tuple
        if current_abs_line >= chunk_start && current_abs_line <= chunk_end
            return [chunk_start, chunk_end]
        endif
    endfor

    # Fallback if math fails or we are completely out of bounds
    return [1, get(b:, 'pager_total_lines', line('$'))]
enddef

export def GetBoundaryStart(jump: bool = v:false): number
    var boundaries = GetCurrentChunkBoundaries()
    var target_abs_line = boundaries[0]
    if jump | execute 'normal ' .. target_abs_line .. 'G' | endif
    return target_abs_line
enddef

export def GetBoundaryEnd(jump: bool = v:false): number
    var boundaries = GetCurrentChunkBoundaries()
    var target_abs_line = boundaries[1]
    if jump | execute 'normal ' .. target_abs_line .. 'G' | endif
    return target_abs_line
enddef
