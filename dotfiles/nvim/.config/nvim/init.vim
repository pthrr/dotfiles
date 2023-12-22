lua << EOF
  local version_file = io.open("/proc/version", "rb")
  if version_file ~= nil and string.find(version_file:read("*a"), "microsoft") then
    version_file:close()
    vim.g.wsl = true
  end
EOF
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
        call dein#add('nvim-treesitter/nvim-treesitter-textobjects')
        call dein#add('nvim-lua/plenary.nvim')
        call dein#add('nvim-telescope/telescope.nvim')
    endif
    " common
    call dein#add('overcache/NeoSolarized')
    call dein#add('neoclide/coc.nvim', { 'merged': 0, 'rev': 'release' })
    call dein#add('liuchengxu/vista.vim')
    call dein#add('TimUntersberger/neogit', { 'depends': 'plenary.nvim' })
    call dein#add('sirver/ultisnips')
    call dein#add('tpope/vim-commentary')
    call dein#add("antoinemadec/FixCursorHold.nvim")
    call dein#add('nvim-neotest/neotest', { 'depends': ['plenary.nvim', 'nvim-treesitter', 'FixCursorHold.nvim'] })
    " Typescript/Javascript
    " Typst
    call dein#add('kaarmu/typst.vim')
    " Quint
    " Python
    call dein#add('nvim-neotest/neotest-python', { 'depends': ['neotest', 'plenary.nvim', 'nvim-treesitter', 'FixCursorHold.nvim'] })
    " Zig
    call dein#add('ziglang/zig.vim')
    call dein#add('lawrence-laz/neotest-zig', { 'depends': ['neotest', 'plenary.nvim', 'nvim-treesitter', 'FixCursorHold.nvim'] })
    " C++
    call dein#add('sakhnik/nvim-gdb')
    call dein#add('MunifTanjim/nui.nvim')
    call dein#add('madskjeldgaard/cppman.nvim', { 'depends': 'nui.nvim' })
    call dein#add('derekwyatt/vim-fswitch')
    call dein#add('KabbAmine/zeavim.vim')
    call dein#end()
    call dein#save_state()
endif
if dein#check_install()
    call dein#install()
endif
let g:coc_global_extensions = [
    \ 'coc-pyright',
    \ 'coc-zls',
    \ 'coc-cmake',
    \ 'coc-clangd',
    \ 'coc-sourcekit',
    \ 'coc-rust-analyzer',
    \ 'coc-tsserver',
    \ 'coc-tslint-plugin',
    \ 'coc-eslint',
    \ 'coc-prettier',
    \ 'coc-toml',
    \ 'coc-yaml',
    \ 'coc-xml',
    \ 'coc-json',
    \ 'coc-markdownlint',
    \ 'coc-sh',
    \ 'coc-docker',
    \ '@yaegassy/coc-ansible',
    \ 'coc-snippets'
    \ ]
set termguicolors
set background=dark
colorscheme NeoSolarized
syntax off
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
set ttyfast
set timeoutlen=600
set ttimeoutlen=0
set title
set hidden
set path+=**
set wildmode=list:longest,full
set wildignore+=.git,.hg,.svn
set wildignore+=*.aux,*.out,*.toc
set wildignore+=*.o,*.obj,*.exe,*.dll
set wildignore+=*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp
set wildignore+=*.avi,*.divx,*.mp4,*.webm,*.mov,*.mkv,*.vob,*.mpg,*.mpeg
set wildignore+=*.mp3,*.oga,*.ogg,*.wav,*.flac
set wildignore+=*.otf,*.ttf
set wildignore+=*.doc,*.pdf
set wildignore+=*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz
set wildignore+=*.swp,.lock,.DS_Store,._*
set statusline=
set statusline+=%-4.(%n%)
set statusline+=%f\ %h%m%r
set statusline+=%=
set statusline+=%-14.(%l,%c%V%)
set statusline+=\ %P
set colorcolumn=80,110
set clipboard+=unnamedplus
if exists('g:wsl')
  let g:clipboard = {
    \   'name': 'WslClipboard',
    \   'copy': {
    \      '+': 'clip.exe',
    \      '*': 'clip.exe',
    \    },
    \   'paste': {
    \      '+': 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    \      '*': 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    \   },
    \   'cache_enabled': 0,
    \ }
