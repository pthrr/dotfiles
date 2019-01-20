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

    call dein#add('iCyMind/NeoSolarized')
    call dein#add('vim-airline/vim-airline')
    call dein#add('kien/ctrlp.vim')
    call dein#add('scrooloose/nerdtree')
    call dein#add('lervag/vimtex')

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

set number " Show line numbers
set rnu " Relative Numbering
set so=999 " Center cursor

"autocmd InsertEnter,InsertLeave * set cul!
autocmd InsertEnter * set cul
autocmd InsertLeave * set nocul

set guicursor=n-v-c:block,i-ci-ve:block "ver25 ",r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175

"if has("autocmd")
"  au VimEnter,InsertLeave * silent execute '!echo -ne "\e[2 q"' | redraw!
"  au InsertEnter,InsertChange *
"    if v:insertmode == 'i' | 
"        silent execute '!echo -ne "\e[6 q"' | redraw! |
"    elseif v:insertmode == 'r' |
"        silent execute '!echo -ne "\e[4 q"' | redraw! |
"    endif
"  au VimLeave * silent execute '!echo -ne "\e[ q"' | redraw!
"endif

set colorcolumn=100
set tw=99 " Autoformat to 99 chars per row
set nowrap " Dont't auto wrap on load
set fo-=t " Dont't auto wrap text when typing
set list listchars=tab:\›\ ,trail:-,extends:>,precedes:< ",eol:¬
set linespace=0

" More natural splits
set splitbelow " Horizontal split below current
set splitright

" Disable spk noise
set vb
set t_vb=

" Highlight search
set hlsearch

" Tabs are 4 spaces
set tabstop=4
set softtabstop=4
set shiftwidth=4
set shiftround
set expandtab

" Show matching brackets
set showmatch
"hi MatchParen cterm=underline ctermbg=green ctermfg=blue
"hi MatchParen cterm=bold ctermbg=none ctermfg=magenta
hi MatchParen guibg=none guifg=magenta gui=bold
set matchtime=0

" Enable code folding (optimized for Python)
set foldmethod=indent
set foldnestmax=2

" Mapping for fast open/close fold
" TIP: zj,zk to move between folds
nnoremap <space> za

" Disable Swap Files
set nobackup
set nowritebackup
set noswapfile

" Set <Leader> key
let mapleader = ","
let maplocalleader = ";"

" Quick quit
nnoremap <Leader>q :q<CR>

" Quick save
nnoremap <Leader>w :w<CR>

" Ctags
"nnoremap <Leader>. :CtrlPTag<CR>

" Quick sort
"vnoremap <Leader>s :sort<CR>

" Copy to clipboard
set clipboard=unnamedplus

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

" --- PLUGINS -----------------------------------------------------------------
cd ~/

" vimtex
"let g:vimtex_latexmk_progname = 'nvr'
"let g:vimtex_view_method = 'evince'

" vim-airline setup
set laststatus=2
let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tabline#buffer_nr_show=1 " NUM Ctrl-6

" ctrlP setup
let g:ctrlp_max_height = 5
set wildignore+=*.pyc,*_build/*,*/coverage/*

" NERDtree mapping
map <C-n> :NERDTreeToggle<CR>
