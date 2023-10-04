return {
  "neoclide/coc.nvim",
  branch = "master",
  build = "yarn install --frozen-lockfile",
  config = function()
    vim.g.coc_global_extensions = {
      "coc-docker",
      "@yaegassy/coc-ansible",
      "coc-tsserver",
      "coc-zls",
      "coc-elixir",
      "coc-cmake",
      "coc-clangd",
      "coc-toml",
      "coc-yaml",
      "coc-xml",
      "coc-json",
      "coc-sh",
      "coc-pyright",
      "coc-clojure",
      "coc-rust-analyzer",
      "coc-java",
      "coc-markdownlint",
      "coc-snippets",
    }
  end,
}
