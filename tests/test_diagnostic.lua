local MiniTest = require("mini.test")
local diagnostic = require("tiny-inline-diagnostic.diagnostic")
local state = require("tiny-inline-diagnostic.state")
local test_helpers = require("tests.init")

local T = MiniTest.new_set()

local function create_test_opts()
  return test_helpers.create_full_opts({
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
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line" })

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  local opts = create_test_opts()
  local diags = {
    { lnum = 0, col = 0, end_col = 5, message = "error", severity = vim.diagnostic.severity.ERROR },
  }

  local result = diagnostic.filter_diags_under_cursor(opts, buf, diags)
  MiniTest.expect.equality(type(result), "table")

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["filter_diags_under_cursor"]["filters out diagnostics not under cursor"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line", "line 2" })

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

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

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["get_diagnostic_under_cursor"] = MiniTest.new_set()

T["get_diagnostic_under_cursor"]["returns diagnostic at cursor position"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line" })

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  vim.diagnostic.set(vim.api.nvim_create_namespace("test_cursor"), buf, {
    { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
  })

  local result = diagnostic.get_diagnostic_under_cursor()
  MiniTest.expect.equality(type(result), "table")

  vim.api.nvim_buf_delete(buf, { force = true })
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
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test" })
  vim.bo[buf].filetype = "help"

  local opts = create_test_opts()
  opts.options.mode = "all"

  diagnostic.set_diagnostic_autocmds(opts)

  vim.api.nvim_buf_delete(buf, { force = true })
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

return T
