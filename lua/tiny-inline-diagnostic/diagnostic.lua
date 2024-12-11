local M = {}

local chunk_utils = require("tiny-inline-diagnostic.chunk")
local utils = require("tiny-inline-diagnostic.utils")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local timers = require("tiny-inline-diagnostic.timer")

local AUGROUP_NAME = "TinyInlineDiagnosticAutocmds"
local USER_EVENT = "TinyDiagnosticEvent"
local USER_EVENT_THROTTLED = "TinyDiagnosticEventThrottled"

M.enabled = true
M.user_toggle_state = true

local attached_buffers = {}

local function enable()
	M.enabled = true
	vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

local function disable()
	M.enabled = false
	vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

-- Diagnostic filtering functions
---@param opts DiagnosticConfig
---@param diagnostics table
---@param line number
---@param col number
---@return table
local function filter_diags_at_position(opts, diagnostics, line, col)
	if not diagnostics or #diagnostics == 0 then
		return {}
	end

	local diags_on_line = vim.tbl_filter(function(diag)
		return diag.lnum == line
	end, diagnostics)

	if opts.options.show_all_diags_on_cursorline then
		return #diags_on_line > 0 and diags_on_line or {}
	end

	local current_pos_diags = vim.tbl_filter(function(diag)
		return diag.lnum == line and col >= diag.col and col <= diag.end_col
	end, diagnostics)

	return #current_pos_diags > 0 and current_pos_diags or diags_on_line
end

---@param opts DiagnosticConfig
---@param buf number
---@param diagnostics table
---@return table
function M.filter_diags_under_cursor(opts, buf, diagnostics)
	if
		not vim.api.nvim_buf_is_valid(buf)
		or vim.api.nvim_get_current_buf() ~= buf
		or not diagnostics
		or #diagnostics == 0
	then
		return {}
	end

	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local curline, curcol = cursor_pos[1] - 1, cursor_pos[2]

	return filter_diags_at_position(opts, diagnostics, curline, curcol)
end

---@param opts DiagnosticConfig
---@param diagnostics table
---@return table
local function filter_by_severity(opts, diagnostics)
	local severity_filter = opts.options.severity
	return vim.tbl_filter(function(diag)
		return vim.tbl_contains(severity_filter, diag.severity)
	end, diagnostics)
end

---@param opts DiagnosticConfig
---@param event table
---@param diagnostics table
---@return table
local function filter_diagnostics(opts, event, diagnostics)
	local filtered = filter_by_severity(opts, diagnostics)

	if not opts.options.multilines then
		return M.filter_diags_under_cursor(opts, event.buf, filtered)
	end

	local under_cursor = M.filter_diags_under_cursor(opts, event.buf, filtered)
	return not vim.tbl_isempty(under_cursor) and under_cursor or filtered
end

---@param diagnostics table
---@return table
local function get_visible_diagnostics(diagnostics)
	local first_line = vim.fn.line("w0") - 1
	local last_line = vim.fn.line("w$")

	local visible_diags = {}
	for _, diag in ipairs(diagnostics) do
		if diag.lnum >= first_line and diag.lnum <= last_line then
			visible_diags[diag.lnum] = visible_diags[diag.lnum] or {}
			table.insert(visible_diags[diag.lnum], diag)
		end
	end

	return visible_diags
end

-- Core functionality
---@param opts DiagnosticConfig
---@param event table
local function apply_virtual_texts(opts, event)
	local current_win = vim.api.nvim_get_current_win()
	if not vim.api.nvim_win_is_valid(current_win) then
		return
	end

	if
		not M.user_toggle_state
		or not (M.enabled and vim.diagnostic.is_enabled() and vim.api.nvim_buf_is_valid(event.buf))
	then
		extmarks.clear(event.buf)
		return
	end

	local ok, diagnostics = pcall(vim.diagnostic.get, event.buf)
	if not ok or vim.tbl_isempty(diagnostics) then
		extmarks.clear(event.buf)
		return
	end

	local filtered_diags = filter_diagnostics(opts, event, diagnostics)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local visible_diags = get_visible_diagnostics(filtered_diags)

	extmarks.clear(event.buf)

	for lnum, diags in pairs(visible_diags) do
		if diags then
			local diagnostic_pos = { lnum, 0 }
			local virt_priority = opts.options.virt_texts.priority
			local virt_lines, offset, need_to_be_under

			if opts.options.multiple_diag_under_cursor and lnum == cursor_line then
				virt_lines, offset, need_to_be_under =
					virtual_text_forge.from_diagnostics(opts, diags, diagnostic_pos, event.buf)
			else
				local chunks = chunk_utils.get_chunks(opts, diags, 1, diagnostic_pos[1], cursor_line, event.buf)
				local max_width = chunk_utils.get_max_width_from_chunks(chunks.chunks) - 1
				virt_lines, offset, need_to_be_under = virtual_text_forge.from_diagnostic(opts, chunks, 1, max_width, 1)
			end

			extmarks.create_extmarks(
				opts,
				event,
				diagnostic_pos[1],
				virt_lines,
				offset,
				need_to_be_under,
				virt_priority
			)
		end
	end
