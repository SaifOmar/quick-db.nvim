local adapter = {}

---@param path string
--- @return boolean
local isPathCorrect = function(path)
	local file = vim.fn.findfile("artisan", path .. ";")
	if file ~= "" then
		return true
	end
	return false
end

---@param lines any
---@param data table
--- @return table
local function getDBConnectionValues(lines, data)
	for line in lines do
		if line:match("^%s*$") or line:match("^%s*#") then
			goto continue
		end
		local key, value = line:match("^(DB_%w+)%s*=%s*(.*)$")
		if key then
			value = value:match("^%s*(.-)%s*$")
			data[key] = value
		end
		::continue::
	end
	return data
end

---@param path string
--- @return table
local parseFile = function(path)
	local data = {}
	local file = io.open(path .. "/.env", "r")
	if not file then
		print("File not found")
		return data
	end
	data = getDBConnectionValues(file:lines(), data)
	file:close()
	return data
end

---@param path string
--- @return table
function adapter:parse(path)
	if isPathCorrect(path) then
		return parseFile(path)
	else
		print("Path is not correct")
		return {}
	end
end

return adapter
