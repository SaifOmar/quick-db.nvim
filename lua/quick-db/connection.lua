local env = require("quick-db.env")
local CONNECTION = {}
CONNECTION.__index = CONNECTION

---@class CONNECTION
---@filed public spec table

---@param spec table
function CONNECTION:new(spec)
	return setmetatable(spec, self)
end

local function getSpec(connection_data)
	if connection_data.name == "sqlite" then
		return require("quick-db.databases.sqlite").spec(connection_data)
	end
	if connection_data.name == "mysql" then
		return require("quick-db.databases.mysql").spec(connection_data)
	end
	if connection_data.name == "pgsql" then
		return require("quick-db.databases.pgsql").spec(connection_data)
	end
end

--- this needs to be changed (it's currently tailored only to laravel)
---@param env_data table
function CONNECTION:fromEnv(env_data)
	local connection_data = {}
	connection_data.path = vim.fn.getcwd() .. "/database/" .. env_data.DB_DATABASE .. ".sqlite"
	connection_data.persistant = true
	connection_data.name = env_data.DB_CONNECTION
	connection_data.username = env_data.DB_USERNAME
	connection_data.password = env_data.DB_PASSWORD
	connection_data.host = env_data.DB_HOST
	connection_data.port = env_data.DB_PORT
	connection_data.database = env_data.DB_DATABASE

	return self:new(getSpec(connection_data))
end

return CONNECTION
