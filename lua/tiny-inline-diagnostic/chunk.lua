local M = {}

local extmarks = require("tiny-inline-diagnostic.extmarks")
local utils = require("tiny-inline-diagnostic.utils")
local highlights = require("tiny-inline-diagnostic.highlights")

--- Function to calculates the maximum width from a list of chunks.
--- @param chunks table: A table representing the chunks of a diagnostic message.
--- @return number: The maximum width among all chunks.
function M.get_max_width_from_chunks(chunks)
	local max_chunk_line_length = 0

	for i = 1, #chunks do
		local line_length = vim.fn.strdisplaywidth(chunks[i])
		if line_length > max_chunk_line_length then
			max_chunk_line_length = line_length
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
	total_chunks,
	severities
)
	local virt_texts = {}

	if index_diag == 1 then
		virt_texts = {
			{ opts.signs.left, diag_inv_hi },
		}
	else
		local spaces = math.max(vim.fn.strdisplaywidth(opts.signs.left), 1)
		virt_texts = {
			{ string.rep(" ", spaces), "None" },
		}
	end

	vim.list_extend(virt_texts, { { " ", diag_hi } })

	if index_diag == 1 and total_chunks == 1 then
		if severities ~= nil and #severities > 0 then
			-- skip the first severity, as it is already highlighted
			table.sort(severities, function(a, b)
				return a > b
			end)

			for i = 1, #severities - 1 do
				local hl, hl_inv, _ =
					highlights.get_diagnostic_mixed_highlights_from_severity(severities[#severities], severities[i])

				local severity_virt_texts = {
					{ opts.signs.diag, hl },
				}

				vim.list_extend(virt_texts, severity_virt_texts)
			end
		end
	end

	vim.list_extend(virt_texts, {
		{ opts.signs.diag, diag_hi },
	})

	if not need_to_be_under and index_diag > 1 then
		table.insert(virt_texts, 1, { string.rep(" ", vim.fn.strcharlen(opts.signs.arrow)), diag_inv_hi })
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
				{ string.rep(" ", vim.fn.strcharlen(opts.signs.right)), diag_inv_hi },
			})
		end
	else
		vim.list_extend(virt_texts, {
			{ " " .. message .. text_after_message, diag_hi },
			{ string.rep(" ", vim.fn.strcharlen(opts.signs.right)), diag_inv_hi },
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
		local spaces = math.max(vim.fn.strdisplaywidth(opts.signs.left .. opts.signs.arrow), 1)
		table.insert(chunk_virtual_texts, 1, { string.rep(" ", spaces), diag_inv_hi })
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

function M.get_arrow_from_chunk(opts, diagnostic_line, ret)
	local arrow = opts.signs.arrow
	local need_to_be_under = ret.need_to_be_under

	local chunk = {}

	local hi = "TinyInlineDiagnosticVirtualTextArrow"

	if diagnostic_line ~= ret.line or ret.need_to_be_under then
		hi = "TinyInlineDiagnosticVirtualTextArrowNoBg"
	end

	if need_to_be_under then
		arrow = opts.signs.up_arrow
		chunk = {
			{ " ", "None" },
			{ arrow, hi },
		}
	else
		chunk = { arrow, hi }
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
	local message_chunk = {}

	message_chunk = utils.wrap_text(message, distance)

	return message_chunk
end

function M.get_chunks(opts, diags_on_line, diag_index, diag_line, cursor_line, buf)
	local win_width = vim.api.nvim_win_get_width(0)
	local lines = vim.api.nvim_buf_get_lines(buf, diag_line, diag_line + 1, false)
	local line_length = 0
	local offset = 0
	local need_to_be_under = false

	if lines ~= nil and lines[1] ~= nil then
		line_length = #lines[1]
	end

	local diag = diags_on_line[diag_index]

	if opts.options.show_source and diag.source ~= nil then
		diag.message = diag.message .. " (" .. diag.source .. ")"
	end

	local chunks = { diag.message }
	local severities = {}

	for _, other_diag in ipairs(diags_on_line) do
		table.insert(severities, other_diag.severity)
	end

	local other_extmarks_offset = extmarks.handle_other_extmarks(opts, buf, diag_line, line_length)

	if (opts.options.overflow.mode ~= "none" and not opts.options.multilines) or cursor_line == diag_line then
		if line_length > win_width - opts.options.softwrap then
			need_to_be_under = true
		end
	end

	local diag_message = diag.message

	if opts.options.format ~= nil and diag_message ~= nil then
		diag_message = opts.options.format(diag)
	end

	if not opts.options.multilines or cursor_line == diag_line then
		if opts.options.break_line.enabled == true then
			chunks = {}
			chunks = utils.wrap_text(diag_message, opts.options.break_line.after)
		elseif opts.options.overflow.mode == "wrap" then
			if need_to_be_under then
				offset = 0
			else
				local win_col = vim.fn.virtcol("$")
				offset = win_col
			end

			chunks = M.get_message_chunks_for_overflow(diag_message, offset + other_extmarks_offset, win_width, opts)
		elseif opts.options.overflow.mode == "none" then
			chunks = utils.wrap_text(diag_message, 0)
		elseif opts.options.overflow.mode == "oneline" then
			chunks = { utils.remove_newline(diag_message) }
		end
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

return M
