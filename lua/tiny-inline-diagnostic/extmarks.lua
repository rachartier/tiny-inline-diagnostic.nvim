local M = {}

local INITIAL_UID = 1
local MAX_UID = 2 ^ 32 - 1
local DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("TinyInlineDiagnostic")

local state = {
	uid_counter = INITIAL_UID,
	skip_lines = {
		count = 0,
		start_line = 0,
	},
}

---@param buf number
---@return boolean
local function is_valid_buffer(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

---@return number
local function generate_uid()
	state.uid_counter = state.uid_counter + 1
	if state.uid_counter > MAX_UID then
		state.uid_counter = INITIAL_UID
	end
	return state.uid_counter
end

---@return {row: number, col: number}
local function get_window_position()
	local ok_winline, result_winline = pcall(vim.fn.winline)
	local ok_virtcol, result_virtcol = pcall(vim.fn.virtcol, "$")
	local ok_winsaveview, result_winsaveview = pcall(vim.fn.winsaveview)

	if not ok_winline or not ok_virtcol or not ok_winsaveview then
		return { row = 0, col = 0 }
	end

	return {
		row = result_winline - 1,
		col = result_virtcol - result_winsaveview.leftcol,
	}
end

---@param buf number
---@param line number
---@param virt_text table
---@param win_col number
---@param priority number
---@param pos? string
local function set_extmark(buf, line, virt_text, win_col, priority, pos)
	if not is_valid_buffer(buf) then
		return
	end

	vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, line, 0, {
		id = generate_uid(),
		line_hl_group = line == 0 and "TinyInlineDiagnosticVirtualTextBg" or nil,
		virt_text_pos = pos or "eol",
		virt_text = virt_text,
		virt_text_win_col = win_col,
		priority = priority,
		strict = false,
	})
end

local function should_skip_line(curline)
	local skip = state.skip_lines
	return skip.count > 0 and curline > skip.start_line and curline < skip.start_line + skip.count
end

local function create_multiline_extmark(buf, curline, virt_lines, priority)
	local remaining_lines = {}
	for i = 2, #virt_lines do
		table.insert(remaining_lines, virt_lines[i])
	end

	vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, curline, 0, {
		id = generate_uid(),
		virt_text_pos = "eol",
		virt_text = virt_lines[1],
		virt_lines = remaining_lines,
		priority = priority,
		strict = false,
	})
end

local function handle_under_cursor_case(buf, curline, virt_lines, buf_lines_count, priority)
	if curline >= buf_lines_count - 1 then
		return
	end

	vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, curline + 1, 0, {
		id = generate_uid(),
		virt_text_pos = "overlay",
		virt_text_win_col = 0,
		virt_text = virt_lines[2],
		priority = priority,
		strict = false,
	})
end

local function handle_overflow_case(buf, curline, virt_lines, win_col, offset, priority, buf_lines_count)
	local existing_lines = buf_lines_count - curline
	local overflow_lines = {}

	-- Handle first line
	set_extmark(buf, curline, virt_lines[1], win_col, priority)

	-- Handle middle lines
	for i = 2, existing_lines do
		set_extmark(buf, curline + i - 1, virt_lines[i], win_col + offset, priority, "overlay")
	end

	-- Handle overflow lines
	for i = buf_lines_count - curline + 1, #virt_lines do
		local line = vim.deepcopy(virt_lines[i])
		table.insert(line, 1, { string.rep(" ", win_col + offset), "None" })
		table.insert(overflow_lines, line)
	end

	if #overflow_lines > 0 then
		vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, buf_lines_count - 1, 0, {
			id = generate_uid(),
			virt_lines_above = false,
			virt_lines = overflow_lines,
			priority = priority,
			strict = false,
		})
	end
end

local function handle_normal_case(buf, curline, virt_lines, win_col, offset, priority)
	set_extmark(buf, curline, virt_lines[1], win_col, priority)

	for i = 2, #virt_lines do
		set_extmark(buf, curline + i - 1, virt_lines[i], win_col + offset, priority, "overlay")
	end
