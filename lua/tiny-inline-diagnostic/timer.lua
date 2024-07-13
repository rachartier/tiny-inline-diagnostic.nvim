local M = {}

M.timers_by_buffer = {}

function M.close_timers()
    for _, timer in pairs(M.timers_by_buffer) do
        if timer then
            timer:close()
        end
    end
end

function M.close(buf)
    if M.timers_by_buffer[buf] then
        M.timers_by_buffer[buf]:close()
        M.timers_by_buffer[buf] = nil
    end
end

function M.set_timers()
    if not vim.tbl_isempty(M.timers_by_buffer) then
        M.close_timers()
    end

    M.timers_by_buffer = {}
end

function M.add(buf, timer)
    if not M.timers_by_buffer[buf] then
        M.timers_by_buffer[buf] = timer
    end
end

return M
