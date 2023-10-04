return {
    "overcache/NeoSolarized",
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      vim.opt.background = "dark"
      vim.cmd.colorscheme 'NeoSolarized'
    end,
}
