local M = {}
local timers_by_buffer = {}

M.enabled = true

local diagnostic_ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
local utils = require("tiny-inline-diagnostic.utils")
local highlights = require("tiny-inline-diagnostic.highlights")
local resize = require("tiny-inline-diagnostic.resize_win")
local plugin_handler = require("tiny-inline-diagnostic.plugin")

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

--- Function to generates a header for a diagnostic message chunk.
--- @param message string: The diagnostic message.
--- @param num_chunks number: The total number of chunks the message is split into.
--- @param opts table: The options table, which includes signs for the diagnostic message.
--- @param diag_hi string: The highlight group for the diagnostic message.
--- @param diag_inv_hi string: The highlight group for the diagnostic signs.
--- @return table: A table representing the virtual text array for the diagnostic message header.
local function get_header_from_chunk(
    message,
    index_diag,
    num_chunks,
    need_to_be_under,
    opts,
    diag_hi,
    diag_inv_hi
)
    local virt_texts = {}

    virt_texts = {
        { opts.signs.left, diag_inv_hi },
        { opts.signs.diag, diag_hi }
    }

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
        vim.list_extend(virt_texts, {
            { " " .. message .. " ", diag_hi },
            { opts.signs.right,      diag_inv_hi },
        })
    else
        vim.list_extend(virt_texts, {
            { " " .. message .. text_after_message, diag_hi },
            { string.rep(" ", #opts.signs.right),   diag_inv_hi },
        })
    end

    return virt_texts
end

--- Function to generates the body for a diagnostic message chunk.
--- @param chunk string: The chunk of the diagnostic message.
--- @param opts table: The options table, which includes signs for the diagnostic message.
--- @param need_to_be_under boolean: A flag indicating whether the arrow needs to point upwards.
--- @param diag_overflow_last_line boolean: A flag indicating whether the diagnostic message is the last line of the buffer.
--- @param diag_hi string: The highlight group for the diagnostic message.
--- @param diag_inv_hi string: The highlight group for the diagnostic signs.
--- @param offset_space string: The offset space for aligning the chunk message.
--- @param is_last boolean: A flag indicating whether the chunk is the last one.
--- @return table: A table representing the virtual text array for the diagnostic message body.
local function get_body_from_chunk(
    chunk,
    opts,
    need_to_be_under,
    diag_overflow_last_line,
    diag_hi,
    diag_inv_hi,
    offset_space,
    is_last
)
    local vertical_sign = opts.signs.vertical

    if is_last then
        vertical_sign = opts.signs.vertical_end
    end

    local chunk_virtual_texts = {
        { vertical_sign, diag_hi },
        { " " .. chunk,  diag_hi },
        { " ",           diag_hi },
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

local function get_arrow_from_chunk(
    offset,
    cursorpos,
    opts,
    need_to_be_under
)
    local arrow = opts.signs.arrow
    local chunck = {}

    if need_to_be_under then
        arrow = opts.signs.up_arrow
        chunck = {
            { " ",   "None" },
            { arrow, "TinyInlineDiagnosticVirtualTextArrow" },
        }
    else
        chunck = { arrow, "TinyInlineDiagnosticVirtualTextArrow" }
    end

    return chunck
end

--- Function to calculates the maximum width from a list of chunks.
--- @param chunks table: A table representing the chunks of a diagnostic message.
--- @return number: The maximum width among all chunks.
local function get_max_width_from_chunks(chunks)
    local max_chunk_line_length = 0

    for i = 1, #chunks do
        if #chunks[i] > max_chunk_line_length then
            max_chunk_line_length = #chunks[i]
        end
    end

    return max_chunk_line_length
end


--- Function to forge the virtual texts from a diagnostic.
--- @param opts table - The table of options, which includes the signs to use for the virtual texts.
--- @param diags table - The diagnostic to get the virtual texts for.
local function forge_virt_texts_from_diagnostic(opts, cursorpos, index_diag, diag, buf)
    local diag_hi, diag_inv_hi = highlights.get_diagnostic_highlights(diag.severity)
    local curline = cursorpos[1]

    local all_virtual_texts = {}

    local plugin_offset = plugin_handler.handle_plugins(opts)

    local chunks, ret = resize.get_chunks(opts, diag, plugin_offset, curline, buf)
    local need_to_be_under = ret.need_to_be_under
    local offset = ret.offset
    local offset_win_col = ret.offset_win_col
    local offset_space = ""

    if need_to_be_under then
        offset = 0
    else
        offset_space = string.rep(" ", offset)
    end

    local max_chunk_line_length = get_max_width_from_chunks(chunks)

    local line_count = vim.api.nvim_buf_line_count(buf)
    local diag_overflow_last_line = curline + #chunks > line_count - 1

    for i = 1, #chunks do
        local message = utils.trim(chunks[i])

        local to_add = max_chunk_line_length - #message
        message = message .. string.rep(" ", to_add)

        if i == 1 then
            local chunk_header = get_header_from_chunk(
                message,
                index_diag,
                #chunks,
                need_to_be_under,
                opts,
                diag_hi,
                diag_inv_hi
            )

            if index_diag == 1 then
                local chunck_arrow = get_arrow_from_chunk(
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
            local chunk_body = get_body_from_chunk(
                message,
                opts,
                need_to_be_under,
                diag_overflow_last_line,
                diag_hi,
                diag_inv_hi,
                offset_space,
                i == #chunks
            )

            table.insert(all_virtual_texts, chunk_body)
        end
    end

    if need_to_be_under then
        table.insert(all_virtual_texts, 1, {
            { " ", "None" },
        })
    end

    return all_virtual_texts, offset_win_col, diag_overflow_last_line, need_to_be_under
end

local function forge_virt_texts_from_diagnostics(opts, diags, cursor_pos, buf)
    local all_virtual_texts = {}
    local offset_win_col = 0
    local overflow_last_line = false
    local need_to_be_under = false

    for index_diag, diag in ipairs(diags) do
        local virt_texts, diag_offset_win_col, diag_overflow_last_line, diag_need_to_be_under =
            forge_virt_texts_from_diagnostic(
                opts,
                cursor_pos,
                index_diag,
                diag,
                buf
            )

        if need_to_be_under == false then
            need_to_be_under = diag_need_to_be_under
        end

        if overflow_last_line == false then
            overflow_last_line = diag_overflow_last_line
        end

        -- Remove new line if not needed
        if need_to_be_under and index_diag > 1 then
            table.remove(virt_texts, 1)
        end

        vim.list_extend(all_virtual_texts, virt_texts)
    end

    return all_virtual_texts, offset_win_col, overflow_last_line, need_to_be_under
end

--- Function to get the diagnostic under the cursor.
--- @param buf number - The buffer number to get the diagnostics for.
--- @return table, number, number - A table of diagnostics for the current position, the current line number, the current col, or nil if there are no diagnostics.
function M.get_diagnostic_under_cursor(buf)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local curline = cursor_pos[1] - 1
    local curcol = cursor_pos[2]

    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    local diagnostics = vim.diagnostic.get(buf, { lnum = curline })

    if #diagnostics == 0 then
        return
    end

    return get_current_pos_diags(diagnostics, curline, curcol), curline, curcol
end

local function apply_diagnostics_virtual_texts(opts, event)
    pcall(vim.api.nvim_buf_clear_namespace, event.buf, diagnostic_ns, 0, -1)

    if not M.enabled then
        return
    end

    plugin_handler.init(opts)

    local diags, curline, curcol = M.get_diagnostic_under_cursor(event.buf)

    local cursorpos = {
        curline,
        curcol,
    }

    if diags == nil or curline == nil then
        return
    end

    local virt_prorioty = opts.options.virt_texts.priority
    local virt_lines, offset, diag_overflow_last_line, need_to_be_under

    if opts.options.multiple_diag_under_cursor then
        virt_lines, offset, diag_overflow_last_line, need_to_be_under = forge_virt_texts_from_diagnostics(
            opts,
            diags,
            cursorpos,
            event.buf
        )
    else
        virt_lines, offset, diag_overflow_last_line, need_to_be_under = forge_virt_texts_from_diagnostic(
            opts,
            cursorpos,
            1,
            diags[1],
            event.buf
        )
    end

    local win_col = vim.fn.virtcol("$")

    if need_to_be_under then
        win_col = 0
    end

    if need_to_be_under then
        vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline + 1, cursorpos[2], {
            id = curline + 100,
            line_hl_group = "CursorLine",
            virt_text_pos = "overlay",
            virt_text_win_col = cursorpos[2] - 1,
            virt_text = virt_lines[2],
            priority = virt_prorioty,
            strict = false,
        })
        table.remove(virt_lines, 2)
        if not diag_overflow_last_line then
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
            id = curline + 1,
            line_hl_group = "CursorLine",
            virt_text_pos = "eol",
            virt_text = virt_lines[1],
            virt_lines = other_virt_lines,
            priority = virt_prorioty,
            strict = false,
        })
    else
        vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline, 0, {
            id = curline + 1,
            line_hl_group = "CursorLine",
            virt_text_pos = "eol",
            virt_text = virt_lines[1],
            -- virt_text_win_col = win_col + offset,
            priority = virt_prorioty,
            strict = false,
        })

        for i, line in ipairs(virt_lines) do
            if i > 1 then
                vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline + i - 1, 0, {
                    id = curline + i + 1,
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


--- Function to set diagnostic autocmds.
--- This function creates an autocmd for the `LspAttach` event.
--- @param opts table - The table of options, which includes the `clear_on_insert` option and the signs to use for the virtual texts.
function M.set_diagnostic_autocmds(opts)
    local autocmd_ns = vim.api.nvim_create_augroup("TinyInlineDiagnosticAutocmds", { clear = true })

    for _, timer in pairs(timers_by_buffer) do
        if timer then
            timer:close()
        end
    end
    timers_by_buffer = {}

    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
            local throttled_apply_diagnostics_virtual_texts, timer = utils.throttle(
                function()
                    apply_diagnostics_virtual_texts(opts, event)
                end,
                opts.options.throttle
            )

            if not timers_by_buffer[event.buf] then
                timers_by_buffer[event.buf] = timer
            end

            vim.api.nvim_create_autocmd("User", {
                group = autocmd_ns,
                pattern = "TinyDiagnosticEvent",
                callback = function()
                    apply_diagnostics_virtual_texts(opts, event)
                end
            })

            vim.api.nvim_create_autocmd({ "LspDetach" }, {
                group = autocmd_ns,
                buffer = event.buf,
                callback = function()
                    if timers_by_buffer[event.buf] then
                        timers_by_buffer[event.buf]:close()
                        timers_by_buffer[event.buf] = nil
                    end
                end
            })

            vim.api.nvim_create_autocmd("User", {
                group = autocmd_ns,
                pattern = "TinyDiagnosticEventThrottled",
                callback = function()
                    throttled_apply_diagnostics_virtual_texts()
                end
            })

            vim.api.nvim_create_autocmd("InsertEnter", {
                group = autocmd_ns,
                buffer = event.buf,
                callback = function()
                    if vim.api.nvim_buf_is_valid(event.buf) then
                        pcall(vim.api.nvim_buf_clear_namespace, event.buf, diagnostic_ns, 0, -1)
                    end
                end
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
