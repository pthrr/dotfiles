-- check env
local version_file = io.open("/proc/version", "rb")
if version_file ~= nil then
    vim.g.wsl = false
    if string.find(version_file:read("*a"), "microsoft") then
        vim.g.wsl = true
    end
    version_file:close()
end
-- mini.nvim
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
-- autoformat
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = {
        "*.c", "*.cpp", "*.h", "*.hpp",       -- C++
        "*.rs",                               -- Rust
        "*.ts", "*.tsx", "*.js", "*.jsx",     -- Typescript
        "*.sh", "*.bash", "*.zsh",            -- Bash
        "*.py",                               -- Python
        "*.zig",                              -- Zig
        "*.tla",                              -- TLA+
        "*.typ",                              -- Typst
    },
    callback = function()
        if not vim.bo.modified then return end
        local file = vim.fn.expand('%')
        local function run_external(cmd, args)
            vim.loop.spawn(cmd, { args = args }, function()
                vim.schedule(function() vim.cmd('checktime') end)
            end)
        end
        if file:match("%.rs$") then
            run_external("rustfmt", { file })
        elseif file:match("%.typ$") then
            run_external("typstyle", { "-i", file })
        elseif file:match("%.tla$") then
            run_external("tlafmt", { file })
        elseif file:match("%.zig$") then
            run_external("zig", { "fmt", file })
        elseif file:match("%.[ch]pp?$") then
            run_external("clang-format", { "-i", file })
        elseif file:match("%.sh$") or file:match("%.bash$") or file:match("%.zsh$") then
            run_external("shfmt", { "-w", file })
        elseif file:match("%.py$") then
            run_external("black", { "--quiet", file })
        elseif file:match("%.ts$") or file:match("%.tsx$") or file:match("%.js$") or file:match("%.jsx$") then
            run_external("prettier", { "--write", file })
        else
            vim.lsp.buf.format({ async = false })
        end
    end
})
-- completion/diagnostics
now(function()
    local severity_names = {
        [vim.diagnostic.severity.ERROR] = "Error",
        [vim.diagnostic.severity.WARN]  = "Warning",
        [vim.diagnostic.severity.INFO]  = "Info",
        [vim.diagnostic.severity.HINT]  = "Hint",
    }
    vim.o.completeopt = "menuone,noselect"
    vim.diagnostic.config({
        virtual_text = {
            spacing = 4,
            prefix = '●',
            severity = { min = vim.diagnostic.severity.WARN },
        },
        signs = false,
        underline = true,
        update_in_insert = true,
        severity_sort = true,
        float = {
            source = 'always',
            border = 'single',
            severity = { min = vim.diagnostic.severity.INFO },
        },
    })
    local on_attach = function(client, bufnr)
        local bufopts = { noremap=true, silent=true, buffer=bufnr }
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, bufopts)
    end
    local servers = { 'ty', 'bashls', 'clangd', 'rust_analyzer', 'ts_ls', 'leanls', 'zls', 'tinymist', 'eslint' }
    local server_configs = {
        eslint = {
            settings = {
                packageManager = "bun"
            }
        }
    }
    for _, lsp in ipairs(servers) do
        local config = vim.tbl_deep_extend("force", { on_attach = on_attach }, server_configs[lsp] or {})
        require('lspconfig')[lsp].setup(config)
    end
    local diagnostic_float_win = nil
    local function open_corner_float()
        if diagnostic_float_win ~= nil and vim.api.nvim_win_is_valid(diagnostic_float_win) then
            vim.api.nvim_win_close(diagnostic_float_win, true)
        end
        local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line('.') - 1 })
        if #diagnostics == 0 then return end
        local messages = {}
        local max_width = 0
        for _, diagnostic in ipairs(diagnostics) do
            local prefix = string.format("[%s] ", severity_names[diagnostic.severity] or "Unknown")
            for line in diagnostic.message:gmatch("[^\n]+") do
                local msg = prefix .. line
                table.insert(messages, msg)
                max_width = math.max(max_width, #msg)
                prefix = "         "
            end
        end
        local editor_width = vim.api.nvim_get_option("columns")
        max_width = math.min(max_width, editor_width - 10)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)
        local height = vim.api.nvim_get_option("lines")
        local max_height = math.min(#messages, 5)
        local row = height - max_height - 4
        local col = editor_width - max_width - 2
        diagnostic_float_win = vim.api.nvim_open_win(buf, false, {
            relative = "editor",
            width = max_width,
            height = max_height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
            focusable = false,
        })
        vim.api.nvim_create_autocmd({"CursorMoved", "InsertEnter", "BufLeave", "FocusLost"}, {
            once = true,
            callback = function()
                if diagnostic_float_win ~= nil and vim.api.nvim_win_is_valid(diagnostic_float_win) then
                    vim.api.nvim_win_close(diagnostic_float_win, true)
                    diagnostic_float_win = nil
                end
            end,
        })
    end
    vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
            open_corner_float()
        end,
    })
