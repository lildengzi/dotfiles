return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {},
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
        "pyright",
        "ruff",
      },
    },
  },
}
