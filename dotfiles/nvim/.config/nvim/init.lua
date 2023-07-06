-- Providers: HM uses wrapRc=false; hosts are set via extraWrapperArgs in home.nix.
-- Disable legacy providers we do not use (avoids checkhealth noise if wrapper changes).
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

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

--- Runs an external formatter command synchronously.
--- Formats via a temp file so the original is never touched — Neovim's own
--- :w writes the formatted buffer, avoiding mtime mismatch warnings.
--- @param cmd string The command to execute
--- @param args table Command arguments (must include the file path to format)
local function run_external_formatter(cmd, args)
    if vim.fn.executable(cmd) ~= 1 then
        vim.notify("Formatter not found: " .. cmd, vim.log.levels.WARN)
        return
    end
    local view = vim.fn.winsaveview()
    local file = vim.fn.expand("%:p")
    local dir = vim.fn.fnamemodify(file, ":h")
    local ext = vim.fn.fnamemodify(file, ":e")
    local tmpfile = dir .. "/.nvim_fmt_" .. vim.fn.getpid() .. "." .. ext

    vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), tmpfile)

    -- Swap the real file path for the temp file in the formatter args
    local tmp_args = {}
    for _, arg in ipairs(args) do
        if vim.fn.fnamemodify(arg, ":p") == file then
            tmp_args[#tmp_args + 1] = tmpfile
        else
            tmp_args[#tmp_args + 1] = arg
        end
    end

    vim.fn.system(vim.list_extend({ cmd }, tmp_args))

    local new_lines = vim.fn.readfile(tmpfile)
    vim.fn.delete(tmpfile)

    -- Apply only changed lines to preserve buffer state (folds, marks, etc.)
    local cur_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local first = 1
    local max_common = math.min(#new_lines, #cur_lines)
    while first <= max_common and new_lines[first] == cur_lines[first] do
        first = first + 1
    end
    if first <= max_common or #new_lines ~= #cur_lines then
        local last_new = #new_lines
        local last_cur = #cur_lines
        while last_new >= first and last_cur >= first and new_lines[last_new] == cur_lines[last_cur] do
            last_new = last_new - 1
            last_cur = last_cur - 1
        end
        local replacement = {}
        for i = first, last_new do
            replacement[#replacement + 1] = new_lines[i]
        end
        vim.api.nvim_buf_set_lines(0, first - 1, last_cur, false, replacement)
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
    end
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
            source = true,
            border = "single",
            severity = { min = vim.diagnostic.severity.HINT },
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
        ty = {
            cmd = { "ty", "server" },
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
            root_dir = function(bufnr)
                local root = vim.fs.root(bufnr, {
                    "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel",
                    "BUILD.bazel", "Cargo.toml", ".git", ".jj",
                })
                if root then
                    return root
                end
                local bufname = vim.api.nvim_buf_get_name(bufnr)
                if bufname == "" then
                    return nil
                end
                local fallback = vim.fn.fnamemodify(bufname, ":p:h")
                vim.notify(
                    "rust-analyzer: no workspace root found, falling back to " .. fallback,
                    vim.log.levels.WARN
                )
                return fallback
            end,
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
                packageManager = "npm",
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
                    workspace = {
                        checkThirdParty = false,
                        library = vim.api.nvim_get_runtime_file("", true),
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
        -- als = {  -- agda-language-server is unmaintained
        --     cmd = { "als" },
        --     filetypes = { "agda" },
        --     root_markers = { "*.agda-lib", ".git", ".jj" },
        -- },
        marksman = {
            cmd = { "marksman", "server" },
            filetypes = { "markdown" },
            root_markers = { ".marksman.toml", ".git", ".jj" },
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
        "*.cc",
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
        "*.lean", -- Lean
        "*.md", -- Markdown
    },
    callback = function()
        -- Avoid spawning a formatter when nothing changed (e.g. plain :w on a clean buffer)
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
        elseif file:match("%.cc$") or file:match("%.cpp$") or file:match("%.hpp$") or file:match("%.c$") or file:match("%.h$") then
            run_external_formatter("clang-format", { "-i", file })
        elseif file:match("%.sh$") or file:match("%.bash$") or file:match("%.zsh$") then
            run_external_formatter("shfmt", { "-w", file })
        elseif file:match("%.py$") then
            run_external_formatter("ruff", { "format", "--quiet", file })
        elseif file:match("%.ts$") or file:match("%.tsx$") or file:match("%.js$") or file:match("%.jsx$") or file:match("%.md$") then
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
        elseif file:match("%.lean$") then
            vim.lsp.buf.format({ async = false })
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
            pcall(vim.treesitter.start)
        end,
    })
end)

later(function()
    local hipat = require("mini.hipatterns")
    hipat.setup({
        highlighters = {
            fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
            hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
            todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
            note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
            hex_color = hipat.gen_highlighter.hex_color(),
        },
    })
end)

-- -----------------------------------------------------------------------------
-- Symbol Picker
-- -----------------------------------------------------------------------------

later(function()
    require("mini.pick").setup()
    local extra = require("mini.extra")
    extra.setup()

    vim.keymap.set("n", "<leader>ss", function()
        extra.pickers.lsp({ scope = "document_symbol" })
    end, { desc = "List document symbols" })

    vim.keymap.set("n", "<leader>sS", function()
        extra.pickers.lsp({ scope = "workspace_symbol" })
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
    vim.api.nvim_create_autocmd("BufWritePre", {
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

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    callback = function()
        if vim.fn.getcmdwintype() == "" then
            vim.cmd.checktime()
        end
    end,
})

-- -----------------------------------------------------------------------------
-- Search
-- -----------------------------------------------------------------------------

vim.o.hlsearch = true
vim.o.path = vim.o.path .. ",**"
vim.o.wildmode = "list:longest,full"
vim.o.wildignore =
    ".git,.hg,.svn,*.aux,*.out,*.toc,*.o,*.obj,*.exe,*.dll,*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp,*.avi,*.divx,*.mp4,*.webm,*.mov,*.mkv,*.vob,*.mpg,*.mpeg,*.mp3,*.oga,*.ogg,*.wav,*.flac,*.otf,*.ttf,*.doc,*.pdf,*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.swp,*.lock,.DS_Store,._*"

-- -----------------------------------------------------------------------------
-- Folding
-- -----------------------------------------------------------------------------

vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldenable = true
vim.o.foldlevel = 99
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
    callback = function()
        vim.wo.cursorline = true
    end,
})

vim.api.nvim_create_autocmd("BufLeave", {
    callback = function()
        vim.wo.cursorline = false
    end,
})

-- Show relative numbers only in active buffer and normal mode
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave" }, {
    callback = function()
        vim.wo.relativenumber = true
    end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter" }, {
    callback = function()
        vim.wo.relativenumber = false
    end,
})

-- Underline cursorline in insert mode (replace whole highlight to clear bg/fg)
vim.api.nvim_create_autocmd("InsertEnter", {
    callback = function()
        vim.api.nvim_set_hl(0, "CursorLine", { underline = true })
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    callback = function()
        vim.api.nvim_set_hl(0, "CursorLine", {})
    end,
})

-- -----------------------------------------------------------------------------
-- Restore Cursor Position
-- -----------------------------------------------------------------------------

later(function()
    require("mini.misc").setup_restore_cursor()
end)

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
    local fold_lines_by_buf = {}
    local fold_state_by_buf = {}

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
                local multiline = er > sr
                for row = sr, er do
                    local s_col = row == sr and sc or 0
                    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
                    local e_col = row == er and ec or #line
                    local before = line:sub(1, s_col)
                    if before:match("^%s*$") then
                        -- Comment-only line: fold only for multi-line blocks or consecutive line runs
                        if node:type() == "line_comment" or multiline then
                            fold_lines[row + 1] = true
                        end
                    elseif multiline then
                        -- Inline comment: conceal only when the comment spans multiple lines
                        vim.api.nvim_buf_set_extmark(bufnr, categories[kind].ns, row, s_col, {
                            end_col = e_col,
                            conceal = "…",
                        })
                    end
                end
            end
        end

        -- Drop isolated line comments; multi-line blocks are already >=2 lines
        local to_remove = {}
        for lnum in pairs(fold_lines) do
            if not fold_lines[lnum - 1] and not fold_lines[lnum + 1] then
                to_remove[#to_remove + 1] = lnum
            end
        end
        for _, lnum in ipairs(to_remove) do
            fold_lines[lnum] = nil
        end
    end

    function _G.RustCommentFoldExpr(lnum)
        local lines = fold_lines_by_buf[vim.api.nvim_get_current_buf()]
        local treesitter_expr = vim.treesitter.foldexpr(lnum)
        if not lines or not lines[lnum] then
            return treesitter_expr
        end

        local treesitter_level = tonumber(tostring(treesitter_expr):match("%d+")) or 0
        local comment_level = treesitter_level + 1
        if not lines[lnum - 1] then
            return ">" .. comment_level
        end
        return tostring(comment_level)
    end

    function _G.RustCommentFoldText()
        local lines = fold_lines_by_buf[vim.api.nvim_get_current_buf()]
        if not lines or not lines[vim.v.foldstart] then
            return vim.fn.foldtext()
        end

        local count = vim.v.foldend - vim.v.foldstart + 1
        local line = vim.fn.getline(vim.v.foldstart)
        local indent = line:match("^(%s*)") or ""
        return {
            { indent .. "… " .. count .. " comments", "Comment" },
        }
    end

    local function any_hidden(bufnr)
        for _, cat in pairs(categories) do
            if vim.b[bufnr][cat.key] then
                return true
            end
        end
        return false
    end

    local function comment_fold_starts(bufnr)
        local starts = {}
        local lines = fold_lines_by_buf[bufnr] or {}
        for lnum in pairs(lines) do
            if not lines[lnum - 1] then
                starts[#starts + 1] = lnum
            end
        end
        table.sort(starts)
        return starts
    end

    local function is_fold_start(lnum)
        return tostring(_G.RustCommentFoldExpr(lnum)):match("^>") ~= nil
    end

    local function capture_fold_state(bufnr, winid)
        if not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_win_get_buf(winid) ~= bufnr then
            return
        end

        local closed_folds = {}
        vim.api.nvim_win_call(winid, function()
            for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
                if vim.fn.foldclosed(lnum) == lnum then
                    closed_folds[lnum] = true
                end
            end
        end)
        fold_state_by_buf[bufnr] = {
            level = vim.api.nvim_get_option_value("foldlevel", { win = winid }),
            closed = closed_folds,
        }
    end

    local function restore_fold_state(bufnr, winid)
        local state = fold_state_by_buf[bufnr]
        if state == nil then
            state = { level = 99, closed = {} }
            for _, lnum in ipairs(comment_fold_starts(bufnr)) do
                state.closed[lnum] = true
            end
        end

        vim.api.nvim_win_call(winid, function()
            local view = vim.fn.winsaveview()
            vim.wo.foldlevel = state.level
            vim.cmd("normal! zX")
            for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
                if state.closed[lnum] and is_fold_start(lnum) and vim.fn.foldclosed(lnum) == -1 then
                    vim.api.nvim_win_set_cursor(winid, { lnum, 0 })
                    vim.cmd("normal! zc")
                end
            end
            vim.fn.winrestview(view)
        end)
    end

    -- Window-local options must target the window that shows `bufnr`. Capture
    -- the winid at call time so a scheduled callback doesn't bleed into a
    -- different window the user has since switched to.
    local function apply(bufnr, winid)
        winid = winid or vim.api.nvim_get_current_win()
        if not vim.api.nvim_win_is_valid(winid) then
            return
        end
        if vim.api.nvim_win_get_buf(winid) ~= bufnr then
            return
        end

        refresh(bufnr)
        local hidden = any_hidden(bufnr)

        vim.api.nvim_win_call(winid, function()
            if hidden then
                vim.wo.conceallevel = 2
                vim.wo.concealcursor = "vc"
                vim.wo.foldenable = true
                vim.wo.foldminlines = 0
                vim.wo.foldmethod = "expr"
                vim.wo.foldexpr = "v:lua.RustCommentFoldExpr(v:lnum)"
                vim.wo.foldtext = "v:lua.RustCommentFoldText()"
                vim.wo.foldlevel = 99
                if not vim.wo.fillchars:match("fold:") then
                    vim.opt_local.fillchars:append("fold: ")
                end
            else
                vim.wo.conceallevel = 0
                vim.wo.foldenable = true
                vim.wo.foldmethod = "expr"
                vim.wo.foldexpr = "v:lua.RustCommentFoldExpr(v:lnum)"
                vim.wo.foldlevel = 99
            end
        end)

        restore_fold_state(bufnr, winid)
    end

    local function open_fold_or_right()
        if vim.fn.foldclosed(".") ~= -1 then
            vim.cmd("normal! zo")
        else
            vim.cmd("normal! l")
        end
    end
    local function close_fold_or_left()
        local line = vim.api.nvim_get_current_line()
        local first_nonblank_col = #(line:match("^%s*") or "") + 1
        local at_or_before_content = vim.fn.col(".") <= first_nonblank_col
        if at_or_before_content and vim.fn.foldlevel(".") > 0 and vim.fn.foldclosed(".") == -1 then
            vim.cmd("normal! zc")
        else
            vim.cmd("normal! h")
        end
    end

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "rust",
        callback = function(args)
            for _, cat in pairs(categories) do
                vim.b[args.buf][cat.key] = true
            end

            local winid = vim.api.nvim_get_current_win()
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                    apply(args.buf, winid)
                end
            end)

            -- BufReadPost covers autoread reloads, where FileType does not refire
            -- but buffer content changes underneath the cached fold table.
            vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufReadPost" }, {
                buffer = args.buf,
                callback = function()
                    refresh(args.buf)
                end,
            })

            local function toggle(kind)
                capture_fold_state(args.buf, vim.api.nvim_get_current_win())
                vim.b[args.buf][categories[kind].key] = not vim.b[args.buf][categories[kind].key]
                apply(args.buf)
            end
            local kopts = function(desc) return { buffer = args.buf, desc = desc } end

            vim.keymap.set("n", "<leader>cl", function() toggle("line") end, kopts("Toggle line comment visibility"))
            vim.keymap.set("n", "<leader>cd", function() toggle("doc") end, kopts("Toggle doc comment visibility"))
            vim.keymap.set("n", "<leader>cb", function() toggle("block") end, kopts("Toggle block comment visibility"))

            vim.keymap.set("n", "<leader>cc", function()
                capture_fold_state(args.buf, vim.api.nvim_get_current_win())
                local target = not any_hidden(args.buf)
                for _, cat in pairs(categories) do
                    vim.b[args.buf][cat.key] = target
                end
                apply(args.buf)
            end, kopts("Toggle all comment visibility"))

            vim.keymap.set("n", "l", open_fold_or_right, kopts("Open fold or move right"))
            vim.keymap.set("n", "<Right>", open_fold_or_right, kopts("Open fold or move right"))
            vim.keymap.set("n", "h", close_fold_or_left, kopts("Close fold or move left"))
            vim.keymap.set("n", "<Left>", close_fold_or_left, kopts("Close fold or move left"))

            vim.api.nvim_create_autocmd({ "BufWinLeave", "WinLeave" }, {
                buffer = args.buf,
                callback = function(event)
                    capture_fold_state(event.buf, vim.api.nvim_get_current_win())
                end,
            })

            vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
                buffer = args.buf,
                callback = function(event)
                    local entered_winid = vim.api.nvim_get_current_win()
                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(event.buf) then
                            apply(event.buf, entered_winid)
                        end
                    end)
                end,
            })
        end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        callback = function(args)
            fold_lines_by_buf[args.buf] = nil
            fold_state_by_buf[args.buf] = nil
        end,
    })
end
