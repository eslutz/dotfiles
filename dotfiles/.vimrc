" Enable syntax highlighting for better code readability
syntax on

" Basic editor improvements
set number                      " Show line numbers
set hlsearch                    " Highlight search results
set incsearch                   " Incremental search
set ignorecase                  " Case insensitive search
set smartcase                   " Case sensitive when uppercase letters are used
set tabstop=4                   " Tab width - 4 spaces for better visibility
set shiftwidth=4                " Indent width - matches tabstop
set expandtab                   " Use spaces instead of tabs
set autoindent                  " Automatically indent new lines
set smartindent                 " Smart indentation for code
set backspace=indent,eol,start  " Allow backspace over everything
set ruler                       " Show cursor position
set showcmd                     " Show incomplete commands
set wildmenu                    " Enhanced command completion
set scrolloff=3                 " Keep 3 lines visible above/below cursor

" File handling and backup
set nobackup                    " Don't create backup files - modern editors handle this
set noswapfile                  " Don't create swap files - cleaner filesystem, Git handles versioning
set undofile                    " Persistent undo - undo survives file close/reopen
set undodir=~/.vim/undodir      " Where to store undo files

" Visual improvements
set cursorline                  " Highlight current line - easier to see cursor position
set showmatch                   " Show matching brackets - helpful for coding
set colorcolumn=80              " Show column at 80 chars - encourages good line length
set wrap                        " Wrap long lines - better for reading
set linebreak                   " Break lines at word boundaries - cleaner wrapping

" Search improvements
set wrapscan                    " Wrap searches around end of file - more intuitive

" Modern conveniences
set mouse=a                     " Enable mouse support in all modes (normal, visual, insert, command-line)
set clipboard=unnamed           " Use system clipboard - easier copy/paste
