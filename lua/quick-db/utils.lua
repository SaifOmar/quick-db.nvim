local M = {}

local log_file = vim.fn.stdpath("cache") .. "/quickdb.log"

---@param msg any
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
	local fields
	sep, fields = sep or " ", {}
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

---@param lines_lens table
---@return string
function M._print_table(lines_lens)
	local table_lines = {}
	for i = 1, #lines_lens do
		table_lines[i] = string.rep("─", lines_lens[i])
	end
	return table.concat(table_lines, " ")
end

--- we need to take a table being the reocrds first get max len for each column
--- after that we can print the table with print_table
--- then we can just put each value in each column
---@param tbl table
function M._table_to_formated_table(tbl)
	local lines_lens = {}
	local keys = {}
	local values = {}

	for k, v in pairs(tbl) do
		if v == vim.NIL then
			v = ""
		end
		local nPostfix = math.max(string.len(tostring(v)), string.len(k))
		local postFix = M._postFix(k, nPostfix)

		if k == "id" then
			if M.__contains(keys, k) ~= true then
				table.insert(keys, 1, postFix)
			end
			table.insert(lines_lens, 1, nPostfix)
			table.insert(values, 1, tostring(v))
		else
			if M.__contains(keys, k) ~= true then
				table.insert(keys, postFix)
			end
			table.insert(lines_lens, nPostfix)
			table.insert(values, tostring(v))
		end
	end

	return {
		keys = keys,
		table_lines = M._print_table(lines_lens),
		values = values,
		lines_lens = lines_lens,
	}
end

---@param str string
---@param nPostfix number
---@return string
function M._postFix(str, nPostfix)
	local postFix = ""
	if nPostfix > 0 then
		postFix = string.rep(" ", (nPostfix - string.len(str)) + 1)
	end
	return str .. postFix
end

-- formating needed to print the table in a buffer
function M.table_to_lines(tbl)
	tbl = M._table_to_formated_table(tbl)

	local valuesStr = ""
	for i = 1, #tbl.values do
		valuesStr = valuesStr .. tbl.values[i] .. string.rep(" ", tbl.lines_lens[i] - string.len(tbl.values[i])) .. " "
	end

	return {
		table.concat(tbl.keys, ""), -- this is good enough
		tbl.table_lines,
		valuesStr,
	}
end

function M.__contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
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
