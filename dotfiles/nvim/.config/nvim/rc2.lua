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
    source = 'EdenEast/nightfox.nvim',
  })
end)
later(function()
  vim.o.termguicolors = true
  vim.cmd.colorscheme('nightfox')
end)
-- now(function()
--   require('mini.notify').setup()
--   vim.notify = require('mini.notify').make_notify()
-- end)
-- now(function() require('mini.icons').setup() end)
-- now(function() require('mini.tabline').setup() end)
-- now(function() require('mini.statusline').setup() end)

-- later(function() require('mini.ai').setup() end)
-- later(function() require('mini.comment').setup() end)
-- later(function() require('mini.pick').setup() end)
-- later(function() require('mini.surround').setup() end)

-- vim.o.showmode = false
-- require('mini.ai').setup()         -- a/i textobjects
-- require('mini.align').setup()      -- aligning
-- require('mini.bracketed').setup()  -- unimpaired bindings with TS
-- require('mini.comment').setup()    -- TS-wise comments
-- require('mini.icons').setup()      -- minimal icons
-- require('mini.jump').setup()       -- fFtT work past a line
-- require('mini.pairs').setup()      -- pair brackets
-- require('mini.statusline').setup() -- minimal statusline
