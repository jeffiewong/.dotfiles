-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Move up half page" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Move down half page" })
vim.keymap.set("n", "<Tab>", ">>", { desc = "Indent" })
vim.keymap.set("n", "<S-Tab>", "<<", { desc = "Un-indent" })

vim.keymap.set("i", "kj", "<Esc>", { desc = "Esc" })
vim.keymap.set("i", "<S-Tab>", "<C-d>", { desc = "Un-indent" })

vim.keymap.set("v", "<Tab>", ">gv", { desc = "Indent" })
vim.keymap.set("v", "<S-Tab>", "<gv", { desc = "Un-indent" })
