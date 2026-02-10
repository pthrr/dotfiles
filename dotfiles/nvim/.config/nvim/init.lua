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

if not vim.uv.fs_stat(mini_path) then
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

--- Runs an external formatter command synchronously
--- @param cmd string The command to execute
--- @param args table Command arguments
local function run_external_formatter(cmd, args)
    if vim.fn.executable(cmd) ~= 1 then
        vim.notify("Formatter not found: " .. cmd, vim.log.levels.WARN)
        return
    end
    -- Save cursor position and view
    local view = vim.fn.winsaveview()
    -- Save buffer first so formatter operates on current content
    vim.cmd("noautocmd write")
    vim.fn.system(vim.list_extend({ cmd }, args))
    vim.cmd("edit!")
    -- Restore cursor position and view
    vim.fn.winrestview(view)
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
            root_markers = {
                "MODULE.bazel",
                "WORKSPACE",
                "WORKSPACE.bazel",
                "BUILD.bazel",
                "pyproject.toml",
                "setup.py",
                ".git",
                ".jj",
            },
        },
        ty = {
            cmd = { "ty" },
            filetypes = { "python" },
            root_markers = {
                "MODULE.bazel",
                "WORKSPACE",
                "WORKSPACE.bazel",
                "BUILD.bazel",
                "pyproject.toml",
                "setup.py",
                ".git",
                ".jj",
            },
        },
        bashls = {
            cmd = { "bash-language-server", "start" },
            filetypes = { "sh", "bash", "zsh" },
            root_markers = { ".git", ".jj" },
        },
        clangd = {
            cmd = { "clangd" },
            filetypes = { "c", "cpp" },
            root_markers = {
                "MODULE.bazel",
                "WORKSPACE",
                "WORKSPACE.bazel",
                "BUILD.bazel",
                "compile_commands.json",
                ".clangd",
                ".git",
                ".jj",
            },
            init_options = {
                fallbackFlags = { "--std=c++23" },
            },
        },
        rust_analyzer = {
            cmd = { "rust-analyzer" },
            filetypes = { "rust" },
            root_markers = {
                "MODULE.bazel",
                "WORKSPACE",
                "WORKSPACE.bazel",
                "BUILD.bazel",
                "Cargo.toml",
                ".git",
                ".jj",
            },
            settings = {
                ["rust-analyzer"] = {
                    check = {
                        command = "clippy",
                    },
                    clippy = {
                        allTargets = true,
                    },
                    diagnostics = {
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
            root_markers = { "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", ".eslintrc.json", ".eslintrc.js", ".eslintrc.yaml", ".eslintrc.yml", "package.json", ".git", ".jj" },
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
                        version = "LuaJIT",
                    },
                    diagnostics = {
                        globals = { "vim" },
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
        nixd = {
            cmd = { "nixd" },
            filetypes = { "nix" },
            root_markers = { "flake.nix", "default.nix", "shell.nix", ".git", ".jj" },
            settings = {
                nixd = {
                    formatting = {
                        command = { "nixfmt" },
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
        local editor_width = vim.o.columns
        max_width = math.min(max_width, editor_width - 10)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)

        local height = vim.o.lines
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
                    local win_buf = vim.api.nvim_win_get_buf(diagnostic_float_win)
                    vim.api.nvim_win_close(diagnostic_float_win, true)
                    if vim.api.nvim_buf_is_valid(win_buf) then
                        vim.api.nvim_buf_delete(win_buf, { force = true })
                    end
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
        "*.nix", -- Nix
    },
    callback = function()
        -- Skip if buffer hasn't been modified
        if not vim.bo.modified then
            return
        end

        local file = vim.fn.expand("%")

        -- Route to appropriate formatter based on file extension
        if file:match("%.rs$") then
            run_external_formatter("verusfmt", { file })
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
            run_external_formatter("ruff", { "format", "--quiet", file })
        elseif file:match("%.ts$") or file:match("%.tsx$") or file:match("%.js$") or file:match("%.jsx$") then
            run_external_formatter("prettier", { "--write", file })
        elseif file:match("%.lua$") then
            local config_path = vim.fn.expand("~") .. "/.config/stylua/stylua.toml"
            if vim.fn.filereadable(config_path) == 1 then
                run_external_formatter("stylua", { "--config-path", config_path, file })
            else
                run_external_formatter("stylua", { file })
            end
        elseif file:match("%.nix$") then
            run_external_formatter("nixfmt", { file })
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
    -- nvim-treesitter is provided by NixOS home-manager with all grammars
    vim.api.nvim_create_autocmd("FileType", {
        callback = function()
            vim.treesitter.start()
        end,
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
vim.o.colorcolumn = "88,120"
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

vim.o.shell = "/bin/bash"

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
        str = str .. vim.fn.expand("%:t")
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
    local function switch_source_header()
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

    vim.keymap.set("n", "<A-o>", switch_source_header, {
        silent = true,
        desc = "Toggle between source and header",
    })
end)

-- -----------------------------------------------------------------------------
-- Comment Concealing (Rust)
-- -----------------------------------------------------------------------------

do
    local categories = {
        line = { ns = vim.api.nvim_create_namespace("hide_comments_line"), key = "comments_hide_line" },
        doc = { ns = vim.api.nvim_create_namespace("hide_comments_doc"), key = "comments_hide_doc" },
        block = { ns = vim.api.nvim_create_namespace("hide_comments_block"), key = "comments_hide_block" },
    }
    local ws_ns = vim.api.nvim_create_namespace("hide_comments_ws")
    local fold_lines_by_buf = {}

    local function classify_comment(node, bufnr)
        local node_type = node:type()
        local sr, sc = node:range()
        local line = vim.api.nvim_buf_get_lines(bufnr, sr, sr + 1, false)[1] or ""
        local text = line:sub(sc + 1)
        if node_type == "line_comment" then
            if text:match("^///") or text:match("^//!") then
                return "doc"
            end
            return "line"
        elseif node_type == "block_comment" then
            if text:match("^/%*%*") or text:match("^/%*!") then
                return "doc"
            end
            return "block"
        end
    end

    local function refresh(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        for _, cat in pairs(categories) do
            vim.api.nvim_buf_clear_namespace(bufnr, cat.ns, 0, -1)
        end
        vim.api.nvim_buf_clear_namespace(bufnr, ws_ns, 0, -1)

        local fold_lines = {}
        fold_lines_by_buf[bufnr] = fold_lines

        local any_hidden = false
        for _, cat in pairs(categories) do
            if vim.b[bufnr][cat.key] then
                any_hidden = true
                break
            end
        end
        if not any_hidden then
            return
        end

        local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "rust")
        if not ok or not parser then
            return
        end
        local tree = parser:parse()[1]
        if not tree then
            return
        end
        local root = tree:root()
        local query = vim.treesitter.query.parse("rust", "[(line_comment) (block_comment)] @comment")

        for _, node in query:iter_captures(root, bufnr, 0, -1) do
            local kind = classify_comment(node, bufnr)
            if kind and vim.b[bufnr][categories[kind].key] then
                local sr, sc, er, ec = node:range()
                -- Node ranges may include trailing newline (er=next row, ec=0); skip that row
                if ec == 0 and er > sr then
                    er = er - 1
                    ec = #(vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or "")
                end
                for row = sr, er do
                    local s_col = row == sr and sc or 0
                    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
                    local e_col = row == er and ec or #line
                    local before = line:sub(1, s_col)
                    if before:match("^%s*$") then
                        -- Comment-only line: conceal entire line, mark for folding
                        vim.api.nvim_buf_set_extmark(bufnr, ws_ns, row, 0, {
                            end_col = e_col,
                            conceal = "…",
                        })
                        fold_lines[row + 1] = true
                    else
                        -- Inline comment: conceal just the comment part
                        vim.api.nvim_buf_set_extmark(bufnr, categories[kind].ns, row, s_col, {
                            end_col = e_col,
                            conceal = "…",
                        })
                    end
                end
            end
        end
    end

    function _G.RustCommentFoldExpr(lnum)
        local lines = fold_lines_by_buf[vim.api.nvim_get_current_buf()]
        if lines and lines[lnum] then
            return "1"
        end
        return "0"
    end

    function _G.RustCommentFoldText()
        local count = vim.v.foldend - vim.v.foldstart + 1
        local line = vim.fn.getline(vim.v.foldstart)
        local indent = line:match("^(%s*)") or ""
        return {
            { indent .. "… " .. count .. " comments", "Comment" },
        }
    end

    local function apply(bufnr)
        refresh(bufnr)
        local any_hidden = false
        for _, cat in pairs(categories) do
            if vim.b[bufnr][cat.key] then
                any_hidden = true
                break
            end
        end
        if any_hidden then
            vim.wo.conceallevel = 2
            vim.wo.concealcursor = "nvic"
            vim.wo.foldenable = true
            vim.wo.foldminlines = 0
            vim.wo.foldmethod = "expr"
            vim.wo.foldexpr = "v:lua.RustCommentFoldExpr(v:lnum)"
            vim.wo.foldtext = "v:lua.RustCommentFoldText()"
            vim.wo.foldlevel = 0
            vim.opt_local.fillchars:append("fold: ")
        else
            vim.wo.conceallevel = 0
            vim.wo.foldenable = false
            vim.wo.foldmethod = "indent"
        end
    end

    local function make_toggle(kind, desc)
        vim.keymap.set("n", "<leader>c" .. kind:sub(1, 1), function()
            local bufnr = vim.api.nvim_get_current_buf()
            if vim.bo[bufnr].filetype ~= "rust" then
                return
            end
            vim.b[bufnr][categories[kind].key] = not vim.b[bufnr][categories[kind].key]
            apply(bufnr)
        end, { desc = desc })
    end

    make_toggle("line", "Toggle line comment visibility")
    make_toggle("doc", "Toggle doc comment visibility")
    make_toggle("block", "Toggle block comment visibility")

    vim.keymap.set("n", "<leader>cc", function()
        local bufnr = vim.api.nvim_get_current_buf()
        if vim.bo[bufnr].filetype ~= "rust" then
            return
        end
        local any_hidden = false
        for _, cat in pairs(categories) do
            if vim.b[bufnr][cat.key] then
                any_hidden = true
                break
            end
        end
        for _, cat in pairs(categories) do
            vim.b[bufnr][cat.key] = not any_hidden
        end
        apply(bufnr)
    end, { desc = "Toggle all comment visibility" })

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "rust",
        callback = function(args)
            for _, cat in pairs(categories) do
                vim.b[args.buf][cat.key] = true
            end
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                    apply(args.buf)
                end
            end)
            vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
                buffer = args.buf,
                callback = function()
                    refresh(args.buf)
                    if vim.wo.foldmethod == "expr" then
                        vim.wo.foldmethod = "expr"
                    end
                end,
            })
        end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        callback = function(args)
            fold_lines_by_buf[args.buf] = nil
        end,
    })
end
