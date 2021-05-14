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
    "call dein#add('lifepillar/vim-solarized8')
    call dein#add('overcache/NeoSolarized')
    call dein#add('preservim/tagbar')
    call dein#end()
    call dein#save_state()
endif
if dein#check_install()
    call dein#install()
endif
syntax on
filetype plugin indent on
"let g:solarized_use16=1
"colorscheme solarized8
set termguicolors
colorscheme NeoSolarized
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8
set nobackup
set nowritebackup
set noswapfile
set nobomb
set splitbelow
set splitright
set relativenumber
set nowrap
set autoread
set hlsearch
set title
set hidden
set noshowmode
set novisualbell
set noerrorbells
set statusline=
set statusline +=\ %n\             "buffer number
set statusline +=%{&ff}            "file format
set statusline +=%y                "file type
set statusline +=\ %<%F            "full path
set statusline +=%m                "modified flag
set statusline +=%=%5l             "current line
set statusline +=/%L               "total lines
set statusline +=%4v\              "virtual column number
set statusline +=0x%04B\           "character under cursor
set colorcolumn=80
"highlight ColorColumn ctermbg=darkgrey ctermfg=none cterm=none
set clipboard=unnamedplus
"set clipboard+=unnamedplus
"let g:clipboard = {
"    \   'name':'win32yank-wsl',
"    \   'copy': {
"    \       '+': 'win32yank.exe -i --crlf',
"    \       '*': 'win32yank.exe -i --crlf',
"    \   },
"    \   'paste': {
"    \       '+': 'win32yank.exe -o --lf',
"    \       '*': 'win32yank.exe -o --lf',
"    \   },
"    \   'cache_enabled': 0,
"    \ }
set list listchars=tab:\›\ ,trail:-,extends:>,precedes:<
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set foldmethod=indent
set foldnestmax=2
set foldlevelstart=10
nnoremap <space> za
vnoremap <space> zf
" terminal mode
tnoremap <Esc> <C-\><C-n>
" just be a text editor
let g:loaded_python_provider = 0 " disable py2
let g:python3_host_prog = '/usr/bin/python3'
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
highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
set matchtime=0
" highlight cursorline in insert mode
highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
autocmd InsertEnter * set cursorline
autocmd InsertLeave * set nocursorline
" UltiSnips config
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$HOME.'/Documents/snippets']
let g:ultisnips_python_style = 'sphinx'
" tagbar
nmap <F8> :TagbarToggle<CR>
let g:tagbar_compact = 1
let g:tagbar_show_linenumbers = 1
let g:tagbar_width = max([25, winwidth(0) / 4])
