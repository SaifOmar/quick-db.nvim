local sqlite = {}

local utils = require("quick-db.utils")

---@param connection_data table
---@return table
sqlite.spec = function(connection_data)
	local spec = {}
	spec.name = "sqlite"
	spec.cmd = "sqlite3"
	spec.path = connection_data.path
	spec.connection_args = { "-json", connection_data.path }
	spec.persistant = connection_data.persistant or true
	spec.queryBuilder = function(query)
		-- wrap in quotes for sqlite
		query = '"' .. query .. '"'
		vim.notify("query is " .. vim.inspect(query))
		return query
	end

	spec.specialChecks = function(data)
		if type(data) ~= "string" then
			return false
		end
		return data:sub(-3) == "}]\n"
	end

	---@return table
	spec.parse = function(data)
		if data == nil then
			return {}
		end

		if type(data) == "string" then
			local ok, decoded = pcall(vim.json.decode, data)
			if ok then
				return decoded
			else
				return {}
			end
		end

		-- Case 2: data is a table of JSON strings
		if type(data) == "table" then
			local out = {}

			for _, item in ipairs(data) do
				if type(item) == "string" then
					local ok, decoded = pcall(vim.json.decode, item)
					if ok then
						table.insert(out, decoded)
					end
				end
			end

			return out
		end

		-- Fallback
		return {}
	end
	-- formats the reslts of the .tables query to be shown for the ui correctly
	-- @param data table
	spec.formatTables = function(data)
		local temp = {}
		for k, v in pairs(data) do
			temp[k] = v.name
		end
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
		local path = nil

		table.insert(processed, "-json")

		for _, v in ipairs(args) do
			if v ~= "-json" then
				table.insert(processed, v)

				local match = v:match("([%w%p]+%.sqlite)$")
				if match then
					path = match
				end
			end
		end

		if not path then
			path = vim.fn.getcwd() .. "/database/database.sqlite"
			table.insert(processed, path)
		end

		spec.connection_args = processed
		spec.path = path
	end
	-- checks if the sqlite file is readable thus can be connected to
	spec.checkConnection = function()
		if vim.fn.filereadable(spec.path) == 1 then
			return true
		else
			vim.notify("file is not readable")
			return false
		end
	end

	spec.callbacks = {}
	spec.queries = {
		getTables = function()
			return "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';"
		end,
		getTableRecords = function(table_name)
			return "SELECT * FROM " .. table_name .. ";"
		end,
	}
	return spec
end

return sqlite
