-- ==============================================================================
-- 1. ENVIRONMENT DETECTION
-- ==============================================================================

-- Detect WSL environment for clipboard integration
local version_file = io.open("/proc/version", "rb")
if version_file ~= nil then
    vim.g.wsl = false
    if string.find(version_file:read("*a"), "microsoft") then
        vim.g.wsl = true
    end
    version_file:close()
end

-- ==============================================================================
-- 2. PLUGIN MANAGER BOOTSTRAP
-- ==============================================================================

-- Bootstrap mini.nvim plugin manager
local path_package = vim.fn.stdpath("data") .. "/site"
local mini_path = path_package .. "/pack/deps/start/mini.nvim"

if not vim.loop.fs_stat(mini_path) then
    vim.cmd('echo "Installing `mini.nvim`" | redraw')
    local clone_cmd = {
        "git",
        "clone",
        "--filter=blob:none",
        "--branch",
        "stable",
        "https://github.com/echasnovski/mini.nvim",
        mini_path,
    }
    vim.fn.system(clone_cmd)
    vim.cmd("packadd mini.nvim | helptags ALL")
    vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

require("mini.deps").setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- ==============================================================================
-- 3. HELPER FUNCTIONS
-- ==============================================================================

--- Runs an external formatter command asynchronously
--- @param cmd string The command to execute
--- @param args table Command arguments
local function run_external_formatter(cmd, args)
    vim.loop.spawn(cmd, { args = args }, function()
        vim.schedule(function()
            vim.cmd("checktime")
        end)
    end)
end

-- ==============================================================================
-- 4. LSP & COMPLETION
-- ==============================================================================

