local M = {}
M.__index = M

local CON = require("quick-db.connection")
local Env = require("quick-db.env")
local utils = require("quick-db.utils")
local UI = require("quick-db.ui")
local uv = vim.uv

--- @class QuickDB
--- @field spec table
--- @field rawChunks table
--- @field error_output table
--- @field connect function

---@return QuickDB
function M:new()
	local o = {
		spec = nil,
		rawChunks = {},
		error_output = {},
	}
	return setmetatable(o, M)
end

function M:setup()
	local env_data = Env:new(vim.fn.getcwd()):parse().data
	if env_data == nil or next(env_data) == nil then
		return "No env data found"
	end
	self.spec = CON:fromEnv(env_data)
end

function M:connect()
	if not self.spec then
		local err = self:setup()
		if err ~= nil then
			vim.notify("Failed to setup: " .. err, vim.log.levels.ERROR)
			return
		end
	end

	if self.spec.checkConnection() == false then
		self:_promptForConnection()
		return
	end

	self:_step_getTables()
end

function M:_promptForConnection()
	UI:promptUser("Please provide a connection command", "docker", function(input)
		if input and input ~= "" then
			self.spec.cmd = input
		else
			return
		end
		UI:promptUser("Please provide a connection args", table.concat(self.spec.connection_args, " "), function(ins)
			if ins and ins ~= "" then
				self.spec.assignUserArgs(utils.split(ins, " "))
			end
			self:_step_getTables()
		end)
	end)
end

function M:_step_getTables()
	self:quick(
		utils.flatten({
			self.spec.cmd,
			self.spec.connection_args,
			self.spec.queries.getTables(),
		}),
		function()
			self:_step_showTablesUI()
		end
	)
end

function M:_step_showTablesUI()
	if not self.rawChunks or #self.rawChunks == 0 then
		vim.notify("No tables found or empty response", vim.log.levels.ERROR)
		return
	end

	local entry_maker = function(record)
		return { value = record, ordinal = record, display = record }
	end

	local on_choice = function(table_name)
		if table_name then
			-- Next Step: Get records for selected table
			self:_step_getRecords(table_name)
		end
	end

	UI:showPicker(
		"Select a table",
		self.spec.formatTables(self.spec.parse(table.concat(self.rawChunks))),
		on_choice,
		entry_maker
	)
end

function M:_step_getRecords(table_name)
	local query = self.spec.queries.getTableRecords(table_name)
	self:quick(
		utils.flatten({
			self.spec.cmd,
			self.spec.connection_args,
			query,
		}),
		function()
			self:_step_showRecordsUI()
		end
	)
end

function M:_step_showRecordsUI()
	local entry_maker = function(record)
		local expanded = utils.expand(record)
		return {
			value = record,
			ordinal = record.id .. " " .. expanded,
			display = record.id .. " " .. expanded,
		}
	end

	local on_choice = function(record)
		if record then
			-- Final Step: Display Record
			self:_step_displayRecord(record)
		end
	end

	UI:showPicker(
		"Select a record",
		self.spec.formatTableResults(self.spec.parse(table.concat(self.rawChunks))),
		on_choice,
		entry_maker
	)
end

function M:_step_displayRecord(record)
	utils.log("record is " .. vim.inspect(record))
	UI:open_buffer_with_lines_win(utils.table_to_lines(record))
end

-- @param args table
-- @param on_complete function (Required)
function M:quick(args, on_complete)
	local cmd = args[1]
	local cmd_args = {}
	for i = 2, #args do
		table.insert(cmd_args, args[i])
	end
	local stdout = uv.new_pipe(false)
	local stderr = uv.new_pipe(false)

	self.rawChunks = {}
	self.error_output = {}

	args[#args] = '"' .. args[#args] .. '"'
	local flattened = utils.flatten(args)
	utils.log("try set args " .. table.concat(flattened, " "))

	local handle

	---@diagnostic disable-next-line: missing-fields
	handle = uv.spawn(cmd, {
		args = cmd_args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		if stdout then
			stdout:close()
		end
		if stderr then
			stderr:close()
		end
		handle:close()

		vim.schedule(function()
			if code ~= 0 then
				utils.log("Process failed with code: " .. vim.inspect(code))
				-- TODO: handle error flow here
			end

			if on_complete then
				on_complete()
			end
		end)
	end)

	---@diagnostic disable-next-line: param-type-mismatch
	uv.read_start(stdout, function(err, data)
		assert(not err, err)
		if data then
			table.insert(self.rawChunks, data)
		end
	end)

	---@diagnostic disable-next-line: param-type-mismatch
	uv.read_start(stderr, function(err, data)
		assert(not err, err)
		if data then
			table.insert(self.error_output, data)
		end
	end)
end

return M
