local M = require("quick-db")

vim.api.nvim_create_user_command("QuickConnect", M.connect2, {})
-- vim.api.nvim_create_user_command("TestMe", M.Qtest, {})
-- vim.api.nvim_create_user_command("Testt", M.test, {})
