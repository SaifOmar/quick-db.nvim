local env = require("quick-db.env")

local CONNECTION = {}
CONNECTION.__index = DB

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
end
---@param env_data table
function CONNECTION:fromEnv(env_data)
	--
	local connection_data = {}
	connection_data.path = vim.fn.getcwd() .. "/database/" .. env_data.DB_DATABASE .. ".sqlite"
	connection_data.persistant = true
	connection_data.name = "sqlite"

	return self:new(getSpec(connection_data))
end

return CONNECTION

-- previewer = previewers.new_buffer_previewer({
--     define_preview = function(self, entry)
--         local lines = dict_to_pretty_lines(entry.value)
--         vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
--     end,
-- }),
