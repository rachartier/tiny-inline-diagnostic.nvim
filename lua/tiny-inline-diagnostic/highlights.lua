local M = {}

local utils = require("tiny-inline-diagnostic.utils")


local function get_hi(name)
    local hi = vim.api.nvim_get_hl(0, {
        name = name
    })

    return {
        fg = utils.int_to_hex(hi.fg),
        bg = utils.int_to_hex(hi.bg)
    }
end

--- Function to setup highlights for diagnostics.
-- @param blend table - The table of blend options, which includes the blend factor.
-- @param default_hi table - The table of default highlights, which includes the colors for each diagnostic type, the arrow, and the background.
function M.setup_highlights(blend, default_hi)
    local colors = {
        error = get_hi(default_hi.error),
        warn = get_hi(default_hi.warn),
        info = get_hi(default_hi.info),
        hint = get_hi(default_hi.hint),
        arrow = get_hi(default_hi.arrow),
    }

    if default_hi.background:sub(1, 1) == "#" then
        colors.background = default_hi.background
    else
        colors.background = get_hi(default_hi.background).bg
    end

    if default_hi.mixing_color == "None" then
        if vim.g.background == "light" then
            colors.mixing_color = "#ffffff"
        else
            colors.mixing_color = "#000000"
        end
    else
        colors.mixing_color = default_hi.mixing_color
    end

    local factor = blend.factor
    local c = colors.mixing_color

    local blends = {
        error = utils.blend(colors.error.fg, c, factor),
        warn = utils.blend(colors.warn.fg, c, factor),
        info = utils.blend(colors.info.fg, c, factor),
        hint = utils.blend(colors.hint.fg, c, factor),
    }

    local hi = {
        TinyInlineDiagnosticVirtualTextError = { bg = blends.error, fg = colors.error.fg },
        TinyInlineDiagnosticVirtualTextWarn = { bg = blends.warn, fg = colors.warn.fg },
        TinyInlineDiagnosticVirtualTextInfo = { bg = blends.info, fg = colors.info.fg },
        TinyInlineDiagnosticVirtualTextHint = { bg = blends.hint, fg = colors.hint.fg },
        TinyInlineDiagnosticVirtualTextArrow = { bg = colors.background, fg = colors.arrow.fg },

        TinyInlineInvDiagnosticVirtualTextError = { fg = blends.error, bg = colors.background },
        TinyInlineInvDiagnosticVirtualTextWarn = { fg = blends.warn, bg = colors.background },
        TinyInlineInvDiagnosticVirtualTextInfo = { fg = blends.info, bg = colors.background },
        TinyInlineInvDiagnosticVirtualTextHint = { fg = blends.hint, bg = colors.background },
    }

    for name, opts in pairs(hi) do
        vim.api.nvim_set_hl(0, name, {
            bg = opts.bg,
            fg = opts.fg,
        })
    end
end

function M.get_diagnostic_highlights(severity)
    local diag_type = { "Error", "Warn", "Info", "Hint" }

    local hi = diag_type[severity]
    local diag_hi = "TinyInlineDiagnosticVirtualText" .. hi
    local diag_inv_hi = "TinyInlineInvDiagnosticVirtualText" .. hi

    return diag_hi, diag_inv_hi
end

return M
