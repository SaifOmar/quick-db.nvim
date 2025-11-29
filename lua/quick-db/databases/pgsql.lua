local mysql = {}

local utils = require("quick-db.utils")
---@param connection_data table
---@return table
mysql.spec = function(connection_data)
	return {
		name = "pgsql",
		cmd = "docker",
		connection_args = {
			"exec",
			"postgres17",
			"psql",
			"-h",
			connection_data.host,
			"-p",
			tostring(connection_data.port),
			"-U",
			connection_data.username,
			"-d",
			connection_data.database,
			"-t",
			"-A",
			"-F",
			",",
			"-c",
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
					decoded = decoded
				end
			end

			return decoded
		end,
		-- formats the reslts of the .tables query to be shown for the ui correctly
		-- @param data table
		formatTables = function(data)
			return data
			--
			-- local temp = {}
			-- for k, v in pairs(data) do
			-- 	temp[k] = v.TABLE_NAME
			-- end
			-- utils.log("temp is " .. vim.inspect(temp))
			-- return temp
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
				return "SELECT json_agg(table_name) FROM information_schema.tables WHERE table_schema = '"
					.. "public"
					.. "';"
			end,

			getTableRecords = function(table_name)
				return "SELECT json_agg(t) FROM (SELECT * FROM " .. table_name .. ") t" .. ";"
			end,
		},
	}
end

return mysql
