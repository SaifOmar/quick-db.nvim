local mysql = {}

local utils = require("quick-db.utils")
---@param connection_data table
---@return table
mysql.spec = function(connection_data)
	local spec = {}
	spec.name = "mysql"
	spec.cmd = "docker"
	spec.database = connection_data.database
	spec.connection_args = {
		"exec",
		"gobydb",
		"mysqlsh",
		"--quiet-start=2",
		"--json",
		"--user=" .. (connection_data.username or "root"),
		"--host=" .. (connection_data.host or "localhost"),
		"--port=" .. (connection_data.port or "3306"),
		"--password=" .. (connection_data.password or ""),
		"--database=" .. (connection_data.database or ""),
		"-e",
	}
	spec.persistant = connection_data.persistant or true

	spec.query_builder = function(query)
		return query .. ";\n"
	end
	---@return table
	spec.parse = function(data)
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
	end

	-- formats the reslts of the .tables query to be shown for the ui correctly
	-- @param data table
	spec.formatTables = function(data)
		utils.log("data is " .. vim.inspect(data))

		local temp = {}
		for k, v in pairs(data) do
			temp[k] = v.TABLE_NAME
		end
		utils.log("temp is " .. vim.inspect(temp))
		return temp
	end

	-- formats the reslts of the table select query to be shown for the ui correctly
	spec.formatTableResults = function(data)
		local lines = {}
		for k, v in pairs(data) do
			v = v == vim.NIL and "nil" or tostring(v)
			v = v:gsub("[\r\n]", " ")
			table.insert(lines, string.format("%-20s = %s", k, v))
		end
		return data
	end

	spec.assignUserArgs = function(args)
		local processed = {}

		for _, v in ipairs(args) do
			table.insert(processed, v)
			local db = v:match("^%-%-database=(.+)$")
			if db then
				spec.database = db
			end
		end

		spec.connection_args = processed
	end

	spec.checkConnection = function()
		local stobj = vim.system(utils.flatten({
			spec.cmd,
			spec.connection_args,
			"SELECT 1;",
		})):wait()
		if stobj.code ~= 0 then
			return false
		end

		local ok, data = pcall(vim.json.decode, stobj.stdout)

		if not ok then
			return false
		end

		return data.hasData == true
	end

	spec.callbacks = {}

	spec.queries = {
		getTables = function()
			return "SELECT table_name FROM information_schema.tables WHERE table_schema = '" .. spec.database .. "';"
		end,
		getTableRecords = function(table_name)
			return "SELECT * FROM " .. table_name .. ";"
		end,
	}

	return spec
end

return mysql
