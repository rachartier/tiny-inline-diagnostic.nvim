local M = {}

local extmarks = require("tiny-inline-diagnostic.extmarks")
local utils = require("tiny-inline-diagnostic.utils")
local highlights = require("tiny-inline-diagnostic.highlights")

--- Calculate the maximum width from a list of chunks.
---@param chunks table: A table representing the chunks of a diagnostic message.
---@return number: The maximum width among all chunks.
function M.get_max_width_from_chunks(chunks)
	local max_chunk_line_length = 0

	for _, chunk in ipairs(chunks) do
		local line_length = vim.fn.strdisplaywidth(chunk)
		if line_length > max_chunk_line_length then
			max_chunk_line_length = line_length
		end
	end

	return max_chunk_line_length
end

--- Generate a header for a diagnostic message chunk.
---@param message string: The diagnostic message.
---@param index_diag number: The index of the diagnostic message.
---@param chunk_info ChunkInfo
---@param opts table: The options table, which includes signs for the diagnostic message.
---@param diag_hi string: The highlight group for the diagnostic message.
---@param diag_inv_hi string: The highlight group for the diagnostic signs.
---@param total_chunks number: The total number of chunks.
---@param severities table: The severities of the diagnostic messages.
---@return table: A table representing the virtual text array for the diagnostic message header.
function M.get_header_from_chunk(message, index_diag, chunk_info, opts, diag_hi, diag_inv_hi, total_chunks, severities)
	local virt_texts = {}
	local num_chunks = #chunk_info.chunks
	local need_to_be_under = chunk_info.need_to_be_under

	if index_diag == 1 then
		virt_texts = { { opts.signs.left, diag_inv_hi } }
	end

	vim.list_extend(virt_texts, { { " ", diag_hi } })

	if index_diag == 1 and total_chunks == 1 then
		M.add_severity_icons(virt_texts, opts, severities, diag_hi)
	end

	local icon = M.get_diagnostic_icon(opts, severities, index_diag, total_chunks)
	vim.list_extend(virt_texts, { { icon, diag_hi } })

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	if not opts.options.add_messages and cursor_line ~= chunk_info.line then
		message = ""
	end
	M.add_message_text(virt_texts, message, num_chunks, total_chunks, index_diag, opts, diag_hi, diag_inv_hi)

	return virt_texts
end