now(function()
    -- Diagnostic severity name mapping for display
    local severity_names = {
        [vim.diagnostic.severity.ERROR] = "Error",
        [vim.diagnostic.severity.WARN] = "Warning",
        [vim.diagnostic.severity.INFO] = "Info",
        [vim.diagnostic.severity.HINT] = "Hint",
    }

    -- Configure completion
    vim.o.completeopt = "menuone,noselect"

    -- Configure diagnostic display
    vim.diagnostic.config({
        virtual_text = {
            spacing = 4,
            prefix = "●",
            severity = { min = vim.diagnostic.severity.WARN },
        },
        signs = false,
        underline = true,
        update_in_insert = true,
        severity_sort = true,
        float = {
            source = "always",
            border = "single",
            severity = { min = vim.diagnostic.severity.INFO },
        },
    })

    -- LSP keybindings attached to each buffer
    local on_attach = function(client, bufnr)
        local bufopts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
    end

    -- Language servers configuration
    local servers = {
        pyright = {
            cmd = { "pyright-langserver", "--stdio" },
            filetypes = { "python" },
            root_markers = { "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel", "BUILD.bazel", "pyproject.toml", "setup.py", ".git", ".jj" },
        },
        ty = {
            cmd = { "ty" },
            filetypes = { "python" },
            root_markers = { "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel", "BUILD.bazel", "pyproject.toml", "setup.py", ".git", ".jj" },
        },
        bashls = {
            cmd = { "bash-language-server", "start" },
            filetypes = { "sh", "bash", "zsh" },
            root_markers = { ".git", ".jj" },
        },
        clangd = {
            cmd = { "clangd" },
            filetypes = { "c", "cpp" },
            root_markers = { "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel", "BUILD.bazel", "compile_commands.json", ".clangd", ".git", ".jj" },
            init_options = {
                fallbackFlags = { "--std=c++23" },
            },
        },
        rust_analyzer = {
            cmd = { "rust-analyzer" },
            filetypes = { "rust" },
            root_markers = { "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel", "BUILD.bazel", "Cargo.toml", ".git", ".jj" },
            settings = {
                ["rust-analyzer"] = {
                    check = {
                        command = "clippy",
                        extraArgs = {
                            "--",
                            "-W", "clippy::missing_const_for_fn",
                            "-W", "clippy::borrow_interior_mutable_const",
                            "-W", "clippy::declare_interior_mutable_const",
                            "-W", "clippy::cloned_instead_of_copied",
                            "-W", "clippy::trivially_copy_pass_by_ref",
                            "-W", "clippy::disallowed_methods",
                            "-A", "clippy::redundant_closure_call",
                            "-A", "clippy::needless_return",
                            "-A", "clippy::single_match",
                            "-A", "unused_macros",
                        },
                        extraEnv = {
                            CLIPPY_CONF_DIR = vim.fn.expand("~/.config/clippy"),
                        },
                    },
                    cargo = {
                        extraEnv = {
                            CLIPPY_CONF_DIR = vim.fn.expand("~/.config/clippy"),
                        },
                    },
                    clippy = {
                        allTargets = true,
                    },
                    diagnostics = {
                        disabled = {},
                        enable = true,
                    },
                    procMacro = {
                        enable = true,
                    },
                },
            },
        },
        ts_ls = {
            cmd = { "typescript-language-server", "--stdio" },
            filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
            root_markers = { "package.json", "tsconfig.json", ".git", ".jj" },
        },
        leanls = {
            cmd = { "lean", "--server" },
            filetypes = { "lean" },
            root_markers = { "lean-toolchain", "lakefile.lean", ".git", ".jj" },
        },
        zls = {
            cmd = { "zls" },
            filetypes = { "zig" },
            root_markers = { "build.zig", ".git", ".jj" },
        },
        tinymist = {
            cmd = { "tinymist" },
            filetypes = { "typst" },
            root_markers = { ".git", ".jj" },
        },
        eslint = {
            cmd = { "vscode-eslint-language-server", "--stdio" },
            filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
            root_markers = { "package.json", ".git", ".jj" },
            settings = {
                packageManager = "bun",
            },
        },
        lua_ls = {
            cmd = { "lua-language-server" },
            filetypes = { "lua" },
            root_markers = { ".luarc.json", ".luarc.jsonc", ".git", ".jj" },
            settings = {
                Lua = {
                    runtime = {
                        version = 'LuaJIT',
                    },
                    diagnostics = {
                        globals = { 'vim' },
                    },
                    workspace = {
                        checkThirdParty = false,
                    },
                    telemetry = {
                        enable = false,
                    },
                },
            },
        },
    }

    -- Enable all configured language servers
    for name, server_config in pairs(servers) do
        local config = vim.tbl_deep_extend("force", {
            on_attach = on_attach,
        }, server_config)
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
    end

    -- Diagnostic float window management
    local diagnostic_float_win = nil

    --- Opens a diagnostic float window in the bottom-right corner
    --- Closes automatically on cursor movement or mode change
    local function open_diagnostic_corner_float()
        -- Close existing float if open
        if diagnostic_float_win ~= nil and vim.api.nvim_win_is_valid(diagnostic_float_win) then
            vim.api.nvim_win_close(diagnostic_float_win, true)
        end

        -- Get diagnostics for current line
        local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
        if #diagnostics == 0 then
            return
        end

        -- Format diagnostic messages
        local messages = {}
        local max_width = 0
        for _, diagnostic in ipairs(diagnostics) do
            local prefix = string.format("[%s] ", severity_names[diagnostic.severity] or "Unknown")
            for line in diagnostic.message:gmatch("[^\n]+") do
                local msg = prefix .. line
                table.insert(messages, msg)
                max_width = math.max(max_width, #msg)
                prefix = "         " -- Indent continuation lines
            end
        end

        -- Calculate window dimensions
        local editor_width = vim.api.nvim_get_option("columns")
        max_width = math.min(max_width, editor_width - 10)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)

        local height = vim.api.nvim_get_option("lines")
        local max_height = math.min(#messages, 5)
        local row = height - max_height - 4
        local col = editor_width - max_width - 2

        -- Open floating window
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

        -- Auto-close on cursor movement
        vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave", "FocusLost" }, {
            once = true,
            callback = function()
                if diagnostic_float_win ~= nil and vim.api.nvim_win_is_valid(diagnostic_float_win) then
                    vim.api.nvim_win_close(diagnostic_float_win, true)
                    diagnostic_float_win = nil
                end
            end,
        })
    end

    -- Show diagnostics on cursor hold
    vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
            open_diagnostic_corner_float()
        end,
    })
end)

