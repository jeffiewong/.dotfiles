return {
  {
    "mfussenegger/nvim-dap",
    opts = function ()
      local dap = require("dap")

      if not dap.adapters["pwa-node"] then
        dap.adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "js-debug-adapter",
            args = { "${port}" },
          },
        }
      end

      for _, language in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
        dap.configurations[language] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Node: Launch (npm run dev)",
            runtimeExecutable = "npm",
            runtimeArgs = { "run", "dev" },
            -- serverReadyAction = {
            --   pattern = "started server on .+, url: (https?://.+)",
            --   uriFormat = "%s",
            --   action = "openExternally",
            -- },
            skipFiles = { "<node_internals>/**" },
            sourceMaps = true,
            autoAttachChildProcesses = true,
            resolveSourceMapLocations = {
              "${workspaceFolder}/**",
              "!**/node_modules/**",
            },
          },
          {
            -- Start local server with: NODE_OPTIONS='--inspect' npm run dev
            type = "pwa-node",
            request = "attach",
            name = "Next.js: Attach",
            -- processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            skipFiles = { "<node_internals>/**" },
            sourceMaps = true,
            autoAttachChildProcesses = true,
            resolveSourceMapLocations = {
              "${workspaceFolder}/**",
              "!**/node_modules/**",
            },
            port = 9230,
            -- outputCapture = "std",
            -- console = "integratedTerminal",
          },
        }
      end
    end,
  }
}
