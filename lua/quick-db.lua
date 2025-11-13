local DB = require("quick-db.connection")
local M = {}
local Env = require("quick-db.env")
local log = require("quick-db.utils")

M.connect = function()
	local path = vim.fn.getcwd()
	print(path)
	log.log("Path: " .. path)
	local env = Env:new(path)
	env:parse()
	print(env.data)
	log.log("Data: " .. vim.inspect(env.data))
	-- matchValues(env.data, DB)

	local db = DB:fromEnv(env.data)
	db:connect()
	log.log(vim.inspect(db))
end

return M
