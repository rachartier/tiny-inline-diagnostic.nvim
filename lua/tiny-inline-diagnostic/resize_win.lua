local M = {}
local extmarks = require('tiny-inline-diagnostic.extmarks')

local utils = require('tiny-inline-diagnostic.utils')



--- Function to splits a diagnostic message into chunks for overflow handling.
--- @param message string: The diagnostic message.
--- @param offset number: The offset from the start of the line to the diagnostic position.
--- @param need_to_be_under boolean: A flag indicating whether the diagnostic message needs to be displayed under the line.
--- @param line_length number: The length of the line where the diagnostic message is.
--- @param win_width number: The width of the window where the diagnostic message is displayed.
--- @param opts table: The options table, which includes signs for the diagnostic message and the softwrap option.
--- @return table, boolean: A table representing the chunks of the diagnostic message, and a boolean indicating whether the message needs to be displayed under the line.
local function get_message_chunks_for_overflow(
    message,
    offset,
    need_to_be_under,
    win_width,
    opts
)
    local signs_total_text_len = #opts.signs.arrow + #opts.signs.right + #opts.signs.left + #opts.signs.diag + 4

    local distance = win_width - offset - signs_total_text_len

    if distance < opts.options.softwrap then
        need_to_be_under = true
        distance = win_width - signs_total_text_len
    end

    local message_chunk = {}
    message_chunk = utils.wrap_text(message, distance)

    return message_chunk, need_to_be_under
end

function M.get_chunks(opts, diag, plugin_offset, curline, buf)
    local win_width = vim.api.nvim_win_get_width(0)
    local line_length = #vim.api.nvim_get_current_line()
    local offset = 0
    local need_to_be_under = false
    local win_option_wrap_enabled = vim.api.nvim_get_option_value("wrap", { win = 0 })

    local chunks = { diag.message }

    local other_extmarks_offset = extmarks.handle_other_extmarks(
        opts,
        buf,
        curline,
        line_length
    )

    if win_option_wrap_enabled then
        if line_length > win_width - opts.options.softwrap then
            need_to_be_under = true
        end
    end

    if opts.options.break_line.enabled == true then
        chunks = {}
        chunks = utils.wrap_text(diag.message, opts.options.break_line.after)
    elseif opts.options.overflow.mode == "wrap" then
        if need_to_be_under then
            offset = 0
        else
            offset = line_length
        end

        chunks, need_to_be_under = get_message_chunks_for_overflow(
            diag.message,
            offset + plugin_offset + other_extmarks_offset,
            need_to_be_under,
            win_width, opts
        )
    elseif opts.options.overflow.position == "none" then
        chunks = { " " .. diag.message }
    end


    return chunks, {
        offset = offset,
        offset_win_col = other_extmarks_offset + plugin_offset,
        need_to_be_under = need_to_be_under
    }
end

return M
