local MiniTest = require("mini.test")

MiniTest.setup({
  collect = {
    find_files = function()
      return vim.fn.globpath("tests", "test_*.lua", true, true)
    end,
    filter_cases = function(case)
      return true
    end,
  },
  execute = {
    reporter = MiniTest.gen_reporter.buffer({ window = { border = "rounded" } }),
  },
})

vim.keymap.set("n", "<leader>tr", function()
  MiniTest.run()
end, { desc = "Run all tests" })

vim.keymap.set("n", "<leader>tf", function()
  MiniTest.run_file()
end, { desc = "Run current file tests" })

vim.keymap.set("n", "<leader>tc", function()
  MiniTest.run_at_location()
end, { desc = "Run test at cursor" })

local M = {}

function M.create_full_opts(overrides)
  local opts = {
    preset = "modern",
    transparent_bg = false,
    transparent_cursorline = true,
    hi = {
      error = "DiagnosticError",
      warn = "DiagnosticWarn",
      info = "DiagnosticInfo",
      hint = "DiagnosticHint",
      arrow = "NonText",
      background = "CursorLine",
      mixing_color = "Normal",
    },
    signs = {
      left = "",
      right = "",
      diag = "●",
      arrow = "    ",
      up_arrow = "    ",
      vertical = " │ ",
      vertical_end = " └ ",
    },
    blend = {
      factor = 0.27,
    },
    options = {
      show_source = {
        enabled = false,
        if_many = false,
      },
      add_messages = {
        messages = true,
        display_count = false,
        use_max_severity = false,
        show_multiple_glyphs = true,
      },
      set_arrow_to_diag_color = false,
      use_icons_from_diagnostic = false,
      throttle = 20,
      softwrap = 30,
      multilines = {
        enabled = false,
        always_show = false,
        trim_whitespaces = false,
        tabstop = 4,
      },
      show_all_diags_on_cursorline = false,
      enable_on_insert = false,
      enable_on_select = false,
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
      override_open_float = false,
      overwrite_events = nil,
      multiple_diag_under_cursor = false,
    },
    disabled_ft = {},
  }

  if overrides then
    opts = vim.tbl_deep_extend("force", opts, overrides)
  end

  return opts
end

return M
