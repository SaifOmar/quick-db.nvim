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
	-- print(vim.inspect(str:sub(-3)))
	if type(str) ~= "string" then
		return false
	end
	return str:sub(-3) == "}]\n"
	-- if type(str) ~= "string" then
	-- 	return false
	-- end
	-- return str:sub(-3) == "\\n'"
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
return M
