local M = {}

local INITIAL_UID = 1
local MAX_UID = 2 ^ 32 - 1
local DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("TinyInlineDiagnostic")

---@class ExtmarkState
---@field uid_counter number
---@field skip_lines table
local state = {
	uid_counter = INITIAL_UID,
}

---@class WindowPosition
---@field row number
---@field col number

---Check if buffer is valid
---@param buf number
---@return boolean
local function is_valid_buffer(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

---Generate a new unique identifier
---@return number
local function generate_uid()
	state.uid_counter = (state.uid_counter % MAX_UID) + 1
	return state.uid_counter
end

---Get current cursor position inside the window
---@return WindowPosition
local function get_window_position()
	local ok_winline, result_winline = pcall(vim.fn.winline)
	local ok_virtcol, result_virtcol = pcall(vim.fn.virtcol, "$")
	local ok_winsaveview, result_winsaveview = pcall(vim.fn.winsaveview)

	if not (ok_winline and ok_virtcol and ok_winsaveview) then
		return { row = 0, col = 0 }
	end

	return {
		row = result_winline - 1,
		col = result_virtcol - result_winsaveview.leftcol,
	}
end

---Create a single extmark
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

	local extmark_opts = {
		id = generate_uid(),
		virt_text = virt_text,
		virt_text_pos = pos or "eol",
		virt_text_win_col = win_col,
		priority = priority,
		strict = false,
	}

	if line == 0 then
		extmark_opts.line_hl_group = "TinyInlineDiagnosticVirtualTextBg"
	end

	vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, line, 0, extmark_opts)
end

---Check if line should be skipped
---@param diag_line number
---@return boolean
local function should_skip_line(cursor_line, diag_line, diags_dims)
	for _, dims in ipairs(diags_dims) do
		if diag_line ~= dims[1] then
			if cursor_line == dims[1] then
				if diag_line > dims[1] and diag_line < dims[1] + dims[2] then
					return true
				end
			end
		end
	end

	return false
end

---Create a multiline extmark
---@param buf number
---@param curline number
---@param virt_lines table
---@param priority number
local function create_multiline_extmark(buf, curline, virt_lines, priority)
	local remaining_lines = { unpack(virt_lines, 2) }

	vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, curline, 0, {
		id = generate_uid(),
		virt_text_pos = "eol",
		virt_text = virt_lines[1],
		virt_lines = remaining_lines,
		priority = priority,
		strict = false,
	})
end

---Handle overflow case for extmarks
---@param buf number
---@param params table
local function handle_overflow_case(buf, params)
	local existing_lines = params.buf_lines_count - params.curline
	local overflow_lines = {}
	local start_index = params.need_to_be_under and 3 or 1
	local signs_offset = params.need_to_be_under and (params.signs_offset == 0 and 0 or 1) or params.signs_offset

	if params.need_to_be_under then
		-- set_extmark(buf, params.curline, params.virt_lines[1], params.win_col, params.priority)
		set_extmark(buf, params.curline + 1, params.virt_lines[2], params.win_col, params.priority)
	end

	-- Create extmarks for existing lines
	for i = start_index, existing_lines do
		local col_offset = params.win_col + params.offset + (i > start_index and signs_offset or 0)
		set_extmark(buf, params.curline + i - 1, params.virt_lines[i], col_offset, params.priority, "overlay")
	end

	-- Handle overflow lines
	for i = existing_lines + 1, #params.virt_lines do
		local line = vim.deepcopy(params.virt_lines[i])
		local col_offset = params.win_col + params.offset + (i > start_index and signs_offset or 0)
		table.insert(line, 1, { string.rep(" ", col_offset), "None" })
		table.insert(overflow_lines, line)
	end

	if #overflow_lines > 0 then
		vim.api.nvim_buf_set_extmark(buf, DIAGNOSTIC_NAMESPACE, params.buf_lines_count - 1, 0, {
			id = generate_uid(),
			virt_lines_above = false,
			virt_lines = overflow_lines,
			priority = params.priority,
			strict = false,
		})
	end
end

---Count inlay hint characters
---@param buf number
---@param linenr number
---@return number
local function count_inlay_hints_characters(buf, linenr)
	local line = vim.api.nvim_buf_get_lines(buf, linenr, linenr + 1, false)[1]
	if not line then
		return 0
	end

	local line_char_count = vim.fn.strchars(line)
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

-- Public API

---Clear extmarks from buffer
---@param buf number
function M.clear(buf)
	if not is_valid_buffer(buf) then
		return
	end
	pcall(vim.api.nvim_buf_clear_namespace, buf, DIAGNOSTIC_NAMESPACE, 0, -1)
end

---Get extmarks on a specific line
---@param bufnr number
---@param linenr number
---@param col number
---@return table
function M.get_extmarks_on_line(bufnr, linenr, col)
	if not is_valid_buffer(bufnr) then
		return {}
	end

	return vim.api.nvim_buf_get_extmarks(bufnr, -1, { linenr, col }, { linenr, -1 }, {
		details = true,
		overlap = vim.fn.has("nvim-0.10.0") == 1,
	})
end

---Handle other extmarks
---@param bufnr number
---@param curline number
---@param col number
---@return number
function M.handle_other_extmarks(bufnr, curline, col)
	local extmarks = M.get_extmarks_on_line(bufnr, curline, col)
	local offset = 0

	for _, extmark in ipairs(extmarks) do
		local detail = extmark[4]
		if
			(detail.virt_text_pos == "eol" or detail.virt_text_pos == "win_col")
			and detail.virt_text
			and detail.virt_text[1]
			and detail.virt_text[1][1]
		then
			offset = offset + #detail.virt_text[1][1]
		end
	end

	if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
		offset = offset + count_inlay_hints_characters(bufnr, curline)
	end

	return offset
end

---Create extmarks
---@param opts table
---@param event table
---@param diag_line number
---@param virt_lines table
---@param offset number
---@param signs_offset number
---@param need_to_be_under boolean
---@param virt_priority number
function M.create_extmarks(
	opts,
	event,
	diag_line,
	diags_dims,
	virt_lines,
	offset,
	signs_offset,
	need_to_be_under,
	virt_priority
)
	if not is_valid_buffer(event.buf) or not virt_lines or vim.tbl_isempty(virt_lines) then
		return
	end

	local buf_lines_count = vim.api.nvim_buf_line_count(event.buf)
	if buf_lines_count == 0 then
		return
	end

	local win_col = need_to_be_under and 0 or get_window_position().col
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	-- Handle multiline extmarks
	if opts.options.multilines and diag_line ~= cursor_line then
		if should_skip_line(cursor_line, diag_line, diags_dims) then
			return
		end

		create_multiline_extmark(event.buf, diag_line, virt_lines, virt_priority)

		return
	end

	if need_to_be_under or diag_line - 1 + #virt_lines > buf_lines_count - 1 then
		handle_overflow_case(event.buf, {
			curline = diag_line,
			virt_lines = virt_lines,
			win_col = win_col,
			offset = offset,
			signs_offset = signs_offset,
			priority = virt_priority,
			need_to_be_under = need_to_be_under,
			buf_lines_count = buf_lines_count,
		})
	else
		for i = 1, #virt_lines do
			local col_offset = i == 1 and win_col or (win_col + offset + signs_offset)
			set_extmark(
				event.buf,
				diag_line + i - 1,
				virt_lines[i],
				col_offset,
				virt_priority,
				i > 1 and "overlay" or nil
			)
		end
	end
end

return M
