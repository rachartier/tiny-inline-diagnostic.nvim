local M = {}

local utils = require("tiny-inline-diagnostic.utils")

local function get_hi(name)
	local hi = vim.api.nvim_get_hl(0, {
		name = name,
		link = false,
	})

	return {
		fg = utils.int_to_hex(hi.fg),
		bg = utils.int_to_hex(hi.bg),
		italic = hi.italic,
	}
end

--- Function to setup highlights for diagnostics.
-- @param blend table - The table of blend options, which includes the blend factor.
-- @param default_hi table - The table of default highlights, which includes the colors for each diagnostic type, the arrow, and the background.
-- @param italics boolean - Whether to use italics for the diagnostics.
function M.setup_highlights(blend, default_hi)
	local colors = {
		error = get_hi(default_hi.error),
		warn = get_hi(default_hi.warn),
		info = get_hi(default_hi.info),
		hint = get_hi(default_hi.hint),
		ok = get_hi(default_hi.ok),
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
		TinyInlineDiagnosticVirtualTextBg = { bg = colors.background },

		TinyInlineDiagnosticVirtualTextError = { bg = blends.error, fg = colors.error.fg, italic = colors.error.italic },
		TinyInlineDiagnosticVirtualTextWarn = { bg = blends.warn, fg = colors.warn.fg, italic = colors.warn.italic },
		TinyInlineDiagnosticVirtualTextInfo = { bg = blends.info, fg = colors.info.fg, italic = colors.info.italic },
		TinyInlineDiagnosticVirtualTextHint = { bg = blends.hint, fg = colors.hint.fg, italic = colors.hint.italic },
		TinyInlineDiagnosticVirtualTextOk = { bg = blends.hint, fg = colors.hint.fg, italic = colors.ok.italic },

		TinyInlineDiagnosticVirtualTextArrow = { bg = colors.background, fg = colors.arrow.fg },
		TinyInlineDiagnosticVirtualTextArrowNoBg = { bg = "None", fg = colors.arrow.fg },

		TinyInlineInvDiagnosticVirtualTextError = { fg = blends.error, bg = colors.background },
		TinyInlineInvDiagnosticVirtualTextWarn = { fg = blends.warn, bg = colors.background },
		TinyInlineInvDiagnosticVirtualTextInfo = { fg = blends.info, bg = colors.background },
		TinyInlineInvDiagnosticVirtualTextHint = { fg = blends.hint, bg = colors.background },

		TinyInlineInvDiagnosticVirtualTextErrorNoBg = { fg = blends.error, bg = "None" },
		TinyInlineInvDiagnosticVirtualTextWarnNoBg = { fg = blends.warn, bg = "None" },
		TinyInlineInvDiagnosticVirtualTextInfoNoBg = { fg = blends.info, bg = "None" },
		TinyInlineInvDiagnosticVirtualTextHintNoBg = { fg = blends.hint, bg = "None" },
	}

	-- mix up all background with foreground for each VirtualTextError, Warn, Info, Hint, Ok
	local to_mix = {
		"TinyInlineDiagnosticVirtualTextError",
		"TinyInlineDiagnosticVirtualTextWarn",
		"TinyInlineDiagnosticVirtualTextInfo",
		"TinyInlineDiagnosticVirtualTextHint",
	}

	local mixed_name = {
		"MixError",
		"MixWarn",
		"MixInfo",
		"MixHint",
	}

	for i, name in ipairs(to_mix) do
		for _, bg_name in ipairs(to_mix) do
			local fg = hi[name].fg
			local bg = hi[bg_name].bg

			hi[bg_name .. mixed_name[i]] = { fg = fg, bg = bg, italic = hi[name].italic }
		end
	end

	for name, opts in pairs(hi) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

--- Function to get diagnostic highlights based on severity and line comparison.
--- @param diag_ret table - The table containing diagnostic information, including severity and line.
--- @param curline number - The current line number to compare with the diagnostic line.
--- @param index_diag number - The index of the diagnostic in the list.
--- @return string, string, string - The highlight group names for the diagnostic and its inverse, and the body highlight group name.
function M.get_diagnostic_highlights(diag_ret, curline, index_diag)
	local severity = diag_ret.severity
	local diag_line = diag_ret.line

	local diag_hi, diag_inv_hi, body_hi = M.get_diagnostic_highlights_from_severity(severity)

	if diag_line and diag_line ~= curline or index_diag > 1 or diag_ret.need_to_be_under then
		diag_inv_hi = diag_inv_hi .. "NoBg"
	end

	return diag_hi, diag_inv_hi, body_hi
end

function M.get_diagnostic_highlights_from_severity(severity)
	local diag_type = { "Error", "Warn", "Info", "Hint" }

	local hi = diag_type[severity]

	local diag_hi = "TinyInlineDiagnosticVirtualText" .. hi
	local diag_inv_hi = "TinyInlineInvDiagnosticVirtualText" .. hi
	local body_hi = "TinyInlineInvDiagnosticVirtualText" .. hi .. "NoBg"

	return diag_hi, diag_inv_hi, body_hi
end

function M.get_diagnostic_mixed_highlights_from_severity(severity_a, severity_b)
	local diag_type = { "Error", "Warn", "Info", "Hint" }

	local hi_a = diag_type[severity_a]
	local hi_b = diag_type[severity_b]

	local diag_hi = "TinyInlineDiagnosticVirtualText" .. hi_a .. "Mix" .. hi_b
	local diag_inv_hi = "TinyInlineInvDiagnosticVirtualText" .. hi_a .. "Mix" .. hi_b

	return diag_hi, diag_inv_hi
end
return M
