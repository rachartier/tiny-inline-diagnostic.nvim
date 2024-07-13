local M = {}

local diagnostic_ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")

function M.clear(buf)
    pcall(vim.api.nvim_buf_clear_namespace, buf, diagnostic_ns, 0, -1)
end

function M.get_extmarks_on_line(bufnr, linenr, col)
    local namespace_id = -1
    local start_pos = { linenr, col }
    local end_pos = { linenr, -1 }

    local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr,
        namespace_id,
        start_pos,
        end_pos,
        { details = true, overlap = true }
    )

    return extmarks
end

function M.handle_other_extmarks(opts, buf, curline, col)
    local e = M.get_extmarks_on_line(buf, curline, col)
    local offset = 0

    if #e > 0 then
        for _, extmark in ipairs(e) do
            local detail = extmark[4]
            local to_check = {
                "eol",
                "win_col",
            }
            for _, to in ipairs(to_check) do
                if detail["virt_text_pos"] == to then
                    if detail["virt_text"] ~= nil and detail["virt_text"][1][1] ~= nil then
                        offset = offset + #detail["virt_text"][1][1]
                    end
                end
            end
        end
    end

    return offset
end

function M.create_extmarks(
    event,
    curline,
    virt_lines,
    offset,
    need_to_be_under,
    virt_prorioty
)
    local diag_overflow_last_line = false
    local buf_lines_count = vim.api.nvim_buf_line_count(event.buf)

    local total_lines = #virt_lines
    if curline - 1 + total_lines > buf_lines_count - 1 then
        diag_overflow_last_line = true
    end

    local win_col = vim.fn.virtcol("$")

    if need_to_be_under then
        win_col = 0
    end

    if need_to_be_under then
        vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline + 1, 0, {
            id = curline + 1000,
            line_hl_group = "CursorLine",
            virt_text_pos = "overlay",
            virt_text_win_col = 0,
            virt_text = virt_lines[2],
            priority = virt_prorioty,
            strict = false,
        })
        table.remove(virt_lines, 2)
        win_col = 0

        if curline < buf_lines_count - 1 then
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
            virt_text_pos = "overlay",
            virt_text = virt_lines[1],
            virt_lines = other_virt_lines,
            virt_text_win_col = win_col + offset,
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

return M