end

---@param buf number
function M.clear(buf)
	if not is_valid_buffer(buf) then
		return
	end
	pcall(vim.api.nvim_buf_clear_namespace, buf, DIAGNOSTIC_NAMESPACE, 0, -1)
end

--- Count characters of inlay hints on a line
--- @param buf number
--- @param linenr number
local function count_inlay_hints_characters(buf, linenr)
	local line_char_count = vim.fn.strchars(vim.api.nvim_buf_get_lines(buf, linenr, linenr + 1, false)[1])
	local inlay_hints = vim.lsp.inlay_hint.get({
		bufnr = buf,
		range = {
			start = { line = linenr, character = 0 },
			["end"] = { line = linenr, character = line_char_count },
		},
	})
	local count = 0

	for _, hint in ipairs(inlay_hints) do
		if type(hint.inlay_hint.label) == "string" then
			count = count + #hint.inlay_hint.label
		else
			for _, label in ipairs(hint.inlay_hint.label) do
				count = count + #label.value
			end
		end
	end
	return count
end

---@param bufnr number
---@param linenr number
---@param col number
---@return table
function M.get_extmarks_on_line(bufnr, linenr, col)
	if not is_valid_buffer(bufnr) then
		return {}
	end

	local opts = {
		details = true,
		overlap = vim.fn.has("nvim-0.10.0") == 1,
	}

	return vim.api.nvim_buf_get_extmarks(bufnr, -1, { linenr, col }, { linenr, -1 }, opts)
end

---@param bufnr number
---@param curline number
---@param col number
---@return number
function M.handle_other_extmarks(_, bufnr, curline, col)
	local extmarks = M.get_extmarks_on_line(bufnr, curline, col)
	local offset = 0

	for _, extmark in ipairs(extmarks) do
		local detail = extmark[4]
		if detail.virt_text_pos == "eol" or detail.virt_text_pos == "win_col" then
			if detail.virt_text and detail.virt_text[1] and detail.virt_text[1][1] then
				offset = offset + #detail.virt_text[1][1]
			end
		end
	end

	if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
		local inlay_hints_count = count_inlay_hints_characters(bufnr, curline)
		offset = offset + inlay_hints_count
	end

	return offset
end

---@param opts DiagnosticConfig
---@param event table
---@param diag_line number
---@param virt_lines table
---@param offset number
---@param need_to_be_under boolean
---@param virt_priority number
function M.create_extmarks(opts, event, diag_line, virt_lines, offset, need_to_be_under, virt_priority)
	if not is_valid_buffer(event.buf) then
		return
	end

	if virt_lines == nil or vim.tbl_isempty(virt_lines) then
		return
	end

	local buf_lines_count = vim.api.nvim_buf_line_count(event.buf)
	local win_col = need_to_be_under and 0 or get_window_position().col
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	if buf_lines_count == 0 then
		return
	end

	-- Handle multiline mode
	if opts.options.multilines and diag_line ~= cursor_line then
		if should_skip_line(diag_line) then
			return
		end
		create_multiline_extmark(event.buf, diag_line, virt_lines, virt_priority)

		state.skip_lines.count = 0
		state.skip_lines.start_line = diag_line
		return
	end

	state.skip_lines.count = #virt_lines
	state.skip_lines.start_line = diag_line

	-- Handle under-cursor case
	if need_to_be_under then
		handle_under_cursor_case(event.buf, diag_line, virt_lines, buf_lines_count, virt_priority)
		table.remove(virt_lines, 2)
		win_col = 0
		if diag_line < buf_lines_count - 1 then
			diag_line = diag_line + 1
		end
	end

	-- Handle overflow case
	if diag_line - 1 + #virt_lines > buf_lines_count - 1 then
		handle_overflow_case(event.buf, diag_line, virt_lines, win_col, offset, virt_priority, buf_lines_count)
	else
		handle_normal_case(event.buf, diag_line, virt_lines, win_col, offset, virt_priority)
	end
end

return M
