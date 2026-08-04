return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      local mason_path = vim.fn.stdpath("data") .. "/mason/packages"

      -- GDB (C/C++/Rust) — 系统已装
      dap.adapters.gdb = {
        type = "executable",
        command = "/usr/bin/gdb",
        args = { "-i", "dap", "-q" },
      }
      dap.configurations.c = {
        {
          name = "Launch (GDB)",
          type = "gdb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }
      dap.configurations.cpp = dap.configurations.c
      dap.configurations.rust = dap.configurations.c

      -- debugpy (Python)
      local debugpy_bin = mason_path .. "/debugpy/venv/bin/python"
      dap.adapters.python = {
        type = "executable",
        command = debugpy_bin,
        args = { "-m", "debugpy.adapter" },
      }
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
        },
      }
    end,
  },
}