end)
-- colorscheme
now(function()
    add({
        source = 'overcache/NeoSolarized',
    })
    vim.o.termguicolors = true
    vim.o.background = "dark"
    vim.cmd.colorscheme('NeoSolarized')
end)
-- highlighting
now(function()
    require('nvim-treesitter.configs').setup{
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = false,
        },
    }
end)
later(function()
    require("mini.hipatterns").setup({
        highlighters = {
            fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
            hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
            todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
            note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
            hex_color = require("mini.hipatterns").gen_highlighter.hex_color(),
        },
    })
end)
-- list symbols
later(function()
  require('mini.pick').setup()
  require('mini.extra').setup()
  vim.keymap.set('n', '<leader>ss', function()
    require('mini.extra').pickers.lsp({ scope = 'document_symbol' })
  end, { desc = 'Document symbols' })
  vim.keymap.set('n', '<leader>sS', function()
    require('mini.extra').pickers.lsp({ scope = 'workspace_symbol' })
  end, { desc = 'Workspace symbols' })
end)
-- comments
later(function()
    require('mini.comment').setup({})
end)
-- remove trailing whitespaces
later(function()
    require('mini.trailspace').setup({})
    vim.api.nvim_create_autocmd({"BufWritePre"}, {
        pattern = "*",
        callback = function()
            MiniTrailspace.trim()
            MiniTrailspace.trim_last_lines()
        end,
    })
end)
-- settings
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
vim.o.listchars = table.concat({ "extends:…", "trail:-", "nbsp:␣", "precedes:…", "tab:> " }, ",")
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
vim.o.path = vim.o.path .. ",**"
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
        copy = {
            ['+'] = 'clip.exe',
            ['*'] = 'clip.exe'
        },
        paste = {
            ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
            ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))'
        },
        cache_enabled = 0,
    }
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
-- Function to switch between .cpp/.hpp and .c/.h files
later(function()
    function switch_source_header()
        local extension = vim.fn.expand("%:e")
        local base_name = vim.fn.expand("%:r")
        local counterpart_file = nil
        if extension == "hpp" then
            if vim.fn.filereadable(base_name .. ".cpp") == 1 then
                counterpart_file = base_name .. ".cpp"
            elseif vim.fn.filereadable(base_name .. ".c") == 1 then
                counterpart_file = base_name .. ".c"
            end
        elseif extension == "cpp" then
            if vim.fn.filereadable(base_name .. ".hpp") == 1 then
                counterpart_file = base_name .. ".hpp"
            elseif vim.fn.filereadable(base_name .. ".h") == 1 then
                counterpart_file = base_name .. ".h"
            end
        elseif extension == "h" then
            if vim.fn.filereadable(base_name .. ".c") == 1 then
                counterpart_file = base_name .. ".c"
            elseif vim.fn.filereadable(base_name .. ".cpp") == 1 then
                counterpart_file = base_name .. ".cpp"
            end
        elseif extension == "c" then
            if vim.fn.filereadable(base_name .. ".h") == 1 then
                counterpart_file = base_name .. ".h"
            elseif vim.fn.filereadable(base_name .. ".hpp") == 1 then
                counterpart_file = base_name .. ".hpp"
            end
        end
        if counterpart_file then
            vim.cmd("edit " .. counterpart_file)
        else
            print("No corresponding file found for " .. base_name .. "." .. extension)
        end
    end
    vim.api.nvim_set_keymap('n', '<A-o>', '<cmd>lua switch_source_header()<CR>', { noremap = true, silent = true })
end)
-- neogit
now(function()
    add({
        source = 'NeogitOrg/neogit',
    })
end)
later(function()
    require('neogit').setup {}
end)