-- Autoformat on save using external formatters
-- Falls back to LSP formatting if no external formatter is configured
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = {
        "*.c",
        "*.cpp",
        "*.h",
        "*.hpp", -- C/C++
        "*.rs", -- Rust
        "*.ts",
        "*.tsx",
        "*.js",
        "*.jsx", -- TypeScript/JavaScript
        "*.sh",
        "*.bash",
        "*.zsh", -- Shell scripts
        "*.py", -- Python
        "*.zig", -- Zig
        "*.tla", -- TLA+
        "*.typ", -- Typst
        "*.lua", -- Lua
    },
    callback = function()
        -- Skip if buffer hasn't been modified
        if not vim.bo.modified then
            return
        end

        local file = vim.fn.expand("%")

        -- Route to appropriate formatter based on file extension
        if file:match("%.rs$") then
            run_external_formatter("rustfmt", { file })
        elseif file:match("%.typ$") then
            run_external_formatter("typstyle", { "-i", file })
        elseif file:match("%.tla$") then
            run_external_formatter("tlafmt", { file })
        elseif file:match("%.zig$") then
            run_external_formatter("zig", { "fmt", file })
        elseif file:match("%.[ch]pp?$") then
            run_external_formatter("clang-format", { "-i", file })
        elseif file:match("%.sh$") or file:match("%.bash$") or file:match("%.zsh$") then
            run_external_formatter("shfmt", { "-w", file })
        elseif file:match("%.py$") then
            run_external_formatter("black", { "--quiet", file })
        elseif file:match("%.ts$") or file:match("%.tsx$") or file:match("%.js$") or file:match("%.jsx$") then
            run_external_formatter("prettier", { "--write", file })
        elseif file:match("%.lua$") then
            local config_path = vim.fn.expand("~") .. "/stylua.toml"
            if vim.fn.filereadable(config_path) == 1 then
                run_external_formatter("stylua", { "--config-path", config_path, file })
            else
                run_external_formatter("stylua", { file })
            end
        else
            -- Fallback to LSP formatting
            vim.lsp.buf.format({ async = false })
        end
    end,
})

-- ==============================================================================
-- 5. PLUGINS
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- Colorscheme
-- -----------------------------------------------------------------------------

now(function()
    add({ source = "overcache/NeoSolarized" })
    vim.o.termguicolors = true
    vim.o.background = "dark"
    vim.cmd.colorscheme("NeoSolarized")
end)

-- -----------------------------------------------------------------------------
-- Treesitter & Highlighting
-- -----------------------------------------------------------------------------

now(function()
    require("nvim-treesitter.configs").setup({
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = false,
        },
        indent = {
            enable = false,
        },
        textobjects = {
            select = {
                enable = true,
                lookahead = true,
                keymaps = {
                    ["af"] = "@function.outer",
                    ["if"] = "@function.inner",
                    ["ac"] = "@class.outer",
                    ["ic"] = "@class.inner",
                    ["aa"] = "@parameter.outer",
                    ["ia"] = "@parameter.inner",
                },
            },
            move = {
                enable = true,
                set_jumps = true,
                goto_next_start = {
                    ["]m"] = "@function.outer",
                    ["]c"] = "@class.outer",
                },
                goto_next_end = {
                    ["]M"] = "@function.outer",
                    ["]C"] = "@class.outer",
                },
                goto_previous_start = {
                    ["[m"] = "@function.outer",
                    ["[c"] = "@class.outer",
                },
                goto_previous_end = {
                    ["[M"] = "@function.outer",
                    ["[C"] = "@class.outer",
                },
            },
        },
        incremental_selection = {
            enable = true,
            keymaps = {
                init_selection = "gnn",
                node_incremental = "grn",
                scope_incremental = "grc",
                node_decremental = "grm",
            },
        },
    })
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

-- -----------------------------------------------------------------------------
-- Symbol Picker
-- -----------------------------------------------------------------------------

later(function()
    require("mini.pick").setup()
    require("mini.extra").setup()

    vim.keymap.set("n", "<leader>ss", function()
        require("mini.extra").pickers.lsp({ scope = "document_symbol" })
    end, { desc = "List document symbols" })

    vim.keymap.set("n", "<leader>sS", function()
        require("mini.extra").pickers.lsp({ scope = "workspace_symbol" })
    end, { desc = "List workspace symbols" })
end)

-- -----------------------------------------------------------------------------
-- Comments
-- -----------------------------------------------------------------------------

later(function()
    require("mini.comment").setup({})
end)

-- -----------------------------------------------------------------------------
-- Trailing Whitespace
-- -----------------------------------------------------------------------------

later(function()
    require("mini.trailspace").setup({})

    -- Auto-trim on save
    vim.api.nvim_create_autocmd({ "BufWritePre" }, {
        pattern = "*",
        callback = function()
            MiniTrailspace.trim()
            MiniTrailspace.trim_last_lines()
        end,
    })
end)

-- -----------------------------------------------------------------------------
-- Git Integration
-- -----------------------------------------------------------------------------

now(function()
    add({ source = "NeogitOrg/neogit" })
end)