endif
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set foldmethod=indent
set nofoldenable
set foldnestmax=2
set foldlevelstart=10
" automatically save view, load with :loadview
autocmd BufWinLeave *.* mkview
" save session
nnoremap <Leader>sa :mksession! .session.vim<CR>
vnoremap <Leader>sa <Esc>:mksession! .session.vim<CR>v
nnoremap <Leader>so :source .session.vim<CR>
vnoremap <Leader>so <Esc>:source .session.vim<CR>v
" highlight cursorline
autocmd BufEnter * setlocal cursorline
autocmd BufLeave * setlocal nocursorline
autocmd InsertEnter * highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
autocmd InsertLeave * highlight cursorline guibg=#073642 guifg=none gui=none ctermbg=none ctermfg=none cterm=none
" no rel nums on non focused buffer
autocmd BufEnter,FocusGained,InsertLeave * setlocal relativenumber
autocmd BufLeave,FocusLost,InsertEnter * setlocal norelativenumber
" remove trailing white space at save
lua << EOF
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})
EOF
" show matching brackets
highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
" change leader key
let mapleader = "'"
let maplocalleader = "\\"
" map ESC
inoremap jk <ESC>
tnoremap jk <C-\><C-n>
tnoremap <Esc> <C-\><C-n>
" lua << EOF
" -- New tab
" keymap.set("n", "te", ":tabedit")
" keymap.set("n", "<tab>", ":tabnext<Return>", opts)
" keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)
" -- Split window
" keymap.set("n", "ss", ":split<Return>", opts)
" keymap.set("n", "sv", ":vsplit<Return>", opts)
" -- Move window
" keymap.set("n", "sh", "<C-w>h")
" keymap.set("n", "sk", "<C-w>k")
" keymap.set("n", "sj", "<C-w>j")
" keymap.set("n", "sl", "<C-w>l")
" EOF
" Split window
nmap ss :split<Return><C-w>w
nmap sv :vsplit<Return><C-w>w
" Move window
map sh <C-w>h
map sk <C-w>k
map sj <C-w>j
map sl <C-w>l
" Switch tab
nmap <S-Tab> :tabprev<Return>
nmap <Tab> :tabnext<Return>
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
" vim-fswitch
au BufEnter *.h  let b:fswitchdst = "c,cc,cpp" | let b:fswitchlocs = 'reg:|include.*|src/**|'
au BufEnter *.c  let b:fswitchdst = "h"
au BufEnter *.cpp  let b:fswitchdst = "h,hh,hpp"
nnoremap <silent> <A-o> :FSHere<cr>
nnoremap <silent> <localleader>oh :FSSplitLeft<cr>
nnoremap <silent> <localleader>oj :FSSplitBelow<cr>
nnoremap <silent> <localleader>ok :FSSplitAbove<cr>
nnoremap <silent> <localleader>ol :FSSplitRight<cr>
" zeal
nmap <leader>z <Plug>Zeavim
vmap <leader>z <Plug>ZVVisSelection
nmap gz <Plug>ZVOperator
nmap <leader><leader>z <Plug>ZVKeyDocset
if exists('g:wsl')
  let g:zv_zeal_executable = '/mnt/c/Program Files/Zeal/zeal.exe'
endif
" vista
nmap <F8> :Vista!!<CR>
let g:vista_default_executive = 'ctags'
let g:vista_sidebar_width = 50
let g:vista_echo_cursor = 0
let g:vista_echo_cursor_strategy = 'scroll'
let g:vista_enable_centering_jump = 1
let g:vista_close_on_jump = 0
let g:vista_close_on_fzf_select = 1
let g:vista_stay_on_open = 0
let g:vista_blink = [0, 0]
let g:vista_top_level_blink = [0, 0]
let g:vista_highlight_whole_line = 1
let g:vista#renderer#ctags = 'kind'
" ultisnips
let g:UltiSnipsExpandTrigger = '<tab>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:UltiSnipsSnippetDirectories = [$XDG_TEMPLATES_DIR.'/snippets']
" telescope
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>
" coc
nmap <leader>rn <Plug>(coc-rename)
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction
nnoremap <silent> K :call ShowDocumentation()<CR>
command! -nargs=0 Format :call CocActionAsync('format')
command! -nargs=? Fold :call CocAction('fold', <f-args>)
command! -nargs=0 OR :call CocActionAsync('runCommand', 'editor.action.organizeImport')
nmap <F6> :Format<CR>
nmap <F7> :OR<CR>
nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>
" cppman
lua << EOF
  local cppman = require"cppman"
  cppman.setup()
  -- Make a keymap to open the word under cursor in CPPman
  vim.keymap.set("n", "<leader>cm", function()
      cppman.open_cppman_for(vim.fn.expand("<cword>"))
  end)
  -- Open search box
  vim.keymap.set("n", "<leader>cc", function()
      cppman.input()
  end)
