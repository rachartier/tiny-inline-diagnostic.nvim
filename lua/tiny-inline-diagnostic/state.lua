local M = {
}

function M.create()
    return {
        current_diagnostic = nil,
        current_line = 0
    }
end

return M
