# vim-paginate

A Vim9 plugin for paging very large files without fully loading them into RAM.

- Responsive navigation of files well over 10GB
- Ultra-fast search powered by `ripgrep`
- Minimal RAM usage by chunk swapping

This plugin splits the source file into on-disk chunks, loads a sliding 3-chunk window into a scratch buffer, and keeps your cursor aligned to real file line numbers.

## Requirements

- Vim 9.0+ 
- `rg` 
- `coreutils` 

## Installation

```vim
filetype plugin on
Plug 'pabsan-0/vim-paginate'
```

Users that don't want to maintain their own vim environment can also install a portable version with:

```
curl -fsSL https://raw.githubusercontent.com/pabsan-0/vim-paginate/master/install.sh | bash
```

## Quick start

- Open a large file normally. Feel free to interrupt loading with `^C`
- Run `:PagerInit` to chunk the file and enter the read-only pager view (paginate://...).
- Run `:PagerQuit` to return to the editable, original file

## Commands and mappings

Pagination commands:

| Command         | Scope  | Action                                                                  |
| ---             | ---    | ---                                                                     |
| `:PagerInit`    | Global | Chunk the current file into /tmp and open the pager view                |
| `:PagerFreeAll` | Global | Forcefully wipe all hidden pager buffers and delete all /tmp files      |
| `:PagerQuit`    | Buffer | Destroy the pager, delete its temp files, and native-edit the real file |
| `:PagerInfo`    | Buffer | Print debug information (offsets, chunk lines, file sizes, etc.)        |
| `:J {line}`     | Buffer | Jump to an absolute line (equivalent to {line}G)                        |

Hijacked mappings that override default Vim bahavior:

| Mapping             | Action                                                         |
| ---                 | ---                                                            |
| `j` / `k`           | Move up/down                                                   |
| `<C-f>` / `<C-b>`   | Page down / Page up                                            |
| `<C-d>` / `<C-u>`   | Half-page down / Half-page up                                  |
| `gg` / `G`          | Jump to top / bottom (or specific line with <count>G)          |
| `/` / `?`           | Forward / backward search (Native RAM -> Ripgrep)              |
| `n` / `N`           | Repeat search forward / backward                               |
| `*` / `#`           | Search word under cursor (or visual selection)                 |
| `m{a-z}` / `'{a-z}` | Set / Jump to local mark                                       |
| `<C-o>` / `<C-i>`   | Jump backward / forward in custom buffer jump list             |
| `gv`                | Restore last visual selection                                  |

Additional mappings:

| Mapping             | Action                                                         |
| ---                 | ---                                                            |
| `g/` / `g?`         | Line-wise inverse search (yields lines without a match)        |
| `g*` / `g#`         | Line-wise inverse search from word / visual selection          |
| `[c` / `]c`         | Jump to the start / end boundary of the currently loaded chunk |

## Tests

The suite generates a deterministic temporary file, runs pager interactions, and prints a pass/fail report in a scratch buffer.

```bash
make tests
```


## FAQ 

#### How do I edit a file?
Pager view is strictly read-only for performance and simplicity. To edit a line, run `:PagerQuit` to load the original file at the current line, and edit there.

#### Why are the line numbers in the gutter incorrect?
The native gutter resets per chunk. Read your true absolute line number from the bottom-right statusline. Gutter stays visible just to help discussing with colleagues.

#### Does this plugin take up disk space?
Yes. To save RAM, files are copied into chunks at `/tmp/vim-paginate/`. You need free space equal to the paginated file size. Chunks auto-destruct when closing the buffer or exiting Vim.

#### Why won't the screen scroll while I'm dragging a Visual selection?
Visual mode is intentionally limited to the current view and does not trigger new chunks to load. To navigate further, drop back to Normal mode and continue scrolling.

#### Can I yank huge blocks of text?
Yanking is strictly limited to the loaded view, larger motions will be truncated. To extract many lines, use CLI tools like `sed` or `awk` instead of Vim registers.

#### Can I search not using smartcase?
No. To simplify the coordiunation between Vim's internal engine and Ripgrep, **smartcase** is enforced. Explicit case-override flags such as `\c \C` will be rejected.
