local M = {}

local plugin = {}

function M.init(opts)
    if opts.plugin.gitblame.enabled then
        local ok, req = pcall(require, "gitblame")
        plugin["gitblame"] = {
            ok = ok,
            req = req
        }
    end
end

function M.handle_plugins(opts)
    local plugin_offset = 0

    local vim_mode = vim.api.nvim_get_mode().mode

    -- if opts.plugin.gitblame.enabled and plugin["gitblame"].ok and vim_mode ~= "i" then
    --     local gitblame = plugin["gitblame"].req
    --
    --     if gitblame.is_blame_text_available() then
    --         local gitblame_offset = #gitblame.get_current_blame_text() - 1
    --
    --         if gitblame_offset > 0 then
    --             plugin_offset = gitblame_offset
    --         end
    --     end
    -- end

    return plugin_offset
end

return M
