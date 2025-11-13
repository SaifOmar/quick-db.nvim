local M = require("quick-db")

vim.api.nvim_create_user_command("QuickConnect", M.connect, {})
vim.api.nvim_create_user_command("TestMe", M.Qtest, {})
