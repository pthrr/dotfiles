" bootstrap dein and install plugins
let s:settings = {}
let s:settings.cache_dir = expand('~/.config/nvim/cache')
let s:settings.dein_dir = s:settings.cache_dir . '/dein'
let s:settings.dein_repo_dir = s:settings.dein_dir . '/repos/github.com/Shougo/dein.vim'
if &runtimepath !~# '/dein.vim'
    if !isdirectory(s:settings.dein_repo_dir)
        execute '!git clone --depth 1 https://github.com/Shougo/dein.vim ' . s:settings.dein_repo_dir
    endif
    execute 'set rtp^=' . fnamemodify(s:settings.dein_repo_dir, ':p')
endif
if dein#load_state(s:settings.dein_dir)
    call dein#begin(s:settings.dein_dir)
    call dein#add('sirver/ultisnips')
    call dein#end()
    call dein#save_state()
endif
if dein#check_install()
    call dein#install()
endif
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
set scrolloff=1
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
hi MatchParen guibg=none guifg=red gui=bold
set matchtime=0
" highlight cursorline in insert mode
highlight clear cursorline
highlight cursorline gui=underline cterm=underline
autocmd InsertEnter * set cursorline
autocmd InsertLeave * set nocursorline
" UltiSnips config
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$HOME.'/Documents/snippets']
let g:ultisnips_python_style = 'google'
