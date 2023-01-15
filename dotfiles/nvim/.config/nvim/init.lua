-- HOME = os.getenv("HOME")
local function map(mode, shortcut, command)
    vim.api.nvim_set_keymap(mode, shortcut, command, { noremap = true, silent = true })
end
local function nmap(shortcut, command)
    map('n', shortcut, command)
end
local function imap(shortcut, command)
    map('i', shortcut, command)
end
local function is_vscode()
    if !exists('g:vscode')vim.g.vscode then
        return true
    end
    return false
end
local function is_wsl()
    local version_file = io.open("/proc/version", "rb")
    if version_file ~= nil and string.find(version_file:read("*a"), "microsoft") then
        version_file:close()
        return true
    end
    return false
end
if not is_vscode() then
local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end
local packer_bootstrap = ensure_packer()
return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'overcache/NeoSolarized'
    use 'sirver/ultisnips'
    use 'ludovicchabant/vim-gutentags'
    use 'preservim/tagbar'
    use 'dense-analysis/ale'
    -- use 'numToStr/Comment.nvim'
    use 'b3nj5m1n/kommentary'
    use 'tpope/vim-repeat'
    use { 'ggandor/leap.nvim', requires = { 'vim-repeat' } }
    if packer_bootstrap then
        require('packer').sync()
    end
