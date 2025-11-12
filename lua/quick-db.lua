local DB = require("quick-db.connection")
local M = {}
local Env = require("quick-db.env")
local log = require("quick-db.utils")

M.DB = DB

---@param data table
---@param db DBConnection
local function matchValues(data, db)
	local key_mapping = {
		DB_DATABASE = "db",
		DB_CONNECTION = "type",
		DB_HOST = "host",
		DB_PORT = "port",
		DB_USER = "user",
		DB_PASSWORD = "password",
		DB_PATH = "path",
	}

	for key, value in pairs(data) do
		local db_field = key_mapping[key]
		if db_field then
			db[db_field] = value
		end
	end
end

M.connect = function()
	local path = vim.fn.getcwd()
	print(path)
	log.log("Path: " .. path)
	local env = Env:new(path)
	env:parse()
	print(env.data)
	log.log("Data: " .. vim.inspect(env.data))
	matchValues(env.data, DB)

	DB:fromEnv(env.data)
	DB:connect()
	print(DB.connected)
	log.log(DB.connected)
end

return M
