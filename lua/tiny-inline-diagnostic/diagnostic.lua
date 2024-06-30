local M = {}

local diagnostic_ns = vim.api.nvim_create_namespace("CursorDiagnostics")
local utis = require("tiny-inline-diagnostic.utils")

--- Function to get diagnostics for the current position in the code.
-- @param diagnostics table - The table of diagnostics to check.
-- @param curline number - The current line number.
-- @param curcol number - The current column number.
-- @return table - A table of diagnostics for the current position.
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

--- Function to forge the virtual texts from a diagnostic.
-- @param opts table - The table of options, which includes the signs to use for the virtual texts.
-- @param diag table - The diagnostic to get the virtual texts for.
-- @return table - A table of virtual texts for the given diagnostic.
local function forge_virt_texts_from_diagnostic(opts, diag)
    local diag_type = { "Error", "Warn", "Info", "Hint" }

    local hi = diag_type[diag.severity]
    local virt_texts = { opts.signs.arrow, "TinyInlineDiagnosticVirtualTextArrow" }

    local diag_hi = "TinyInlineDiagnosticVirtualText" .. hi
    local diag_inv_hi = "TinyInlineInvDiagnosticVirtualText" .. hi

    local all_virtual_texts = {}

    local diag_sign = opts.signs.diag
    local text_after_message = ""

    local message_chunk = {
        diag.message
    }
    local max_chunk_line_length = 0

    if opts.options.break_line.enabled == true then
        diag_sign = " " .. diag_sign
        text_after_message = "   "

        message_chunk = {}
        message_chunk = utis.wrap_text(diag.message, opts.options.break_line.after)
    elseif opts.options.overflow == "wrap" then
        diag_sign = " " .. diag_sign
        text_after_message = "   "

        local win_width = vim.api.nvim_win_get_width(0)
        local offset = #vim.api.nvim_get_current_line()
        local distance = win_width - offset - #opts.signs.arrow - #opts.signs.right - #opts.signs.left - #diag_sign - 3

        message_chunk = {}
        message_chunk = utis.wrap_text(diag.message, distance)
    end

    for i = 1, #message_chunk do
        if #message_chunk[i] > max_chunk_line_length then
            max_chunk_line_length = #message_chunk[i]
        end
    end

    local offset = #vim.api.nvim_get_current_line()
    local offset_space = string.rep(" ", offset + 1)

    for i = 1, #message_chunk do
        local message = message_chunk[i]

        local to_add = max_chunk_line_length - #message
        message = message .. string.rep(" ", to_add)

        if i == 1 then
            local chunk_virtual_texts = {
                virt_texts,
                { opts.signs.left,               diag_inv_hi },
                { diag_sign,                     diag_hi },
                { message .. text_after_message, diag_hi },
            }

            if #message_chunk == 1 then
                vim.list_extend(chunk_virtual_texts, {
                    { opts.signs.right, diag_inv_hi },
                })
            end

            table.insert(all_virtual_texts, chunk_virtual_texts)
        else
            local vertical_sign = opts.signs.vertical

            if i == #message_chunk then
                vertical_sign = opts.signs.vertical_end
            end

            local chunk_virtual_texts = {
                { offset_space .. string.rep(" ", #opts.signs.arrow - 1), diag_inv_hi },
                { vertical_sign,                                          diag_hi },
                { " " .. message .. " ",                                  diag_hi },
                { " ",                                                    diag_hi },
            }

            if i == #message_chunk then
                vim.list_extend(chunk_virtual_texts, {
                    { opts.signs.right, diag_inv_hi },
                })
            end

            table.insert(all_virtual_texts, chunk_virtual_texts)
        end
    end

    return all_virtual_texts
end

--- Function to get the diagnostic under the cursor.
-- @param buf number - The buffer number to get the diagnostics for.
-- @return table, number - A table of diagnostics for the current position and the current line number, or nil if there are no diagnostics.
function M.get_diagnostic_under_cursor(buf)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local curline = cursor_pos[1] - 1
    local curcol = cursor_pos[2]

    local diagnostics = vim.diagnostic.get(buf, { lnum = curline })

    if #diagnostics == 0 then
        return
    end

    return get_current_pos_diags(diagnostics, curline, curcol), curline
end

--- Function to set diagnostic autocmds.
-- This function creates an autocmd for the `LspAttach` event.
-- @param opts table - The table of options, which includes the `clear_on_insert` option and the signs to use for the virtual texts.
function M.set_diagnostic_autocmds(opts)
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
            if opts.options.clear_on_insert then
                vim.api.nvim_create_autocmd("InsertEnter", {
                    buffer = event.buf,
                    callback = function()
                        vim.api.nvim_buf_clear_namespace(event.buf, diagnostic_ns, 0, -1)
                    end,
                    desc = "Clear diagnostics on insert enter",
                })
            end

            vim.api.nvim_create_autocmd({ "CursorHold", "VimResized", "CursorMovedI" }, {
                buffer = event.buf,
                callback = function()
                    pcall(vim.api.nvim_buf_clear_namespace, event.buf, diagnostic_ns, 0, -1)

                    local diag, curline = M.get_diagnostic_under_cursor(event.buf)

                    if diag == nil or curline == nil then
                        return
                    end

                    local virt_texts = forge_virt_texts_from_diagnostic(opts, diag[1])

                    local virt_lines = {}

                    if #virt_texts > 1 then
                        for i = 2, #virt_texts do
                            table.insert(virt_lines, virt_texts[i])
                        end
                    end

                    vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline, 0, {
                        virt_text = virt_texts[1],
                        virt_lines = virt_lines
                    })
                end,
                desc = "Show diagnostics on cursor hold",
            })
        end,
        desc = "Show diagnostics on cursor hold",
    })
end

return M
