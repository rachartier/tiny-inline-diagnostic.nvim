---@class HighlightColor
---@field fg string
---@field bg string
---@field italic boolean

---@class BlendOptions
---@field factor number

---@class DefaultHighlights
---@field error string
---@field warn string
---@field info string
---@field hint string
---@field ok string
---@field arrow string
---@field background string
---@field mixing_color string

local M = {}

local utils = require("tiny-inline-diagnostic.utils")

-- Constants
local DIAGNOSTIC_SEVERITIES = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	HINT = 4,
}

local SEVERITY_NAMES = { "Error", "Warn", "Info", "Hint" }
local HIGHLIGHT_PREFIX = "TinyInlineDiagnosticVirtualText"
local INV_HIGHLIGHT_PREFIX = "TinyInlineInvDiagnosticVirtualText"

---Get highlight attributes for a given highlight group
---@param name string
---@return HighlightColor
local function get_highlight(name)
	local hi = vim.api.nvim_get_hl(0, {
		name = name,
		link = false,
	})

	return {
		fg = utils.int_to_hex(hi.fg),
		bg = utils.int_to_hex(hi.bg),
		italic = hi.italic or false,
	}
end

---Get background color based on configuration
---@param color string
---@return string
local function get_background_color(color)
	if color:sub(1, 1) == "#" then
		return color
	end
	return get_highlight(color).bg
end

---Get mixing color based on configuration
---@param color string
---@return string
local function get_mixing_color(color)
	if color == "None" then
		return vim.g.background == "light" and "#ffffff" or "#000000"
	end
	if color:sub(1, 1) == "#" then
		return color
	end
	return get_highlight(color).bg
end

---Create diagnostic highlight groups
---@param colors table<string, HighlightColor>
---@param blends table<string, string>
---@return table<string, table>
local function create_highlight_groups(colors, blends, transparent)
	local hi = {
		[HIGHLIGHT_PREFIX .. "Bg"] = { bg = colors.background },
	}

	-- Create base highlight groups
	for severity, name in pairs(SEVERITY_NAMES) do
		-- Cursor line highlights
		hi[HIGHLIGHT_PREFIX .. name .. "CursorLine"] = {
			bg = colors.cursor_line.bg,
			fg = colors[string.lower(name)].fg,
			italic = colors[string.lower(name)].italic,
		}

		-- Regular highlights
		hi[HIGHLIGHT_PREFIX .. name] = {
			bg = transparent and "None" or blends[string.lower(name)],
			fg = colors[string.lower(name)].fg,
			italic = colors[string.lower(name)].italic,
		}

		hi[HIGHLIGHT_PREFIX .. name .. "NoBg"] = {
			fg = colors[string.lower(name)].fg,
			bg = "None",
			italic = colors[string.lower(name)].italic,
		}

		-- Inverse highlights with and without background
		hi[INV_HIGHLIGHT_PREFIX .. name] = {
			fg = blends[string.lower(name)],
			bg = transparent and "None" or colors.background,
			italic = colors[string.lower(name)].italic,
		}

		hi[INV_HIGHLIGHT_PREFIX .. name .. "NoBg"] = {
			fg = blends[string.lower(name)],
			bg = "None",
			italic = colors[string.lower(name)].italic,
		}
	end

	-- Arrow highlights
	hi[HIGHLIGHT_PREFIX .. "Arrow"] = {
		bg = colors.background,
		fg = colors.arrow.fg,
	}
	hi[HIGHLIGHT_PREFIX .. "ArrowNoBg"] = {
		bg = "None",
		fg = colors.arrow.fg,
	}

	return hi
end

---Create mixed highlight groups
---@param hi table<string, table>
local function create_mixed_highlights(hi)
	local base_groups = {
		HIGHLIGHT_PREFIX .. "Error",
		HIGHLIGHT_PREFIX .. "Warn",
		HIGHLIGHT_PREFIX .. "Info",
		HIGHLIGHT_PREFIX .. "Hint",
	}

	for _, primary in ipairs(base_groups) do
		for _, secondary in ipairs(base_groups) do
			local mixed_name = primary .. "Mix" .. secondary:match("Text(%w+)$")
			hi[mixed_name] = {
				fg = hi[primary].fg,
				bg = hi[secondary].bg,
				italic = hi[primary].italic,
			}
		end
	end
