local M = {}

local log_file = vim.fn.stdpath("cache") .. "/quickdb.log"

function M.log(msg)
	local f = io.open(log_file, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end

return M
