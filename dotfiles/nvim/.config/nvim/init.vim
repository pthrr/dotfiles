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
    call dein#add('phaazon/hop.nvim')
    call dein#add('numToStr/Comment.nvim')
    call dein#add('nvim-lua/plenary.nvim')
    call dein#add('folke/todo-comments.nvim', { 'depends': 'plenary' })
    call dein#add('dense-analysis/ale')
    call dein#add('nvim-treesitter/nvim-treesitter')
    call dein#add('nvim-orgmode/orgmode', { 'depends': 'nvim-treesitter' })
    call dein#add('rust-lang/rust.vim')
    call dein#add('cespare/vim-toml')
    call dein#add('LnL7/vim-nix')
    call dein#add('raimon49/requirements.txt.vim')
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
set laststatus=2
set statusline=
set statusline+=%-4.(%n%)
set statusline+=%f\ %h%m%r
set statusline+=%=
set statusline+=%-14.(%l,%c%V%)
set statusline+=\ %P
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
let maplocalleader = "\\"
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
" orgmode
lua << EOF
  -- Load custom tree-sitter grammar for org filetype
  require('orgmode').setup_ts_grammar()

  -- Tree-sitter configuration
  require'nvim-treesitter.configs'.setup {
    -- If TS highlights are not enabled at all, or disabled via `disable` prop, highlighting will fallback to default Vim syntax highlighting
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = {'org'}, -- Required for spellcheck, some LaTex highlights and code block highlights that do not have ts grammar
    },

    ensure_installed = {'org'}, -- Or run :TSUpdate org
  }

  require('orgmode').setup({
    org_todo_keywords = { "TODO", "IN-PROGRESS", "WAITING", "|", "DONE", "CANCELED" },
    org_agenda_files = {'~/agenda/**/*'},
    org_default_notes_file = '~/org/refile.org',
  })
EOF
" hop
nmap <C-h> :HopWord<CR>
nmap <S-h> :HopWordCurrentLine<CR>
lua << EOF
  require("hop").setup {
    --keys = 'etovxqpdygfblzhckisuran',
    jump_on_sole_occurrence = true,
  }
EOF
" comment
lua << EOF
  require("Comment").setup {
    ---Add a space b/w comment and the line
    padding = true,
    ---Whether the cursor should stay at its position
    sticky = true,
    ---Lines to be ignored while (un)comment
    ignore = nil,
    ---LHS of toggle mappings in NORMAL mode
    toggler = {
      ---Line-comment toggle keymap
      line = 'gcc',
      ---Block-comment toggle keymap
      block = 'gbc',
    },
    ---LHS of operator-pending mappings in NORMAL and VISUAL mode
    opleader = {
      ---Line-comment keymap
      line = 'gc',
      ---Block-comment keymap
      block = 'gb',
    },
    ---LHS of extra mappings
    extra = {
      ---Add comment on the line above
      above = 'gcO',
      ---Add comment on the line below
      below = 'gco',
      ---Add comment at the end of line
      eol = 'gcA',
    },
    ---Enable keybindings
    ---NOTE: If given `false` then the plugin won't create any mappings
    mappings = {
      ---Operator-pending mapping; `gcc` `gbc` `gc[count]{motion}` `gb[count]{motion}`
      basic = true,
      ---Extra mapping; `gco`, `gcO`, `gcA`
      extra = true,
      ---Extended mapping; `g>` `g<` `g>[count]{motion}` `g<[count]{motion}`
      extended = false,
    },
    ---Function to call before (un)comment
    pre_hook = nil,
    ---Function to call after (un)comment
    post_hook = nil,
  }
EOF
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
" TODO: add mypy
let g:ale_linters = {
    \ 'python': ['pylint'],
    \ 'cpp': ['clangtidy'],
    \ 'c': ['clangtidy'],
    \ 'xml': ['xmllint'],
    \ 'rust': ['analyzer'],
    \ 'nix': ['statix'],
    \ 'json': ['jq'],
    \ 'sh': ['shell'],
    \}
let g:ale_fixers = {
    \ 'python': ['black', 'isort'],
    \ 'cpp': ['clang-format'],
    \ 'c': ['clang-format'],
    \ 'xml': ['xmllint'],
    \ 'rust': ['rustfmt'],
    \ 'json': ['fixjson'],
    \ 'sh': ['shfmt'],
    \ '*': ['remove_trailing_lines', 'trim_whitespace'],
    \}
let g:ale_python_black_options = '--line-length 79'
let g:ale_python_isort_options = '--profile black --atomic --line-length 79'
let g:ale_cpp_clangformat_style_option = 'chromium'
let g:ale_c_clangformat_style_option = 'webkit'
let g:ale_xml_xmllint_indentsize = 4
let g:ale_sh_shfmt_options = '-i 4 -ci'
let g:ale_rust_cargo_use_check = 1
let g:ale_rust_cargo_check_tests = 1
let g:ale_rust_cargo_check_examples = 1
let g:ale_fix_on_save = 0
let g:ale_lint_on_enter = 1
let g:ale_lint_on_filetype_changed = 0
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_text_changed = 0
let g:ale_lint_on_save = 1
let g:ale_sign_column_always = 1