end

---@param buf number
local function detach_buffer(buf)
	timers.close(buf)
	attached_buffers[buf] = nil
end

local function setup_cursor_autocmds(autocmd_ns, opts, event, throttle_apply)
	local events = { "CursorMoved" }
	if opts.options.enable_on_insert then
		table.insert(events, "CursorMovedI")
	end

	vim.api.nvim_create_autocmd(events, {
		group = autocmd_ns,
		buffer = event.buf,
		callback = function()
			if vim.api.nvim_buf_is_valid(event.buf) then
				throttle_apply()
			else
				detach_buffer(event.buf)
			end
		end,
		desc = "Update diagnostics on cursor move (throttled)",
	})
end

local function setup_mode_change_autocmds(autocmd_ns, event)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = autocmd_ns,
		pattern = "*:[vV\x16is]*",
		callback = function()
			if vim.api.nvim_buf_is_valid(event.buf) then
				disable()
				extmarks.clear(event.buf)
			else
				detach_buffer(event.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = autocmd_ns,
		pattern = "[vV\x16is]*:*",
		callback = function()
			if vim.api.nvim_buf_is_valid(event.buf) then
				enable()
			else
				detach_buffer(event.buf)
			end
		end,
	})
end

-- Autocmd setup
local function setup_buffer_autocmds(autocmd_ns, opts, event, throttled_apply)
	if not vim.api.nvim_buf_is_valid(event.buf) or attached_buffers[event.buf] then
		return
	end

	attached_buffers[event.buf] = true

	-- Diagnostic change events
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = autocmd_ns,
		callback = function()
			if vim.api.nvim_buf_is_valid(event.buf) then
				vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
			end
		end,
	})

	-- Core diagnostic events
	vim.api.nvim_create_autocmd("User", {
		group = autocmd_ns,
		pattern = USER_EVENT,
		callback = function()
			if not vim.api.nvim_buf_is_valid(event.buf) then
				detach_buffer(event.buf)
			end
			apply_virtual_texts(opts, event)
		end,
	})

	-- Buffer cleanup events
	vim.api.nvim_create_autocmd({ "LspDetach", "BufDelete", "BufUnload", "BufWipeout" }, {
		group = autocmd_ns,
		buffer = event.buf,
		callback = function()
			detach_buffer(event.buf)
		end,
	})

	-- Throttled events
	vim.api.nvim_create_autocmd("User", {
		group = autocmd_ns,
		pattern = USER_EVENT_THROTTLED,
		callback = function()
			if not vim.api.nvim_buf_is_valid(event.buf) then
				detach_buffer(event.buf)
			end
			throttled_apply()
		end,
	})

	-- Window resize handling
	vim.api.nvim_create_autocmd("VimResized", {
		group = autocmd_ns,
		buffer = event.buf,
		callback = function()
			if vim.api.nvim_buf_is_valid(event.buf) then
				vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
			else
				detach_buffer(event.buf)
			end
		end,
		desc = "Update diagnostics on window resize",
	})
end

---@param opts DiagnosticConfig
---@return boolean success
---@return string|nil error
function M.set_diagnostic_autocmds(opts)
	local autocmd_ns = vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
	timers.set_timers()

	local events = opts.options.overwrite_events or { "LspAttach" }

	vim.api.nvim_create_autocmd(events, {
		callback = function(event)
			if not vim.api.nvim_buf_is_valid(event.buf) then
				return
			end

			local throttled_fn, timer = utils.throttle(function()
				if vim.api.nvim_buf_is_valid(event.buf) then
					apply_virtual_texts(opts, event)
				end
			end, opts.options.throttle)

			timers.add(event.buf, timer)

			setup_buffer_autocmds(autocmd_ns, opts, event, throttled_fn)
			setup_cursor_autocmds(autocmd_ns, opts, event, throttled_fn)
			if not opts.options.enable_on_insert then
				setup_mode_change_autocmds(autocmd_ns, event)
			end
		end,
		desc = "Setup diagnostic display system",
	})

	return true
end

function M.enable()
	M.user_toggle_state = true
	vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

function M.disable()
	M.user_toggle_state = false
	vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

function M.toggle()
	M.user_toggle_state = not M.user_toggle_state
	vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

return M
