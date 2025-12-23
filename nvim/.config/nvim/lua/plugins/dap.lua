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
    }
  }
}
