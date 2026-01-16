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
      show_code = false,
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

T["enable"]["re-renders diagnostics in all buffers"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    tiny.setup(create_test_opts())

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_enable"), buf, {
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    diagnostic.disable()
    vim.wait(100)

    local ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
    local extmarks_disabled = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#extmarks_disabled, 0)

    diagnostic.enable()
    vim.wait(100)

    local extmarks_enabled = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#extmarks_enabled > 0, true)
  end)
end

T["disable"] = MiniTest.new_set()

T["disable"]["disables diagnostics"] = function()
  local opts = create_test_opts()
  state.init(opts)
  diagnostic.disable()
  MiniTest.expect.equality(state.user_toggle_state, false)
  state.user_enable()
end

T["disable"]["clears all extmarks from all buffers"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    tiny.setup(create_test_opts())

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_disable"), buf, {
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    diagnostic.enable()
    vim.wait(100)

    local ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
    local extmarks_before = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})

    diagnostic.disable()
    vim.wait(100)

    local extmarks_after = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#extmarks_after, 0)
  end)
end

T["toggle"] = MiniTest.new_set()

T["toggle"]["toggles diagnostic state"] = function()
  local opts = create_test_opts()
  state.init(opts)
  state.user_enable()
  local initial = state.user_toggle_state

  diagnostic.toggle()
  MiniTest.expect.equality(state.user_toggle_state, not initial)

  diagnostic.toggle()
  MiniTest.expect.equality(state.user_toggle_state, initial)
end

T["toggle"]["clears extmarks when toggled off"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    tiny.setup(create_test_opts())

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_toggle_off"), buf, {
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    diagnostic.enable()
    vim.wait(100)

    diagnostic.toggle()
    vim.wait(100)

    local ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
    local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#extmarks, 0)
  end)
end

T["toggle"]["renders extmarks when toggled on"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    tiny.setup(create_test_opts())

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_toggle_on"), buf, {
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    diagnostic.disable()
    vim.wait(100)

    diagnostic.toggle()
    vim.wait(100)

    local ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
    local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#extmarks > 0, true)
  end)
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
  state.user_enable()
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

T["multiple_lsp_diagnostics"] = MiniTest.new_set()

T["multiple_lsp_diagnostics"]["DiagnosticChanged preserves diagnostics from all namespaces"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    local cache = require("tiny-inline-diagnostic.cache")
    tiny.setup(create_test_opts())

    local ns1 = vim.api.nvim_create_namespace("lsp1")
    local ns2 = vim.api.nvim_create_namespace("lsp2")

    vim.diagnostic.set(ns1, buf, {
      { lnum = 0, col = 0, message = "error from lsp1", severity = vim.diagnostic.severity.ERROR },
    })

    vim.wait(100)

    vim.diagnostic.set(ns2, buf, {
      { lnum = 0, col = 5, message = "warn from lsp2", severity = vim.diagnostic.severity.WARN },
    })

    vim.wait(100)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 2)

    local messages = { cached[1].message, cached[2].message }
    table.sort(messages)
    MiniTest.expect.equality(messages[1], "error from lsp1")
    MiniTest.expect.equality(messages[2], "warn from lsp2")
  end)
end

T["multiple_lsp_diagnostics"]["updates from one LSP do not erase diagnostics from other LSPs"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    local cache = require("tiny-inline-diagnostic.cache")
    tiny.setup(create_test_opts())

    local ns1 = vim.api.nvim_create_namespace("lsp_a")
    local ns2 = vim.api.nvim_create_namespace("lsp_b")

    vim.diagnostic.set(ns1, buf, {
      { lnum = 0, col = 0, message = "first lsp error", severity = vim.diagnostic.severity.ERROR },
    })

    vim.wait(100)

    vim.diagnostic.set(ns2, buf, {
      { lnum = 0, col = 5, message = "second lsp error", severity = vim.diagnostic.severity.ERROR },
    })

    vim.wait(100)

    local cached_before = cache.get(buf)
    MiniTest.expect.equality(#cached_before, 2)

    vim.diagnostic.set(ns1, buf, {
      {
        lnum = 0,
        col = 0,
        message = "updated first lsp error",
        severity = vim.diagnostic.severity.WARN,
      },
    })

    vim.wait(100)

    local cached_after = cache.get(buf)
    MiniTest.expect.equality(#cached_after, 2)

    local has_first_lsp = false
    local has_second_lsp = false
    for _, diag in ipairs(cached_after) do
      if diag.message == "updated first lsp error" then
        has_first_lsp = true
      end
      if diag.message == "second lsp error" then
        has_second_lsp = true
      end
    end

    MiniTest.expect.equality(has_first_lsp, true)
    MiniTest.expect.equality(has_second_lsp, true)
  end)
end

T["multiple_lsp_diagnostics"]["clearing one LSP namespace preserves others"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    local cache = require("tiny-inline-diagnostic.cache")
    tiny.setup(create_test_opts())

    local ns1 = vim.api.nvim_create_namespace("lsp_x")
    local ns2 = vim.api.nvim_create_namespace("lsp_y")
    local ns3 = vim.api.nvim_create_namespace("lsp_z")

    vim.diagnostic.set(ns1, buf, {
      { lnum = 0, col = 0, message = "lsp x error", severity = vim.diagnostic.severity.ERROR },
    })

    vim.diagnostic.set(ns2, buf, {
      { lnum = 0, col = 5, message = "lsp y error", severity = vim.diagnostic.severity.WARN },
    })

    vim.diagnostic.set(ns3, buf, {
      { lnum = 0, col = 10, message = "lsp z error", severity = vim.diagnostic.severity.INFO },
    })

    vim.wait(100)

    local cached_all = cache.get(buf)
    MiniTest.expect.equality(#cached_all, 3)

    vim.diagnostic.set(ns2, buf, {})

    vim.wait(100)

    local cached_after_clear = cache.get(buf)
    MiniTest.expect.equality(#cached_after_clear, 2)

    local has_ns1 = false
    local has_ns2 = false
    local has_ns3 = false
    for _, diag in ipairs(cached_after_clear) do
      if diag.message == "lsp x error" then
        has_ns1 = true
      end
      if diag.message == "lsp y error" then
        has_ns2 = true
      end
      if diag.message == "lsp z error" then
        has_ns3 = true
      end
    end

    MiniTest.expect.equality(has_ns1, true)
    MiniTest.expect.equality(has_ns2, false)
    MiniTest.expect.equality(has_ns3, true)
  end)
end

T["multiple_lsp_diagnostics"]["rapid DiagnosticChanged events preserve all diagnostics"] = function()
  H.with_win_buf({ "test line", "line 2", "line 3" }, { 1, 0 }, nil, function(buf, win)
    local tiny = require("tiny-inline-diagnostic")
    local cache = require("tiny-inline-diagnostic.cache")
    tiny.setup(create_test_opts())

    local namespaces = {}
    for i = 1, 5 do
      namespaces[i] = vim.api.nvim_create_namespace("rapid_lsp_" .. i)
    end

    for i, ns in ipairs(namespaces) do
      vim.diagnostic.set(ns, buf, {
        {
          lnum = (i - 1) % 3,
          col = 0,
          message = "diagnostic from lsp " .. i,
          severity = vim.diagnostic.severity.ERROR,
        },
      })
    end

    vim.wait(150)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 5)

    for i = 1, 5 do
      local found = false
      for _, diag in ipairs(cached) do
        if diag.message == "diagnostic from lsp " .. i then
          found = true
          break
        end
      end
      MiniTest.expect.equality(found, true)
    end
  end)
end

return T
