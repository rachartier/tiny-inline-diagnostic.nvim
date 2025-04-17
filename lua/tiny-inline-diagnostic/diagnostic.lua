local M = {}

local chunk_utils = require("tiny-inline-diagnostic.chunk")
local utils = require("tiny-inline-diagnostic.utils")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local timers = require("tiny-inline-diagnostic.timer")

local AUGROUP_NAME = "TinyInlineDiagnosticAutocmds"
local USER_EVENT = "TinyDiagnosticEvent"
local USER_EVENT_THROTTLED = "TinyDiagnosticEventThrottled"
local DISABLED_MODES = {}

M.enabled = true
M.user_toggle_state = true
local attached_buffers = {}

---We store the diagnostics by buffer and then by source.
---Without that, because we're using the diagnostics from the
---`DiagnosticChanged` event, we would overwrite the diagnostics
---of the other sources.
---Buffer number => diagnotic source => diagnostic
---@type table<number, table<string, any>>
local diagnostics_cache = {}

---@class DiagnosticPosition
---@field line number
---@field col number

local function enable()
	-- Prevents calling `enable` even if it's not needed
	if not M.enabled then
		M.enabled = true
		vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
	end
end

local function disable()
	if M.enabled then
		M.enabled = false
		vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
	end
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
	return filter_diags_at_position(opts, diagnostics, cursor_pos[1] - 1, cursor_pos[2])
end

---@param opts DiagnosticConfig
---@param diagnostics table
---@return table
local function filter_by_severity(opts, diagnostics)
	return vim.tbl_filter(function(diag)
		return vim.tbl_contains(opts.options.severity, diag.severity)
	end, diagnostics)
end

---@param opts DiagnosticConfig
---@param event table
---@param diagnostics table
---@return table
local function filter_diagnostics(opts, event, diagnostics)
	if not opts.options.multilines.enabled then
		return M.filter_diags_under_cursor(opts, event.buf, diagnostics)
	end

	if opts.options.multilines.always_show then
		return diagnostics
	end

	local under_cursor = M.filter_diags_under_cursor(opts, event.buf, diagnostics)
	return not vim.tbl_isempty(under_cursor) and under_cursor or diagnostics
end

---@param diagnostics table
---@return table<number, table>
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

---@param opts DiagnosticConfig
---@param bufnr number
---@param diagnostics table
local function update_diagnostics_cache(opts, bufnr, diagnostics)
	-- Do the upfront work of filtering and sorting
	diagnostics = filter_by_severity(opts, diagnostics)
	local per_source = utils.group_by(diagnostics, "source")
	if not diagnostics_cache[bufnr] then
		diagnostics_cache[bufnr] = {}
	end
	for source, source_diags in pairs(per_source) do
		table.sort(source_diags, function(a, b)
			return a.severity < b.severity
		end)
		diagnostics_cache[bufnr][source] = source_diags
	end
end

---Return all the diagnostics of the buffer.
---@param bufnr number
---@return table
local function get_diagnostics(bufnr)
	local all_diags = {}
	for _, diags in pairs(diagnostics_cache[bufnr] or {}) do
		for _, diag in ipairs(diags or {}) do
			table.insert(all_diags, diag)
		end
	end
	return all_diags
end

