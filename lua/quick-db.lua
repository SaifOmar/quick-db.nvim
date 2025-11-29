local CON = require("quick-db.connection")

local M = {}
M.__index = M

local count = 0
-- Constructor
function M:new()
	local o = {
		spec = nil,
		raw = {},
		data = nil,
		callbacks = {},
	}
	return setmetatable(o, M)
end

local Env = require("quick-db.env")
local utils = require("quick-db.utils")
local UI = require("quick-db.ui")

local uv = vim.uv

-- Set up connection
function M:setup()
	local env_data = Env:new(vim.fn.getcwd()):parse().data
	self.spec = CON:fromEnv(env_data)
end

function M:connect2()
	if not self.spec then
		self:setup()
		vim.notify("QuickDB connected!")
	else
		vim.notify("Already connected")
	end

	-- Flatten helper
	local function flatten(tbl, out)
		out = out or {}
		for _, v in ipairs(tbl) do
			if type(v) == "table" then
				flatten(v, out)
			else
				table.insert(out, v)
			end
		end
		return out
	end

	local args = flatten({
		self.spec.cmd,
		self.spec.connection_args,
		self.spec.queries.getTableRecords("migrations"),
	})

	vim.notify("args is " .. vim.inspect(args))

	-- Split command and args
	local cmd = args[1]
	local cmd_args = {}
	for i = 2, #args do
		table.insert(cmd_args, args[i])
	end

	-- Setup pipes
	local stdout = vim.uv.new_pipe(false)
	local stderr = vim.uv.new_pipe(false)

	local output = {}
	local error_output = {}

	-- Spawn process
	local handle
	handle = vim.uv.spawn(cmd, {
		args = cmd_args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		-- close pipes and handle
		stdout:close()
		stderr:close()
		handle:close()

		-- Schedule UI update on main thread
		vim.schedule(function()
			local entry_maker = function(record)
				local expanded = utils.expand(record)
				return {
					value = record,
					ordinal = record.id .. " " .. expanded,
					display = record.id .. " " .. expanded,
				}
			end

			utils.log("output is " .. vim.inspect(output))
			UI:showPicker(
				"Select a record to progress",
				self.spec.formatTableResults(self.spec.parse(table.concat(output))),
				nil,
				entry_maker
			)

			if self.callbacks[#self.callbacks] then
				self.callbacks[#self.callbacks]()
				table.remove(self.callbacks, #self.callbacks)
			end
		end)
	end)

	-- Start reading stdout
	vim.uv.read_start(stdout, function(err, data)
		assert(not err, err)
		if data then
			table.insert(output, data)
		end
	end)

	-- Start reading stderr (optional)
	vim.uv.read_start(stderr, function(err, data)
		assert(not err, err)
		if data then
			table.insert(error_output, data)
		end
	end)
end
-- Public connect
function M:connect()
	if not self.spec then
		self:setup()
		vim.notify("QuickDB connected!")
	else
		vim.notify("Already connected")
	end

	local function flatten(tbl, out)
		out = out or {}
		for _, v in ipairs(tbl) do
			if type(v) == "table" then
				flatten(v, out)
			else
				table.insert(out, v)
				vim.notify("v is " .. vim.inspect(v))
			end
		end
		return out
	end

	local args = flatten({
		self.spec.cmd,
		self.spec.connection_args,
		self.spec.queries.getTableRecords("users"),
	})

	local on_exit = function(obj)
		vim.schedule(function()
			local entry_maker = function(record)
				local expanded = utils.expand(record)
				return {
					value = record,
					ordinal = record.id .. " " .. expanded,
					display = record.id .. " " .. expanded,
				}
			end
			UI:showPicker(
				"Select a record to progress",
				self.spec.formatTableResults(self.spec.parse(obj.stdout)),
				nil,
				entry_maker
			)
			if self.callbacks[#self.callbacks] then
				self.callbacks[#self.callbacks]()
				table.remove(self.callbacks, #self.callbacks)
			end
		end)
	end
	vim.notify("args is " .. vim.inspect(args))

	vim.system(args, { text = true }, on_exit)
end
function M:getData()
	local data = utils.flatten(self.raw)
	return data
end
-- gets all table records
function M:queryTable(table_name)
	self:writeToStdin("SELECT * FROM " .. table_name .. ";\n")

	local prompt = "Select a record to progress"

	local parseData = function(data)
		return self.con.format_table_results(self.con.parse(data))
	end

	local on_choice = function(choice)
		self.selectedRow = choice

		UI:open_buffer_with_lines_win(utils.table_to_lines(choice))
		local stop2 = uv.read_stop(self.stdin)
		local stop = uv.read_stop(self.stdout)
	end

	local entry_maker = function(record)
		local expanded = utils.expand(record)
		-- utils.log("expanded is " .. vim.inspect(expanded))
		return {
			value = record,
			ordinal = record.id .. " " .. expanded,
			display = record.id .. " " .. expanded,
		}
	end
	-- utils.log("here is were we start to fail")
	table.insert(self.callbacks, function(data)
		UI:showPicker(prompt, parseData(data), on_choice, entry_maker)
	end)
end
--

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
		UI:showPicker(promet, parseData(data), on_choice, entry_maker)
	end)
	--
end

return M
