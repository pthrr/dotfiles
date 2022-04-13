" OS dependent
let s:settings = {}
let s:settings.cache_dir = expand($XDG_DATA_HOME.'/nvim/cache')
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
    call dein#add('overcache/NeoSolarized')
    call dein#add('sirver/ultisnips')
    call dein#add('preservim/tagbar')
    call dein#add('ludovicchabant/vim-gutentags')
    call dein#add('nvim-lua/plenary.nvim')
    call dein#add('folke/todo-comments.nvim', { 'depends': 'plenary' })
    call dein#add('dense-analysis/ale')
    call dein#end()
    call dein#save_state()
endif
if dein#check_install()
    call dein#install()
endif
set termguicolors
set background=dark
colorscheme NeoSolarized
" generic
syntax on
filetype plugin indent on
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,latin1,cp1252,default
set nobomb
set nobackup
set noswapfile
set nowritebackup
set noshowmode
set novisualbell
set noerrorbells
set undofile
set undolevels=1000
set undoreload=10000
set complete=.,w,b,u,t
set scrolloff=1
set sidescrolloff=5
set list
set listchars=tab:\›\ ,trail:-,extends:>,precedes:<,nbsp:+
set shell=/usr/bin/env\ bash
set history=1000
set splitbelow
set splitright
set number
set relativenumber
set nowrap
set hlsearch
set incsearch
set autoread
set lazyredraw
set title
set hidden
set path+=**
set wildmenu
set wildmode=list:longest,full
set wildignore +=.git,.hg,.svn
set wildignore +=*.aux,*.out,*.toc
set wildignore +=*.o,*.obj,*.exe,*.dll,*.manifest,*.rbc,*.class
set wildignore +=*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp
set wildignore +=*.avi,*.divx,*.mp4,*.webm,*.mov,*.m2ts,*.mkv,*.vob,*.mpg,*.mpeg
set wildignore +=*.mp3,*.oga,*.ogg,*.wav,*.flac
set wildignore +=*.eot,*.otf,*.ttf,*.woff
set wildignore +=*.doc,*.pdf,*.cbr,*.cbz
set wildignore +=*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.kgb
set wildignore +=*.swp,.lock,.DS_Store,._*
set colorcolumn=80
set clipboard=unnamedplus
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set foldmethod=indent
set foldnestmax=2
set foldlevelstart=10
" automatically save view, load with :loadview
autocmd BufWinLeave *.* mkview
" show matching brackets
set showmatch
set matchtime=0
highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
" highlight cursorline
autocmd BufEnter * setlocal cursorline
autocmd BufLeave * setlocal nocursorline
autocmd InsertEnter * highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
autocmd InsertLeave * highlight cursorline guibg=#073642 guifg=none gui=none ctermbg=none ctermfg=none cterm=none
" c/cpp syntax highlighting options
let g:cpp_member_highlight = 1
let g:cpp_attributes_highlight = 1
" change leader key
let mapleader = "'"
" map ESC
inoremap jk <ESC>
tnoremap jk <C-\><C-n>
" move among buffers with CTRL
map <C-J> :bnext<CR>
map <C-K> :bprev<CR>
" map folding
vnoremap <space> zf
nnoremap <space> za
" paste multiple times
xnoremap <leader>p "0p
nnoremap <leader>p "0p
" delete without yanking
vnoremap <leader>d "_d
nnoremap <leader>d "_d
" replace currently selected text without yanking it
vnoremap <leader>p "_dP
" todo-comments
nmap <F5> :TodoQuickFix cwd=.<CR>
let ver = split(matchstr(execute('version'), 'NVIM v\zs[^\n]*'), "\\.")
if index(["5","6","7","8","9"], ver[1]) >= 0
lua << EOF
  require("todo-comments").setup {
    highlight = {
        before = "", -- "fg" or "bg" or empty
        keyword = "fg", -- "fg", "bg", "wide" or empty
        after = "", -- "fg" or "bg" or empty
        pattern = [[.*<(KEYWORDS)\s*:]],
        comments_only = true,
        max_line_len = 400,
        exclude = {},
    },
    keywords = {
        FIXME = { icon = "! ", color = "error" },
        TODO = { icon = "+ ", color = "info" },
        HACK = { icon = "* ", color = "warning" },
        WARN = { icon = "# ", color = "warning" },
        PERF = { icon = "$ ", color = "default" },
        NOTE = { icon = "> ", color = "hint" },
    },
    merge_keywords = false,
    pattern = [[\b(KEYWORDS):]],
  }
