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
    call dein#add('ludovicchabant/vim-gutentags')
    call dein#add('junegunn/fzf', { 'build': './install', 'merged': 0 })
    call dein#add('junegunn/fzf.vim', { 'depends': 'fzf' })
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
set background=dark
set termguicolors
colorscheme NeoSolarized
" just be a text editor
let g:loaded_python_provider = 0 " disable py2
let g:python3_host_prog = '/usr/bin/python3'
" generic
syntax on
filetype plugin indent on
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,utf-16,cp1252,default,latin1
set nobomb
set nobackup
set noswapfile
set nowritebackup
set undodir=~/.config/nvim/undo
set undofile
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
set statusline +=\ %n\             "buffer number
set statusline +=%{&ff}            "file format
set statusline +=%y                "file type
set statusline +=\ %<%F            "full path
set statusline +=%m                "modified flag
set statusline +=\ %{&fenc}        "file encoding
set statusline +=%=%5l             "current line
set statusline +=/%L               "total lines
set statusline +=%4v\              "virtual column number
set statusline +=0x%04B\           "character under cursor
set path=$PWD/**
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
set list listchars=tab:\›\ ,trail:-,extends:>,precedes:<
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set foldmethod=indent
set foldnestmax=2
set foldlevelstart=10
" map folding
nnoremap <space> za
vnoremap <space> zf
" map ESC
inoremap jk <ESC>
tnoremap jk <C-\><C-n>
" change leader key
let mapleader = "'"
" automatically save view, load with :loadview
autocmd BufWinLeave *.* mkview
" paste multiple times
xnoremap p pgvy
" delete without yanking
nnoremap <leader>d "_d
vnoremap <leader>d "_d
" replace currently selected text with default register
" without yanking it
vnoremap <leader>p "_dP
" show matching brackets
set showmatch
highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
set matchtime=0
" highlight cursorline in insert mode
highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
autocmd InsertEnter * set cursorline
autocmd InsertLeave * set nocursorline
" todo-comments
lua << EOF
  require("todo-comments").setup {
    highlight = {
        before = "", -- "fg" or "bg" or empty
        keyword = "fg", -- "fg", "bg", "wide" or empty
        after = "", -- "fg" or "bg" or empty
        pattern = [[.*<(KEYWORDS)\s*]],
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
    pattern = [[\b(KEYWORDS)]],
  }
EOF
nmap <F5> :TodoQuickFix cwd=.<CR>
" fzf
set grepprg=rg\ --vimgrep\ --smart-case\ --follow
nnoremap <silent> <C-f> :Files<CR>
nnoremap <silent> <Leader>f :Ag<CR>
nnoremap <silent> <Leader>b :Buffers<CR>
nnoremap <silent> <Leader>/ :BLines<CR>
nnoremap <silent> <Leader>' :Marks<CR>
nnoremap <silent> <Leader>g :Commits<CR>
nnoremap <silent> <Leader>H :Helptags<CR>
nnoremap <silent> <Leader>hh :History<CR>
nnoremap <silent> <Leader>h: :History:<CR>
nnoremap <silent> <Leader>h/ :History/<CR> 
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
" gutentags
map oo <C-]>
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
      \ '*sites/*/files/*',
      \ 'bin',
      \ 'node_modules',
      \ 'bower_components',
      \ 'cache',
      \ 'compiled',
      \ 'docs',
      \ '*/venv/*', '*/.venv/*',
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
