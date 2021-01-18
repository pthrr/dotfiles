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
set hlsearch
set title
set hidden
set noshowmode
set novisualbell
set noerrorbells
set showtabline=2
set colorcolumn=80
set textwidth=80
set clipboard=unnamedplus
set list listchars=tab:\›\ ,trail:-,extends:>,precedes:<
set linespace=0
set tabstop=8
set softtabstop=8
set shiftwidth=8
set expandtab
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
