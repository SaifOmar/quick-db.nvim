local M = {}

local log_file = vim.fn.stdpath("cache") .. "/quickdb.log"

function M.log(msg)
	local f = io.open(log_file, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end
function M.flatten(input_table)
	local result = {}

	local function recurse_flatten(current_table)
		for _, value in pairs(current_table) do
			if type(value) == "table" then
				recurse_flatten(value) -- Recursively call for nested tables
			else
				table.insert(result, value) -- Add non-table elements to the result
			end
		end
	end

	recurse_flatten(input_table)
	return result
end

function M.ends_with_backslash_n_quote(str)
	if type(str) ~= "string" then
		return false
	end
	return str:sub(-3) == "}]\n"
end
-- formating needed to print the table in a buffer
function M.table_to_lines(tbl)
	local lines = {}
	for k, v in pairs(tbl) do
		-- convert nil Vim types
		v = v == vim.NIL and "nil" or tostring(v)

		-- remove all newlines
		v = v:gsub("[\r\n]", " ")

		table.insert(lines, string.format("%s = %s", k, v))
	end
	return lines
end

-- Takes a record and returns concated string values of tabls minus id and *_at
---@param record table
---@return string
function M.expand(record)
	local str = ""

	for k, v in pairs(record) do
		if
			v ~= vim.NIL
			and k ~= "id"
			and k ~= "created_at"
			and k ~= "updated_at"
			and k ~= "deleted_at"
			-- and count < 10
		then
			str = str .. tostring(v) .. " "
		end
	end

	return str
end
return M
