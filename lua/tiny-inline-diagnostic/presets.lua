local M = {}

function M.build(name)
	if name == "classic" then
		return {
			signs = {
				left = " ",
				right = " ",
				diag = "●",
				arrow = "",
				up_arrow = "",
				vertical = " │",
				vertical_end = " └",
			},
			blend = {
				factor = 0,
			},
		}
	elseif name == "simple" then
		return {
			signs = {
				left = " ",
				right = "",
				diag = "",
				arrow = "    ",
				up_arrow = "    ",
				vertical = " │",
				vertical_end = " └",
			},
			blend = {
				factor = 0.22,
			},
		}
	elseif name == "minimal" then
		return {
			signs = {
				left = " ",
				right = "",
				diag = "",
				arrow = "",
				up_arrow = "",
				vertical = "  │",
				vertical_end = "  └",
			},
			blend = {
				factor = 0,
			},
		}
	elseif name == "nonerdfont" then
		return {
			signs = {
				left = "░▒",
				right = "▒░",
				diag = "●",
				arrow = "   ",
				up_arrow = "",
				vertical = " │",
				vertical_end = " └",
			},
			blend = {
				factor = 0.22,
			},
		}
	elseif name == "ghost" then
		return {
			signs = {
				left = "",
				right = "",
				diag = "󰊠",
				arrow = "    ",
				up_arrow = "    ",
				vertical = " │",
				vertical_end = " └",
			},
			blend = {
				factor = 0.22,
			},
		}
	end
	return {
		signs = {
			left = "",
			right = "",
			diag = "●",
			arrow = "    ",
			up_arrow = "    ",
			vertical = " │",
			vertical_end = " └",
		},
		blend = {
			factor = 0.22,
		},
	}
end

return M
