local version_file = io.open("/proc/version", "rb")
if version_file ~= nil then
  if string.find(version_file:read("*a"), "microsoft") then
    vim.g.wsl = true
  end
  version_file:close()
end
local path_package = vim.fn.stdpath('data') .. '/site'
local mini_path = path_package .. '/pack/deps/start/mini.nvim'
if not vim.loop.fs_stat(mini_path) then
  vim.cmd('echo "Installing `mini.nvim`" | redraw')
  local clone_cmd = {
    'git', 'clone', '--filter=blob:none',
    '--branch', 'stable',
    'https://github.com/echasnovski/mini.nvim', mini_path
  }
  vim.fn.system(clone_cmd)
  vim.cmd('packadd mini.nvim | helptags ALL')
  vim.cmd('echo "Installed `mini.nvim`" | redraw')
end
require('mini.deps').setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
now(function()
  add({
    source = 'overcache/NeoSolarized',
  })
  add({
    source = 'puremourning/vimspector',
  })
  add({
    source = 'kaarmu/typst.vim',
  })
  add({
    source = 'madskjeldgaard/cppman.nvim',
    depends = { 'MunifTanjim/nui.nvim' },
  })
end)
later(function()
  vim.o.termguicolors = true
  vim.o.background = "dark"
  vim.cmd.colorscheme('NeoSolarized')
end)
vim.cmd('syntax off')
vim.cmd('filetype plugin indent on')
-- ergonomics
vim.o.visualbell = true
vim.o.errorbells = false
vim.o.number = true
vim.o.relativenumber = true
vim.o.timeoutlen = 600
vim.o.ttimeoutlen = 0
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
-- visuals
vim.o.title = true
vim.o.hidden = true
vim.o.showmode = false
vim.o.modelines = 5
vim.o.scrolloff = 1
vim.o.sidescrolloff = 5
vim.o.wrap = false
vim.o.list = true
vim.o.listchars = "tab:› ,trail:-,extends:>,precedes:<,nbsp:+"
vim.o.colorcolumn = "80,120"
vim.o.signcolumn = "yes"
vim.o.splitbelow = true
vim.o.splitright = true
-- encoding
vim.o.bomb = false
vim.o.encoding = "utf-8"
vim.o.fileencodings = "ucs-bom,utf-8,latin1,cp1252,default"
-- declutter
vim.o.backup = false
vim.o.writebackup = false
vim.o.swapfile = false
-- history
vim.o.undofile = true
vim.o.undolevels = 1000
vim.o.undoreload = 10000
vim.o.history = 1000
-- shell
vim.o.shell = "/usr/bin/env bash"
-- autoread
vim.o.updatetime = 300
vim.o.autoread = true
vim.o.lazyredraw = true
vim.o.ttyfast = true
-- search
vim.o.hlsearch = true
vim.o.incsearch = true
vim.o.path = vim.o.path .. "**"
vim.o.magic = true
vim.o.wildmode = "list:longest,full"
vim.o.wildignore = ".git,.hg,.svn,*.aux,*.out,*.toc,*.o,*.obj,*.exe,*.dll,*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp,*.avi,*.divx,*.mp4,*.webm,*.mov,*.mkv,*.vob,*.mpg,*.mpeg,*.mp3,*.oga,*.ogg,*.wav,*.flac,*.otf,*.ttf,*.doc,*.pdf,*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.swp,.lock,.DS_Store,._*"
-- folding
vim.o.foldmethod = "indent"
vim.o.foldenable = false
vim.o.foldnestmax = 2
vim.o.foldlevelstart = 10
-- statusline
vim.o.showtabline = 0
function _G.CustomTabline()
    local str = ''
    local num_tabs = vim.fn.tabpagenr('$')
    if num_tabs > 1 then
        for num_tab = 1, num_tabs do
            if num_tab == vim.fn.tabpagenr() then
                str = str .. '*'
            else
                str = str .. '-'
            end
            local name_tab = vim.fn.fnamemodify(vim.fn.bufname(vim.fn.tabpagebuflist(num_tab)[1]), ':t')
            if name_tab == '' then
                str = str .. '[No Name]'
            else
                str = str .. name_tab
            end
            if vim.fn.getbufvar(vim.fn.tabpagebuflist(num_tab)[1], '&modified') == 1 then
                str = str .. '+'
            end
            if num_tab < num_tabs then
                str = str .. ' '
            end
        end
    else
        str = str .. vim.fn.expand('%f')
    end
    return str
end
vim.o.statusline = "%-4.(%n%)%{v:lua.CustomTabline()} %h%m%r%=%-14.(%l,%c%V%) %P"
-- clipboard
if vim.g.wsl then
  vim.g.clipboard = {
    name = 'WslClipboard',
    copy = { ['+'] = 'clip.exe', ['*'] = 'clip.exe' },
    paste = { ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
              ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))' },
    cache_enabled = 0,
  }
