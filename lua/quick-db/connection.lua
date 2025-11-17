local env = require("quick-db.env")

local DB = {}
DB.__index = DB

---@class DBConnection
---@field private db string
---@field private host? string
---@field private port? string
---@field private user? string
---@field private path? string
---@field private password? string
---@field private connected boolean
---@field type? string

---@param db string
---@param host? string
---@param port? string
---@param user? string
---@param path? string
---@param password? string
---@param type? string
function DB:new(db, host, port, user, password, path, type)
	-- self.db = db
	-- self.host = host
	-- self.port = port
	-- self.user = user
	-- self.password = password

	return setmetatable({
		db = db,
		host = host,
		port = port,
		user = user,
		password = password,
		path = path,
		type = type,
		connected = false,
	}, self)
	-- return self
end

---@param data table
--- @return DBConnection
function DB:fromEnv(data)
	local config = {
		db = nil,
		host = nil,
		port = nil,
		user = nil,
		password = nil,
		path = nil,
		type = nil,
	}

	local key_mapping = {
		DB_CONNECTION = "type",
		DB_DATABASE = "db",
		DB_HOST = "host",
		DB_PORT = "port",
		DB_USER = "user",
		DB_PASSWORD = "password",
		DB_PATH = "path",
	}

	for key, value in pairs(data) do
		local field = key_mapping[key]
		if field then
			-- Handle empty strings as nil
			config[field] = (value ~= "" and value ~= nil) and value or nil
		end
	end

	config.path = vim.fn.getcwd() .. "/database/" .. config.db .. ".sqlite"
	return self:new(config.db, config.host, config.port, config.user, config.password, config.path, config.type)
end

function DB:connect(job_start)
	local db
	if self.type == "sqlite" then
		db = require("quick-db.databases.sqlite")
	end
	-- if self.type == "mysql" then
	--   db = require("quick-db.databases.mysql")
	-- end
	-- if self.type == "postgres" then
	--   db = require("quick-db.databases.postgres")
	-- end
	local job_id = db.connect(self, job_start)
	require("quick-db.utils").log(vim.inspect(job_id) .. " is job id")
	if job_id then
		self.connected = true
	end
	-- db.getTables(send)
	return job_id
end
function DB:getPath()
	return self.path
end
return DB
