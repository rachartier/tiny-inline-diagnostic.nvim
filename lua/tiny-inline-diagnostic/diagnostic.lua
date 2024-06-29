local M = {}

local diagnostic_ns = vim.api.nvim_create_namespace("CursorDiagnostics")

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

local function get_virt_texts_from_diag(opts, diag)
    local diag_type = { "Error", "Warn", "Info", "Hint" }

    local hi = diag_type[diag.severity]
    local virt_texts = { { opts.signs.arrow, "TinyInlineDiagnosticVirtualTextArrow" } }

    local diag_hi = "TinyInlineDiagnosticVirtualText" .. hi
    local diag_inv_hi = "TinyInlineInvDiagnosticVirtualText" .. hi

    vim.list_extend(virt_texts, {
        { opts.signs.left,     diag_inv_hi },
        { opts.signs.diag,     diag_hi },
        { " " .. diag.message, diag_hi },
        { opts.signs.right,    diag_inv_hi },
    })

    return virt_texts
end


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

            vim.api.nvim_create_autocmd("CursorHold", {
                buffer = event.buf,
                callback = function()
                    pcall(vim.api.nvim_buf_clear_namespace, event.buf, diagnostic_ns, 0, -1)

                    local cursor_pos = vim.api.nvim_win_get_cursor(0)
                    local curline = cursor_pos[1] - 1
                    local curcol = cursor_pos[2]

                    local diagnostics = vim.diagnostic.get(event.buf, { lnum = curline })

                    if #diagnostics == 0 then
                        return
                    end

                    local current_pos_diags = get_current_pos_diags(diagnostics, curline, curcol)
                    local virt_texts = get_virt_texts_from_diag(opts, current_pos_diags[1])

                    vim.api.nvim_buf_set_extmark(event.buf, diagnostic_ns, curline, 0, {
                        virt_text = virt_texts,
                        virt_lines_above = true,
                    })
                end,
                desc = "Show diagnostics on cursor hold",
            })
        end,
        desc = "Show diagnostics on cursor hold",
    })
end

return M
