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

function M.setup_highlights(blend, default_hi)
    local colors = {
        error = get_hi(default_hi.error),
        warn = get_hi(default_hi.warn),
        info = get_hi(default_hi.info),
        hint = get_hi(default_hi.hint),
        arrow = get_hi(default_hi.arrow),
        background = default_hi.background,
    }

    local factor = blend.factor
    local c = colors.background

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
        TinyInlineDiagnosticVirtualTextArrow = colors.arrow,

        TinyInlineInvDiagnosticVirtualTextError = { fg = blends.error, bg = "None" },
        TinyInlineInvDiagnosticVirtualTextWarn = { fg = blends.warn, bg = "None" },
        TinyInlineInvDiagnosticVirtualTextInfo = { fg = blends.info, bg = "None" },
        TinyInlineInvDiagnosticVirtualTextHint = { fg = blends.hint, bg = "None" },
    }

    for name, opts in pairs(hi) do
        vim.api.nvim_set_hl(0, name, {
            bg = opts.bg,
            fg = opts.fg,
        })
    end
end

return M
