local M = {}

M.enabled = true

local chunk_utils = require("tiny-inline-diagnostic.chunk")
local utils = require("tiny-inline-diagnostic.utils")
local plugin_handler = require("tiny-inline-diagnostic.plugin")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local timers = require("tiny-inline-diagnostic.timer")

local attached_buffers = {}

--- Function to get diagnostics for the current position in the code.
--- @param diagnostics table - The table of diagnostics to check.
--- @param curline number - The current line number.
--- @param curcol number - The current column number.
--- @return table - A table of diagnostics for the current position.
local function get_current_pos_diags(diagnostics, curline, curcol)
	local current_pos_diags = {}

	for _, diag in ipairs(diagnostics) do
		if diag.lnum == curline and curcol >= diag.col and curcol <= diag.end_col then
			table.insert(current_pos_diags, diag)
		end
	end

	if next(current_pos_diags) == nil then
		if #diagnostics == 0 then
			return current_pos_diags
		end
		table.insert(current_pos_diags, diagnostics[1])
	end

	return current_pos_diags
end

--- Function to get the diagnostic under the cursor.
--- @param buf number - The buffer number to get the diagnostics for.
--- @param opts table - The table of options.
--- @return table, number - A table of diagnostics for the current position, the current line number.
function M.get_diagnostic_under_cursor(buf, opts)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local curline = cursor_pos[1] - 1
	local curcol = cursor_pos[2]

	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	if vim.api.nvim_get_current_buf() ~= buf then
		return
	end

	local diagnostics = vim.diagnostic.get(buf, { lnum = curline, severity = opts.options.severity })

	if #diagnostics == 0 then
		return
	end

	return get_current_pos_diags(diagnostics, curline, curcol), curcol
end

function M.get_all_diagnostics(buf, opts)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	if vim.api.nvim_get_current_buf() ~= buf then
		return
	end

	return vim.diagnostic.get(buf, { severity = opts.options.severity })
end

local function apply_diagnostics_virtual_texts(opts, event)
	extmarks.clear(event.buf)

	if not M.enabled then
		return
	end

	if not vim.diagnostic.is_enabled() then
		return
	end

	plugin_handler.init(opts)

	local diagnostics = nil
	if opts.options.multilines then
		diagnostics = M.get_all_diagnostics(event.buf, opts)
	else
		diagnostics = M.get_diagnostic_under_cursor(event.buf, opts)
	end

	if diagnostics == nil then
		return
	end

	if opts.options.multilines then
		local under_cursor_diags = M.get_diagnostic_under_cursor(event.buf, opts)
		if under_cursor_diags ~= nil then
			for i, diag in ipairs(diagnostics) do
				if diag.lnum == under_cursor_diags[1].lnum then
					table.remove(diagnostics, i)
				end
			end
			diagnostics = {}
			for _, diag in ipairs(under_cursor_diags) do
				table.insert(diagnostics, diag)
			end
		end
	end

	local fist_visually_seen_line = vim.fn.line("w0")
	local last_visually_seen_line = vim.fn.line("w$")

	-- group all_diags by lnum
	local all_diags_grouped = {}
	for _, diag in ipairs(diagnostics) do
		if diag.lnum >= fist_visually_seen_line - 1 and diag.lnum <= last_visually_seen_line then
			if all_diags_grouped[diag.lnum] == nil then
				all_diags_grouped[diag.lnum] = {}
			end
			table.insert(all_diags_grouped[diag.lnum], diag)
		end
	end

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	for lnum, line_diags in pairs(all_diags_grouped) do
		if line_diags == nil then
			return
		end

		local diagnostic_pos = {
			lnum,
			0,
		}

		local virt_priority = opts.options.virt_texts.priority
		local virt_lines, offset, need_to_be_under

		if opts.options.multiple_diag_under_cursor and lnum == cursor_line then
			virt_lines, offset, need_to_be_under =
				virtual_text_forge.from_diagnostics(opts, line_diags, diagnostic_pos, event.buf)
		else
			local plugin_offset = plugin_handler.handle_plugins(opts)
			local ret = chunk_utils.get_chunks(opts, line_diags, 1, plugin_offset, diagnostic_pos[1], event.buf)

			local max_chunk_line_length = chunk_utils.get_max_width_from_chunks(ret.chunks)

			virt_lines, offset, need_to_be_under =
				virtual_text_forge.from_diagnostic(opts, ret, diagnostic_pos, 1, max_chunk_line_length, 1)
		end

		extmarks.create_extmarks(opts, event, diagnostic_pos[1], virt_lines, offset, need_to_be_under, virt_priority)
	end
