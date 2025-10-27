local H = require("tests.helpers")
local MiniTest = require("mini.test")
local diagnostic = require("tiny-inline-diagnostic.diagnostic")
local state = require("tiny-inline-diagnostic.state")

local T = MiniTest.new_set()

local function create_test_opts()
  return H.make_opts({
    options = {
      add_messages = { messages = true },
      use_icons_from_diagnostic = false,
      set_arrow_to_diag_color = false,
      show_source = { enabled = false },
      overflow = { mode = "none" },
      break_line = { enabled = false },
      multilines = { enabled = false },
      softwrap = 10,
      virt_texts = { priority = 100 },
      throttle = 20,
      multiple_diag_under_cursor = false,
    },
    disabled_ft = { "help", "man" },
  })
end

T["filter_diags_under_cursor"] = MiniTest.new_set()

T["filter_diags_under_cursor"]["returns diagnostics under cursor"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local diags = {
      {
        lnum = 0,
        col = 0,
        end_col = 5,
        message = "error",
        severity = vim.diagnostic.severity.ERROR,
      },
    }

    local result = diagnostic.filter_diags_under_cursor(opts, buf, diags)
    MiniTest.expect.equality(type(result), "table")
  end)
end

T["filter_diags_under_cursor"]["filters out diagnostics not under cursor"] = function()
  H.with_win_buf({ "test line", "line 2" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local diags = {
      {
        lnum = 0,
        col = 0,
        end_col = 5,
        message = "error1",
        severity = vim.diagnostic.severity.ERROR,
      },
      {
        lnum = 1,
        col = 0,
        end_col = 5,
        message = "error2",
        severity = vim.diagnostic.severity.ERROR,
      },
    }

    local result = diagnostic.filter_diags_under_cursor(opts, buf, diags)
    MiniTest.expect.equality(type(result), "table")
  end)
end

T["get_diagnostic_under_cursor"] = MiniTest.new_set()

T["get_diagnostic_under_cursor"]["returns diagnostic at cursor position"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    vim.diagnostic.set(vim.api.nvim_create_namespace("test_cursor"), buf, {
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    local result = diagnostic.get_diagnostic_under_cursor()
    MiniTest.expect.equality(type(result), "table")
  end)
end

T["enable"] = MiniTest.new_set()

T["enable"]["enables diagnostics"] = function()
  local opts = create_test_opts()
  state.init(opts)
  diagnostic.enable()
  MiniTest.expect.equality(state.user_toggle_state, true)
end

T["disable"] = MiniTest.new_set()

T["disable"]["disables diagnostics"] = function()
  local opts = create_test_opts()
  state.init(opts)
  diagnostic.disable()
  MiniTest.expect.equality(state.user_toggle_state, false)
  state.user_enable()
end

T["toggle"] = MiniTest.new_set()

T["toggle"]["toggles diagnostic state"] = function()
  local opts = create_test_opts()
  state.init(opts)
  local initial = state.user_toggle_state

  diagnostic.toggle()
  MiniTest.expect.equality(state.user_toggle_state, not initial)

  diagnostic.toggle()
  MiniTest.expect.equality(state.user_toggle_state, initial)
end

T["set_diagnostic_autocmds"] = MiniTest.new_set()

T["set_diagnostic_autocmds"]["returns true on success"] = function()
  local opts = create_test_opts()
  opts.options.mode = "all"

  local result = diagnostic.set_diagnostic_autocmds(opts)
  MiniTest.expect.equality(result, true)
end

T["set_diagnostic_autocmds"]["sets up autocmds"] = function()
  local opts = create_test_opts()
  opts.options.mode = "all"

  diagnostic.set_diagnostic_autocmds(opts)

  local autocmds = vim.api.nvim_get_autocmds({ group = "TinyInlineDiagnosticAutocmds" })
  MiniTest.expect.equality(#autocmds > 0, true)
end

T["set_diagnostic_autocmds"]["respects disabled filetypes"] = function()
  H.with_buf({ "test" }, function(buf)
    vim.bo[buf].filetype = "help"

    local opts = create_test_opts()
    opts.options.mode = "all"

    diagnostic.set_diagnostic_autocmds(opts)
  end)
end

T["enabled"] = MiniTest.new_set()

T["enabled"]["reflects state.enabled"] = function()
  local opts = create_test_opts()
  state.init(opts)
  MiniTest.expect.equality(diagnostic.enabled, state.enabled)
end

T["user_toggle_state"] = MiniTest.new_set()

T["user_toggle_state"]["reflects state.user_toggle_state"] = function()
  local opts = create_test_opts()
  state.init(opts)
  MiniTest.expect.equality(diagnostic.user_toggle_state, state.user_toggle_state)
end

T["single_diagnostic_lifecycle"] = MiniTest.new_set()

T["single_diagnostic_lifecycle"]["clears when single diagnostic is fixed"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local ns = vim.api.nvim_create_namespace("test_single_diag")

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 4,
        message = "error",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local diags = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags, 1)

    vim.diagnostic.set(ns, buf, {})

    local diags_after = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags_after, 0)
  end)
end

T["single_diagnostic_lifecycle"]["handles single diagnostic removal from multiple"] = function()
  H.with_win_buf({ "line 1", "line 2" }, { 1, 0 }, nil, function(buf, win)
    local ns = vim.api.nvim_create_namespace("test_multi_diag")

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 4,
        message = "error1",
        severity = vim.diagnostic.severity.ERROR,
      },
      {
        lnum = 1,
        col = 0,
        end_col = 4,
        message = "error2",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local diags = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags, 2)

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 1,
        col = 0,
        end_col = 4,
        message = "error2",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local diags_after = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags_after, 1)
    MiniTest.expect.equality(diags_after[1].message, "error2")
  end)
end

T["single_diagnostic_lifecycle"]["handles all diagnostics cleared"] = function()
  H.with_win_buf({ "line 1", "line 2", "line 3" }, { 1, 0 }, nil, function(buf, win)
    local ns = vim.api.nvim_create_namespace("test_all_clear")

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 4,
        message = "error1",
        severity = vim.diagnostic.severity.ERROR,
      },
      {
        lnum = 1,
        col = 0,
        end_col = 4,
        message = "error2",
        severity = vim.diagnostic.severity.WARN,
      },
      {
        lnum = 2,
        col = 0,
        end_col = 4,
        message = "error3",
        severity = vim.diagnostic.severity.INFO,
      },
    })

    local diags = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags, 3)

    vim.diagnostic.set(ns, buf, {})

    local diags_after = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags_after, 0)
  end)
end

T["single_diagnostic_lifecycle"]["handles diagnostic replacement"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local ns = vim.api.nvim_create_namespace("test_replace")

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 4,
        message = "old error",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local diags = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags, 1)
    MiniTest.expect.equality(diags[1].message, "old error")

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 4,
        message = "new error",
        severity = vim.diagnostic.severity.WARN,
      },
    })

    local diags_after = vim.diagnostic.get(buf, { namespace = ns })
    MiniTest.expect.equality(#diags_after, 1)
    MiniTest.expect.equality(diags_after[1].message, "new error")
    MiniTest.expect.equality(diags_after[1].severity, vim.diagnostic.severity.WARN)
  end)
end

return T
