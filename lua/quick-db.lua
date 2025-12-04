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
--- @field callbacks table
--- @field connect function

---@return QuickDB
function M:new()
	local o = {
		spec = nil,
		rawChunks = {},
		error_output = {},
		callbacks = {},
	}
	return setmetatable(o, M)
end

-- Set up connection
function M:setup()
	local env_data = Env:new(vim.fn.getcwd()):parse().data
	if env_data == nil or next(env_data) == nil then
		return "No env data found"
	end
	self.spec = CON:fromEnv(env_data)
end

-- @param args table
-- @param callback function
function M:quick(args, callback)
	local cmd = args[1]
	local cmd_args = {}
	for i = 2, #args do
		table.insert(cmd_args, args[i])
	end
	local stdout = uv.new_pipe(false)
	local stderr = uv.new_pipe(false)

	args[#args] = '"' .. args[#args] .. '"'
	local flattened = utils.flatten(args)
	utils.log("try set args " .. table.concat(flattened, " "))
	-- Spawn process
	local handle

	---@diagnostic disable-next-line: missing-fields
	handle = uv.spawn(cmd, {
		args = cmd_args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		if code ~= 0 then
			utils.log("code is " .. vim.inspect(code))
		end
		-- close pipes and handle
		if signal ~= nil then
			utils.log("signal is " .. vim.inspect(signal))
		end
		if stdout ~= nil then
			stdout:close()
		end
		if stderr ~= nil then
			stderr:close()
		end
		handle:close()
		if callback ~= nil then
			--- needs args ?
			callback()
		else
			-- Schedule UI update on main thread
			vim.schedule(function()
				if self.callbacks[#self.callbacks] ~= nil then
					self.callbacks[#self.callbacks]()
					table.remove(self.callbacks, #self.callbacks)
				end
				self.rawChunks = {}
			end)
		end
	end)

	-- Start reading stdout
	---@diagnostic disable-next-line: param-type-mismatch
	uv.read_start(stdout, function(err, data)
		assert(not err, err)
		if data then
			table.insert(self.rawChunks, data)
		end
	end)

	-- Start reading stderr (optional)
	---@diagnostic disable-next-line: param-type-mismatch
	uv.read_start(stderr, function(err, data)
		assert(not err, err)
		if data then
			table.insert(self.error_output, data)
		end
	end)
end

function M:connect()
	if not self.spec then
		local err = self:setup()
		if err ~= nil then
			vim.notify("Failed to setup: " .. err, vim.log.levels.ERROR)
			return
		end
	end

	self.callbacks = {
		function(record)
			utils.log("record is " .. vim.inspect(record))
			UI:open_buffer_with_lines_win(utils.table_to_lines(record))
		end,
		function()
			local entry_maker = function(record)
				local expanded = utils.expand(record)
				return {
					value = record,
					ordinal = record.id .. " " .. expanded,
					display = record.id .. " " .. expanded,
				}
			end
			utils.log("output is " .. vim.inspect(self.rawChunks))
			local on_choice = function(choice)
				self.callbacks[#self.callbacks](choice)
				table.remove(self.callbacks, #self.callbacks)
			end
			UI:showPicker(
				"Select a record to progress",
				self.spec.formatTableResults(self.spec.parse(table.concat(self.rawChunks))),
				on_choice,
				entry_maker
			)
		end,
		function(table_name)
			local query = self.spec.queries.getTableRecords(table_name)
			self:quick(utils.flatten({
				self.spec.cmd,
				self.spec.connection_args,
				query,
			}))
		end,
		function()
			local entry_maker = function(record)
				return {
					value = record,
					ordinal = record,
					display = record,
				}
			end
			utils.log("output is " .. vim.inspect(self.rawChunks))
			local on_choice = function(choice)
				self.callbacks[#self.callbacks](choice)
				table.remove(self.callbacks, #self.callbacks)
			end
			if self.rawChunks[1] == nil then
				vim.notify("No tables found", vim.log.levels.ERROR)
				return
			end
			UI:showPicker(
				"Select a table to progress",
				self.spec.formatTables(self.spec.parse(table.concat(self.rawChunks))),
				on_choice,
				entry_maker
			)
		end,
	}

	if self.spec.checkConnection() == false then
		UI:promptUser("Please provide a connection command", "docker", function(input)
			if input and input ~= "" then
				self.spec.cmd = input
			end
			UI:promptUser(
				"Please provide a connection args",
				table.concat(self.spec.connection_args, " "),
				function(ins)
					if ins and ins ~= "" then
						self.spec.assignUserArgs(utils.split(ins, " "))
					end
					self:quick(utils.flatten({
						self.spec.cmd,
						self.spec.connection_args,
						self.spec.queries.getTables(),
					}))
				end
			)
		end)
		return
	end

	self:quick(utils.flatten({
		self.spec.cmd,
		self.spec.connection_args,
		self.spec.queries.getTables(),
	}))
end

return M
