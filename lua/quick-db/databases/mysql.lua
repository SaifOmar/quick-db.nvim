local mysql = {}

local utils = require("quick-db.utils")
---@param connection_data table
---@return table
mysql.spec = function(connection_data)
	return {
		name = "mysql",
		cmd = "docker",
		connection_args = {
			"exec",
			"mysql8",
			"mysqlsh",
			"--quiet-start=2",
			"--json",
			"--user=" .. connection_data.username,
			"--host=" .. connection_data.host,
			"--port=" .. connection_data.port,
			"--password=" .. connection_data.password,
			"--database=" .. connection_data.database,
			"-e",
		},
		persistant = connection_data.persistant or true,
		query_builder = function(query)
			return query .. ";\n"
		end,
		---@return table
		parse = function(data)
			if data == nil then
				return {}
			end
			local decoded = {}
			local ok

			if type(data) == "string" then
				ok, decoded = pcall(vim.json.decode, data)
				if ok then
					decoded = decoded.rows
				end
			end

			return decoded
		end,
		-- formats the reslts of the .tables query to be shown for the ui correctly
		-- @param data table
		formatTables = function(data)
			utils.log("data is " .. vim.inspect(data))

			local temp = {}
			for k, v in pairs(data) do
				temp[k] = v.TABLE_NAME
			end
			utils.log("temp is " .. vim.inspect(temp))
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
				return "SELECT table_name FROM information_schema.tables WHERE table_schema = '"
					.. connection_data.database
					.. "';"
			end,
			getTableRecords = function(table_name)
				return "SELECT * FROM " .. table_name .. ";"
			end,
		},
	}
end

return mysql
