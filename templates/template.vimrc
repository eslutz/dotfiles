" Enable syntax highlighting for better code readability
syntax on

" Basic editor improvements
set number                      " Show line numbers
set hlsearch                    " Highlight search results
set incsearch                   " Incremental search
set ignorecase                  " Case insensitive search
set smartcase                   " Case sensitive when uppercase letters are used
set tabstop={{VIM_TAB_WIDTH}}                   " Tab width
set shiftwidth={{VIM_INDENT_WIDTH}}                " Indent width
set expandtab                   " Use spaces instead of tabs
set autoindent                  " Automatically indent new lines
set smartindent                 " Smart indentation for code
set backspace=indent,eol,start  " Allow backspace over everything
set ruler                       " Show cursor position
set showcmd                     " Show incomplete commands
set wildmenu                    " Enhanced command completion
set scrolloff={{VIM_SCROLL_OFFSET}}                 " Keep {{VIM_SCROLL_OFFSET}} lines visible above/below cursor

" File handling and backup
set nobackup                    " Don't create backup files - modern editors handle this
set noswapfile                  " Don't create swap files - cleaner filesystem, Git handles versioning
set undofile                    " Persistent undo - undo survives file close/reopen
set undodir=~/.vim/undodir      " Where to store undo files

" Visual improvements
set cursorline                  " Highlight current line - easier to see cursor position
set showmatch                   " Show matching brackets - helpful for coding
set colorcolumn={{VIM_LINE_LENGTH}}              " Show column at {{VIM_LINE_LENGTH}} chars - encourages good line length
set wrap                        " Wrap long lines - better for reading
set linebreak                   " Break lines at word boundaries - cleaner wrapping

" Search improvements
set wrapscan                    " Wrap searches around end of file - more intuitive

" Modern conveniences
set mouse={{VIM_MOUSE_MODE}}                     " Enable mouse support
set clipboard={{VIM_CLIPBOARD}}           " Clipboard integration
