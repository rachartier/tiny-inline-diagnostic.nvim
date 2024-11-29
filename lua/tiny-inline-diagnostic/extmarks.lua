local M = {}

local uuid_extmark = 999999999999
local count_lines_to_skip_extmark = {
	count = 0,
	start_line = 0,
}

local diagnostic_ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
local utils = require("tiny-inline-diagnostic.utils")

function M.clear(buf)
	pcall(vim.api.nvim_buf_clear_namespace, buf, diagnostic_ns, 0, -1)
end

function M.get_extmarks_on_line(bufnr, linenr, col)
	local namespace_id = -1
	local start_pos = { linenr, col }
	local end_pos = { linenr, -1 }

	local opts = {
		details = true,
	}

	if vim.fn.has("nvim-0.10.0") == 1 then
		vim.tbl_extend("force", opts, {
			overlap = true,
		})
	end

	local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace_id, start_pos, end_pos, opts)

	return extmarks
end

function M.handle_other_extmarks(opts, buf, curline, col)
	local e = M.get_extmarks_on_line(buf, curline, col)
	local offset = 0

	if #e > 0 then
		for _, extmark in ipairs(e) do
			local detail = extmark[4]
			local to_check = {
				"eol",
				"win_col",
			}
			for _, to in ipairs(to_check) do
				if detail["virt_text_pos"] == to then
					if detail["virt_text"] ~= nil and detail["virt_text"][1][1] ~= nil then
						offset = offset + #detail["virt_text"][1][1]
					end
				end
			end
		end
	end

	return offset
end

local function get_uuid()
	uuid_extmark = uuid_extmark - 1

	if uuid_extmark < 0 then
		uuid_extmark = 999999999999
	end

	return uuid_extmark
end

local function get_relative_position()
	local col = vim.fn.virtcol("$")
	local win_row = vim.fn.winline() - 1
	local leftcol = vim.fn.winsaveview().leftcol

	return { row = win_row, col = col - leftcol }
end

function M.create_extmarks(opts, event, curline, virt_lines, offset, need_to_be_under, virt_prorioty)
	local diag_overflow_last_line = false
	local buf_lines_count = vim.api.nvim_buf_line_count(event.buf)

	local total_lines = #virt_lines
	if curline - 1 + total_lines > buf_lines_count - 1 then
		diag_overflow_last_line = true
	end

	local win_col = get_relative_position().col

	if need_to_be_under then
		win_col = 0
	end

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	if opts.options.multilines and curline ~= cursor_line then
		if
			count_lines_to_skip_extmark.count > 0
			and curline > count_lines_to_skip_extmark.start_line
			and curline < count_lines_to_skip_extmark.start_line + count_lines_to_skip_extmark.count
		then
			count_lines_to_skip_extmark.count = count_lines_to_skip_extmark.count - 1
			return
		end

		local v = {}
		for i, line in ipairs(virt_lines) do
			if i > 1 then
				table.insert(v, line)
			end
		end

		vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline, 0, {
			id = curline + 1000,
			line_hl_group = "None",
			virt_text_pos = "eol",
			virt_text = virt_lines[1],
			virt_lines = v,
			priority = virt_prorioty,
			strict = false,
		})
		return
	end

	count_lines_to_skip_extmark.count = #virt_lines
	count_lines_to_skip_extmark.start_line = curline

	if need_to_be_under then
		vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline + 1, 0, {
			id = get_uuid(),
			line_hl_group = "None",
			virt_text_pos = "overlay",
			virt_text_win_col = 0,
			virt_text = virt_lines[2],
			priority = virt_prorioty,
			strict = false,
		})
		table.remove(virt_lines, 2)
		win_col = 0

		if curline < buf_lines_count - 1 then
			curline = curline + 1
		end
	end

	if diag_overflow_last_line then
		local other_virt_lines = {}
		for i, line in ipairs(virt_lines) do
			if i > 1 then
				table.insert(line, 1, { string.rep(" ", win_col + offset), "None" })
				table.insert(other_virt_lines, line)
			end
		end

		vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline, 0, {
			id = get_uuid(),
			line_hl_group = "TinyInlineDiagnosticVirtualTextBg",
			virt_text_pos = "overlay",
			virt_text = virt_lines[1],
			virt_lines = other_virt_lines,
			virt_text_win_col = win_col + offset,
			priority = virt_prorioty,
			strict = false,
		})
	else
		vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline, 0, {
			id = get_uuid(),
			line_hl_group = "TinyInlineDiagnosticVirtualTextBg",
			virt_text_pos = "eol",
			virt_text = virt_lines[1],
			virt_text_win_col = win_col,
			priority = virt_prorioty,
			strict = false,
		})

		for i, line in ipairs(virt_lines) do
			if i > 1 then
				vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline + i - 1, 0, {
					id = get_uuid(),
					virt_text_pos = "overlay",
					virt_text = line,
					virt_text_win_col = win_col + offset,
					priority = virt_prorioty,
					strict = false,
				})
			end
		end
	end
end

return M
