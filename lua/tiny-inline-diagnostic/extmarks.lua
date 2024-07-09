local M = {}

function M.get_extmarks_on_line(bufnr, linenr, col)
    local namespace_id = -1
    local start_pos = { linenr, col }
    local end_pos = { linenr, -1 }

    local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr,
        namespace_id,
        start_pos,
        end_pos,
        { details = true }
    )

    return extmarks
end

function M.handle_other_extmarks(buf, curline, col)
    local e = M.get_extmarks_on_line(buf, curline, col)

    if #e > 0 then
        for _, extmark in ipairs(e) do
            print(vim.inspect(extmark))
            local detail = extmark[4]
            local to_check = {
                "eol",
                "win_col",
            }
            for _, to in ipairs(to_check) do
                if detail["virt_text_pos"] == to then
                    if detail["virt_text"] ~= nil and detail["virt_text"][1][1] ~= nil then
                        return #detail["virt_text"][1][1]
                    end
                end
            end
        end
    end

    return 0
end

return M
