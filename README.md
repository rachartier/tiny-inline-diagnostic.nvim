#  📦 tiny-inline-diagnostic.nvim

A Neovim plugin that display prettier diagnostic messages. Display one line diagnostic messages where the cursor is, with icons and colors.

## 🖼️ Images

### Multilines enabled

![tinyinline_demo_1](https://github.com/user-attachments/assets/9dfc75c6-6382-4c05-89d8-defea930ac43)



### Overflow handling enabled

![tinyinline_demo_2](https://github.com/user-attachments/assets/e629659c-0925-4031-a046-bffdd57f9a9c)



### Break line enabled

![image](https://github.com/user-attachments/assets/45180d09-8653-4403-a79b-5bee522560e3)


## 🛠️ Setup

- You need to set `vim.diagnostic.config({ virtual_text = false })`, to not have all diagnostics in the buffer displayed.

## 📥 Installation

> [!NOTE]
> Only works with Neovim >= 0.10

With Lazy.nvim:

```lua
{
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy", -- Or `LspAttach`
    priority = 1000, -- needs to be loaded in first
    config = function()
        require('tiny-inline-diagnostic').setup()
    end
}
```

## ⚙️ Options

```lua
-- Default configuration
require("tiny-inline-diagnostic").setup({
	preset = "modern", -- Can be: "modern", "classic", "minimal", "powerline", ghost", "simple", "nonerdfont", "amongus"
	hi = {
		error = "DiagnosticError",
		warn = "DiagnosticWarn",
		info = "DiagnosticInfo",
		hint = "DiagnosticHint",
		arrow = "NonText",
		background = "CursorLine", -- Can be a highlight or a hexadecimal color (#RRGGBB)
		mixing_color = "None", -- Can be None or a hexadecimal color (#RRGGBB). Used to blend the background color with the diagnostic background color with another color.
	},
	options = {
		-- Show the source of the diagnostic.
		show_source = false,

		-- Use your defined signs in the diagnostic config table.
		use_icons_from_diagnostic = false,

        -- Add messages to the diagnostic when multilines is enabled
        add_messages = true,

		-- Throttle the update of the diagnostic when moving cursor, in milliseconds.
		-- You can increase it if you have performance issues.
		-- Or set it to 0 to have better visuals.
		throttle = 20,

		-- The minimum length of the message, otherwise it will be on a new line.
		softwrap = 30,

		-- If multiple diagnostics are under the cursor, display all of them.
		multiple_diag_under_cursor = false,

		-- Enable diagnostic message on all lines.
	        -- Can either be a boolean or a table with the following options:
	        --  multilines = {
	        -- 	-- Enable the multilines feature
	        -- 	enabled = false,
	        --
	        -- 	-- Always show diagnostic messages on all lines
	        --  	always_show = false,
	        --  }
		--
	        -- If it is a boolean set as true, it will enable the feature with the default options:
	        --  multilines = {
	        -- 	enabled = true,
	        -- 	always_show = false,
	        -- }
        
		multilines = {
	            enabled = false,
	            always_show = false,
	        },

		-- Show all diagnostics on the cursor line.
		show_all_diags_on_cursorline = false,

		-- Enable diagnostics on Insert mode. You should also se the `throttle` option to 0, as some artefacts may appear.
		enable_on_insert = false,

		overflow = {
			-- Manage the overflow of the message.
			--    - wrap: when the message is too long, it is then displayed on multiple lines.
			--    - none: the message will not be truncated.
			--    - oneline: message will be displayed entirely on one line.
			mode = "wrap",
		},

		-- Format the diagnostic message.
		-- Example:
		-- format = function(diagnostic)
		--     return diagnostic.message .. " [" .. diagnostic.source .. "]"
		-- end,
		format = nil,

		--- Enable it if you want to always have message with `after` characters length.
		break_line = {
			enabled = false,
			after = 30,
		},

		virt_texts = {
			priority = 2048,
		},

		-- Filter by severity.
		severity = {
			vim.diagnostic.severity.ERROR,
			vim.diagnostic.severity.WARN,
			vim.diagnostic.severity.INFO,
			vim.diagnostic.severity.HINT,
		},

		-- Overwrite events to attach to a buffer. You should not change it, but if the plugin
		-- does not works in your configuration, you may try to tweak it.
		overwrite_events = nil,
	},
})
```

:warning: **Note**: Overriding `signs` or `blend` tables will override the default values of the preset. If you want to use the default values of the preset, you need to set the `preset` option **ONLY**.

If you do not want to use the `preset` option, you can set the your own style with:

```lua
require("tiny-inline-diagnostic").setup({
    -- ...
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
    -- ...
})
```
## Presets
### modern
![image](https://github.com/user-attachments/assets/38460aab-bb4d-4766-9cc6-4315315964c0)

### classic
![image](https://github.com/user-attachments/assets/add17b8e-a0b3-4ffa-883f-ed3f7f7ac162)

### minimal
![image](https://github.com/user-attachments/assets/931c75a8-27a7-4691-9ee1-6c9cd145c78d)

### powerline
![image](https://github.com/user-attachments/assets/717d92b0-db8e-4287-9dcf-bc214ecd1f4b)

### simple
![image](https://github.com/user-attachments/assets/897e3204-7382-48c5-afc4-77259228d263)

### nonerdfont
![image](https://github.com/user-attachments/assets/b901f3d7-fab8-44f5-b761-4255aa38acd9)

### ghost
![image](https://github.com/user-attachments/assets/41f652de-5744-4c1f-a112-d44cda8f6a5a)

### amongus
![image](https://github.com/user-attachments/assets/780dc83e-43c4-4399-84b1-1a08d48e1e86)


## 💡 Highlights

- TinyInlineDiagnosticVirtualTextError
- TinyInlineDiagnosticVirtualTextWarn
- TinyInlineDiagnosticVirtualTextInfo
- TinyInlineDiagnosticVirtualTextHint
- TinyInlineDiagnosticVirtualTextArrow

`Inv` is used for left and right signs.
- TinyInlineInvDiagnosticVirtualTextError
- TinyInlineInvDiagnosticVirtualTextWarn
- TinyInlineInvDiagnosticVirtualTextInfo
- TinyInlineInvDiagnosticVirtualTextHint

## 📚 API

- `require("tiny-inline-diagnostic").change(blend, highlights)`: change the colors of the diagnostic. You need to refer to `setup` to see the structure of the `blend` and `highlights` options.
- `require("tiny-inline-diagnostic").get_diagnostic_under_cursor(bufnr)`: get the diagnostic under the cursor, useful if you want to display the diagnostic in a statusline.
- `require("tiny-inline-diagnostic").enable()`: enable the diagnostic.
- `require("tiny-inline-diagnostic").disable()`: disable the diagnostic.
- `require("tiny-inline-diagnostic").toggle()`: toggle the diagnostic, on/off.
- `require("tiny-inline-diagnostic").change_severities(severities)`: change the severity of the diagnostic. `severities` is an array of severity, like `vim.diagnostic.severity.ERROR`.


## ❓ FAQ:


- **Q**: My colors are bad
    - You can change the colors with the `hi` option.
    - If you have no background color, you should try to set `blend.mixing_color` to a color that will blend with the background color.
- **Q**: All diagnostics are still displayed
    - You need to set `vim.diagnostic.config({ virtual_text = false })` to remove all the others diagnostics.
- **Q**: Diagnostics are not readable on a light background
    - You can either set `vim.g.background = "light"` to use white diagnostics background. Will not work if `hi.mixing_color` is set
- **Q**: `GitBlame` (or other) is displayed first
    - You need to modify the `virt_texts.priority` option to a higher value.
