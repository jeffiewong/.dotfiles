return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      transparent_background = true,
      integrations = {
        snacks = {
          enabled = true,
          -- indent_scope_color = "mauve",
          indent_scope_color = "lavender",
        }
      },
      highlight_overrides = {
        all = function(colors)
          return {
            DapStoppedLine = { bg = colors.surface0 },
          }
        end,
      }
    }
  }
}
