local adapter = {}

---@param t string
---@return table
local function djangoDefaults(t)
	local defaults = {
		sqlite = {
			DB_CONNECTION = "sqlite",
			DB_DATABASE = vim.fn.getcwd() .. "/db/db.sqlite3",
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
			DB_PASSWORD = "",
			DB_DATABASE = "",
		},
	}
	return defaults[t] or {}
end

---@param engine string
---@return string
local function inferDBConnection(engine)
	if not engine then
		return "sqlite"
	end
	engine = engine:lower()
	if engine:match("mysql") then
		return "mysql"
	elseif engine:match("postgres") or engine:match("pgsql") then
		return "pgsql"
	else
		return "sqlite"
	end
end

---@param data table
---@return table
local function populateWithDefaults(data)
	-- Normalize engine
	if data.ENGINE then
		data.DB_CONNECTION = inferDBConnection(data.ENGINE)
	end

	local mapping = {
		DATABASE = "DB_DATABASE",
		NAME = "DB_DATABASE",
		USER = "DB_USERNAME",
		PASSWORD = "DB_PASSWORD",
		HOST = "DB_HOST",
		PORT = "DB_PORT",
	}

	for djangoKey, internalKey in pairs(mapping) do
		if data[djangoKey] and data[internalKey] == nil then
			data[internalKey] = data[djangoKey]
		end
	end

	local defaults = djangoDefaults(data.DB_CONNECTION)
	for key, value in pairs(defaults) do
		if data[key] == nil then
			data[key] = value
		end
	end

	vim.notify("data is " .. vim.inspect(data))
	return data
end

---@param line string
---@return boolean
local function isCommented(line)
	local stripped = line:match("^%s*(.-)%s*$")
	return stripped:match("^#") ~= nil
end

---@param value string
---@return string
local function cleanValue(value)
	-- Remove BASE_DIR references and path operations
	if value:match("BASE_DIR") then
		-- Extract just the filename if it's a path concatenation
		local filename = value:match('["/]([^"/]+%.%w+)"?%s*$')
		if filename then
			return vim.fn.getcwd() .. "/db/" .. filename
		end
		-- Return default if we can't parse it
		return vim.fn.getcwd() .. "/db/db.sqlite3"
	end
	return value
end

---@param lines any
---@param data table
---@return table
local function getDBConnectionValues(lines, data)
	local in_databases = false
	local in_default = false
	local brace_count = 0

	for line in lines do
		-- Skip commented lines
		if isCommented(line) then
			goto continue
		end

		local stripped = line:match("^%s*(.-)%s*$")
		if stripped == "" then
			goto continue
		end

		-- Check if we're entering DATABASES block
		if stripped:match("^DATABASES%s*=%s*{") then
			in_databases = true
			brace_count = 1
			goto continue
		end

		-- Track braces when inside DATABASES
		if in_databases then
			local open_braces = select(2, stripped:gsub("{", ""))
			local close_braces = select(2, stripped:gsub("}", ""))
			brace_count = brace_count + open_braces - close_braces

			-- Exit DATABASES block when braces are balanced
			if brace_count == 0 then
				in_databases = false
				in_default = false
				goto continue
			end
		end

		-- Only process lines inside DATABASES block
		if not in_databases then
			goto continue
		end

		-- Start of "default" block
		if stripped:match("[\"']default[\"']%s*:%s*{") then
			in_default = true
			goto continue
		end

		-- Extract key-value pairs inside "default"
		if in_default then
			-- Match "KEY": "VALUE" or 'KEY': 'VALUE'
			local key, value = stripped:match("[\"'](%w+)[\"']%s*:%s*[\"']([^\"']+)[\"']")
			if key and value then
				-- Skip BASE_DIR for non-NAME fields
				if key ~= "NAME" or not value:match("BASE_DIR") then
					data[key] = value
				else
					-- For NAME field with BASE_DIR, clean it
					data[key] = cleanValue(value)
				end
			else
				-- Try to match Python path concatenation for NAME field
				local nameKey, pathValue = stripped:match("[\"'](%w+)[\"']%s*:%s*(.+),?%s*$")
				if nameKey == "NAME" and pathValue then
					data[nameKey] = cleanValue(pathValue)
				end
			end
		end

		::continue::
	end

	require("quick-db.utils").log(vim.inspect(data))
	return populateWithDefaults(data)
end

---@param path string
---@return table
local function parseFile(path)
	local file = io.open(path .. "/settings.py", "r")
	if not file then
		return {}
	end
	local data = getDBConnectionValues(file:lines(), {})
	file:close()
	return data
end

local function findSettingsFile(path)
	local pathParts = vim.split(path, "/")
	local projectName = pathParts[#pathParts]
	local settingsPath = path .. "/" .. projectName
	if vim.fn.filereadable(settingsPath .. "/settings.py") == 1 then
		return settingsPath
	end
	return ""
end

---@param path string
---@return table
function adapter:parse(path)
	local settingsFile = findSettingsFile(path)
	if settingsFile ~= "" then
		return parseFile(settingsFile)
	end
	return {}
end

return adapter