EOF
" neotest
lua << EOF
  require("neotest").setup({
    adapters = {
      require("neotest-zig"),
      require("neotest-python"),
    }
  })
EOF
" treesitter
if exists('g:wsl')
lua << EOF
  require'nvim-treesitter.configs'.setup {
    ensure_installed = {
        "c",
        "go",
        "zig",
        "cpp",
        "java",
        "rust",
        "lua",
        "python",
        "yaml",
        "toml",
        "json",
        "markdown",
        "bash",
        "cmake",
        "meson",
        "dockerfile",
        "git_rebase",
        "gitattributes",
        "gitcommit",
        "elixir",
        "eex",
        "heex",
        "haskell",
        "ocaml",
        "vim",
        "nix",
        "verilog",
        "clojure"
    },
    sync_install = false,
    auto_install = false,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  }
EOF
else
lua << EOF
  require'nvim-treesitter.configs'.setup {
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
    textobjects = {
      move = {
        enable = true,
        set_jumps = true, -- whether to set jumps in the jumplist
        goto_next_start = {
          ["]m"] = "@function.outer",
          ["]]"] = { query = "@class.outer", desc = "Next class start" },
          --
          -- You can use regex matching and/or pass a list in a "query" key to group multiple queires.
          ["]o"] = "@loop.*",
          -- ["]o"] = { query = { "@loop.inner", "@loop.outer" } }
          --
          -- You can pass a query group to use query from `queries/<lang>/<query_group>.scm file in your runtime path.
          -- Below example nvim-treesitter's `locals.scm` and `folds.scm`. They also provide highlights.scm and indent.scm.
          ["]s"] = { query = "@scope", query_group = "locals", desc = "Next scope" },
          ["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
        },
        goto_next_end = {
          ["]M"] = "@function.outer",
          ["]["] = "@class.outer",
        },
        goto_previous_start = {
          ["[m"] = "@function.outer",
          ["[["] = "@class.outer",
        },
        goto_previous_end = {
          ["[M"] = "@function.outer",
          ["[]"] = "@class.outer",
        },
        -- Below will go to either the start or the end, whichever is closer.
        -- Use if you want more granular movements
        -- Make it even more gradual by adding multiple queries and regex.
        goto_next = {
          ["]d"] = "@conditional.outer",
        },
        goto_previous = {
          ["[d"] = "@conditional.outer",
        }
      },
      select = {
        enable = true,

        -- Automatically jump forward to textobj, similar to targets.vim
        lookahead = true,

        keymaps = {
          -- You can use the capture groups defined in textobjects.scm
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          -- You can optionally set descriptions to the mappings (used in the desc parameter of
          -- nvim_buf_set_keymap) which plugins like which-key display
          ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
        },
        -- You can choose the select mode (default is charwise 'v')
        --
        -- Can also be a function which gets passed a table with the keys
        -- * query_string: eg '@function.inner'
        -- * method: eg 'v' or 'o'
        -- and should return the mode ('v', 'V', or '<c-v>') or a table
        -- mapping query_strings to modes.
        selection_modes = {
          ['@parameter.outer'] = 'v', -- charwise
          ['@function.outer'] = 'V', -- linewise
          ['@class.outer'] = '<c-v>', -- blockwise
        },
        -- If you set this to `true` (default is `false`) then any textobject is
        -- extended to include preceding or succeeding whitespace. Succeeding
        -- whitespace has priority in order to act similarly to eg the built-in
        -- `ap`.
        --
        -- Can also be a function which gets passed a table with the keys
        -- * query_string: eg '@function.inner'
        -- * selection_mode: eg 'v'
        -- and should return true of false
        include_surrounding_whitespace = true,
      },
    },
  }
EOF
endif
" treesitter-textobjects
lua <<EOF
  local ts_repeat_move = require "nvim-treesitter.textobjects.repeatable_move"

  -- Repeat movement with ; and ,
  -- ensure ; goes forward and , goes backward regardless of the last direction
  vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
  vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

  -- vim way: ; goes to the direction you were moving.
  -- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
  -- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

  -- Optionally, make builtin f, F, t, T also repeatable with ; and ,
  vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f)
  vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F)
  vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t)
  vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T)
EOF
" Quint
au BufRead,BufNewFile *.qnt setfiletype quint
au BufNewFile,BufReadPost *.qnt runtime syntax/quint.vim
" Typst
au BufRead,BufNewFile *.typ set syntax=typst
