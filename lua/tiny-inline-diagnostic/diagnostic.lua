local M = {}

M.enabled = true

local utils = require("tiny-inline-diagnostic.utils")
local plugin_handler = require("tiny-inline-diagnostic.plugin")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local timers = require("tiny-inline-diagnostic.timer")

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
    extmarks.clear(event.buf)

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

    local virt_priority = opts.options.virt_texts.priority
    local virt_lines, offset, need_to_be_under

    if opts.options.multiple_diag_under_cursor then
        virt_lines, offset, need_to_be_under = virtual_text_forge.from_diagnostics(
            opts,
            diags,
            cursorpos,
            event.buf
        )
    else
        virt_lines, offset, need_to_be_under = virtual_text_forge.from_diagnostic(
            opts,
            cursorpos,
            1,
            diags[1],
            event.buf
        )
    end


    extmarks.create_extmarks(
        event,
        curline,
        virt_lines,
        offset,
        need_to_be_under,
        virt_priority
    )
end


--- Function to set diagnostic autocmds.
--- This function creates an autocmd for the `LspAttach` event.
--- @param opts table - The table of options, which includes the `clear_on_insert` option and the signs to use for the virtual texts.
function M.set_diagnostic_autocmds(opts)
    local autocmd_ns = vim.api.nvim_create_augroup("TinyInlineDiagnosticAutocmds", { clear = true })

    timers.set_timers()

    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
            local throttled_apply_diagnostics_virtual_texts, timer = utils.throttle(
                function()
                    apply_diagnostics_virtual_texts(opts, event)
                end,
                opts.options.throttle
            )

            timers.add(event.buf, timer)

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
                    timers.close(event.buf)
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
                        extmarks.clear(event.buf)
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
