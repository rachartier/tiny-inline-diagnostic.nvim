local M = {}

local chunck_utils = require("tiny-inline-diagnostic.chunck")
local highlights = require("tiny-inline-diagnostic.highlights")
local plugin_handler = require("tiny-inline-diagnostic.plugin")
local utils = require("tiny-inline-diagnostic.utils")

--- @param opts table containing options
--- @param cursorpos table containing cursor position
--- @param index_diag integer representing the diagnostic index
--- @param diag table containing diagnostic data
--- @param buf integer: buffer number.
function M.from_diagnostic(opts, cursorpos, index_diag, diag, buf)
    local diag_hi, diag_inv_hi = highlights.get_diagnostic_highlights(diag.severity)
    local curline = cursorpos[1]

    local all_virtual_texts = {}

    local plugin_offset = plugin_handler.handle_plugins(opts)

    local chunks, ret = chunck_utils.get_chunks(opts, diag, plugin_offset, curline, buf)
    local need_to_be_under = ret.need_to_be_under
    local offset = ret.offset
    local offset_win_col = ret.offset_win_col

    local max_chunk_line_length = chunck_utils.get_max_width_from_chunks(chunks)

    for index_chunk = 1, #chunks do
        local message = utils.trim(chunks[index_chunk])

        local to_add = max_chunk_line_length - #message
        message = message .. string.rep(" ", to_add)

        if index_chunk == 1 then
            local chunk_header = chunck_utils.get_header_from_chunk(
                message,
                index_diag,
                #chunks,
                need_to_be_under,
                opts,
                diag_hi,
                diag_inv_hi
            )

            if index_diag == 1 then
                local chunck_arrow = chunck_utils.get_arrow_from_chunk(
                    offset,
                    cursorpos,
                    opts,
                    need_to_be_under
                )

                if type(chunck_arrow[1]) == "table" then
                    table.insert(all_virtual_texts, chunck_arrow)
                else
                    table.insert(chunk_header, 1, chunck_arrow)
                end
            end

            table.insert(all_virtual_texts, chunk_header)
        else
            local chunk_body = chunck_utils.get_body_from_chunk(
                message,
                opts,
                need_to_be_under,
                diag_hi,
                diag_inv_hi,
                index_chunk == #chunks
            )

            table.insert(all_virtual_texts, chunk_body)
        end
    end

    if need_to_be_under then
        table.insert(all_virtual_texts, 1, {
            { " ", "None" },
        })
    end

    return all_virtual_texts, offset_win_col, need_to_be_under
end

function M.from_diagnostics(opts, diags, cursor_pos, buf)
    local all_virtual_texts = {}
    local offset_win_col = 0
    local need_to_be_under = false

    for index_diag, diag in ipairs(diags) do
        local virt_texts, diag_offset_win_col, diag_need_to_be_under =
            M.from_diagnostic(
                opts,
                cursor_pos,
                index_diag,
                diag,
                buf
            )

        if diag_need_to_be_under == true then
            need_to_be_under = true
        end

        -- Remove new line if not needed
        if need_to_be_under and index_diag > 1 then
            table.remove(virt_texts, 1)
        end

        vim.list_extend(all_virtual_texts, virt_texts)
    end
    return all_virtual_texts, offset_win_col, need_to_be_under
end

return M
