local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local sorters = require("telescope.sorters")

local utils = require("quick-db.utils")

local conf = require("telescope.config").values
local themes = require("telescope.themes")
local previewers = require("telescope.previewers")

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

function M:open_buffer_with_lines_win(lines)
	local win = self.window()
	vim.api.nvim_buf_set_keymap(win.buf, "n", "q", ":close<CR>", { noremap = true, silent = true })

	vim.api.nvim_win_set_buf(win.win, win.buf)
	vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
end

---@param prompt string
---@param data table
---@param on_choice function
---@param entry_maker function
function M:showPicker(prompt, data, on_choice, entry_maker)
	utils.log("data is in picker " .. vim.inspect(data))
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

---@param prompt string
---@param default string
function M:promptUser(prompt, default, callback)
	vim.ui.input({
		prompt = "Enter parameters: ",
		default = default,
		completion = "file",
		highlight = false,
	}, callback)
end

return M
