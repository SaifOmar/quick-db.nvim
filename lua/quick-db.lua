local CON = require("quick-db.connection")

local M = {}
M.__index = M

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local themes = require("telescope.themes")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
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
---@field private con? table
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

---takes a record and returns array of first 3 values plus id
---@param record table
---@return table
local function expand(record)
	local expanded = {}
	local count = 0

	for k, v in pairs(record) do
		if k ~= "id" and k ~= "created_at" and k ~= "updated_at" and count < 3 then
			table.insert(expanded, v)
			count = count + 1
		end
	end

	-- Store id separately for easy access
	expanded.id = record.id

	return expanded
end

function M.connect()
	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	local m = M:new(stdin, stdout, stderr)

	local connection_data = Env:new(vim.fn.getcwd()):parse().data

	m.con = CON:fromEnv(connection_data)
	log.log("connection is " .. vim.inspect(m.con))

	m:initConnection()
	m:getTables()

	uv.read_start(stdout, function(err, data)
		assert(not err, err)
		if data then
			m.data = data
			vim.schedule(function()
				m.callbacks[#m.callbacks]()
				table.remove(m.callbacks, #m.callbacks)
			end)
		else
		end
	end)
end

function M:queryTable(table_name)
	self:writeToStdin("SELECT * FROM " .. table_name .. ";\n")

	local prompt = "Select a record to progress"

	local data = function()
		return self.con.format_table_results(self.con.parse(self.data))
	end

	local on_choice = function(choice)
		-- vim.notify("Selected record: " .. vim.inspect(choice), vim.log.levels.INFO)
		-- log.log(vim.inspect(choice))
		-- log.log(choice)
		-- self.selectedRow = vim.json.decode(choice)
		self.selectedRow = choice

		log.log("log")
		log.log(self.selectedRow)
		log.log(vim.inspect(self.selectedRow))

		M:open_buffer_with_lines(choice)
	end

	local entry_maker = function(record)
		local expanded = expand(record)
		log.log("expanded is " .. vim.inspect(expanded))
		return {
			value = record,
			ordinal = expanded[1] .. " " .. expanded[2] .. " " .. expanded.id,
			display = string.format("%s %s (ID: %s)", expanded[1] or "?", expanded[2] or "?", expanded.id or "?"),
		}
	end
	-- vim.notify("Table selected: " .. table_name, vim.log.levels.INFO)
	log.log(vim.inspect(self.data))
	log.log(vim.inspect(data()))
	log.log("here is were we start to fail")
	table.insert(self.callbacks, function()
		self:showPicker(prompt, data(), on_choice, entry_maker)
	end)
end
--
local function table_to_lines(tbl)
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
function M:open_buffer_with_lines(lines)
	-- Create a new empty buffer (listed = true, scratch = false)
	local buf = vim.api.nvim_create_buf(true, false)

	log.log("here")
	local new = table_to_lines(lines)

	log.log("here2" .. vim.inspect(lines))
	-- Write lines into the buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, new)

	-- Open in a new split
	vim.api.nvim_win_set_buf(0, buf)

	return buf
end
function M:getTables()
	self:writeToStdin("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';\n")

	local promet = "Select a table to view"
	local data = function()
		return self.con.format_tables(self.con.parse(self.data))
	end
	local on_choice = function(choice)
		log.log("get tables is " .. vim.inspect(choice))
		self:queryTable(choice)
	end
	local entry_maker = function(entry)
		return {
			value = entry,
			display = entry,
			ordinal = entry,
		}
	end
	table.insert(self.callbacks, function()
		self:showPicker(promet, data(), on_choice, entry_maker)
	end)
	--
end

---@param prompt string
---@param data table
---@param on_choice function
---@param entry_maker function
function M:showPicker(prompt, data, on_choice, entry_maker)
	log.log("here")
	log.log(vim.inspect(data))
	local opts = {}
	pickers
		.new(opts, {
			prompt_title = prompt,
			finder = finders.new_table({
				results = data,
				entry_maker = entry_maker or function(entry)
					return {
						value = entry,
						display = entry,
						ordinal = entry,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			-- previewer = previewers.new_buffer_previewer({
			-- 	define_preview = function(self, entry)
			-- 		local lines = dict_to_pretty_lines(entry.value)
			-- 		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			-- 	end,
			-- }),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					on_choice(selection.value)
				end)
				return true
			end,
		})
		:find()
end

---@param stdinData string
function M:writeToStdin(stdinData, errHandler)
	uv.write(self.stdin, stdinData, errHandler or function(err)
		if err then
			-- vim.notify("Error: " .. err, vim.log.levels.ERROR)
			log.log(vim.inspect(err))
		end
	end)
end

function M:initConnection()
	local cmd = self.con.cmd
	local args = self.con.connection_args
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
