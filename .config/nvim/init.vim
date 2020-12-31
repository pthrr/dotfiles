" Auto reload .vimrc on save
autocmd BufWritePost $MYVIMRC source $MYVIMRC

" Bootstrap dein and install plugins
let s:settings = {}
let s:settings.is_win = has('win32') || has('win64')
if s:settings.is_win
    set shellslash
endif

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

    call dein#add('itchyny/lightline.vim')
    call dein#add('mengelbrecht/lightline-bufferline')
    call dein#add('iCyMind/NeoSolarized')
    call dein#add('lervag/vimtex')
    call dein#add('sirver/ultisnips')

    call dein#end()
    call dein#save_state()
endif

if dein#check_install()
    call dein#install()
endif

" Colorscheme
if has('termguicolors')
  set termguicolors
endif

set background=dark
colorscheme NeoSolarized

" Syntax highlighting
syntax on
filetype plugin indent on

" Encoding
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8

" Center cursor
set number " Show line numbers
set rnu " Relative Numbering
set so=999 " Center cursor

" Highlight match
highlight clear cursorline
highlight cursorline gui=underline cterm=underline
autocmd InsertEnter * set cursorline
autocmd InsertLeave * set nocursorline

" Hide - INSERT -
set noshowmode

" Modify pane
set colorcolumn=80
set tw=79 " Autoformat to 79 chars per row
set nowrap " Dont't auto wrap on load
set fo-=t " Dont't auto wrap text when typing
set list listchars=tab:\›\ ,trail:-,extends:>,precedes:<
set linespace=0

" More natural splits
set splitbelow " Horizontal split below current
set splitright

" Disable spk noise
set vb
set t_vb=
set novisualbell
set noerrorbells

" Highlight search
set hlsearch

" Tabs are 8 spaces
set tabstop=8
set softtabstop=8
set shiftwidth=8
"set shiftround
set expandtab

set autoindent
set smartindent

" Show matching brackets
set showmatch
hi MatchParen guibg=none guifg=magenta gui=bold
set matchtime=0

" Mouse support
set mouse=a

" Enable code folding (optimized for Python)
set foldmethod=syntax
set foldnestmax=2
set viewoptions-=options " dont save path with view
autocmd BufWinLeave *.* mkview
autocmd BufWinEnter *.* silent loadview

" Mapping for fast open/close fold
" TIP: zj,zk to move between folds
nnoremap <space> za

" Disable Swap Files
set nobackup
set nowritebackup
set noswapfile

" allow buffer switching without saving
set hidden

" Set <Leader> key
let mapleader = ","
let maplocalleader = ";"

" Quick quit
nnoremap <Leader>q :q<CR>

" Quick save
nnoremap <Leader>w :w<CR>

" Copy to clipboard
set clipboard=unnamedplus
" paste multiple times
xnoremap p pgvy

" Term ESC
tnoremap <Esc> <C-\><C-n>

" ALT+hjkl for moving between windows
tnoremap <A-h> <C-\><C-N><C-w>h
tnoremap <A-j> <C-\><C-N><C-w>j
tnoremap <A-k> <C-\><C-N><C-w>k
tnoremap <A-l> <C-\><C-N><C-w>l
inoremap <A-h> <C-\><C-N><C-w>h
inoremap <A-j> <C-\><C-N><C-w>j
inoremap <A-k> <C-\><C-N><C-w>k
inoremap <A-l> <C-\><C-N><C-w>l
nnoremap <A-h> <C-w>h
nnoremap <A-j> <C-w>j
nnoremap <A-k> <C-w>k
nnoremap <A-l> <C-w>l

" comprehensive movement
tnoremap <S-PageUp> <C-\><C-O>5k
tnoremap <S-PageDown> <C-\><C-O>5j
inoremap <S-PageUp> <C-\><C-O>5k
inoremap <S-PageDown> <C-\><C-O>5j
xnoremap <S-PageUp> 5k
xnoremap <S-PageDown> 5j
nnoremap <S-PageUp> 5k
nnoremap <S-PageDown> 5j
tnoremap <PageUp> <C-\><C-O>40k
tnoremap <PageDown> <C-\><C-O>40j
inoremap <PageUp> <C-\><C-O>40k
inoremap <PageDown> <C-\><C-O>40j
xnoremap <PageUp> 40k
xnoremap <PageDown> 40j
nnoremap <PageUp> 40k
nnoremap <PageDown> 40j

" --- PLUGINS -----------------------------------------------------------------
set path=$PWD/**
set wildmenu
set wildmode=list:longest,full

" python support
let g:python3_host_prog = '/usr/bin/python3'

" vimtex
let g:vimtex_compiler_progname = 'nvr'
let g:tex_flavor = 'latex'
let g:vimtex_view_method = 'zathura'
let g:vimtex_quickfix_mode = 0
set conceallevel=1 " conceal irrelevant synatx
let g:tex_conceal = 'abdmg'
let g:latex_view_general_viewer = 'zathura'

" ultisnips
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$HOME.'/Documents/LaTex/UltiSnips_snippets']

" install fzf
" If installed using git
set rtp+=~/.fzf

" lightline
set showtabline=2 " force tabline

let g:lightline = { 'colorscheme': 'solarized',}
let g:lightline#bufferline#show_number  = 1
let g:lightline#bufferline#shorten_path = 1
let g:lightline#bufferline#unnamed      = '[No Name]'
let g:lightline.tabline          = {'left': [['buffers']], 'right': []}
let g:lightline.component_expand = {'buffers': 'lightline#bufferline#buffers'}
let g:lightline.component_type   = {'buffers': 'tabsel'}
