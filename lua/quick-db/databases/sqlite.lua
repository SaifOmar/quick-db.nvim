local sqlite = {}

local utils = require("quick-db.utils")

---@param connection_data table
---@return table
sqlite.spec = function(connection_data)
	return {
		name = "sqlite",
		cmd = "sqlite3",
		path = connection_data.path,
		connection_args = { "-json", connection_data.path },
		persistant = connection_data.persistant or true,
		queryBuilder = function(query)
			-- wrap in quotes for sqlite
			query = '"' .. query .. '"'
			vim.notify("query is " .. vim.inspect(query))
			return query
		end,

		specialChecks = function(data)
			if type(data) ~= "string" then
				return false
			end
			return data:sub(-3) == "}]\n"
		end,

		---@return table
		parse = function(data)
			return vim.json.decode(data)
		end,
		-- formats the reslts of the .tables query to be shown for the ui correctly
		-- @param data table
		formatTables = function(data)
			local temp = {}
			for k, v in pairs(data) do
				temp[k] = v.name
			end
			return temp
		end,

		-- formats the reslts of the table select query to be shown for the ui correctly
		formatTableResults = function(data)
			local lines = {}
			for k, v in pairs(data) do
				v = v == vim.NIL and "nil" or tostring(v)
				v = v:gsub("[\r\n]", " ")
				table.insert(lines, string.format("%-20s = %s", k, v))
			end
			return data
		end,

		callbacks = {},
		queries = {
			getTables = function()
				return "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';"
			end,
			getTableRecords = function(table_name)
				return "SELECT * FROM " .. table_name .. ";"
			end,
		},
	}
end

return sqlite