end

--- Function to set diagnostic autocmds.
--- This function creates an autocmd for the `LspAttach` event.
--- @param opts table - The table of options, which includes the `clear_on_insert` option and the signs to use for the virtual texts.
function M.set_diagnostic_autocmds(opts)
	local autocmd_ns = vim.api.nvim_create_augroup("TinyInlineDiagnosticAutocmds", { clear = true })

	timers.set_timers()

	local events = opts.options.overwrite_events or { "LspAttach" }

	vim.api.nvim_create_autocmd(events, {
		callback = function(event)
			if attached_buffers[event.buf] then
				return
			end

			table.insert(attached_buffers, event.buf)

			local throttled_apply_diagnostics_virtual_texts, timer = utils.throttle(function()
				apply_diagnostics_virtual_texts(opts, event)
			end, opts.options.throttle)

			timers.add(event.buf, timer)

			vim.api.nvim_create_autocmd("User", {
				group = autocmd_ns,
				pattern = "TinyDiagnosticEvent",
				callback = function()
					apply_diagnostics_virtual_texts(opts, event)
				end,
			})

			vim.api.nvim_create_autocmd({ "LspDetach", "BufDelete" }, {
				group = autocmd_ns,
				buffer = event.buf,
				callback = function()
					timers.close(event.buf)

					if attached_buffers[event.buf] then
						attached_buffers[event.buf] = nil
					end
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				group = autocmd_ns,
				pattern = "TinyDiagnosticEventThrottled",
				callback = function()
					throttled_apply_diagnostics_virtual_texts()
				end,
			})

			vim.api.nvim_create_autocmd("CursorHold", {
				group = autocmd_ns,
				buffer = event.buf,
				callback = function()
					if vim.api.nvim_buf_is_valid(event.buf) then
						vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEvent" })
					end
				end,
				desc = "Show diagnostics on cursor hold",
			})

			vim.api.nvim_create_autocmd("DiagnosticChanged", {
				group = autocmd_ns,
				buffer = event.buf,
				callback = function()
					if vim.api.nvim_buf_is_valid(event.buf) then
						vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEvent" })
					end
				end,
			})

			vim.api.nvim_create_autocmd({ "VimResized" }, {
				group = autocmd_ns,
				buffer = event.buf,
				callback = function()
					if vim.api.nvim_buf_is_valid(event.buf) then
						vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEvent" })
					end
				end,
				desc = "Handle window resize event, force diagnostics update to fit new window width.",
			})

			vim.api.nvim_create_autocmd("CursorMoved", {
				group = autocmd_ns,
				buffer = event.buf,
				callback = function()
					if vim.api.nvim_buf_is_valid(event.buf) then
						vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEventThrottled" })
					end
				end,
				desc = "Show diagnostics on cursor move, throttled.",
			})

			vim.api.nvim_create_autocmd("ModeChanged", {
				group = autocmd_ns,
				pattern = "*:[vV\x16is]*",
				callback = function()
					if vim.api.nvim_buf_is_valid(event.buf) then
						M.disable()
						extmarks.clear(event.buf)
					end
				end,
			})

			vim.api.nvim_create_autocmd("ModeChanged", {
				group = autocmd_ns,
				pattern = "[vV\x16is]*:*",
				callback = function()
					if vim.api.nvim_buf_is_valid(event.buf) then
						M.enable()
					end
				end,
			})
		end,
		desc = "Apply autocmds for diagnostics on cursor move and window resize events.",
	})
end

function M.enable()
	M.enabled = true
	vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEvent" })
end

function M.disable()
	M.enabled = false
	vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEvent" })
end

function M.toggle()
	M.enabled = not M.enabled
	vim.api.nvim_exec_autocmds("User", { pattern = "TinyDiagnosticEvent" })
end

return M
