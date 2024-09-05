local M = {}

local hi = require("tiny-inline-diagnostic.highlights")
local diag = require("tiny-inline-diagnostic.diagnostic")

local default_config = {
	signs = {
		left = "",
		right = "",
		diag = " ●",
		arrow = "    ",
		up_arrow = "    ",
		vertical = " │",
		vertical_end = " └",
	},
	hi = {
		error = "DiagnosticError",
		warn = "DiagnosticWarn",
		info = "DiagnosticInfo",
		hint = "DiagnosticHint",
		arrow = "NonText",
		background = "CursorLine",
		mixing_color = "None",
	},
	blend = {
		factor = 0.27,
	},
	options = {
		show_source = false,
		throttle = 20,
		softwrap = 30,
		multiple_diag_under_cursor = true,
		multilines = false,
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
	plugin = {},
}

M.config = nil

function M.setup(opts)
	if opts == nil then
		opts = {}
	end

	local config = vim.tbl_deep_extend("force", default_config, opts)

	-- config.options.overflow.position = config.options.overflow.position:lower()
	config.options.overflow.mode = config.options.overflow.mode:lower()
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

function M.change(blend, highlights)
	local config = vim.tbl_deep_extend("force", M.config, {
		blend = blend or M.config.blend,
		hi = highlights or M.config.hi,
	})

	hi.setup_highlights(config.blend, config.hi)
end

function M.enable()
	diag.enable()
end

function M.disable()
	diag.disable()
end

function M.toggle()
	diag.toggle()
end

return M
