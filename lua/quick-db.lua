local CON = require("quick-db.connection")

local M = {}
M.__index = M

local Env = require("quick-db.env")
local utils = require("quick-db.utils")
local UI = require("quick-db.ui")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local sorters = require("telescope.sorters")

local conf = require("telescope.config").values
local themes = require("telescope.themes")
local previewers = require("telescope.previewers")

local uv = vim.uv

-- Main data obj
---@class QuickDB
---@field private stdin uv_pipe_t
---@field private stdout uv_pipe_t
---@field private stderr uv_pipe_t
---@field private handle? uv_process_t
---@field private pid? integer
---@field private data? string
---@field private raw? string
---@field private con? table
---
---@filed private callbacks? table

---@param stdin uv_pipe_t
---@param stdout uv_pipe_t
---@param stderr uv_pipe_t
---@param handle? uv_process_t
---@param pid? integer
---@param data? string
---@param dbconnection? DBConnection
function M:new(stdin, stdout, stderr, handle, pid, data, dbconnection)
	return setmetatable({
		raw = "",
		data = data or nil,
		stdin = stdin,
		stdout = stdout,
		stderr = stderr,
		handle = handle,
		pid = pid,
		dbconnection = dbconnection,
		callbacks = {},
	}, self)
end

-- Takes a record and returns concated string values of tabls minus id and *_at
---@param record table
---@return string
local function expand(record)
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

-- starts the connection to the database cli and exposes std (out,err,in) pipes
function M.connect()
	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	local m = M:new(stdin, stdout, stderr)

	local connection_data = Env:new(vim.fn.getcwd()):parse().data

	m.con = CON:fromEnv(connection_data)
	-- utils.log("connection is " .. vim.inspect(m.con))

	m:initConnection()
	m:getTables()

	uv.read_start(stdout, function(err, chunk)
		assert(not err, err)
		if chunk then
			m.raw = m.raw .. chunk
			local bol = utils.ends_with_backslash_n_quote(chunk)
			if bol then
				m.data = m.raw
				vim.schedule(function()
					if m.callbacks[#m.callbacks] then
						m.callbacks[#m.callbacks](m.data)
						table.remove(m.callbacks, #m.callbacks)
						m.raw = ""
						m.data = nil
					else
						vim.notify("WHOPS NO CALLBACK", vim.log.levels.ERROR)
					end
				end)
			end
		else
			utils.log("Disconnected")
			vim.notify("Disconnected", vim.log.levels.INFO)
		end
	end)
end

-- gets all table records
function M:queryTable(table_name)
	self:writeToStdin("SELECT * FROM " .. table_name .. ";\n")

	local prompt = "Select a record to progress"

	-- utils.log("here" .. vim.inspect(data))
	local parseData = function(data)
		return self.con.format_table_results(self.con.parse(data))
	end

	local on_choice = function(choice)
		self.selectedRow = choice

		M:open_buffer_with_lines_win(choice)
		local stop = uv.read_stop(self.stdout)
		utils.log(vim.inspect(stop))
	end

	local entry_maker = function(record)
		local expanded = expand(record)
		-- utils.log("expanded is " .. vim.inspect(expanded))
		return {
			value = record,
			ordinal = record.id .. " " .. expanded,
			display = record.id .. " " .. expanded,
		}
	end
	-- utils.log("here is were we start to fail")
	table.insert(self.callbacks, function(data)
		self:showPicker(prompt, parseData(data), on_choice, entry_maker)
	end)
end
--

function M:open_buffer_with_lines_win(lines)
	local win = UI.window()
	vim.api.nvim_win_set_buf(win.win, win.buf)
	vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, utils.table_to_lines(lines))
end

function M:getTables()
	self:writeToStdin("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';\n")

	local promet = "Select a table to view"
	local parseData = function(data)
		return self.con.format_tables(self.con.parse(data))
	end
	local on_choice = function(choice)
		-- utils.log("get tables is " .. vim.inspect(choice))
		self:queryTable(choice)
	end
	local entry_maker = function(entry)
		return {
			value = entry,
			display = entry,
			ordinal = entry,
		}
	end
	table.insert(self.callbacks, function(data)
		self:showPicker(promet, parseData(data), on_choice, entry_maker)
	end)
	--
end

---@param prompt string
---@param data table
---@param on_choice function
---@param entry_maker function
function M:showPicker(prompt, data, on_choice, entry_maker)
	-- utils.log("here")
	-- utils.log(vim.inspect(data))
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
			utils.log(vim.inspect(err))
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

return M
