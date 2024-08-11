local M = {}

local extmarks = require("tiny-inline-diagnostic.extmarks")
local utils = require("tiny-inline-diagnostic.utils")

--- Function to calculates the maximum width from a list of chunks.
--- @param chunks table: A table representing the chunks of a diagnostic message.
--- @return number: The maximum width among all chunks.
function M.get_max_width_from_chunks(chunks)
	local max_chunk_line_length = 0

	for i = 1, #chunks do
		if #chunks[i] > max_chunk_line_length then
			max_chunk_line_length = #chunks[i]
		end
	end

	return max_chunk_line_length
end

--- Function to generates a header for a diagnostic message chunk.
--- @param message string: The diagnostic message.
--- @param num_chunks number: The total number of chunks the message is split into.
--- @param opts table: The options table, which includes signs for the diagnostic message.
--- @param diag_hi string: The highlight group for the diagnostic message.
--- @param diag_inv_hi string: The highlight group for the diagnostic signs.
--- @return table: A table representing the virtual text array for the diagnostic message header.
function M.get_header_from_chunk(
	message,
	index_diag,
	num_chunks,
	need_to_be_under,
	opts,
	diag_hi,
	diag_inv_hi,
	total_chunks
)
	local virt_texts = {}

	if index_diag == 1 then
		virt_texts = {
			{ opts.signs.left, diag_inv_hi },
			{ opts.signs.diag, diag_hi },
		}
	else
		virt_texts = {
			{ " ", "None" },
			{ opts.signs.diag, diag_hi },
		}
	end

	if not need_to_be_under and index_diag > 1 then
		table.insert(virt_texts, 1, { string.rep(" ", #opts.signs.arrow - 2), diag_inv_hi })
	end

	-- if need_to_be_under then
	--     virt_texts = {
	--         { string.rep(" ", #opts.signs.arrow - 1) .. " ", diag_inv_hi },
	--         { opts.signs.diag,                               diag_hi },
	--     }
	-- end

	local text_after_message = " "

	if num_chunks == 1 then
		if total_chunks == 1 or index_diag == total_chunks then
			vim.list_extend(virt_texts, {
				{ " " .. message .. " ", diag_hi },
				{ opts.signs.right, diag_inv_hi },
			})
		else
			vim.list_extend(virt_texts, {
				{ " " .. message .. text_after_message, diag_hi },
				{ string.rep(" ", #opts.signs.right), diag_inv_hi },
			})
		end
	else
		vim.list_extend(virt_texts, {
			{ " " .. message .. text_after_message, diag_hi },
			{ string.rep(" ", #opts.signs.right), diag_inv_hi },
		})
	end

	return virt_texts
end

--- Function to generates the body for a diagnostic message chunk.
--- @param chunk string: The chunk of the diagnostic message.
--- @param opts table: The options table, which includes signs for the diagnostic message.
--- @param need_to_be_under boolean: A flag indicating whether the arrow needs to point upwards.
--- @param diag_hi string: The highlight group for the diagnostic message.
--- @param diag_inv_hi string: The highlight group for the diagnostic signs.
--- @return table: A table representing the virtual text array for the diagnostic message body.
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

	if not need_to_be_under then
		table.insert(chunk_virtual_texts, 1, { string.rep(" ", #opts.signs.arrow - 1), diag_inv_hi })
	else
		table.insert(chunk_virtual_texts, 1, { " ", diag_inv_hi })
	end

	if is_last then
		vim.list_extend(chunk_virtual_texts, {
			{ opts.signs.right, diag_inv_hi },
		})
	end

	return chunk_virtual_texts
end

function M.get_arrow_from_chunk(opts, need_to_be_under)
	local arrow = opts.signs.arrow
	local chunk = {}

	if need_to_be_under then
		arrow = opts.signs.up_arrow
		chunk = {
			{ " ", "None" },
			{ arrow, "TinyInlineDiagnosticVirtualTextArrow" },
		}
	else
		chunk = { arrow, "TinyInlineDiagnosticVirtualTextArrow" }
	end

	return chunk
end

--- Function to splits a diagnostic message into chunks for overflow handling.
--- @param message string: The diagnostic message.
--- @param offset number: The offset from the start of the line to the diagnostic position.
--- @param win_width number: The width of the window where the diagnostic message is displayed.
--- @param opts table: The options table, which includes signs for the diagnostic message and the softwrap option.
--- @return table: A table representing the chunks of the diagnostic message.
function M.get_message_chunks_for_overflow(message, offset, win_width, opts)
	local signs_total_text_len = #opts.signs.arrow + #opts.signs.right + #opts.signs.left + #opts.signs.diag + 4

	local distance = win_width - offset - signs_total_text_len

	-- if distance < opts.options.softwrap then
	--     distance = win_width - signs_total_text_len - #message
	--     print("distance", distance)
	-- end

	local message_chunk = {}
	message_chunk = utils.wrap_text(message, distance)

	return message_chunk
end

function M.get_chunks(opts, diag, plugin_offset, curline, buf)
	local win_width = vim.api.nvim_win_get_width(0)
	local lines = vim.api.nvim_buf_get_lines(buf, curline, curline + 1, false)
	local line_length = 0
	local offset = 0
	local need_to_be_under = false
	local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	-- local win_option_wrap_enabled = vim.api.nvim_get_option_value("wrap", { win = 0 })

	if lines ~= nil and lines[1] ~= nil then
		line_length = #lines[1]
	end

	local chunks = { diag.message }

	local other_extmarks_offset = extmarks.handle_other_extmarks(opts, buf, curline, line_length)

	if (opts.options.overflow.mode ~= "none" and not opts.options.multilines) or current_line == curline then
		if line_length > win_width - opts.options.softwrap then
			need_to_be_under = true
		end
	end

	if not opts.options.multilines or current_line == curline then
		if opts.options.break_line.enabled == true then
			chunks = {}
			chunks = utils.wrap_text(diag.message, opts.options.break_line.after)
		elseif opts.options.overflow.mode == "wrap" then
			if need_to_be_under then
				offset = 0
			else
				local win_col = vim.fn.virtcol("$")
				offset = win_col
			end

			chunks = M.get_message_chunks_for_overflow(
				diag.message,
				offset + plugin_offset + other_extmarks_offset,
				win_width,
				opts
			)
		elseif opts.options.overflow.mode == "none" then
			chunks = utils.wrap_text(diag.message, 0)
		elseif opts.options.overflow.mode == "oneline" then
			chunks = { utils.remove_newline(diag.message) }
		end
	else
		chunks = { " " .. diag.message }
	end

	return {
		chunks = chunks,
		severity = diag.severity,
		source = diag.source,
		offset = offset,
		offset_win_col = other_extmarks_offset + plugin_offset,
		need_to_be_under = need_to_be_under,
	}
end

return M
