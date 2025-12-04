local quickDb = require("quick-db")
local db = quickDb:new()

vim.api.nvim_create_user_command("QuickConnect", function()
	db:connect()
end, {})
-- vim.api.nvim_create_user_command("TestMe", M.Qtest, {})
-- vim.api.nvim_create_user_command("Testt", M.test, {})
