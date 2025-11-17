local sqlite = {}

---@param connection_data table
---@return table
sqlite.spec = function(connection_data)
	return {
		name = "sqlite",
		cmd = "sqlite3",
		connection_args = { "-json", connection_data.path },
		persistant = connection_data.persistant or true,
		query_builder = function(query)
			return query .. ";\n"
		end,
		---@return table
		parse = function(data)
			return vim.json.decode(data)
		end,
		format_tables = function(data)
			local temp = {}
			for i, table in ipairs(data) do
				temp[i] = table.name
			end
			return temp
		end,
		format_table_results = function(data)
			local lines = {}
			for k, v in pairs(data) do
				v = v == vim.NIL and "nil" or tostring(v)
				v = v:gsub("[\r\n]", " ")
				table.insert(lines, string.format("%-20s = %s", k, v))
			end
			return data
		end,
	}
end

return sqlite