--- Add severity icons to the virtual text array.
---@param virt_texts table: The virtual text array.
---@param opts table: The options table.
---@param severities table: The severities of the diagnostic messages.
---@param diag_hi string: The highlight group for the diagnostic message.
function M.add_severity_icons(virt_texts, opts, severities, diag_hi)
	if severities and #severities > 0 then
		table.sort(severities, function(a, b)
			return a > b
		end)

		for i = 1, #severities - 1 do
			local hl, _, _ =
				highlights.get_diagnostic_mixed_highlights_from_severity(severities[#severities], severities[i])
			local icon = opts.signs.diag

			if opts.options.use_icons_from_diagnostic then
				icon = highlights.get_diagnostic_icon(severities[i])
			end

			local severity_virt_texts = { { icon, hl } }
			vim.list_extend(virt_texts, severity_virt_texts)
		end
	end
end

--- Get the diagnostic icon based on the options and severities.
---@param opts table: The options table.
---@param severities table: The severities of the diagnostic messages.
---@param index_diag number: The index of the diagnostic message.
---@param total_chunks number: The total number of chunks.
---@return string: The diagnostic icon.
function M.get_diagnostic_icon(opts, severities, index_diag, total_chunks)
	local icon = opts.signs.diag

	if opts.options.use_icons_from_diagnostic then
		if total_chunks == 1 then
			icon = highlights.get_diagnostic_icon(severities[#severities])
		else
			icon = highlights.get_diagnostic_icon(severities[index_diag])
		end
	end

	return icon
end

--- Add the message text to the virtual text array.
---@param virt_texts table: The virtual text array.
---@param message string: The diagnostic message.
---@param num_chunks number: The total number of chunks the message is split into.
---@param total_chunks number: The total number of chunks.
---@param index_diag number: The index of the diagnostic message.
---@param opts table: The options table.
---@param diag_hi string: The highlight group for the diagnostic message.
---@param diag_inv_hi string: The highlight group for the diagnostic signs.
function M.add_message_text(virt_texts, message, num_chunks, total_chunks, index_diag, opts, diag_hi, diag_inv_hi)
	local text_after_message = " "

	if num_chunks == 1 then
		if total_chunks == 1 or index_diag == total_chunks then
			if message ~= "" then
				message = message .. " "
			end
			vim.list_extend(virt_texts, { { " " .. message, diag_hi }, { opts.signs.right, diag_inv_hi } })
		else
			vim.list_extend(virt_texts, {
				{ " " .. message .. text_after_message, diag_hi },
				-- { string.rep(" ", vim.fn.strcharlen(opts.signs.right)), diag_inv_hi },
			})
		end
	else
		vim.list_extend(virt_texts, {
			{ " " .. message .. text_after_message, diag_hi },
			-- { string.rep(" ", vim.fn.strcharlen(opts.signs.right)), diag_inv_hi },
		})
	end
end

--- Generate the body for a diagnostic message chunk.
---@param chunk string: The chunk of the diagnostic message.
---@param index_diag number: The index of the diagnostic message.
---@param index_chunk number: The index of the chunk.
---@param num_chunks number: The total number of chunks the message is split into.
---@param need_to_be_under boolean: A flag indicating whether the arrow needs to point upwards.
---@param opts table: The options table, which includes signs for the diagnostic message.
---@param diag_hi string: The highlight group for the diagnostic message.
---@param diag_inv_hi string: The highlight group for the diagnostic signs.
---@param total_chunks number: The total number of chunks.
---@return table: A table representing the virtual text array for the diagnostic message body.
function M.get_body_from_chunk(
	chunk,
	index_diag,
	index_chunk,
	num_chunks,
	need_to_be_under,
	opts,
	diag_hi,
	diag_inv_hi,
	total_chunks
)
	local vertical_sign = opts.signs.vertical
	local is_last = index_diag == total_chunks and index_chunk == num_chunks

	if index_chunk == num_chunks then
		vertical_sign = opts.signs.vertical_end
	end

	local chunk_virtual_texts = {
		{ vertical_sign, diag_hi },
		{ " " .. chunk, diag_hi },
		{ " ", diag_hi },
	}

	if is_last then
		vim.list_extend(chunk_virtual_texts, { { opts.signs.right, diag_inv_hi } })
	end

	return chunk_virtual_texts
end

--- Get the arrow for a diagnostic message chunk.
---@param opts table: The options table.
---@param diagnostic_line number: The line number of the diagnostic message.
---@param ret table: The return table containing diagnostic information.
---@param hl_diag_hi string: The highlight group for the diagnostic message.
---@return table: A table representing the virtual text array for the arrow.
function M.get_arrow_from_chunk(opts, diagnostic_line, ret, hl_diag_hi)
	local arrow = opts.signs.arrow
	local need_to_be_under = ret.need_to_be_under

	local chunk = {}

	local hi = "TinyInlineDiagnosticVirtualTextArrow"
	if opts.options.set_arrow_to_diag_color then
		hi = hl_diag_hi
	end

	if diagnostic_line ~= ret.line or ret.need_to_be_under then
		hi = "TinyInlineDiagnosticVirtualTextArrowNoBg"

		if opts.options.set_arrow_to_diag_color then
			hi = hl_diag_hi
		end
	end

	if need_to_be_under then
		arrow = opts.signs.up_arrow
		chunk = {
			{ "", "None" },
			{ arrow, hi },
		}
	else
		chunk = { arrow, hi }
	end

	return chunk
end

--- Split a diagnostic message into chunks for overflow handling.
---@param message string: The diagnostic message.
---@param offset number: The offset from the start of the line to the diagnostic position.
---@param win_width number: The width of the window where the diagnostic message is displayed.
---@param opts table: The options table, which includes signs for the diagnostic message and the softwrap option.
---@return table: A table representing the chunks of the diagnostic message.
function M.get_message_chunks_for_overflow(message, offset, win_width, opts)
	local signs_total_text_len = #opts.signs.arrow + #opts.signs.right + #opts.signs.left + #opts.signs.diag + 4
	local distance = win_width - offset - signs_total_text_len
	return utils.wrap_text(message, distance)
end

--- Get the chunks for a diagnostic message.
---@param opts table: The options table.
---@param diags_on_line table: The diagnostics on the line.
---@param diag_index number: The index of the diagnostic message.
---@param diag_line number: The line number of the diagnostic message.
---@param cursor_line number: The line number of the cursor.
---@param buf number: The buffer number.
---@return table: A table containing the chunks and other diagnostic information.
function M.get_chunks(opts, diags_on_line, diag_index, diag_line, cursor_line, buf)
	local win_width = vim.api.nvim_win_get_width(0)
	local lines = vim.api.nvim_buf_get_lines(buf, diag_line, diag_line + 1, false)
	local line_length = lines[1] and #lines[1] or 0
	local offset = 0
	local need_to_be_under = false

	local diag = diags_on_line[diag_index]

	local show_source = false
	if type(opts.options.show_source) == "table" then
		if opts.options.show_source.enabled then
			if opts.options.show_source.if_many then
				local sources = {}
				for _, d in ipairs(diags_on_line) do
					if d.source then
						sources[d.source] = true
					end
				end
				show_source = vim.tbl_count(sources) > 1
			else
				show_source = true
			end
		end
	elseif opts.options.show_source then
		show_source = true
	end

	if show_source and diag.source then
		diag.message = diag.message .. " (" .. diag.source .. ")"
	end

	local chunks = { diag.message }
	local severities = vim.tbl_map(function(d)
		return d.severity
	end, diags_on_line)

	local other_extmarks_offset = extmarks.handle_other_extmarks(buf, diag_line, line_length)

	if (opts.options.overflow.mode ~= "none" and not opts.options.multilines) or cursor_line == diag_line then
		if (line_length + other_extmarks_offset) > win_width - opts.options.softwrap then
			need_to_be_under = true
		end
	end

	local diag_message = diag.message

	if opts.options.format and diag_message then
		diag_message = opts.options.format(diag)
	end

	if not opts.options.multilines or cursor_line == diag_line then
		chunks = M.handle_overflow_modes(opts, diag_message, need_to_be_under, win_width, offset)
	else
		chunks = { " " .. diag_message }
	end

	return {
		chunks = chunks,
		severity = diag.severity,
		severities = severities,
		source = diag.source,
		offset = offset,
		offset_win_col = other_extmarks_offset,
		need_to_be_under = need_to_be_under,
		line = diag.lnum,
	}
end

--- Handle different overflow modes for diagnostic messages.
---@param opts table: The options table.
---@param diag_message string: The diagnostic message.
---@param need_to_be_under boolean: A flag indicating whether the arrow needs to point upwards.
---@param win_width number: The width of the window where the diagnostic message is displayed.
---@param offset number: The offset from the start of the line to the diagnostic position.
---@return table: A table representing the chunks of the diagnostic message.
function M.handle_overflow_modes(opts, diag_message, need_to_be_under, win_width, offset)
	local chunks = {}

	if opts.options.break_line.enabled then
		chunks = utils.wrap_text(diag_message, opts.options.break_line.after)
	elseif opts.options.overflow.mode == "wrap" then
		if need_to_be_under then
			offset = 0
		else
			local ok, win_col = pcall(vim.fn.virtcol, "$")
			offset = ok and win_col or 0
		end
		offset = (opts.options.overflow.padding or 0) + offset
		chunks = M.get_message_chunks_for_overflow(diag_message, offset, win_width, opts)
	elseif opts.options.overflow.mode == "none" then
		chunks = utils.wrap_text(diag_message, 0)
	elseif opts.options.overflow.mode == "oneline" then
		chunks = utils.remove_newline(diag_message)
	end

	return chunks
end

return M
