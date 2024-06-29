#  📦 tiny-inline-diagnostic.nvim

A Neovim plugin that display prettier diagnostic messages. Display one line diagnostic messages where the cursor is, with icons and colors.

## 🖼️ Images

![tinyinlinediagnostic](https://github.com/rachartier/tiny-inline-diagnostic.nvim/assets/2057541/9e9b756b-aee8-4153-9c1e-856c3167c140)

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
        },
        hi = {
            error = "DiagnosticError",
            warn = "DiagnosticWarn",
            info = "DiagnosticInfo",
            hint = "DiagnosticHint",
            arrow = "NonText",
            background = "None", -- Should be "None" or a hexadecimal color (#RRGGBB)
        },
        blend = {
            factor = 0.27,
        },
        options = {
            clear_on_insert = false,
        }
})
```

## 📚 API

- `require("tiny-inline-diagnostic").change(background, factor)`: change the background color and the blend factor, useful if you want to change the colorscheme on the fly.


