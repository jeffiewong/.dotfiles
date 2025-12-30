return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          -- Show hidden/ignored files by default
          files = {
            hidden = true,
            ignored = true,
          },
          grep = {
            hidden = true,
            ignored = true,
          },
        },
      },
    },
  },
}
