# vim-paginate

A Vim9 plugin for paging very large files without loading them into RAM.

It splits the source file into on-disk chunks, loads a sliding 3-chunk window into a scratch buffer, and keeps your cursor aligned to real file line numbers.

## Requirements

- Vim 9+ with `:filetype plugin on`
- `split`
- `wc`
- `rg` 

## Installation

```vim
Plug 'pabsan-0/vim-paginate'
```

## Quick start

- Open a large file normally. Feel free to interrupt loading with `^C`
- Run `:PagerInit` to enter the read-only pager view
- Run `:PagerQuit` to return to the editable, original file

## Commands and mappings

Pagination commands:

- `:PagerInit`: Enter pager mode for the current file.
- `:PagerInfo`: Print pager/chunk debug information.
- `:PagerQuit`: Exit pager mode and reopen the native file at the same line.

Hijacked vim mappings that work with paginated files:

- Movement: `j`, `k`, `gg`, `G`, `<C-f>`, `<C-b>`, `<C-d>`, `<C-u>`
- Search: `/`, `?`, `n`, `N`, `*`
- Marks: `m`, `'`, `` ` ``
- Jump list: `<C-o>`, `<C-i>`

## Tests

The suite generates a deterministic temporary file, runs pager interactions, and prints a pass/fail report in a scratch buffer.

```bash
make tests
```