---@param opts DiagnosticConfig
---@param event table
local function apply_virtual_texts(opts, event)
	-- Validate window and state
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

	-- Get diagnostics and clear them if needed
	local diagnostics = get_diagnostics(event.buf)
	if diagnostics == nil or vim.tbl_isempty(diagnostics) then
		extmarks.clear(event.buf)
		return
	end

	-- Process diagnostics
	local filtered_diags = filter_diagnostics(opts, event, diagnostics)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local visible_diags = get_visible_diagnostics(filtered_diags)

	-- Clear existing extmarks
	extmarks.clear(event.buf)

	local diags_dims = {}
	local to_render = {}
	local virt_priority = opts.options.virt_texts.priority

	-- Create new extmarks
	for lnum, diags in pairs(visible_diags) do
		if diags then
			local diagnostic_pos = { lnum, 0 }
			local virt_lines, offset, need_to_be_under

			if lnum == cursor_line then
				virt_lines, offset, need_to_be_under =
					virtual_text_forge.from_diagnostics(opts, diags, diagnostic_pos, event.buf)
			else
				local chunks = chunk_utils.get_chunks(opts, diags, 1, diagnostic_pos[1], cursor_line, event.buf)
				local max_width = chunk_utils.get_max_width_from_chunks(chunks.chunks)
				virt_lines, offset, need_to_be_under = virtual_text_forge.from_diagnostic(opts, chunks, 1, max_width, 1)
			end

			table.insert(diags_dims, { lnum, #virt_lines })
			table.insert(to_render, {
				virt_lines = virt_lines,
				offset = offset,
				need_to_be_under = need_to_be_under,
				diagnostic_pos = diagnostic_pos,
			})
		end
	end

	for _, data in ipairs(to_render) do
		local virt_lines = data.virt_lines
		local offset = data.offset
		local need_to_be_under = data.need_to_be_under
		local diagnostic_pos = data.diagnostic_pos
		local signs_offset = 0

		if need_to_be_under then
			signs_offset = vim.fn.strdisplaywidth(opts.signs.left)
		else
			signs_offset = vim.fn.strdisplaywidth(opts.signs.left) + vim.fn.strdisplaywidth(opts.signs.arrow)
		end

		extmarks.create_extmarks(
			opts,
			event,
			diagnostic_pos[1],
			diags_dims,
			virt_lines,
			offset,
			signs_offset,
			need_to_be_under,
			virt_priority
		)
	end
end

---@param buf number
local function detach_buffer(buf)
	timers.close(buf)
	attached_buffers[buf] = nil
	diagnostics_cache[buf] = nil
end

---@param autocmd_ns number
---@param opts DiagnosticConfig
---@param event table
---@param throttle_apply function
local function setup_cursor_autocmds(autocmd_ns, opts, event, throttle_apply)
	local events = opts.options.enable_on_insert and { "CursorMoved", "CursorMovedI" } or { "CursorMoved" }

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

---@param autocmd_ns number
---@param event table
local function setup_mode_change_autocmds(autocmd_ns, event)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = autocmd_ns,
		callback = function()
			local mode = vim.api.nvim_get_mode().mode

			if not vim.api.nvim_buf_is_valid(event.buf) then
				detach_buffer(event.buf)
				return
			end

			if vim.tbl_contains(DISABLED_MODES, mode) then
				disable()
				extmarks.clear(event.buf)
			else
				enable()
			end
		end,
	})
end

---@param autocmd_ns number
---@param opts DiagnosticConfig
---@param event table
---@param throttled_apply function
local function setup_buffer_autocmds(autocmd_ns, opts, event, throttled_apply)
	if not vim.api.nvim_buf_is_valid(event.buf) or attached_buffers[event.buf] then
		return
	end

	attached_buffers[event.buf] = true

	-- Setup diagnostic change events
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = autocmd_ns,
		callback = function(args)
			if vim.api.nvim_buf_is_valid(args.buf) then
				update_diagnostics_cache(opts, args.buf, args.data.diagnostics)
				vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
			end
		end,
	})

	-- Setup core diagnostic events
	vim.api.nvim_create_autocmd("User", {
		group = autocmd_ns,
		pattern = USER_EVENT,
		callback = function()
			if not vim.api.nvim_buf_is_valid(event.buf) then
				detach_buffer(event.buf)
				return
			end
			apply_virtual_texts(opts, event)
		end,
	})

	-- Setup buffer cleanup events
	vim.api.nvim_create_autocmd({ "LspDetach", "BufDelete", "BufUnload", "BufWipeout" }, {
		group = autocmd_ns,
		buffer = event.buf,
		callback = function()
			detach_buffer(event.buf)
		end,
	})

	-- Setup throttled events
	vim.api.nvim_create_autocmd("User", {
		group = autocmd_ns,
		pattern = USER_EVENT_THROTTLED,
		callback = function()
			if not vim.api.nvim_buf_is_valid(event.buf) then
				detach_buffer(event.buf)
				return
			end
			throttled_apply()
		end,
	})

	-- Setup window resize handling
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

---Setup diagnostic autocmds
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

			if not opts.options.enable_on_select then
				table.insert(DISABLED_MODES, "s")
			end

			if not opts.options.enable_on_insert then
				table.insert(DISABLED_MODES, "i")
				table.insert(DISABLED_MODES, "v")
				table.insert(DISABLED_MODES, "V")
			end

			if vim.tbl_contains(opts.disabled_ft, vim.bo[event.buf].filetype) then
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
			setup_mode_change_autocmds(autocmd_ns, event)
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

function M.get_diagnostic_under_cursor()
	local buf = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(buf)
	return M.filter_diags_under_cursor({ options = {} }, buf, diagnostics)
end

return M
