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

---@param type string
---@return table
local function laravelDefatuls(type)
	local dbDefaults = {
		sqlite = {
			DB_CONNECTION = "sqlite",
			DB_DATABASE = vim.fn.getcwd() .. "/database/database.sqlite",
		},

		mysql = {
			DB_CONNECTION = "mysql",
			DB_HOST = "127.0.0.1",
			DB_PORT = "3306",
			DB_USERNAME = "root",
			DB_PASSWORD = "",
			DB_DATABASE = "",
		},
		pgsql = {
			DB_CONNECTION = "pgsql",
			DB_HOST = "127.0.0.1",
			DB_PORT = "5432",
			DB_USERNAME = "root",
			Db_PASSWORD = "",
		},
	}
	return dbDefaults[type] or {}
end

---@param data table
--- @return table
local function populateWithDefaults(data)
	for key, value in pairs(laravelDefatuls(data.DB_CONNECTION)) do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
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
	require("quick-db.utils").log(vim.inspect(data))
	return populateWithDefaults(data)
end

---@param path string
--- @return table
local parseFile = function(path)
	local data = {}
	local file = io.open(path .. "/.env", "r")
	if not file then
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
		return {}
	end
end

return adapter
