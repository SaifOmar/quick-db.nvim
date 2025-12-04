local env = {}
env.__index = env
local utils = require("quick-db.utils")

---@class EnvData
---@field private path string
---@field private data table
---@field public supportedFrameworks table

---@param path string
---@return table
function env:new(path)
	self.supportedFrameworks = {
		"laravel",
		"django",
	}
	return setmetatable({
		path = path,
		supportedFrameworks = self.supportedFrameworks,
	}, self)
end

function env:parse()
	local data = nil
	for _, framework in ipairs(self.supportedFrameworks) do
		local adapter = require("quick-db.adapters." .. framework)
		data = adapter:parse(self.path)
		if data ~= nil and data ~= {} and next(data) ~= nil then
			self.data = data
			break
		end
	end
	return self
end

return env