EOF
endif
" ultisnips
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$XDG_DOCUMENTS_DIR.'/snippets']
" tagbar
nmap <F8> :TagbarToggle<CR>
let g:tagbar_compact = 1
let g:tagbar_sort = 1
let g:tagbar_foldlevel = 1
let g:tagbar_show_linenumbers = 1
let g:tagbar_width = max([80, winwidth(0) / 4])
" gutentags
map oo <C-]>
map OO <C-T>
map <C-O> g]
set tags=$XDG_DATA_HOME.'/nvim/cache/tags'
let g:gutentags_modules = ['ctags']
let g:gutentags_add_default_project_roots = 0
let g:gutentags_project_root = ['requirements.txt', '.git', 'README.md']
let g:gutentags_cache_dir=$XDG_DATA_HOME.'/nvim/cache/tags'
let g:gutentags_generate_on_new = 1
let g:gutentags_generate_on_missing = 1
let g:gutentags_generate_on_write = 1
let g:gutentags_generate_on_empty_buffer = 0
let g:gutentags_ctags_extra_args = [
      \ '--tag-relative=yes',
      \ '--fields=+ailmnS',
      \ ]
let g:gutentags_ctags_exclude = [
      \ '*.git', '*.svg', '*.hg',
      \ '*/tests/*',
      \ 'build',
      \ 'dist',
      \ '*/venv/*', '*/.venv/*',
      \ '*sites/*/files/*',
      \ 'bin',
      \ 'node_modules',
      \ 'bower_components',
      \ 'cache',
      \ 'compiled',
      \ 'docs',
      \ 'example',
      \ 'bundle',
      \ 'vendor',
      \ '*.md',
      \ '*-lock.json',
      \ '*.lock',
      \ '*bundle*.js',
      \ '*build*.js',
      \ '.*rc*',
      \ '*.json',
      \ '*.min.*',
      \ '*.map',
      \ '*.bak',
      \ '*.zip',
      \ '*.pyc',
      \ '*.class',
      \ '*.sln',
      \ '*.Master',
      \ '*.csproj',
      \ '*.tmp',
      \ '*.csproj.user',
      \ '*.cache',
      \ '*.pdb',
      \ 'tags*',
      \ 'cscope.*',
      \ '*.css',
      \ '*.less',
      \ '*.scss',
      \ '*.exe', '*.dll',
      \ '*.mp3', '*.ogg', '*.flac',
      \ '*.swp', '*.swo',
      \ '*.bmp', '*.gif', '*.ico', '*.jpg', '*.png',
      \ '*.rar', '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
      \ '*.pdf', '*.doc', '*.docx', '*.ppt', '*.pptx',
      \ ]
" ale
nmap <F6> :ALEFix<CR>
let g:ale_linters = {
    \ 'python': ['pylint'],
    \ 'cpp': ['clangtidy'],
    \ 'c': ['clangtidy'],
    \}
let g:ale_fixers = {
    \ 'python': ['black', 'isort'],
    \ 'cpp': ['clang-format'],
    \ 'c': ['clang-format'],
    \ '*': ['remove_trailing_lines', 'trim_whitespace'],
    \}
let g:ale_python_black_options = '--line-length 79'
let g:ale_python_isort_options = '--profile black --atomic --line-length 79'
let g:ale_cpp_clangformat_style_option = 'chromium'
let g:ale_c_clangformat_style_option = 'webkit'
let g:ale_fix_on_save = 0
let g:ale_lint_on_enter = 1
let g:ale_lint_on_filetype_changed = 0
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_text_changed = 0
let g:ale_lint_on_save = 1
