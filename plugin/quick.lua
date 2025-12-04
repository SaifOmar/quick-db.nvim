local quickDb = require("quick-db")
local db = quickDb:new()

vim.api.nvim_create_user_command("QuickConnect", function()
	db:Connect()
end, {})

vim.api.nvim_create_user_command("QuickConnectUserConnection", function()
	db:ConnectUserConnection()
end, {})
