return {
  {
    "mfussenegger/nvim-dap-python",
    dependencies = {
      "mfussenegger/nvim-dap"
    },
    config = function()
      require("dap-python").setup("debugpy-adapter")
      local dap = require("dap")

      for _, config in ipairs(dap.configurations.python) do
        config.console = "integratedTerminal"
      end
    end,
  },
}
