#!/usr/bin/env bash
set -e

# Default to standard XDG userland paths if env vars are not provided
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/vim-paginate}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

REPO_URL="https://github.com/pabsan-0/vim-paginate.git"

echo "==> Installing vim-paginate..."

# Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "==> Updating existing installation in $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull origin master
else
    echo "==> Cloning repository into $INSTALL_DIR..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Generate a standalone minimal vimrc
# Don't like these? either seek and edit the file, or **maintain your own vimrc**
echo "==> Generating standalone configuration..."
VIMRC_FILE="$INSTALL_DIR/paginate.vimrc"
cat << EOF > "$VIMRC_FILE"
" Foundation
set nocompatible
set t_RV=
set t_RF=
set t_RB=

" Log-reading performance
set synmaxcol=500
set lazyredraw
set nowrap
set sidescroll=1
set sidescrolloff=5

" Search and UI
set incsearch
set hlsearch
set mouse=a
set shortmess+=I
set cursorline
set number
set relativenumber
set laststatus=2
set statusline=%F
hi StatusLine ctermbg=white ctermfg=black

" Disk hygiene
set noswapfile
set nobackup
set nowritebackup

" Add the plugin to the runtimepath so it loads automatically
set rtp^=${INSTALL_DIR}
runtime! plugin/**/*.vim
EOF

# Generate the wrapper script
# Escape $# and $1 so they evaluate at runtime, but let INSTALL_DIR/VIMRC_FILE expand now
echo "==> Generating executable wrapper..."
WRAPPER_SCRIPT="$INSTALL_DIR/paginate"
cat << EOF > "$WRAPPER_SCRIPT"
#!/usr/bin/env bash

if [ "\$#" -eq 0 ]; then
    echo "Usage: paginate <file>"
    exit 1
fi

# --clean ignores user vimrc/plugins for a pure, fast, isolated pager experience
# -u loads our dedicated minimal pager config
vim --clean \\
    -u "${VIMRC_FILE}" \\
    -c "enew | execute 'file ' .. fnameescape('\$1')" \\
    -c "autocmd VimEnter * vim9cmd PagerInit"
EOF

chmod +x "$WRAPPER_SCRIPT"

# Create the symlink
echo "==> Creating symlink in $BIN_DIR..."
mkdir -p "$BIN_DIR"
ln -sf "$WRAPPER_SCRIPT" "$BIN_DIR/paginate"

echo ""
echo "✅ vim-paginate installed successfully!"
echo "You can now use it like a standalone pager:"
echo "    paginate /var/log/syslog"

# PATH sanity check
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "⚠️  WARNING: $BIN_DIR is not currently in your system PATH."
    echo "To use the 'paginate' command globally, add this to your ~/.bashrc or ~/.zshrc:"
    echo "export PATH=\"\$PATH:$BIN_DIR\""
fi
