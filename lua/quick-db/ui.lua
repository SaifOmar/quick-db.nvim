local M = {}
function M.window(opts)
	opts = opts or {}
	local width = opts.width or math.floor((vim.o.columns * 0.7))
	local height = opts.height or math.floor((vim.o.lines * 0.7))

	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		-- style = "minimal", -- No borders or extra UI elements
		border = "rounded",
	}
	local buf = nil

	if opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win = vim.api.nvim_open_win(buf, true, win_config)

	return { buf = buf, win = win }
end

return M