end

---@param blend BlendOptions
---@param default_hi DefaultHighlights
function M.setup_highlights(blend, default_hi, transparent)
	-- Get base colors
	local colors = {
		error = get_highlight(default_hi.error),
		warn = get_highlight(default_hi.warn),
		info = get_highlight(default_hi.info),
		hint = get_highlight(default_hi.hint),
		ok = get_highlight(default_hi.ok),
		arrow = get_highlight(default_hi.arrow),
		cursor_line = get_highlight("CursorLine"),
	}

	if not transparent then
		transparent = false
	end

	if blend.factor == 0 then
		transparent = true
	end

	-- Get special colors
	colors.background = get_background_color(default_hi.background)
	colors.mixing_color = get_mixing_color(default_hi.mixing_color)

	-- Create blended colors
	local blends = {
		error = utils.blend(colors.error.fg, colors.mixing_color, blend.factor),
		warn = utils.blend(colors.warn.fg, colors.mixing_color, blend.factor),
		info = utils.blend(colors.info.fg, colors.mixing_color, blend.factor),
		hint = utils.blend(colors.hint.fg, colors.mixing_color, blend.factor),
		background = colors.background,
	}

	-- Create highlight groups
	local hi = create_highlight_groups(colors, blends, transparent)

	create_mixed_highlights(hi)

	-- Apply highlights
	for name, opts in pairs(hi) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

---Get diagnostic highlight groups
---@param blend_factor number
---@param diag_ret table
---@param curline number
---@param index_diag number
---@return string diag_hi
---@return string diag_inv_hi
---@return string body_hi
function M.get_diagnostic_highlights(blend_factor, diag_ret, curline, index_diag)
	local diag_hi, diag_inv_hi, body_hi = M.get_diagnostic_highlights_from_severity(diag_ret.severity)

	if (diag_ret.line and diag_ret.line == curline) and index_diag == 1 and blend_factor == 0 then
		diag_hi = diag_hi .. "CursorLine"
	end

	if (diag_ret.line and diag_ret.line ~= curline) or index_diag > 1 or diag_ret.need_to_be_under then
		diag_inv_hi = diag_inv_hi .. "NoBg"
	end

	return diag_hi, diag_inv_hi, body_hi
end

---Get base diagnostic highlight groups from severity
---@param severity number
---@return string diag_hi
---@return string diag_inv_hi
---@return string body_hi
function M.get_diagnostic_highlights_from_severity(severity)
	local hi = SEVERITY_NAMES[severity]
	if not hi then
		hi = SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]
	end

	return HIGHLIGHT_PREFIX .. hi, INV_HIGHLIGHT_PREFIX .. hi, INV_HIGHLIGHT_PREFIX .. hi .. "NoBg"
end

---Get mixed diagnostic highlight groups from two severities
---@param severity_a number
---@param severity_b number
---@return string diag_hi
---@return string diag_inv_hi
function M.get_diagnostic_mixed_highlights_from_severity(severity_a, severity_b)
	local hi_a = SEVERITY_NAMES[severity_a] or SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]
	local hi_b = SEVERITY_NAMES[severity_b] or SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]

	return HIGHLIGHT_PREFIX .. hi_b .. "Mix" .. hi_a, INV_HIGHLIGHT_PREFIX .. hi_a .. "Mix" .. hi_b
end

---Get diagnostic icon
---@param severity number|string
---@return string
function M.get_diagnostic_icon(severity)
	local name = vim.diagnostic.severity[severity]:lower()
	local sign = vim.fn.sign_getdefined("DiagnosticSign" .. name)[1]

	if vim.fn.has("nvim-0.10.0") == 1 then
		local config = vim.diagnostic.config() or {}
		if config.signs == nil or type(config.signs) == "boolean" then
			return sign and sign.text or name:sub(1, 1)
		end
		local signs = config.signs or {}
		if type(signs) == "function" then
			signs = signs(0, 0)
		end
		return type(signs) == "table" and signs.text and signs.text[severity] or sign and sign.text or name:sub(1, 1)
	end

	return sign and sign.text or name or SEVERITY_NAMES[severity]:sub(1, 1)
end

return M
