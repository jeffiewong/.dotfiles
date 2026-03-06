return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<F5>", function () require("dap").continue() end, desc = "DAP Continue" },
      { "<F9>", function () require("dap").toggle_breakpoint() end, desc = "DAP Toggle Breakpoint" },
      { "<F10>", function () require("dap").step_over() end, desc = "DAP Step Over" },
      { "<F11>", function () require("dap").step_into() end, desc = "DAP Step Into" },
      { "<F12>", function () require("dap").step_out() end, desc = "DAP Step Out" },
      { "<S-F5>", function () require("dap").terminate() end, desc = "DAP Terminate" },
      { "<C-F5>", function () require("dap").restart() end, desc = "DAP restart" },
    },
    opts = function()

      local colors = require("catppuccin.palettes").get_palette()
      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = colors.red })
      vim.api.nvim_set_hl(0, "DapStopped", { fg = colors.yellow })

      vim.schedule(function ()
        vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = ""})
        vim.fn.sign_define("DapStopped", { text = "➜", texthl = "DapStopped", linehl = "", numhl = ""})
        -- vim.fn.sign_define("DapBreakpointCondition", { text = "●", linehl = "", numhl = ""})
        -- vim.fn.sign_define("DapLogPoint", { text = "◆", linehl = "", numhl = ""})
      end)
    end,
  }
}
