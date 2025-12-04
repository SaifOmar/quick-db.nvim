local M = {}

local log_file = vim.fn.stdpath("cache") .. "/quickdb.log"

function M.log(msg)
	local f = io.open(log_file, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end

function M.ends_with_backslash_n_quote(str)
	if type(str) ~= "string" then
		return false
	end
	return str:sub(-3) == "}]\n"
end

function M.split(str, sep)
	local sep, fields = sep or " ", {}
	local pattern = string.format("([^%s]+)", sep)
	str:gsub(pattern, function(c)
		fields[#fields + 1] = c
	end)
	return fields
end
function M.flatten(tbl, out)
	out = out or {}
	for _, v in ipairs(tbl) do
		if type(v) == "table" then
			M.flatten(v, out)
		else
			table.insert(out, v)
		end
	end
	return out
end
-- formating needed to print the table in a buffer
--
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
