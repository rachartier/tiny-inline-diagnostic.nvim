# 🩺 tiny-inline-diagnostic.nvim

[![CI](https://github.com/rachartier/tiny-inline-diagnostic.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/rachartier/tiny-inline-diagnostic.nvim/actions/workflows/ci.yml)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-blue.svg)](https://neovim.io/)
[![Stars](https://img.shields.io/github/stars/rachartier/tiny-inline-diagnostic.nvim)](https://github.com/rachartier/tiny-inline-diagnostic.nvim/stargazers)

A Neovim plugin for displaying inline diagnostic messages with customizable styles and icons.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Custom Styling](#custom-styling)
- [Presets](#presets)
- [Examples](#examples)
- [API](#api)
  - [Commands](#commands)
- [Integrations](#integrations)
- [Comparison with Neovim's Built-in `virtual_lines`](#comparison-with-neovims-built-in-virtual_lines)
- [Troubleshooting](#troubleshooting)

## Requirements

- Neovim >= 0.10

## Installation

### Lazy.nvim

```lua
{
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
        require("tiny-inline-diagnostic").setup()
        vim.diagnostic.config({ virtual_text = false }) -- Disable Neovim's default virtual text diagnostics
    end,
}
```

### LazyVim

```lua
{
  {
      "rachartier/tiny-inline-diagnostic.nvim",
      event = "VeryLazy",
      priority = 1000,
      opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    opts = { diagnostics = { virtual_text = false } },
  },
}
```

> [!IMPORTANT]
> This disables Neovim's built-in virtual text diagnostics to prevent conflicts and duplicate displays. The plugin provides its own inline diagnostic display.

## Examples

### Multiline Diagnostics
![tiny_inline_1](https://github.com/user-attachments/assets/0e990581-8daa-4651-a54d-aca222caf6a5)

<details>
<summary>Configuration</summary>

```lua
require("tiny-inline-diagnostic").setup({
    options = {
        multilines = {
            enabled = true,
        },
    },
})
```

</details>

### Overflow Handling (by default)
![tiny_inline_2-ezgif com-speed](https://github.com/user-attachments/assets/19da9737-7335-4a53-b364-ac5c12c663b2)

### With Sources
<img width="2399" height="1136" alt="tiny_inline_4" src="https://github.com/user-attachments/assets/5c45c7fc-eae5-4851-9378-1d3c584b285d" />

<details>
<summary>Configuration</summary>

```lua
require("tiny-inline-diagnostic").setup({
    options = {
        show_source = {
            enabled = true,
        },
    },
})
```

</details>

### Diagnotics count
<img width="2400" height="1138" alt="tiny_inline_3" src="https://github.com/user-attachments/assets/42fcfb20-8df9-4182-b994-326c5fdcc4fc" />

<details>
<summary>Configuration</summary>

```lua
require("tiny-inline-diagnostic").setup({
    options = {
        add_messages = {
            display_count = true,
        },
        multilines = {
            enabled = true,
        },
    },
})
```

</details>

### Related Diagnostics (by default)
<img width="2558" height="1365" alt="tiny_inline_5" src="https://github.com/user-attachments/assets/77af469f-351e-4d4e-a424-51fc0c814a5c" />

## Configuration

```lua
require("tiny-inline-diagnostic").setup({
    -- Choose a preset style for diagnostic appearance
    -- Available: "modern", "classic", "minimal", "powerline", "ghost", "simple", "nonerdfont", "amongus"
    preset = "modern",

    -- Make diagnostic background transparent
    transparent_bg = false,

    -- Make cursorline background transparent for diagnostics
    transparent_cursorline = true,

    -- Customize highlight groups for colors
    -- Use Neovim highlight group names or hex colors like "#RRGGBB"
    hi = {
        error = "DiagnosticError",     -- Highlight for error diagnostics
        warn = "DiagnosticWarn",       -- Highlight for warning diagnostics
        info = "DiagnosticInfo",       -- Highlight for info diagnostics
        hint = "DiagnosticHint",       -- Highlight for hint diagnostics
        arrow = "NonText",             -- Highlight for the arrow pointing to diagnostic
        background = "CursorLine",     -- Background highlight for diagnostics
        mixing_color = "Normal",       -- Color to blend background with (or "None")
    },

    -- List of filetypes to disable the plugin for
    disabled_ft = {},

    options = {
        -- Display the source of diagnostics (e.g., "lua_ls", "pyright")
        show_source = {
            enabled = false,           -- Enable showing source names
            if_many = false,           -- Only show source if multiple sources exist for the same diagnostic
        },

        -- Display the diagnostic code of diagnostics (e.g., "F401", "no-dupe-args")
        show_code = true,

        -- Use icons from vim.diagnostic.config instead of preset icons
        use_icons_from_diagnostic = false,

        -- Color the arrow to match the severity of the first diagnostic
        set_arrow_to_diag_color = false,


        -- Throttle update frequency in milliseconds to improve performance
        -- Higher values reduce CPU usage but may feel less responsive
        -- Set to 0 for immediate updates (may cause lag on slow systems)
        throttle = 20,

        -- Minimum number of characters before wrapping long messages
        softwrap = 30,

        -- Control how diagnostic messages are displayed
        -- NOTE: When using display_count = true, you need to enable multiline diagnostics with multilines.enabled = true
        --       If you want them to always be displayed, you can also set multilines.always_show = true.
        add_messages = {
            messages = true,           -- Show full diagnostic messages
            display_count = false,     -- Show diagnostic count instead of messages when cursor not on line
            use_max_severity = false,  -- When counting, only show the most severe diagnostic
            show_multiple_glyphs = true, -- Show multiple icons for multiple diagnostics of same severity
        },

        -- Settings for multiline diagnostics
        multilines = {
            enabled = false,           -- Enable support for multiline diagnostic messages
            always_show = false,       -- Always show messages on all lines of multiline diagnostics
            trim_whitespaces = false,  -- Remove leading/trailing whitespace from each line
            tabstop = 4,               -- Number of spaces per tab when expanding tabs
            severity = nil,            -- Filter multiline diagnostics by severity (e.g., { vim.diagnostic.severity.ERROR })
          },

        -- Show all diagnostics on the current cursor line, not just those under the cursor
        show_all_diags_on_cursorline = false,

        -- Only show diagnostics when the cursor is directly over them, no fallback to line diagnostics
        show_diags_only_under_cursor = false,

        -- Display related diagnostics from LSP relatedInformation
        show_related = {
            enabled = true,           -- Enable displaying related diagnostics
            max_count = 3,             -- Maximum number of related diagnostics to show per diagnostic
        },

        -- Enable diagnostics display in insert mode
        -- May cause visual artifacts; consider setting throttle to 0 if enabled
        enable_on_insert = false,

        -- Enable diagnostics display in select mode (e.g., during auto-completion)
        enable_on_select = false,

        -- Handle messages that exceed the window width
        overflow = {
            mode = "wrap",             -- "wrap": split into lines, "none": no truncation, "oneline": keep single line
            padding = 0,               -- Extra characters to trigger wrapping earlier
        },

        -- Break long messages into separate lines
        break_line = {
            enabled = false,           -- Enable automatic line breaking
            after = 30,                -- Number of characters before inserting a line break
        },

        -- Custom function to format diagnostic messages
        -- Receives diagnostic object, returns formatted string
        -- Example: function(diag) return diag.message .. " [" .. diag.source .. "]" end
        format = nil,

        -- Virtual text display priority
        -- Higher values appear above other plugins (e.g., GitBlame)
        virt_texts = {
            priority = 2048,
        },

        -- Filter diagnostics by severity levels
        -- Remove severities you don't want to display
        severity = {
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
        },

        -- Events that trigger attaching diagnostics to buffers
        -- Default is {"LspAttach"}; change only if plugin doesn't work with your LSP setup
        overwrite_events = nil,

        -- Automatically disable diagnostics when opening diagnostic float windows
        override_open_float = false,

        -- Experimental options, subject to misbehave in future NeoVim releases
        experimental = {
          -- Make diagnostics not mirror across windows containing the same buffer
          -- See: https://github.com/rachartier/tiny-inline-diagnostic.nvim/issues/127
          use_window_local_extmarks = false,
        },
    },
})
```


### Custom Styling

Override preset signs and blending:

```lua
require("tiny-inline-diagnostic").setup({
    signs = {
        left = "",
        right = "",
        diag = "●",
        arrow = "    ",
        up_arrow = "    ",
        vertical = " │",
        vertical_end = " └",
    },
    blend = {
        factor = 0.22,
    },
})
```

> [!NOTE]
> Providing `signs` or `blend` tables will completely replace the preset defaults. If you want to use a preset's styling, only set the `preset` option and do not include `signs` or `blend` in your configuration. Mixing presets with custom signs/blend is not supported.

## Presets

### modern
![modern](https://github.com/user-attachments/assets/38460aab-bb4d-4766-9cc6-4315315964c0)

### classic
![classic](https://github.com/user-attachments/assets/add17b8e-a0b3-4ffa-883f-ed3f7f7ac162)

### minimal
![minimal](https://github.com/user-attachments/assets/931c75a8-27a7-4691-9ee1-6c9cd145c78d)

### powerline
![powerline](https://github.com/user-attachments/assets/717d92b0-db8e-4287-9dcf-bc214ecd1f4b)

### simple
![simple](https://github.com/user-attachments/assets/897e3204-7382-48c5-afc4-77259228d263)

### nonerdfont
![nonerdfont](https://github.com/user-attachments/assets/b901f3d7-fab8-44f5-b761-4255aa38acd9)

### ghost
![ghost](https://github.com/user-attachments/assets/41f652de-5744-4c1f-a112-d44cda8f6a5a)

### amongus
![amongus](https://github.com/user-attachments/assets/780dc83e-43c4-4399-84b1-1a08d48e1e86)


## API

```lua
local diag = require("tiny-inline-diagnostic")

-- Change settings dynamically
diag.change(blend_opts, highlight_opts)

-- Get diagnostic under cursor
local diag_under_cursor = diag.get_diagnostic_under_cursor()

-- Control visibility
diag.enable()
diag.disable()
diag.toggle()

-- Filter severities
diag.change_severities({ vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN })
```

### Commands

The plugin provides a user command for controlling diagnostic display:

```vim
:TinyInlineDiag enable   " Enable inline diagnostics
:TinyInlineDiag disable  " Disable inline diagnostics
:TinyInlineDiag toggle   " Toggle inline diagnostics on/off
```

You can map these to keybindings for quick access:

```lua
vim.keymap.set("n", "<leader>de", "<cmd>TinyInlineDiag enable<cr>", { desc = "Enable diagnostics" })
vim.keymap.set("n", "<leader>dd", "<cmd>TinyInlineDiag disable<cr>", { desc = "Disable diagnostics" })
vim.keymap.set("n", "<leader>dt", "<cmd>TinyInlineDiag toggle<cr>", { desc = "Toggle diagnostics" })
```

### Auto-Disable on Float

To automatically hide inline diagnostics when opening Neovim's diagnostic float windows, override the function to disable diagnostics before opening the float and re-enable them after closing.

```lua
vim.diagnostic.open_float = require("tiny-inline-diagnostic.override").open_float
```

This wrapper function temporarily disables the plugin when a diagnostic float is opened, preventing overlap or visual interference, and restores the diagnostics once the float is closed. It's a lightweight override that doesn't modify the original `open_float` behavior beyond adding the disable/enable logic.

## Integrations

### sidekick.nvim

The plugin integrates with [sidekick.nvim](https://github.com/folke/sidekick.nvim) to automatically disable diagnostics when the sidekick NES is shown and re-enable them when hidden. This prevents visual clutter...

```lua
local disabled = false
return {
  {
    "folke/sidekick.nvim",
    opts = { nes = { enabled = true } },
    config = function(_, opts)
      require("sidekick").setup(opts)
      vim.api.nvim_create_autocmd("User", {
        pattern = "SidekickNesHide",
        callback = function()
          if disabled then
            disabled = false
            require("tiny-inline-diagnostic").enable()
          end
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "SidekickNesShow",
        callback = function()
          disabled = true
          require("tiny-inline-diagnostic").disable()
        end,
      })
    end,
  },
}
```

This setup listens for `SidekickNesShow` and `SidekickNesHide` events to toggle the diagnostics accordingly.

## Comparison with Neovim's Built-in `virtual_lines`

As of Neovim 0.11, the diagnostic system supports a `virtual_lines` option (see [neovim/neovim#31959](https://github.com/neovim/neovim/pull/31959)). This built-in feature renders diagnostics as virtual lines below the affected code. However, there differences :

**Built-in `virtual_lines`**: Inserts virtual lines into the buffer, which shifts all subsequent text down. This can be distracting during navigation, as the visible text "jumps" whenever diagnostics appear or disappear.

**`tiny-inline-diagnostic.nvim`**: Renders diagnostics as inline virtual text that overlays the code without moving any lines. This approach eliminates visual disruption, maintaining a good editing experience. Additionally, this plugin is highly configurable with multiple presets, extensive display options (overflow handling, multiline support, diagnostic counts, related information), custom formatting, and fine control over when and how diagnostics appear.

For users who prefer diagnostics to remain unobtrusive and non-intrusive while having extensive customization options, `tiny-inline-diagnostic.nvim` provides a cleaner, more flexible alternative.

## Troubleshooting

- **Colors wrong**: Adjust `hi` table or `mixing_color`
- **Default diagnostics show**: Add `vim.diagnostic.config({ virtual_text = false })`
- **Overridden by plugins**: Increase `virt_texts.priority`
- **No diagnostics**: Check LSP config and `disabled_ft`
