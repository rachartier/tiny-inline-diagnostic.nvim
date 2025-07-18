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
        vim.diagnostic.config({ virtual_text = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics
    end
}
```

## ⚙️ Options

```lua
-- Default configuration
require("tiny-inline-diagnostic").setup({
    -- Style preset for diagnostic messages
    -- Available options:
    -- "modern", "classic", "minimal", "powerline",
    -- "ghost", "simple", "nonerdfont", "amongus"
    preset = "modern",

    transparent_bg = false, -- Set the background of the diagnostic to transparent
    transparent_cursorline = false, -- Set the background of the cursorline to transparent (only one the first diagnostic)

    hi = {
        error = "DiagnosticError", -- Highlight group for error messages
        warn = "DiagnosticWarn", -- Highlight group for warning messages
        info = "DiagnosticInfo", -- Highlight group for informational messages
        hint = "DiagnosticHint", -- Highlight group for hint or suggestion messages
        arrow = "NonText", -- Highlight group for diagnostic arrows

        -- Background color for diagnostics
        -- Can be a highlight group or a hexadecimal color (#RRGGBB)
        background = "CursorLine",

        -- Color blending option for the diagnostic background
        -- Use "None" or a hexadecimal color (#RRGGBB) to blend with another color
        mixing_color = "None",
    },

    options = {
        -- Display the source of the diagnostic (e.g., basedpyright, vsserver, lua_ls etc.)
	show_source = {
	    enabled = false,
	    if_many = false,
	},

        -- Use icons defined in the diagnostic configuration
        use_icons_from_diagnostic = false,

        -- Set the arrow icon to the same color as the first diagnostic severity
        set_arrow_to_diag_color = false,

        -- Add messages to diagnostics when multiline diagnostics are enabled
        -- If set to false, only signs will be displayed
        add_messages = true,

        -- Time (in milliseconds) to throttle updates while moving the cursor
        -- Increase this value for better performance if your computer is slow
        -- or set to 0 for immediate updates and better visual
        throttle = 20,

        -- Minimum message length before wrapping to a new line
        softwrap = 30,

        -- Configuration for multiline diagnostics
        -- Can either be a boolean or a table with the following options:
        --  multilines = {
        --      enabled = false,
        --      always_show = false,
        -- }
        -- If it set as true, it will enable the feature with this options:
        --  multilines = {
        --      enabled = true,
        --      always_show = false,
        -- }
        multilines = {
            -- Enable multiline diagnostic messages
            enabled = false,

            -- Always show messages on all lines for multiline diagnostics
            always_show = false,

            -- Trim whitespaces from the start/end of each line
            trim_whitespaces = false,

            -- Replace tabs with spaces in multiline diagnostics
            tabstop = 4,
        },

        -- Display all diagnostic messages on the cursor line
        show_all_diags_on_cursorline = false,

        -- Enable diagnostics in Insert mode
        -- If enabled, it is better to set the `throttle` option to 0 to avoid visual artifacts
        enable_on_insert = false,

		-- Enable diagnostics in Select mode (e.g when auto inserting with Blink)
        enable_on_select = false,

        overflow = {
            -- Manage how diagnostic messages handle overflow
            -- Options:
            -- "wrap" - Split long messages into multiple lines
            -- "none" - Do not truncate messages
            -- "oneline" - Keep the message on a single line, even if it's long
            mode = "wrap",

            -- Trigger wrapping to occur this many characters earlier when mode == "wrap".
            -- Increase this value appropriately if you notice that the last few characters
            -- of wrapped diagnostics are sometimes obscured.
            padding = 0,
        },

        -- Configuration for breaking long messages into separate lines
        break_line = {
            -- Enable the feature to break messages after a specific length
            enabled = false,

            -- Number of characters after which to break the line
            after = 30,
        },

        -- Custom format function for diagnostic messages
        -- Example:
        -- format = function(diagnostic)
        --     return diagnostic.message .. " [" .. diagnostic.source .. "]"
        -- end
        format = nil,


        virt_texts = {
            -- Priority for virtual text display
            priority = 2048,
        },

        -- Filter diagnostics by severity
        -- Available severities:
        -- vim.diagnostic.severity.ERROR
        -- vim.diagnostic.severity.WARN
        -- vim.diagnostic.severity.INFO
        -- vim.diagnostic.severity.HINT
        severity = {
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
        },

        -- Events to attach diagnostics to buffers
        -- You should not change this unless the plugin does not work with your configuration
        overwrite_events = nil,
    },
    disabled_ft = {} -- List of filetypes to disable the plugin
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
- `require("tiny-inline-diagnostic").get_diagnostic_under_cursor()`: get the diagnostic under the cursor, useful if you want to display the diagnostic in a statusline.
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
