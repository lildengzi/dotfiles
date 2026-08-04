return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "c", "cpp", "rust", "python", "lua", "vim", "vimdoc",
        "bash", "toml", "json", "yaml", "markdown", "markdown_inline",
        "regex", "diff", "cmake", "xml",
      },
    },
  },
}
