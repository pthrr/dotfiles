syntax on
filetype plugin indent on
colorscheme elflord
set termguicolors
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8
set nobackup
set nowritebackup
set noswapfile
set number
set relativenumber
set scrolloff=999
set nowrap
set hlsearch
set title
set hidden
set noshowmode
set novisualbell
set noerrorbells
set statusline=%t\ %h%w%m%r%y[%{&fileencoding?&fileencoding:&encoding}]\ 0x%B\ %L\ %P
set colorcolumn=80
set textwidth=79
set clipboard=unnamedplus
set list listchars=tab:\›\ ,trail:-,extends:>,precedes:<
set linespace=0
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
" automatically save view, load with :loadview
autocmd BufWinLeave *.* mkview
" paste multiple times
xnoremap p pgvy
" add all subfolders to path
set path=$PWD/**
set wildmenu
set wildmode=list:longest,full
" show matching brackets
set showmatch
hi MatchParen guibg=none guifg=magenta gui=bold
set matchtime=0
" highlight cursorline in insert mode
highlight clear cursorline
highlight cursorline gui=underline cterm=underline
autocmd InsertEnter * set cursorline
autocmd InsertLeave * set nocursorline