end)
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.cmd('colorscheme NeoSolarized')
end -- if not is vscode
vim.cmd("syntax on")
vim.cmd("filetype plugin indent on")
vim.opt.encoding = "utf-8"
vim.opt.fileencodings = "ucs-bom,utf-8,latin1,cp1252,default"
vim.opt.bomb = false
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undolevels = 1000
vim.opt.undoreload = 10000
vim.opt.showmode = false
vim.opt.visualbell = false
vim.opt.errorbells = false
vim.opt.complete = ".,w,b,u,t"
vim.opt.completeopt = 'menuone,noselect'
vim.opt.scrolloff = 1
vim.opt.sidescrolloff = 5
vim.opt.list = true
vim.opt.listchars = "tab:\›\ ,trail:-,extends:>,precedes:<,nbsp:+"
vim.opt.shell="/usr/bin/env bash"
vim.opt.history = 1000
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.wo.number = true
vim.wo.relativenumber = true
vim.opt.wrap = false
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.smartcase = true
vim.opt.updatetime = 30
vim.opt.signcolumn = true
vim.opt.autoread = true
vim.opt.lazyredraw = true
vim.opt.title = true
vim.opt.hidden = true
vim.opt.path:append({ "**" })
vim.opt.wildmenu = true
vim.opt.wildmode = "list:longest,full"
vim.opt.wildignore:append({
    ".git,.hg,.svn",
    "*.aux,*.out,*.toc",
    "*.o,*.obj,*.exe,*.dll,*.manifest,*.rbc,*.class",
    "*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp",
    "*.avi,*.divx,*.mp4,*.webm,*.mov,*.m2ts,*.mkv,*.vob,*.mpg,*.mpeg",
    "*.mp3,*.oga,*.ogg,*.wav,*.flac",
    "*.eot,*.otf,*.ttf,*.woff",
    "*.doc,*.pdf,*.cbr,*.cbz",
    "*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.kgb",
    "*.swp,.lock,.DS_Store,._*",
})
-- vim.opt.laststatus = 2
vim.opt.statusline = 
-- set statusline+=%-4.(%n%)
-- set statusline+=%f\ %h%m%r
-- set statusline+=%=
-- set statusline+=%-14.(%l,%c%V%)
-- set statusline+=\ %P
vim.opt.colorcolumn = "80,110"
vim.opt.clipboard = "unnamedplus"
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
-- set foldnestmax=2
-- set foldlevelstart=10
-- " no rel nums on non focused buffer
-- augroup numbertoggle
--   autocmd!
--   autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
--   autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
-- augroup END
-- " automatically save view, load with :loadview
vim.api.nvim_create_autocmd("InsertLeave", {
	pattern = "*",
	command = "set nopaste",
})
-- autocmd BufWinLeave *.* mkview
-- highlight cursorline
-- autocmd BufEnter * setlocal cursorline
-- autocmd BufLeave * setlocal nocursorline
-- autocmd InsertEnter * highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
-- autocmd InsertLeave * highlight cursorline guibg=#073642 guifg=none gui=none ctermbg=none ctermfg=none cterm=none
-- show matching brackets
vim.opt.showmatch = true
vim.opt.matchtime = 0
-- highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
-- change leader key
vim.g.mapleader = "'"
vim.g.maplocalleader = "\\"
-- map ESC
-- inoremap jk <ESC>
-- tnoremap jk <C-\><C-n>
-- move among buffers with CTRL
vim.api.nvim_set_keymap(mode, keys, mapping, options)
-- map <C-J> :bnext<CR>
-- map <C-K> :bprev<CR>
-- map folding
-- vnoremap <space> zf
-- nnoremap <space> za
-- paste multiple times
-- xnoremap <leader>p "0p
-- nnoremap <leader>p "0p
-- delete without yanking
-- vnoremap <leader>d "_d
-- nnoremap <leader>d "_d
-- replace currently selected text without yanking it
-- vnoremap <leader>p "_dP
-- configure clipboard if inside WSL
-- https://github.com/memoryInject/wsl-clipboard
if is_wsl() then
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
end
if not is_vscode() then
-- ultisnips
-- let g:UltiSnipsExpandTrigger = '<tab>'
-- let g:UltiSnipsJumpForwardTrigger = '<tab>'
-- let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
-- let g:UltiSnipsSnippetDirectories = [$XDG_TEMPLATES_DIR.'/snippets']
-- tagbar
-- nmap <F8> :TagbarToggle<CR>
vim.g.tagbar_compact = 1
-- let g:tagbar_sort = 1
-- let g:tagbar_foldlevel = 1
-- let g:tagbar_show_linenumbers = 1
-- let g:tagbar_width = max([80, winwidth(0) / 4])
-- gutentags
-- map oo <C-]>
-- map OO <C-T>
-- map <C-O> g]
-- set tags=$XDG_DATA_HOME.'/nvim/cache/tags'
-- let g:gutentags_modules = ['ctags']
-- let g:gutentags_add_default_project_roots = 0
-- let g:gutentags_project_root = ['requirements.txt', '.git', 'README.md']
-- let g:gutentags_cache_dir=$XDG_DATA_HOME.'/nvim/cache/tags'
-- let g:gutentags_generate_on_new = 1
-- let g:gutentags_generate_on_missing = 1
-- let g:gutentags_generate_on_write = 1
-- let g:gutentags_generate_on_empty_buffer = 0
-- let g:gutentags_ctags_extra_args = [
--       \ '--tag-relative=yes',
--       \ '--fields=+ailmnS',
--       \ ]
-- let g:gutentags_ctags_exclude = [
--       \ '*.git', '*.svg', '*.hg',
--       \ '*/tests/*',
--       \ 'build',
--       \ 'dist',
--       \ '*/venv/*', '*/.venv/*',
--       \ '*sites/*/files/*',
--       \ 'bin',
--       \ 'node_modules',
--       \ 'bower_components',
--       \ 'cache',
--       \ 'compiled',
--       \ 'docs',
--       \ 'example',
--       \ 'bundle',
--       \ 'vendor',
--       \ '*.md',
--       \ '*-lock.json',
--       \ '*.lock',
--       \ '*bundle*.js',
--       \ '*build*.js',
--       \ '.*rc*',
--       \ '*.json',
--       \ '*.min.*',
--       \ '*.map',
--       \ '*.bak',
--       \ '*.zip',
--       \ '*.pyc',
--       \ '*.class',
--       \ '*.sln',
--       \ '*.Master',
--       \ '*.csproj',
--       \ '*.tmp',
--       \ '*.csproj.user',
--       \ '*.cache',
--       \ '*.pdb',
--       \ 'tags*',
--       \ 'cscope.*',
--       \ '*.css',
--       \ '*.less',
--       \ '*.scss',
--       \ '*.exe', '*.dll',
--       \ '*.mp3', '*.ogg', '*.flac',
--       \ '*.swp', '*.swo',
--       \ '*.bmp', '*.gif', '*.ico', '*.jpg', '*.png',
--       \ '*.rar', '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
--       \ '*.pdf', '*.doc', '*.docx', '*.ppt', '*.pptx',
--       \ ]
-- " ale
-- nmap <F6> :ALEFix<CR>
-- let g:ale_linters = {
--     \ 'python': ['pylint', 'mypy'],
--     \ 'cpp': ['clangtidy'],
--     \ 'c': ['clangtidy'],
--     \ 'xml': ['xmllint'],
--     \ 'rust': ['analyzer'],
--     \ 'nix': ['statix'],
--     \ 'json': ['jq'],
--     \ 'sh': ['shell'],
--     \}
-- let g:ale_fixers = {
--     \ 'python': ['black', 'isort'],
--     \ 'cpp': ['clang-format'],
--     \ 'c': ['clang-format'],
--     \ 'xml': ['xmllint'],
--     \ 'rust': ['rustfmt'],
--     \ 'json': ['fixjson'],
--     \ 'sh': ['shfmt'],
--     \ '*': ['remove_trailing_lines', 'trim_whitespace'],
--     \}
-- let g:ale_python_isort_options = '--profile black --atomic'
-- let g:ale_cpp_clangformat_style_option = 'webkit'
-- let g:ale_c_clangformat_style_option = 'webkit'
-- let g:ale_xml_xmllint_indentsize = 4
-- let g:ale_sh_shfmt_options = '-i 4 -ci'
-- let g:ale_rust_cargo_use_check = 1
-- let g:ale_rust_cargo_check_tests = 1
-- let g:ale_rust_cargo_check_examples = 1
-- let g:ale_fix_on_save = 0
-- let g:ale_lint_on_enter = 1
-- let g:ale_lint_on_filetype_changed = 0
-- let g:ale_lint_on_insert_leave = 0
-- let g:ale_lint_on_text_changed = 0
-- let g:ale_lint_on_save = 1
-- let g:ale_sign_column_always = 1
-- leap
require('leap').set_default_keymaps()
-- kommentary
require('kommentary.config').use_extended_mappings()
-- comment
-- require("Comment").setup {
--     ---Add a space b/w comment and the line
--     padding = true,
--     ---Whether the cursor should stay at its position
--     sticky = true,
--     ---Lines to be ignored while (un)comment
--     ignore = nil,
--     ---LHS of toggle mappings in NORMAL mode
--     toggler = {
--         ---Line-comment toggle keymap
--         line = 'gcc',
--         ---Block-comment toggle keymap
--         block = 'gbc',
--     },
--     ---LHS of operator-pending mappings in NORMAL and VISUAL mode
--     opleader = {
--         ---Line-comment keymap
--         line = 'gc',
--         ---Block-comment keymap
--         block = 'gb',
--     },
--     ---LHS of extra mappings
--     extra = {
--         ---Add comment on the line above
--         above = 'gcO',
--         ---Add comment on the line below
--         below = 'gco',
--         ---Add comment at the end of line
--         eol = 'gcA',
--     },
--     ---Enable keybindings
--     ---NOTE: If given `false` then the plugin won't create any mappings
--     mappings = {
--         ---Operator-pending mapping; `gcc` `gbc` `gc[count]{motion}` `gb[count]{motion}`
--         basic = true,
--         ---Extra mapping; `gco`, `gcO`, `gcA`
--         extra = true,
--         ---Extended mapping; `g>` `g<` `g>[count]{motion}` `g<[count]{motion}`
--         extended = false,
--     },
--     ---Function to call before (un)comment
--     pre_hook = nil,
--     ---Function to call after (un)comment
--     post_hook = nil,
-- }
end -- if not vscode
