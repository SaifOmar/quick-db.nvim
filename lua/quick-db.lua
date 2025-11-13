local DB = require("quick-db.connection")
local M = {}
local Env = require("quick-db.env")
local log = require("quick-db.utils")
-- local function formatStdout(data)
-- 	if not data then
-- 		return
-- 	end
-- 	for _, line in ipairs(data) do
-- 		if line ~= "" then
-- 			-- Show each line as a notification
-- 			vim.notify(line)
-- 			log.log(line)
-- 		end
-- 	end
-- end

---@param data string
local function send(data)
	vim.fn.chansend(M.job_id, data .. "\n")
end

---@param cmd string
---@param opts? table
local function job_start(cmd, opts)
	opts = opts
		or {
			stdout_buffered = true,
			on_stdout = function(_, data)
				vim.notify("connected to db")
				if data then
					for _, line in ipairs(data) do
						if line ~= "" then
							vim.notify("[stdout] " .. line)
						end
					end
				end
			end,
			on_stderr = function(_, data)
				if data then
					for _, line in ipairs(data) do
						if line ~= "" then
							vim.notify("[stderr] " .. line)
						end
					end
				end
			end,
			on_exit = function(_, code)
				vim.notify("Job exited with code " .. code)
			end,
		}
	print(vim.inspect(opts))
	local id = vim.fn.jobstart(cmd, opts)
	log.log(vim.inspect(id))
	vim.notify(vim.inspect(id))

	vim.defer_fn(function()
		vim.fn.chansend(id, ".tables\n")
	end, 50) -- wait 50ms
	return id
end

M.connect = function()
	local path = vim.fn.getcwd()
	print(path)
	log.log("Path: " .. path)
	local env = Env:new(path)
	env:parse()
	print(env.data)
	log.log("Data: " .. vim.inspect(env.data))
	-- matchValues(env.data, DB)

	local db = DB:fromEnv(env.data)
	M.job_id = db:connect(job_start)

	-- send(".tables")

	log.log(vim.inspect(db))
end

M.Qtest = function()
	-- local cmd = "sqlite3  /home/saif/Dev/personal-projects/git_geniuses/database/database.sqlite"
	local cmd = {
		"sqlite3",
		"/home/saif/Dev/personal-projects/git_geniuses/database/database.sqlite",
		".tables",
	}
	local opts = {
		rpc = false,
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						vim.notify("[stdout] " .. line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						vim.notify("[stderr] " .. line)
					end
				end
			end
		end,
		on_exit = function(_, code)
			vim.notify("Job exited with code " .. code)
		end,
	}
	vim.fn.jobstart(cmd, opts)
end

return M
