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

--- Setup the tiny-inline-diagnostic plugin with user options.
-- @param opts table: User configuration options to override the default settings.
function M.setup(opts)
	if opts == nil then
		opts = {}
	end

	local config = vim.tbl_deep_extend("force", default_config, opts)

	-- config.options.overflow.position = config.options.overflow.position:lower()
	config.options.overflow.mode = config.options.overflow.mode:lower()
	if config.preset then
		config = vim.tbl_deep_extend("keep", config, presets.build(config.preset))
	end
	M.config = config

	hi.setup_highlights(config.blend, config.hi)

	vim.api.nvim_create_autocmd("ColorScheme", {
		pattern = "*",
		callback = function()
			hi.setup_highlights(config.blend, config.hi)
		end,
	})

	diag.set_diagnostic_autocmds(config)
end

--- Change the blend and highlight settings dynamically.
-- @param blend table: New blend settings to apply.
-- @param highlights table: New highlight settings to apply.
function M.change(blend, highlights)
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

function M.change_severities(severities)
	M.config.options.severity = severities
end

return M