later(function()
    require("neogit").setup({})
end)

-- ==============================================================================
-- 6. EDITOR SETTINGS
-- ==============================================================================

-- Disable syntax (use Treesitter instead)
vim.cmd("syntax off")

-- -----------------------------------------------------------------------------
-- UI Behavior
-- -----------------------------------------------------------------------------

vim.o.visualbell = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.timeoutlen = 600
vim.o.ttimeoutlen = 0

-- -----------------------------------------------------------------------------
-- Indentation
-- -----------------------------------------------------------------------------

vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- -----------------------------------------------------------------------------
-- Visual Display
-- -----------------------------------------------------------------------------

vim.o.title = true
vim.o.showmode = false
vim.o.scrolloff = 1
vim.o.wrap = false
vim.o.list = true
vim.o.listchars = table.concat({ "extends:…", "trail:-", "nbsp:␣", "precedes:…", "tab:> " }, ",")
vim.o.colorcolumn = "80,120"
vim.o.signcolumn = "yes"
vim.o.splitbelow = true
vim.o.splitright = true

-- -----------------------------------------------------------------------------
-- Encoding
-- -----------------------------------------------------------------------------

vim.o.bomb = false
vim.o.fileencodings = "ucs-bom,utf-8,latin1,cp1252,default"

-- -----------------------------------------------------------------------------
-- Backup & Swap Files
-- -----------------------------------------------------------------------------

vim.o.backup = false
vim.o.writebackup = false
vim.o.swapfile = false

-- -----------------------------------------------------------------------------
-- Undo History
-- -----------------------------------------------------------------------------

vim.o.undofile = true
vim.o.undolevels = 1000
vim.o.undoreload = 10000
vim.o.history = 1000

-- -----------------------------------------------------------------------------
-- Shell
-- -----------------------------------------------------------------------------

vim.o.shell = "/usr/bin/env bash"

-- -----------------------------------------------------------------------------
-- Autoread
-- -----------------------------------------------------------------------------

vim.o.updatetime = 300
vim.o.autoread = true

-- -----------------------------------------------------------------------------
-- Search
-- -----------------------------------------------------------------------------

vim.o.hlsearch = true
vim.o.path = vim.o.path .. ",**"
vim.o.wildmode = "list:longest,full"
vim.o.wildignore =
    ".git,.hg,.svn,*.aux,*.out,*.toc,*.o,*.obj,*.exe,*.dll,*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp,*.avi,*.divx,*.mp4,*.webm,*.mov,*.mkv,*.vob,*.mpg,*.mpeg,*.mp3,*.oga,*.ogg,*.wav,*.flac,*.otf,*.ttf,*.doc,*.pdf,*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.swp,.lock,.DS_Store,._*"

-- -----------------------------------------------------------------------------
-- Folding
-- -----------------------------------------------------------------------------

vim.o.foldmethod = "indent"
vim.o.foldenable = false
vim.o.foldnestmax = 2

-- -----------------------------------------------------------------------------
-- Statusline & Tabline
-- -----------------------------------------------------------------------------

vim.o.showtabline = 0

--- Custom tabline function showing tabs or filename
function _G.CustomTabline()
    local str = ""
    local num_tabs = vim.fn.tabpagenr("$")

    if num_tabs > 1 then
        for num_tab = 1, num_tabs do
            -- Active tab indicator
            if num_tab == vim.fn.tabpagenr() then
                str = str .. "*"
            else
                str = str .. "-"
            end

            -- Tab name
            local name_tab = vim.fn.fnamemodify(vim.fn.bufname(vim.fn.tabpagebuflist(num_tab)[1]), ":t")
            if name_tab == "" then
                str = str .. "[No Name]"
            else
                str = str .. name_tab
            end

            -- Modified indicator
            if vim.fn.getbufvar(vim.fn.tabpagebuflist(num_tab)[1], "&modified") == 1 then
                str = str .. "+"
            end

            -- Tab separator
            if num_tab < num_tabs then
                str = str .. " "
            end
        end
    else
        str = str .. vim.fn.expand("%f")
    end

    return str
end

vim.o.statusline = "%-4.(%n%)%{v:lua.CustomTabline()} %h%m%r%=%-14.(%l,%c%V%) %P"

-- -----------------------------------------------------------------------------
-- Clipboard (WSL Integration)
-- -----------------------------------------------------------------------------

