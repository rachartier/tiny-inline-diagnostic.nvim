---@class PluginConfig
---@field preset string
---@field hi table
---@field options table
---@field blend table

local M = {}

local hi = require("tiny-inline-diagnostic.highlights")
local diag = require("tiny-inline-diagnostic.diagnostic")
local presets = require("tiny-inline-diagnostic.presets")


local default_config = {
	preset = "modern",
	hi = {
		error = "DiagnosticError",
		warn = "DiagnosticWarn",
		info = "DiagnosticInfo",
		hint = "DiagnosticHint",
		arrow = "NonText",
		background = "CursorLine",
		mixing_color = "Normal",
	},
	options = {
		show_source = false,
		use_icons_from_diagnostic = false,
		throttle = 20,
		softwrap = 30,
		multiple_diag_under_cursor = true,
		multilines = false,
		show_all_diags_on_cursorline = false,
		enable_on_insert = false,
		format = nil,
		overflow = {
			mode = "wrap",
		},
		break_line = {
			enabled = false,
			after = 30,
		},
		virt_texts = {
			priority = 2048,
		},
		severity = {
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
		},
		overwrite_events = nil,
	},
}

M.config = nil

---Create color scheme autocommand
local function setup_colorscheme_handler(config)
	vim.api.nvim_create_autocmd("ColorScheme", {
		pattern = "*",
		callback = function()
			hi.setup_highlights(config.blend, config.hi)
		end,
	})
end

---Normalize configuration values
local function normalize_config(config)
	if config.options.overflow and config.options.overflow.mode then
		config.options.overflow.mode = config.options.overflow.mode:lower()
	end

	if config.preset then
		local preset = presets.build(config.preset:lower())
		config = vim.tbl_deep_extend("keep", config, preset)
	end

	return config
end

--- Setup the tiny-inline-diagnostic plugin with user options.
---@param opts table|nil User configuration options to override the default settings.
function M.setup(opts)
	local config = vim.tbl_deep_extend("force", default_config, opts or {})

	config = normalize_config(config)

	M.config = config

	hi.setup_highlights(config.blend, config.hi)

	setup_colorscheme_handler(config)
	diag.set_diagnostic_autocmds(config)
end

--- Change the blend and highlight settings dynamically.
---@param blend table|nil New blend settings
---@param highlights table|nil New highlight settings
function M.change(blend, highlights)
	if not M.config then
		error("Plugin not initialized. Call setup() first.")
		return
	end

	local config = vim.tbl_deep_extend("force", M.config, {
		blend = blend or M.config.blend,
		hi = highlights or M.config.hi,
	})

	hi.setup_highlights(config.blend, config.hi)
end

--- Enable the diagnostic display.
function M.enable()
	diag.enable()
end

--- Disable the diagnostic display.
function M.disable()
	diag.disable()
end

--- Toggle the diagnostic display on or off.
function M.toggle()
	diag.toggle()
end

---Change diagnostic severities
---@param severities table New severity settings
function M.change_severities(severities)
	if not M.config then
		error("Plugin not initialized. Call setup() first.")
		return
	end

	M.config.options.severity = severities
end

return M
