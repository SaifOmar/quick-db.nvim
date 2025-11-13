local env = {}
env.__index = env

local laravelAdapter = require("quick-db.adapters.laravel")

---@class EnvData
---@field private path string
---@field private data table

---@param path string
---@return table
function env:new(path)
	return setmetatable({
		path = path,
	}, self)
end

function env:parse()
	self.data = laravelAdapter:parse(self.path)
end

return env