else
  vim.o.clipboard = "unnamedplus"
end
-- cursorline
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    command = "setlocal cursorline"
})
vim.api.nvim_create_autocmd("BufLeave", {
    pattern = "*",
    command = "setlocal nocursorline"
})
vim.api.nvim_create_autocmd({"BufEnter", "FocusGained", "InsertLeave"}, {
    pattern = "*",
    command = "setlocal relativenumber"
})
vim.api.nvim_create_autocmd({"BufLeave", "FocusLost", "InsertEnter"}, {
    pattern = "*",
    command = "setlocal norelativenumber"
})
vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    command = "highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline"
})
vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    command = "highlight cursorline guibg=none guifg=none gui=none ctermbg=none ctermfg=none cterm=none"
})
-- restore cursor
vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*",
    callback = function()
        local last_pos = vim.fn.line("'\"")
        if last_pos > 0 and last_pos <= vim.fn.line("$") then
            vim.cmd("normal! g`\"")
        end
    end
})
-- basic mappings
vim.g.mapleader = "'"
vim.g.maplocalleader = "\\"
vim.api.nvim_set_keymap('i', 'jk', '<ESC>', { noremap = true })
vim.api.nvim_set_keymap('t', 'jk', '<C-\\><C-n>', { noremap = true })
vim.api.nvim_set_keymap('t', '<Esc>', '<C-\\><C-n>', { noremap = true })
-- Splitting windows
vim.api.nvim_set_keymap('n', 'ss', ':split<CR><C-w>w', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'sv', ':vsplit<CR><C-w>w', { noremap = true, silent = true })
-- Move between windows
vim.api.nvim_set_keymap('n', 'sh', '<C-w>h', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'sk', '<C-w>k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'sj', '<C-w>j', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'sl', '<C-w>l', { noremap = true, silent = true })
-- Switch tabs (buffers)
vim.api.nvim_set_keymap('n', '<Tab>', ':bnext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<S-Tab>', ':bprev<CR>', { noremap = true, silent = true })
-- Switch buffers (tabs)
vim.api.nvim_set_keymap('n', '<C-Tab>', ':tabnext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-S-Tab>', ':tabprev<CR>', { noremap = true, silent = true })
-- Folding
vim.api.nvim_set_keymap('v', '<space>', 'zf', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<space>', 'za', { noremap = true, silent = true })
-- Paste from register 0 multiple times
vim.api.nvim_set_keymap('x', '<leader>p', '"0p', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>p', '"0p', { noremap = true, silent = true })
-- Delete without yanking
vim.api.nvim_set_keymap('v', '<leader>d', '"_d', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>d', '"_d', { noremap = true, silent = true })
-- Replace currently selected text without yanking it
vim.api.nvim_set_keymap('v', '<leader>p', '"_dP', { noremap = true, silent = true })
-- completion
require('lspconfig').tsserver.setup{}
require('mini.completion').setup{}
-- comments
require('mini.comment').setup{}
-- remove trailing whitespaces
require('mini.trailspace').setup{}
vim.api.nvim_create_autocmd({"BufWritePre"}, {
  pattern = "*",
  callback = function()
    MiniTrailspace.trim()
    MiniTrailspace.trim_last_lines()
  end,
})
-- syntax highlighting
require('nvim-treesitter.configs').setup{
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}
-- quint
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "*.qnt",
  callback = function()
    vim.bo.filetype = "quint"
  end,
})
vim.api.nvim_create_autocmd({"BufNewFile", "BufReadPost"}, {
  pattern = "*.qnt",
  callback = function()
    vim.cmd("runtime syntax/quint.vim")
  end,
})
-- typst
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.typ",
  callback = function()
    vim.cmd("silent! make")
  end,
})
-- cppman
require('cppman').setup{}
vim.api.nvim_set_keymap('n', '<leader>cm', ':CPPMan <C-R><C-W><CR>', { noremap = true, silent = true })
-- Function to switch between .cpp/.hpp and .c/.h files
function switch_source_header()
  local current_file = vim.fn.expand("%:t")
  local extension = vim.fn.expand("%:e")
  local base_name = vim.fn.expand("%:r")
  local counterpart_file = nil
  if extension == "hpp" then
    counterpart_file = base_name .. ".cpp"
  elseif extension == "cpp" then
    counterpart_file = base_name .. ".hpp"
  elseif extension == "h" then
    counterpart_file = base_name .. ".c"
  elseif extension == "c" then
    counterpart_file = base_name .. ".h"
  end
  if counterpart_file and vim.fn.filereadable(counterpart_file) == 1 then
    vim.cmd("edit " .. counterpart_file)
  else
    print("No corresponding file found!")
  end
end
vim.api.nvim_set_keymap('n', '<A-o>', '<cmd>lua switch_source_header()<CR>', { noremap = true, silent = true })
