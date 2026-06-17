vim9script

if exists('b:did_ftplugin')
    finish
endif
b:did_ftplugin = 1

import '../autoload/paginate.vim' as paginate

setlocal statusline=%t\ %=\ Line\ %{paginate#GetPagerRealLineFormatted()}\ /\ %{b:pager_total_formatted}\ (Chunk\ view\ %{b:current_chunk_idx})

setlocal buftype=nofile
setlocal bufhidden=wipe
setlocal noswapfile
setlocal undolevels=-1

augroup PaginateBufferAutocmds
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call paginate.CheckBoundaries()
    autocmd ExitPre <buffer> if exists('b:pager_prefix') | call paginate.CleanupPager(b:pager_prefix) | endif
    autocmd BufWipeout <buffer> if exists('b:pager_prefix') | call paginate.CleanupPager(b:pager_prefix) | endif
augroup END

command! -buffer -nargs=1 J call paginate.GoToRealLine(str2nr(<q-args>))
command! -buffer -nargs=0 PagerInfo call paginate.ShowPagerInfo()
command! -buffer -nargs=0 PagerQuit call paginate.QuitPager()

nnoremap <buffer> <silent> j  <ScriptCmd>paginate.MoveUpDown(v:true, v:count)<CR>
nnoremap <buffer> <silent> k  <ScriptCmd>paginate.MoveUpDown(v:false, v:count)<CR>

nnoremap <buffer> <silent> gg <ScriptCmd>paginate.GoToRealLine(1)<CR>
nnoremap <buffer> <silent> G  <ScriptCmd>paginate.GoToRealLine(v:count)<CR>
nnoremap <buffer> <silent> /  <ScriptCmd>paginate.PromptSearch(v:true)<CR>
nnoremap <buffer> <silent> ?  <ScriptCmd>paginate.PromptSearch(v:false)<CR>
nnoremap <buffer> <silent> n  <ScriptCmd>paginate.RepeatSearch(v:true)<CR>
nnoremap <buffer> <silent> N  <ScriptCmd>paginate.RepeatSearch(v:false)<CR>
nnoremap <buffer> <silent> *  <ScriptCmd>paginate.SearchWordUnderCursor()<CR>

nnoremap <buffer> <silent> g/ <ScriptCmd>paginate.PromptSearch(v:true, v:true)<CR>
nnoremap <buffer> <silent> g? <ScriptCmd>paginate.PromptSearch(v:false, v:true)<CR>

nnoremap <buffer> <silent> <C-f> <ScriptCmd>paginate.MoveUpDown(v:true, winheight(0))<CR>
nnoremap <buffer> <silent> <C-b> <ScriptCmd>paginate.MoveUpDown(v:false, winheight(0))<CR>
nnoremap <buffer> <silent> <C-d> <ScriptCmd>paginate.MoveUpDown(v:true, winheight(0) / 2)<CR>
nnoremap <buffer> <silent> <C-u> <ScriptCmd>paginate.MoveUpDown(v:false, winheight(0) / 2)<CR>

nnoremap <buffer> <silent> m <ScriptCmd>paginate.SetMark(getcharstr())<CR>
nnoremap <buffer> <silent> ' <ScriptCmd>paginate.JumpMark(v:false, getcharstr())<CR>
nnoremap <buffer> <silent> ` <ScriptCmd>paginate.JumpMark(v:true, getcharstr())<CR>

nnoremap <buffer> <silent> <C-o> <ScriptCmd>paginate.NavigateJump(v:true)<CR>
nnoremap <buffer> <silent> <C-i> <ScriptCmd>paginate.NavigateJump(v:false)<CR>

nnoremap <buffer> <silent> [c <ScriptCmd>paginate.GetBoundaryStart(v:true)<CR>
nnoremap <buffer> <silent> ]c <ScriptCmd>paginate.GetBoundaryEnd(v:true)<CR>
