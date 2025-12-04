local quickDb = require("quick-db")
local db = quickDb:new()

vim.api.nvim_create_user_command("QuickConnect", function()
	db:Connect()
end, {})

vim.api.nvim_create_user_command("QuickConnectUserConnection", function()
	db:ConnectUserConnection()
end, {})

vim.api.nvim_create_user_command("QuickTest", function()
	db:Test()
end, {})
local map = vim.api.nvim_set_keymap
map("n", "<leader>tt", ":QuickTest<CR>", { noremap = true, silent = true })
