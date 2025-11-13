local M = {}

local log = require("quick-db.utils")
---@param db DBConnection
---@param job_start function
--- @return number
M.connect = function(db, job_start)
	local cmd = { "sqlite3", db:getPath() }

	log.log("cmd is" .. vim.inspect(cmd))
	local id = job_start(cmd)
	log.log("here" .. vim.inspect(id))
	return id
end

---@param send function
M.getTables = function(send)
	send(".tables")
end

------@param job_id number
---M.getTables = function(job_id)
---	local tables = {}
---	vim.fn.jobsend(job_id, ".tables")
---end

return M
