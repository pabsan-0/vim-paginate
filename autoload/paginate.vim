vim9script

# =============================================================================
# Utils & helpers
# =============================================================================

# Formats an integer like 1000000 into "1_000_000", for readable user display
def FormatNum(n: number): string
    var s = string(n)
    var is_negative = s[0] == '-'
    if is_negative | s = s[1 : ] | endif

    var result = ''
    var length = len(s)
    for i in range(length)
        result ..= s[i]
        var remaining = length - i - 1
        if remaining > 0 && remaining % 3 == 0
            result ..= '_'
        endif
    endfor

    return is_negative ? '-' .. result : result
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

def InstallPagerUI()
    setlocal statusline=%f\ %=\ Line\ %{paginate#GetPagerRealLineFormatted()}\ /\ %{b:pager_total_formatted}\ (Chunk\ view\ %{b:current_chunk_idx})

    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal undolevels=-1
    setlocal ignorecase
    setlocal smartcase

    augroup PaginateBufferAutocmds
        autocmd! * <buffer>
        autocmd CursorMoved <buffer> call paginate#CheckBoundaries()
        autocmd BufWipeout  <buffer> call paginate#CleanupPager()
        autocmd BufDelete   <buffer> call paginate#CleanupPager()
    augroup END

    command! -buffer -nargs=1 J call GoToRealLine(str2nr(<q-args>))
    command! -buffer -nargs=0 PagerInfo call ShowPagerInfo()
    command! -buffer -nargs=0 PagerQuit call QuitPager()

    nnoremap <buffer> <silent> j  <ScriptCmd>MoveUpDown(v:true, v:count)<CR>
    nnoremap <buffer> <silent> k  <ScriptCmd>MoveUpDown(v:false, v:count)<CR>

    nnoremap <buffer> <silent> gg <ScriptCmd>GoToRealLine(1)<CR>
    nnoremap <buffer> <silent> G  <ScriptCmd>GoToRealLine(v:count)<CR>
    nnoremap <buffer> <silent> /  <ScriptCmd>PromptSearch(v:true)<CR>
    nnoremap <buffer> <silent> ?  <ScriptCmd>PromptSearch(v:false)<CR>
    nnoremap <buffer> <silent> n  <ScriptCmd>RepeatSearch(v:true)<CR>
    nnoremap <buffer> <silent> N  <ScriptCmd>RepeatSearch(v:false)<CR>

    nnoremap <buffer> <silent> *  <ScriptCmd>SearchUnderCursor(v:true, v:false)<CR>
    nnoremap <buffer> <silent> g* <ScriptCmd>SearchUnderCursor(v:true, v:true)<CR>
    nnoremap <buffer> <silent> #  <ScriptCmd>SearchUnderCursor(v:false, v:false)<CR>
    nnoremap <buffer> <silent> g# <ScriptCmd>SearchUnderCursor(v:false, v:true)<CR>

    xnoremap <buffer> <silent> *  <ScriptCmd>SearchUnderCursorVisual(v:true, v:false)<CR>
    xnoremap <buffer> <silent> g* <ScriptCmd>SearchUnderCursorVisual(v:true, v:true)<CR>
    xnoremap <buffer> <silent> #  <ScriptCmd>SearchUnderCursorVisual(v:false, v:false)<CR>
    xnoremap <buffer> <silent> g# <ScriptCmd>SearchUnderCursorVisual(v:false, v:true)<CR>

    nnoremap <buffer> <silent> g/ <ScriptCmd>PromptSearch(v:true, v:true)<CR>
    nnoremap <buffer> <silent> g? <ScriptCmd>PromptSearch(v:false, v:true)<CR>

    nnoremap <buffer> <silent> <C-f> <ScriptCmd>MoveUpDown(v:true, winheight(0))<CR>
    nnoremap <buffer> <silent> <C-b> <ScriptCmd>MoveUpDown(v:false, winheight(0))<CR>
    nnoremap <buffer> <silent> <C-d> <ScriptCmd>MoveUpDown(v:true, winheight(0) / 2)<CR>
    nnoremap <buffer> <silent> <C-u> <ScriptCmd>MoveUpDown(v:false, winheight(0) / 2)<CR>

    nnoremap <buffer> <silent> m <ScriptCmd>SetMark(getcharstr())<CR>
    nnoremap <buffer> <silent> ' <ScriptCmd>JumpMark(v:false, getcharstr())<CR>
    nnoremap <buffer> <silent> ` <ScriptCmd>JumpMark(v:true, getcharstr())<CR>

    nnoremap <buffer> <silent> <C-o> <ScriptCmd>NavigateJump(v:true)<CR>
    nnoremap <buffer> <silent> <C-i> <ScriptCmd>NavigateJump(v:false)<CR>

    nnoremap <buffer> <silent> `` <ScriptCmd>NavigateJump(v:true)<CR>
    nnoremap <buffer> <silent> '' <ScriptCmd>NavigateJump(v:true)<CR>
    nnoremap <buffer> <silent> gv <ScriptCmd>RestoreVisualState()<CR>

    nnoremap <buffer> <silent> [c <ScriptCmd>GetBoundaryStart(v:true)<CR>
    nnoremap <buffer> <silent> ]c <ScriptCmd>GetBoundaryEnd(v:true)<CR>

    # Dummy iface
    nnoremap <buffer> <silent> <Down>  <ScriptCmd>MoveUpDown(v:true, v:count)<CR>
    nnoremap <buffer> <silent> <Up>  <ScriptCmd>MoveUpDown(v:false, v:count)<CR>

    b:paginate = true
enddef

export def InitPager()
    if get(b:, "paginate", false)
        echoerr 'This buffer is already a pager.'
        return
    endif

    # Fetch initial file and location
    var original_buf = bufnr('%')
    var original_line = line('.')
    var filepath = expand('%:p')
    if empty(filepath)
        echoerr 'No file currently loaded. Are you on a scratch buffer?'
        return
    endif

    var virtual_name = 'paginate://' .. filepath
    if bufexists(virtual_name)
        execute 'buffer ' .. bufnr(virtual_name)
        return
    endif

    # Setup temporary directory to dump file chunks
    var dirname = fnamemodify(filepath, ':h')
    var filename = fnamemodify(filepath, ':t')
    var tmp_dir = '/tmp/vim-paginate' .. dirname
    var prefix = tmp_dir .. '/' .. filename .. '.parts_'

    # Purge existing chunks from a previous execution / mkdir
    var stale_chunks = glob(prefix .. '*', 1, 1)
    for chunk in stale_chunks
        delete(chunk)
    endfor
    mkdir(tmp_dir, 'p')

    # Verify sufficient disk space before splitting
    var file_size = getfsize(filepath)
    var df_output = systemlist('df -kP ' .. shellescape(tmp_dir))

    if len(df_output) >= 2
        # df -kP guarantees a single-line output for the drive at the bottom
        var available_kb = str2nr(split(df_output[-1])[3])
        var required_kb = file_size / 1024
        var safety_margin_kb = 1 * 1024 * 1024 # 1 GB safety buffer

        if available_kb < required_kb + safety_margin_kb
            var free_after_mb = FormatNum((available_kb - required_kb) / 1024)

            echoerr 'Disk space too low. Rejecting to chunk file into ' .. prefix .. '* and leave you with ' .. free_after_mb .. ' MB free.'
            return
        endif
    endif

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

    # Create a buffer for our pager view
    enew
    execute 'file ' .. fnameescape(virtual_name)

    # Set variables for record
    b:pager_prefix = prefix
    b:pager_filepath = filepath
    b:chunk_size = chunk_size
    b:chunk_lines = chunk_lines
    b:pager_total_lines = total_lines
    b:pager_total_formatted = FormatNum(total_lines)
    b:current_chunk_idx = 0
    b:pager_offset = 0

    # Load the first chunks view and install UI
    LoadChunks(0)
    GoToRealLine(original_line)
    InstallPagerUI()

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
    var target_line = exists('b:pager_offset') ? line('.') + b:pager_offset : line('.')
    var pager_buf = bufnr('%')

    # Open the original file in the current window
    execute 'edit ' .. fnameescape(b:pager_filepath)

    # Explicitly wipe the pager buffer to trigger the cleanup autocommand
    execute 'bwipeout ' .. pager_buf

    # FIXME recover column too
    cursor(target_line, 1)
    silent! norm! zz
    echom 'Pager closed. The full file is now loaded natively and is editable.'
enddef

export def CleanupPager(target_prefix: string = '')
    var prefix = target_prefix != '' ? target_prefix : getbufvar(str2nr(expand('<abuf>')), 'pager_prefix', '')
    if empty(prefix)
        return
    endif

    var chunk_files = glob(prefix .. '*', 1, 1)
    for file in chunk_files
        delete(file)
    endfor
enddef

export def CleanupAllPagers()
    for i in range(1, bufnr('$'))
        if bufexists(i) && getbufvar(i, 'paginate', false)
            var prefix = getbufvar(i, 'pager_prefix', '')
            if !empty(prefix)
                CleanupPager(prefix)
            endif
            silent! execute 'bwipeout! ' .. i
        endif
    endfor
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
export def CheckBoundaries()
    # Skip if in visual mode
    if mode() =~# '^[vV\x16]'
        return
    endif

    var current_line = line('.')
    var total_lines = line('$')
    var visual_margin = winheight(0) * 3
    if visual_margin < 1 | visual_margin = 1 | endif
    var margin = max([total_lines / 4, visual_margin])

    if current_line < margin && b:current_chunk_prev_idx >= 0
        ShiftUp()
    elseif current_line > total_lines - margin + 1 && b:current_chunk_next_idx < len(b:chunk_lines)
        ShiftDown()
    endif
enddef

def ShiftDown()
    setlocal modifiable

    # Save absolute real line and column before ANY modification
    var target_real = line('.') + b:pager_offset
    var target_col = col('.')

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

    # Update pager state
    b:pager_offset += lines_to_delete
    b:current_chunk_idx += 1
    b:current_chunk_prev_idx += 1
    b:current_chunk_next_idx += 1

    # Restore cursor position
    cursor(target_real - b:pager_offset, target_col)

    setlocal nomodifiable
enddef

def ShiftUp()
    setlocal modifiable

    # Save absolute real line and column before ANY modification
    var target_real = line('.') + b:pager_offset
    var target_col = col('.')

    # Purge the last chunk from the bottom of the buffer
    var bottom_chunk_lines = b:chunk_lines[b:current_chunk_idx + 2]
    var bottom_start = line('$') - bottom_chunk_lines + 1
    silent execute ':' .. bottom_start .. ',$delete _'

    # Add the prev chunk at the top of the buffer
    var prev_idx = b:current_chunk_prev_idx
    var lines_added = 0
    if prev_idx >= 0
        var chunk_file = b:pager_prefix .. printf('%05d', prev_idx)
        if filereadable(chunk_file)
            silent execute ':0read ' .. fnameescape(chunk_file)
        endif
        lines_added = b:chunk_lines[prev_idx]
    endif

    # Update pager state
    b:current_chunk_idx -= 1
    b:current_chunk_prev_idx -= 1
    b:current_chunk_next_idx -= 1
    b:pager_offset -= lines_added

    # Restore cursor position
    cursor(target_real - b:pager_offset, target_col)

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
        CheckBoundaries()
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

    # If moving outside of the current chunk, just use the safer GoToRealLine
    # This was once implemented as moving outside of the current chunk view,
    # but there is a pitfall on that as one may jump across 2 chunks near the
    # top/bottom and do a single ShiftUp/ShiftDown.
    if GetCurrentChunkBoundaries(current_real)[0] == GetCurrentChunkBoundaries(target_real)[0]
        # Safe! The text is already in RAM. Jump there natively.
        cursor(buffer_target, col('.'))
    else
        # Danger! The user is jumping out of the buffer. Force an absolute reload.
        # Note this is slower
        GoToRealLine(target_real)
    endif
enddef

# =============================================================================
# Search logic (two-phase native + ripgrep)
# =============================================================================

export def PromptSearch(forward: bool, inverse: bool = v:false)
    var prompt_char = (inverse ? 'g' : '') .. (forward ? '/' : '?')
    var input_pattern = input(prompt_char)
    echo "\r" # Clean the command line

    # Strip trailing unescaped delimiters BEFORE checking for empty string
    # This prevents `//` from bypassing the empty string check
    var delimiter = forward ? '/' : '?'
    if !empty(input_pattern) && input_pattern =~ delimiter .. '$' && input_pattern !~ '\\' .. delimiter .. '$'
        input_pattern = input_pattern[: -2]
    endif

    # Handle empty prompt (repeat last search)
    if empty(input_pattern)
        input_pattern = @/
        if empty(input_pattern)
            return
        endif
    endif

    # Single source of truth for direction, inverse state, and pattern
    b:pager_search_forward = forward
    b:pager_search_inverse = inverse
    @/ = input_pattern
    ExecuteSearch(forward, inverse)
enddef

export def SearchUnderCursor(forward: bool, inverse: bool)
    var word = expand('<cword>')
    echom "*# searching " .. word

    if empty(word)
        return
    endif

    b:pager_search_forward = forward
    b:pager_search_inverse = inverse
    @/ = '\<' .. word .. '\>'
    ExecuteSearch(forward, inverse)
enddef

export def SearchUnderCursorVisual(forward: bool, inverse: bool)
    # Backup z register, as we'll use it to transport our visual selection
    var save_reg = getreg('z')
    var save_regtype = getregtype('z')

    # Yank visual selection
    execute "normal! \"zy"
    var text = @z

    setreg('z', save_reg, save_regtype)

    if empty(text)
        return
    endif

    if inverse && text =~ "\n"
        return
    endif

    # Escape regex meta-characters for BOTH Vim and Ripgrep engines
    var escaped_text = escape(text, '\.+*?()|[]{}^$')

    # Translate literal newlines (0x0A) into '\n' strings
    var pattern = substitute(escaped_text, "\n", '\\n', 'g')

    b:pager_search_forward = forward
    b:pager_search_inverse = inverse
    @/ = pattern

    ExecuteSearch(forward, inverse)
enddef

export def RepeatSearch(forward: bool)
    if empty(@/)
        echoerr 'No previous regular expression'
        return
    endif

    var is_forward = exists('b:pager_search_forward') ? b:pager_search_forward : v:true
    var is_inverse = exists('b:pager_search_inverse') ? b:pager_search_inverse : v:false

    if !forward
        is_forward = !is_forward
    endif

    ExecuteSearch(is_forward, is_inverse)
enddef

# FIXME: phase 4 could be done with ripgrep, worth it?
# FIXME: substitute-count commands should work over the whole file
export def ExecuteSearch(forward: bool, inverse: bool = v:false)
    var pattern = @/
    var original_pos = getpos('.')
    var current_abs_line = original_pos[1] + b:pager_offset

    # FIXME add support in the future
    if pattern =~# '\\c' || pattern =~# '\\C'
        echoerr 'Explicit case overrides (\c or \C) are not supported: Smartcase enforced.'
        return
    endif

    # Hacky way to set highlighting bypassing Vim's timing, that
    # would otherwise cause hl to show momentarily then go away
    if &hlsearch
        feedkeys("\<Cmd>let v:hlsearch = 1\<CR>", 'n')
    endif

    # Phase 1: Native Vim search in currently loaded chunks
    var native_pattern = inverse ? '^\%(.*' .. pattern .. '\)\@!' : pattern
    if search(native_pattern, forward ? 'W' : 'bW') > 0
        FinalizeSearchJump(current_abs_line)
        return
    endif

    # Phase 2 & 3: Unified Ripgrep & Seam Search across unloaded chunks
    if !SearchChunks(pattern, forward, inverse, current_abs_line)
        setpos('.', original_pos)
        echoerr 'Pattern not found: ' .. pattern
    endif
enddef

def SearchChunks(pattern: string, forward: bool, inverse: bool, current_abs_line: number): bool
    echom "Scanning unloaded chunks for '" .. pattern .. "'..." | redraw

    var is_multiline = pattern =~ '\\n'
    var rg_pattern = pattern
    var is_word_search = v:false

    if rg_pattern =~ '^\\<.*\\>$'
        is_word_search = v:true
        rg_pattern = rg_pattern[2 : -3]
    endif

    var safe_pattern = shellescape(rg_pattern)
    var rg_opts = ""
    rg_opts ..= inverse ? '--vimgrep -v' : '--vimgrep'
    rg_opts ..= is_multiline ? ' -U' : ''
    rg_opts ..= is_word_search ? ' -w' : ''
    rg_opts ..= " --smart-case"

    if is_multiline | rg_opts ..= ' -U' | endif
    if is_word_search | rg_opts ..= ' -w' | endif

    var search_order = GetChunkSearchOrder(forward)
    var has_notified_wrap = v:false

    var chunk_starts = [1]
    for lines in b:chunk_lines | add(chunk_starts, chunk_starts[-1] + lines) | endfor

    # Logical starting point: the edges of the currently loaded Vim buffer
    var prev_idx = forward ? b:current_chunk_idx + 2 : b:current_chunk_idx

    for idx in search_order
        # Wrap notification
        if forward && idx <= b:current_chunk_idx && !has_notified_wrap
            echo 'Search hit BOTTOM, continuing at TOP' | redraw | has_notified_wrap = v:true
        elseif !forward && idx >= b:current_chunk_idx && !has_notified_wrap
            echo 'Search hit TOP, continuing at BOTTOM' | redraw | has_notified_wrap = v:true
        endif

        # Seam check (Bridge between contiguous chunks)
        var is_contiguous = forward ? (idx == prev_idx + 1) : (idx == prev_idx - 1)

        if is_multiline && is_contiguous
            var top_idx = min([prev_idx, idx])
            var bot_idx = max([prev_idx, idx])

            # Note: We pass the original `pattern` here because Vim's native
            # matchstrpos() natively understands \< and \>
            var seam = CheckSeamStraddle(top_idx, bot_idx, pattern, forward, chunk_starts, inverse)

            if !empty(seam)
                GoToRealLine(seam.real_line)
                cursor(line('.'), seam.col)
                FinalizeSearchJump(current_abs_line)
                return v:true
            endif
        endif

        # Chunk search
        var chunk_file = b:pager_prefix .. printf('%05d', idx)
        if filereadable(chunk_file)
            var cmd = forward
                ? 'rg ' .. rg_opts .. ' -m 1 -e ' .. safe_pattern .. ' ' .. shellescape(chunk_file) .. ' 2>/dev/null'
                : 'rg ' .. rg_opts .. ' -e ' .. safe_pattern .. ' ' .. shellescape(chunk_file) .. ' 2>/dev/null | tail -n 1'

            var res = trim(system(cmd))
            if !empty(res)
                var parts = split(res, ':')
                if len(parts) >= 3
                    var found_real_line = chunk_starts[idx] + str2nr(parts[1]) - 1
                    var found_column = str2nr(parts[2])

                    GoToRealLine(found_real_line)
                    cursor(line('.'), found_column)
                    FinalizeSearchJump(current_abs_line)
                    return v:true
                endif
            endif
        endif

        # Update position for the next iteration
        prev_idx = idx
    endfor

    return v:false
enddef

def CheckSeamStraddle(idx1: number, idx2: number, pattern: string, forward: bool, chunk_starts: list<number>, inverse: bool): dict<any>
    # Inverse straddling doesn't make logical sense, let Ripgrep handle inverse natively.
    if inverse | return {} | endif

    var file1 = b:pager_prefix .. printf('%05d', idx1)
    var file2 = b:pager_prefix .. printf('%05d', idx2)
    if !filereadable(file1) || !filereadable(file2) | return {} | endif

    # Read 50 lines from the bottom of chunk 1, and 50 from the top of chunk 2
    # FIXME compute from lenght of the pattern
    var window = 50
    var lines1 = readfile(file1, '', -window)
    var lines2 = readfile(file2, '', window)
    var seam_text = join(lines1 + lines2, "\n")

    var start_idx = 0
    var matches = []

    # Find all occurrences in the stitched text
    while v:true
        var m = matchstrpos(seam_text, pattern, start_idx)
        if m[1] == -1 | break | endif
        add(matches, m)
        start_idx = m[1] + 1
    endwhile

    if empty(matches) | return {} | endif

    var len1 = len(lines1)
    var valid_matches = []

    # Filter for matches that ACTUALLY straddle the boundary
    for m in matches
        var prefix_start = strpart(seam_text, 0, m[1])
        var lines_before = count(prefix_start, "\n")

        var prefix_end = strpart(seam_text, 0, m[2])
        var lines_after = count(prefix_end, "\n")

        # STRADDLE CONDITION: Match must start in File 1 and end in File 2
        if lines_before < len1 && lines_after >= len1
            var last_nl = strridx(prefix_start, "\n")
            var col = len(prefix_start) - last_nl

            # Calculate absolute starting line
            var abs_seam_start = chunk_starts[idx1] + b:chunk_lines[idx1] - len1

            add(valid_matches, {
                real_line: abs_seam_start + lines_before,
                col: col
            })
        endif
    endfor

    if empty(valid_matches) | return {} | endif

    return forward ? valid_matches[0] : valid_matches[-1]
enddef

def FinalizeSearchJump(orig_absolute_line: number)
    PushJump(orig_absolute_line)
    CheckBoundaries()
    silent! norm! zz
enddef

def GetChunkSearchOrder(forward: bool): list<number>
    var order = []
    var current = b:current_chunk_idx
    var total = len(b:chunk_lines)

    if forward
        if current + 3 < total | order += range(current + 3, total - 1) | endif
        order += range(0, min([current + 2, total - 1]))
    else
        if current - 1 >= 0 | order += range(current - 1, 0, -1) | endif
        order += range(total - 1, current, -1)
    endif

    return order
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
# Visual Mode State Management
# =============================================================================

export def SaveVisualState()
    # Abort if we are not inside an active pager buffer
    if !exists('b:pager_offset')
        return
    endif

    # Capture the absolute real lines of the visual selection upon exiting
    b:pager_vis_start = getpos("'<")
    b:pager_vis_start[1] += b:pager_offset
    b:pager_vis_end = getpos("'>")
    b:pager_vis_end[1] += b:pager_offset
enddef

export def RestoreVisualState()
    if !exists('b:pager_vis_start') || !exists('b:pager_vis_end')
        return
    endif

    # If the start of the visual selection is out of the current chunk window, jump to it
    if b:pager_vis_start[1] <= b:pager_offset || b:pager_vis_start[1] > b:pager_offset + line('$')
        GoToRealLine(b:pager_vis_start[1])
    endif

    # Translate absolute lines back to current buffer lines
    var buf_start = b:pager_vis_start[1] - b:pager_offset
    var buf_end = b:pager_vis_end[1] - b:pager_offset

    # Clamp the end of the selection if it bleeds out of the loaded chunks
    if buf_end > line('$')
        buf_end = line('$')
    endif

    # Manually overwrite the native marks with the corrected buffer lines
    setpos("'<", [0, buf_start, b:pager_vis_start[2], 0])
    setpos("'>", [0, buf_end, b:pager_vis_end[2], 0])

    # Execute native gv to reselect
    execute 'normal! gv'
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
export def GetCurrentChunkBoundaries(linenr: number = -1): list<number>
    if !exists('b:pager_offset') || !exists('b:chunk_lines')
        return [1, get(b:, 'pager_total_lines', line('$'))]
    endif

    var current_abs_line = linenr > 0 ? linenr : line('.') + b:pager_offset
    var cumulative_lines = 0

    var chunk_index = 0
    for lines_in_chunk in b:chunk_lines
        var chunk_start = cumulative_lines + 1
        cumulative_lines += lines_in_chunk
        var chunk_end = cumulative_lines

        # If the cursor falls within this mathematical window, return the tuple
        if current_abs_line >= chunk_start && current_abs_line <= chunk_end
            return [chunk_index, chunk_start, chunk_end]
        endif

        chunk_index += 1
    endfor

    # Fallback if math fails or we are completely out of bounds
    return [-1, 1, get(b:, 'pager_total_lines', line('$'))]
enddef

export def GetBoundaryStart(jump: bool = v:false): number
    var boundaries = GetCurrentChunkBoundaries()
    var target_abs_line = boundaries[1]
    if jump | execute 'normal ' .. target_abs_line .. 'G' | endif
    return target_abs_line
enddef

export def GetBoundaryEnd(jump: bool = v:false): number
    var boundaries = GetCurrentChunkBoundaries()
    var target_abs_line = boundaries[2]
    if jump | execute 'normal ' .. target_abs_line .. 'G' | endif
    return target_abs_line
enddef
