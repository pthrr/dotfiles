lua << EOF
  local version_file = io.open("/proc/version", "rb")
  if version_file ~= nil and string.find(version_file:read("*a"), "microsoft") then
    version_file:close()
    vim.g.wsl = true
  end
EOF
if !exists('g:vscode')
let $CACHE = expand($XDG_CACHE_HOME)
if !isdirectory($CACHE)
    call mkdir($CACHE, 'p')
endif
if &runtimepath !~# '/dein.vim'
    let s:dein_dir = fnamemodify('dein.vim', ':p')
    if !isdirectory(s:dein_dir)
        let s:dein_dir = $CACHE . '/dein/repos/github.com/Shougo/dein.vim'
        if !isdirectory(s:dein_dir)
            execute '!git clone https://github.com/Shougo/dein.vim' s:dein_dir
        endif
    endif
    execute 'set runtimepath^=' . substitute(
        \ fnamemodify(s:dein_dir, ':p') , '[/\\]$', '', '')
endif
if dein#load_state(s:dein_dir)
    call dein#begin(s:dein_dir)
    if exists('g:wsl')
        call dein#add('nvim-treesitter/nvim-treesitter')
        call dein#add('nvim-lua/plenary.nvim')
        call dein#add('nvim-telescope/telescope.nvim')
        call dein#add('neoclide/coc.nvim', { 'merged': 0, 'rev': 'release' })
        let g:coc_global_extensions = ['coc-pyright', 'coc-rust-analyzer']
    endif
    call dein#add('overcache/NeoSolarized')
    call dein#add('sirver/ultisnips')
    call dein#add('liuchengxu/vista.vim')
    call dein#add('numToStr/Comment.nvim')
    call dein#add('tpope/vim-repeat')
    call dein#add('ggandor/leap.nvim', { 'depends': 'vim-repeat' })
    call dein#end()
    call dein#save_state()
endif
if dein#check_install()
    call dein#install()
endif
set termguicolors
set background=dark
colorscheme NeoSolarized
endif " if not vscode
" generic
if !exists('g:vscode')
syntax off
else
syntax on
endif
filetype plugin indent on
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,latin1,cp1252,default
set nobomb
set nobackup
set nowritebackup
set noswapfile
set noshowmode
set novisualbell
set noerrorbells
set undofile
set undolevels=1000
set undoreload=10000
set timeout
set ttimeout
set timeoutlen=300
set ttimeoutlen=50
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
set updatetime=300
set signcolumn=yes
set autoread
set lazyredraw
set title
set hidden
set path+=**
set wildmenu
set wildmode=list:longest,full
set wildignore+=.git,.hg,.svn
set wildignore+=*.aux,*.out,*.toc
set wildignore+=*.o,*.obj,*.exe,*.dll,*.manifest,*.rbc,*.class
set wildignore+=*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp
set wildignore+=*.avi,*.divx,*.mp4,*.webm,*.mov,*.m2ts,*.mkv,*.vob,*.mpg,*.mpeg
set wildignore+=*.mp3,*.oga,*.ogg,*.wav,*.flac
set wildignore+=*.eot,*.otf,*.ttf,*.woff
set wildignore+=*.doc,*.pdf,*.cbr,*.cbz
set wildignore+=*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.kgb
set wildignore+=*.swp,.lock,.DS_Store,._*
set statusline=
set statusline+=%-4.(%n%)
set statusline+=%f\ %h%m%r
set statusline+=%=
set statusline+=%-14.(%l,%c%V%)
set statusline+=\ %P
set colorcolumn=80,110
set clipboard=unnamedplus
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()
set foldnestmax=2
set foldlevelstart=10
" automatically save view, load with :loadview
autocmd BufWinLeave *.* mkview
" highlight cursorline
autocmd BufEnter * setlocal cursorline
autocmd BufLeave * setlocal nocursorline
autocmd InsertEnter * highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
autocmd InsertLeave * highlight cursorline guibg=#073642 guifg=none gui=none ctermbg=none ctermfg=none cterm=none
" no rel nums on non focused buffer
autocmd BufEnter,FocusGained,InsertLeave * setlocal relativenumber
autocmd BufLeave,FocusLost,InsertEnter * setlocal norelativenumber
" show matching brackets
set showmatch
set matchtime=0
highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
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
" configure clipboard if inside WSL
" https://github.com/memoryInject/wsl-clipboard
if exists('g:wsl')
lua << EOF
  vim.g.clipboard = {
    name = "wsl-clipboard",
    copy = {
      ["+"] = "wcopy",
      ["*"] = "wcopy"
    },
    paste = {
      ["+"] = "wpaste",
      ["*"] = "wpaste"
    },
    cache_enabled = true
  }
EOF
endif
if !exists('g:vscode')
" tree-sitter
lua << EOF
  require'nvim-treesitter.configs'.setup {
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  }
EOF
" ultisnips
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$XDG_TEMPLATES_DIR.'/snippets']
" vista
nmap <F8> :Vista!!<CR>
let g:vista_default_executive = 'coc'
let g:vista_sidebar_width = max([80, winwidth(0) / 4])
let g:vista_echo_cursor = 0
let g:vista_echo_cursor_startegy = 'scroll'
let g:vista_stay_on_open = 0
let g:vista_blink = [0, 0]
let g:vista_top_level_blink = [0, 0]
let g:vista_highlight_whole_line = 1
let g:vista#renderer#enable_icon = 1
let g:vista#renderer#icons = {
    \ "function": "f",
    \ "method": "m",
    \ "variable": "v",
    \ "class": "c",
    \ }
" coc
nmap <F2> <Plug>(coc-rename)
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
" leap
lua << EOF
  require('leap').set_default_keymaps()
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
endif " if not vscode
