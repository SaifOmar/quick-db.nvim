local DB = require("quick-db.connection")

local M = {}
M.__index = M

local Env = require("quick-db.env")
local log = require("quick-db.utils")

local uv = vim.uv

---@class QuickDB
---@field private stdin uv_pipe_t
---@field private stdout uv_pipe_t
---@field private stderr uv_pipe_t
---@field private handle? uv_process_t
---@field private pid? integer
---@field private data? table
---@filed private callbacks? table

---@param stdin uv_pipe_t
---@param stdout uv_pipe_t
---@param stderr uv_pipe_t
---@param handle? uv_process_t
---@param pid? integer
---@param data? table
---@param dbconnection? DBConnection
function M:new(stdin, stdout, stderr, handle, pid, data, dbconnection)
	return setmetatable({
		stdin = stdin,
		stdout = stdout,
		stderr = stderr,
		handle = handle,
		pid = pid,
		data = data,
		dbconnection = dbconnection,
		callbacks = {},
	}, self)
end

function M.connect2()
	-- local env = Env:new(vim.fn.getcwd())
	-- local connectionData = env:parse()
	-- local db = DB:fromEnv(connectionData)
	-- local db = DB:new(nil, nil, nil, nil, nil, nil, "sqlite")

	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	local m = M:new(stdin, stdout, stderr)

	m:initConnection()
	m:getTables()

	uv.read_start(stdout, function(err, data)
		assert(not err, err)
		if data then
			m.data = data
			vim.defer_fn(function()
				m.callbacks[#m.callbacks]()
				table.remove(m.callbacks, #m.callbacks)
			end, 100)
		else
			print("stdout end", M.stdout)
		end
	end)
end

local function formatTableData(data)
	local output = vim.json.decode(data)
	vim.notify("[stdout] " .. vim.inspect(output))

	log.log(vim.inspect(output))
	local temp = {}
	for i, tb in ipairs(output) do
		temp[i] = tb
	end
	return temp
end

function M:queryTable(table_name)
	self:writeToStdin("SELECT * FROM " .. table_name .. ";\n")

	table.insert(self.callbacks, function()
		vim.notify("Table selected: " .. table_name, vim.log.levels.INFO)
		local data = formatTableData(self.data)
		log.log(vim.inspect(data))
		self:showPicker("Select a record to progress", data, function(choice)
			vim.notify("Selected record: " .. vim.inspect(choice), vim.log.levels.INFO)
			log.log(vim.inspect(choice))
			log.log(choice)
			-- self.selectedRow = vim.json.decode(choice)
			self.selectedRow = choice

			log.log("log")
			log.log(self.selectedRow)
			log.log(vim.inspect(self.selectedRow))

			M:open_buffer_with_lines(choice)
			-- self:showPicker("Select a column to view", { self.selectedRow }, function(choice)
			-- 	vim.notify("Selected column: " .. choice, vim.log.levels.INFO)
			-- end)
		end)
	end)
end

local function table_to_lines(tbl)
	local lines = {}
	for k, v in pairs(tbl) do
		v = v == vim.NIL and "nil" or tostring(v)
		table.insert(lines, string.format("%s = %s", k, v))
	end
	return lines
end
function M:open_buffer_with_lines(lines)
	-- Create a new empty buffer (listed = true, scratch = false)
	local buf = vim.api.nvim_create_buf(true, false)

	log.log("here")
	lines = table_to_lines(lines)
	log.log(vim.inspect(lines))
	-- Write lines into the buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Open in a new split
	vim.api.nvim_win_set_buf(0, buf)

	return buf
end
function M:getTables()
	self:writeToStdin("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';\n")
	table.insert(self.callbacks, function()
		self:showPicker("Select a table to view", self:formatData(), function(choice)
			log.log(vim.inspect(choice))
			self:queryTable(choice)
		end)
	end)
end

---@param prompt string
---@param data table
function M:showPicker(prompt, data, on_choice)
	vim.ui.select(data, {
		prompt = prompt,
	}, function(choice)
		if choice then
			on_choice(choice)
		end
	end)
end

---@param stdinData string
function M:writeToStdin(stdinData, errHandler)
	uv.write(self.stdin, stdinData, errHandler or function(err)
		if err then
			vim.notify("Error: " .. err, vim.log.levels.ERROR)
			log.log(vim.inspect(err))
		end
	end)
end

function M:initConnection()
	local cmd = "sqlite3"
	local args = { "-json", "/home/saif/Dev/personal-projects/git_geniuses/database/database.sqlite" }
	local handle, pid = uv.spawn(
		cmd,
		{ args = args, stdio = { self.stdin, self.stdout, self.stderr } },
		function(code, signal)
			print("exit code", code)
			print("exit signal", signal)
		end
	)
	self.handle = handle
	self.pid = pid
end

---@return table
function M:formatData()
	local data = vim.json.decode(self.data)
	local temp = {}
	for i, table in ipairs(data) do
		temp[i] = table.name
	end
	return temp
end

return M
