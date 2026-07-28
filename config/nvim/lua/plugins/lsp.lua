return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {},
        clangd = {},
        pyright = {},
        ruff = { init = { settings = {} } },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        "rust-analyzer",
        "clangd",
        "pyright",
        "ruff",
      },
    },
  },
}
