#  📦 tiny-inline-diagnostic.nvim

A Neovim plugin that display prettier diagnostic messages. Display one line diagnostic messages where the cursor is, with icons and colors.

## 🖼️ Images

![tinyinlinediagnostic_2](https://github.com/rachartier/tiny-inline-diagnostic.nvim/assets/2057541/d0033fe8-1ac3-416b-92a6-96aa49472cc9)

### Overflow handling enabled

![tinyinlinediagnostic_wrap](https://github.com/rachartier/tiny-inline-diagnostic.nvim/assets/2057541/799fd09f-ba7a-4881-825b-8068af8c53bb)


### Break line enabled

![image](https://github.com/rachartier/tiny-inline-diagnostic.nvim/assets/2057541/3d632c8f-6080-4929-8c6e-c747527a9eea)


## 🛠️ Setup

- You need to set `vim.diagnostic.config({ virtual_text = false })`, to not have all diagnostics in the buffer displayed.

## 📥 Installation

With Lazy.nvim:

```lua
{
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    config = function()
        require('tiny-inline-diagnostic').setup()
    end
}
```

## ⚙️ Options

```lua
-- Default configuration
require('tiny-inline-diagnostic').setup({
        signs = {
            left = "",
            right = "",
            diag = "●",
            arrow = "    ",
            up_arrow = "    ",
            vertical = " │",
            vertical_end = " └"
        },
        hi = {
            error = "DiagnosticError",
            warn = "DiagnosticWarn",
            info = "DiagnosticInfo",
            hint = "DiagnosticHint",
            arrow = "NonText",
            background = "CursorLine", -- Can be a highlight or a hexadecimal color (#RRGGBB)
            mixing_color = "None",  -- Can be None or a hexadecimal color (#RRGGBB). Used to blend the background color with the diagnostic background color with another color.
        },
        blend = {
            factor = 0.27,
        },
        options = {
            -- Throttle the update of the diagnostic when moving cursor, in milliseconds.
            -- You can increase it if you have performance issues.
            -- Or set it to 0 to have better visuals.
            throttle = 20,

            -- The minimum length of the message, otherwise it will be on a new line.
            softwrap = 15,

            -- If multiple diagnostics are under the cursor, display all of them.
            multiple_diag_under_cursor = false,

            overflow = {
                -- Manage the overflow of the message.
                --    - wrap: when the message is too long, it is then displayed on multiple lines.
                --    - none: the message will not be truncated, and will be displayed on a single line.
                mode = "wrap",
            },

            --- Enable it if you want to always have message with `after` characters length.
            break_line = {
                enabled = false,
                after = 30,
            },

            virt_texts = {
                priority = 2048,
            }
        }
})
```

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

- `require("tiny-inline-diagnostic").change(background, factor, mixing_color)`: change the background color, mixing color and the blend factor, useful if you want to change the colorscheme on the fly.
- `require("tiny-inline-diagnostic").get_diagnostic_under_cursor(bufnr)`: get the diagnostic under the cursor, useful if you want to display the diagnostic in a statusline.
- `require("tiny-inline-diagnostic").enable()`: enable the diagnostic.
- `require("tiny-inline-diagnostic").disable()`: disable the diagnostic.
- `require("tiny-inline-diagnostic").toggle()`: toggle the diagnostic, on/off.


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
