" OS dependent
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
    call dein#add('overcache/NeoSolarized')
    call dein#add('preservim/tagbar')
    call dein#add('jreybert/vimagit')
    call dein#add('nvim-lua/plenary.nvim')
    call dein#add('folke/todo-comments.nvim', { 'depends': 'plenary' })
    call dein#add('hoschi/yode-nvim', { 'depends': 'plenary' })
    call dein#add('ludovicchabant/vim-gutentags')
    call dein#add('dense-analysis/ale')
    call dein#end()
    call dein#save_state()
endif
if dein#check_install()
    call dein#install()
endif
" Let's save undo info!
if !isdirectory($HOME."/.config")
    call mkdir($HOME."/.config", "", 0770)
endif
if !isdirectory($HOME."/.config/nvim")
    call mkdir($HOME."/.config/nvim", "", 0770)
endif
if !isdirectory($HOME."/.config/nvim/undo")
    call mkdir($HOME."/.config/nvim/undo", "", 0700)
endif
if !isdirectory($HOME."/.config/nvim/tags")
    call mkdir($HOME."/.config/nvim/tags", "", 0700)
endif
set termguicolors
set background=dark
colorscheme NeoSolarized
" disable py2
let g:loaded_python_provider = 0
let g:python3_host_prog = '/usr/bin/python3'
" generic
syntax on
filetype plugin indent on
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,latin1,cp1252,default
set nobomb
set nobackup
set noswapfile
set nowritebackup
set undodir=~/.config/nvim/undo
set undofile
set undolevels=1000
set undoreload=10000
set complete-=i
set ttimeout
set ttimeoutlen=100
set scrolloff=1
set sidescrolloff=5
set list
set listchars=tab:\›\ ,trail:-,extends:>,precedes:<,nbsp:+
set shell=/usr/bin/env\ bash
set history=1000
set tabpagemax=50
set splitbelow
set splitright
set number
set relativenumber
set nowrap
set autoread
set hlsearch
set incsearch
set title
set hidden
set noshowmode
set novisualbell
set noerrorbells
set statusline=
set statusline +=%m\               "modified flag
set statusline +=%n\               "buffer number
set statusline +=%f\               "relative path
set statusline +=%=%{&fenc}\       "file encoding
set statusline +=%{&ff}\           "file format
set statusline +=%{&filetype}\     "file type
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
set lazyredraw
" automatically save view, load with :loadview
autocmd BufWinLeave *.* mkview
" show matching brackets
set showmatch
highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
set matchtime=0
" highlight cursorline in insert mode
highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
autocmd InsertEnter * set cursorline
autocmd InsertLeave * set nocursorline
" change leader key
let mapleader = "'"
" map folding
nnoremap <space> za
vnoremap <space> zf
" map ESC
inoremap jk <ESC>
tnoremap jk <C-\><C-n>
" paste multiple times
xnoremap p pgvy
" delete without yanking
nnoremap <leader>d "_d
vnoremap <leader>d "_d
" replace currently selected text without yanking it
vnoremap <leader>p "_dP
" todo-comments
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
nmap <F5> :TodoQuickFix cwd=.<CR>
" ultisnips
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$HOME.'/Documents/snippets']
let g:ultisnips_python_style = 'sphinx'
" tagbar
nmap <F8> :TagbarToggle<CR>
let g:tagbar_compact = 1
let g:tagbar_sort = 1
let g:tagbar_foldlevel = 1
let g:tagbar_show_linenumbers = 1
let g:tagbar_width = max([80, winwidth(0) / 4])
" magit
let g:magit_default_fold_level = 0
nmap <F7> :MagitOnly<CR>
" c/cpp syntax highlighting options
let g:cpp_member_highlight = 1
let g:cpp_attributes_highlight = 1
" yode
lua require('yode-nvim').setup({})
map <Leader>yc :YodeCreateSeditorFloating<CR>
map <Leader>yr :YodeCreateSeditorReplace<CR>
nmap <Leader>bd :YodeBufferDelete<cr>
imap <Leader>bd <esc>:YodeBufferDelete<cr>
map <C-W>r :YodeLayoutShiftWinDown<CR>
map <C-W>R :YodeLayoutShiftWinUp<CR>
map <C-W>J :YodeLayoutShiftWinBottom<CR>
map <C-W>K :YodeLayoutShiftWinTop<CR>
" gutentags
map oo <C-]>
map OO <C-T>
map <C-O> g]
set tags=~/.config/nvim/tags
let g:gutentags_modules = ['ctags']
let g:gutentags_add_default_project_roots = 0
let g:gutentags_project_root = ['requirements.txt', '.git', 'README.md']
let g:gutentags_cache_dir='~/.config/nvim/tags'
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
let g:ale_cpp_clangformat_style_option = 'google'
let g:ale_c_clangformat_style_option = 'google'
let g:ale_cpp_clangtidy_checks = [
    \ 'bugprone-*',
    \ 'cppcoreguidelines-*',
    \ 'google-*',
    \ 'modernize-*',
    \ 'misc-*',
    \ 'performance-*',
    \ 'readability-*',
    \]
let g:ale_fix_on_save = 0
let g:ale_lint_on_enter = 1
let g:ale_lint_on_filetype_changed = 0
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_text_changed = 0
let g:ale_lint_on_save = 1