if vim.g.wsl then
    vim.g.clipboard = {
        name = "WslClipboard",
        copy = {
            ["+"] = "clip.exe",
            ["*"] = "clip.exe",
        },
        paste = {
            ["+"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
            ["*"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
        },
        cache_enabled = 0,
    }
end

-- ==============================================================================
-- 7. AUTOCOMMANDS
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- Cursorline Management
-- -----------------------------------------------------------------------------

-- Show cursorline only in active buffer
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    command = "setlocal cursorline",
})

vim.api.nvim_create_autocmd("BufLeave", {
    pattern = "*",
    command = "setlocal nocursorline",
})

-- Show relative numbers only in active buffer and normal mode
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave" }, {
    pattern = "*",
    command = "setlocal relativenumber",
})

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter" }, {
    pattern = "*",
    command = "setlocal norelativenumber",
})

-- Underline cursorline in insert mode
vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    command = "highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline",
})

vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    command = "highlight cursorline guibg=none guifg=none gui=none ctermbg=none ctermfg=none cterm=none",
})

-- -----------------------------------------------------------------------------
-- Restore Cursor Position
-- -----------------------------------------------------------------------------

-- Jump to last known cursor position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*",
    callback = function()
        local last_pos = vim.fn.line("'\"")
        if last_pos > 0 and last_pos <= vim.fn.line("$") then
            vim.cmd('normal! g`"')
        end
    end,
})

-- ==============================================================================
-- 8. KEYMAPS
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- Leader Keys
-- -----------------------------------------------------------------------------

vim.g.mapleader = ","
vim.g.maplocalleader = "\\"

-- -----------------------------------------------------------------------------
-- Mode Switching
-- -----------------------------------------------------------------------------

vim.keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode" })
vim.keymap.set("t", "jk", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- -----------------------------------------------------------------------------
-- Window Management
-- -----------------------------------------------------------------------------

vim.keymap.set("n", "ss", ":split<CR><C-w>w", { silent = true, desc = "Split horizontal" })
vim.keymap.set("n", "sv", ":vsplit<CR><C-w>w", { silent = true, desc = "Split vertical" })

-- Window navigation
vim.keymap.set("n", "sh", "<C-w>h", { silent = true, desc = "Move to left window" })
vim.keymap.set("n", "sk", "<C-w>k", { silent = true, desc = "Move to window above" })
vim.keymap.set("n", "sj", "<C-w>j", { silent = true, desc = "Move to window below" })
vim.keymap.set("n", "sl", "<C-w>l", { silent = true, desc = "Move to right window" })

-- -----------------------------------------------------------------------------
-- Buffer Navigation
-- -----------------------------------------------------------------------------

vim.keymap.set("n", "]b", ":bnext<CR>", { silent = true, desc = "Next buffer" })
vim.keymap.set("n", "[b", ":bprev<CR>", { silent = true, desc = "Previous buffer" })

-- -----------------------------------------------------------------------------
-- Tab Navigation
-- -----------------------------------------------------------------------------

vim.keymap.set("n", "]t", ":tabnext<CR>", { silent = true, desc = "Next tab" })
vim.keymap.set("n", "[t", ":tabprev<CR>", { silent = true, desc = "Previous tab" })

-- -----------------------------------------------------------------------------
-- Register Operations
-- -----------------------------------------------------------------------------

-- Paste from register 0 (last yank, not delete)
vim.keymap.set("n", "<leader>p", '"0p', { silent = true, desc = "Paste from yank register" })

-- Delete without yanking
vim.keymap.set("v", "<leader>d", '"_d', { silent = true, desc = "Delete without yanking" })
vim.keymap.set("n", "<leader>d", '"_d', { silent = true, desc = "Delete without yanking" })

-- Replace selection without yanking
vim.keymap.set("v", "<leader>p", '"_dP', { silent = true, desc = "Replace without yanking" })

-- -----------------------------------------------------------------------------
-- C/C++ Source/Header Toggle
-- -----------------------------------------------------------------------------

later(function()
    --- Switches between C/C++ source and header files
    function switch_source_header()
        local extension = vim.fn.expand("%:e")
        local base_name = vim.fn.expand("%:r")
        local counterpart_file = nil

        -- Define extension pairs and search order
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

        -- Open counterpart or show error
        if counterpart_file then
            vim.cmd("edit " .. counterpart_file)
        else
            print("No corresponding file found for " .. base_name .. "." .. extension)
        end
    end

    vim.keymap.set("n", "<A-o>", "<cmd>lua switch_source_header()<CR>", {
        silent = true,
        desc = "Toggle between source and header",
    })
end)
