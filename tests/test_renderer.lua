local H = require("tests.helpers")
local MiniTest = require("mini.test")
local renderer = require("tiny-inline-diagnostic.renderer")
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
    },
  })
end

T["safe_render"] = MiniTest.new_set()

T["safe_render"]["handles invalid buffer"] = function()
  local opts = create_test_opts()
  renderer.safe_render(opts, 999999)
end

T["safe_render"]["calls render for valid buffer"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = create_test_opts()
    state.init(opts)

    renderer.safe_render(opts, buf)
  end)
end

T["render"] = MiniTest.new_set()

T["render"]["clears extmarks when disabled"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = create_test_opts()
    state.init(opts)
    state.user_disable()

    renderer.render(opts, buf)

    state.user_enable()
  end)
end

T["render"]["clears extmarks when user_toggle_state is false"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = create_test_opts()
    state.init(opts)
    state.user_toggle_state = false

    renderer.render(opts, buf)

    state.user_toggle_state = true
  end)
end

T["render"]["clears extmarks when no diagnostics"] = function()
  H.with_win_buf({ "test line" }, nil, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)

    renderer.render(opts, buf)
  end)
end

T["render"]["renders diagnostics when present"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_diag"), buf, {
      {
        lnum = 0,
        col = 0,
        message = "test error",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, vim.diagnostic.get(buf))

    renderer.render(opts, buf)
  end)
end

T["render"]["handles multiline diagnostics"] = function()
  H.with_win_buf({ "line 1", "line 2", "line 3" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    opts.options.multilines = { enabled = true }
    state.init(opts)

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_diag2"), buf, {
      {
        lnum = 0,
        col = 0,
        message = "error on line 1",
        severity = vim.diagnostic.severity.ERROR,
      },
      {
        lnum = 1,
        col = 0,
        message = "error on line 2",
        severity = vim.diagnostic.severity.WARN,
      },
    })

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, vim.diagnostic.get(buf))

    renderer.render(opts, buf)
  end)
end

T["render"]["respects visible filter"] = function()
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, "line " .. i)
  end
  H.with_win_buf(lines, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_diag3"), buf, {
      {
        lnum = 0,
        col = 0,
        message = "visible error",
        severity = vim.diagnostic.severity.ERROR,
      },
      {
        lnum = 90,
        col = 0,
        message = "non-visible error",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, vim.diagnostic.get(buf))

    renderer.render(opts, buf)
  end)
end

T["render"]["handles cursor line differently"] = function()
  H.with_win_buf({ "line 1", "line 2" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)

    vim.diagnostic.set(vim.api.nvim_create_namespace("test_diag4"), buf, {
      {
        lnum = 0,
        col = 0,
        message = "error on cursor line",
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, vim.diagnostic.get(buf))

    renderer.render(opts, buf)
  end)
end

T["render"]["handles invalid window"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = create_test_opts()
    state.init(opts)

    renderer.render(opts, buf)
  end)
end

T["window_resolution"] = MiniTest.new_set()

-- Regression for #181: rendering must use the window that displays the buffer,
-- not whatever window happens to be current. Opening another window (e.g.
-- :OverseerOpen) used to reflow diagnostics to the new window's width.
T["window_resolution"]["uses buffer window geometry not current window"] = function()
  local saved_columns = vim.o.columns
  vim.o.columns = 120

  local long_message =
    "this is a fairly long diagnostic message that should wrap differently in a narrow window"

  H.with_win_buf({ "x", "line 2" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    opts.options.overflow = { mode = "wrap" }
    opts.options.softwrap = 30
    opts.options.multilines.enabled = true
    opts.options.multilines.always_show = true
    state.init(opts)

    local ns = vim.api.nvim_create_namespace("test_win_resolution")
    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        message = long_message,
        severity = vim.diagnostic.severity.ERROR,
      },
    })

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, vim.diagnostic.get(buf))

    local diag_ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
    -- Layout signature per extmark: row / virt_lines count / virt_text chunk
    -- count. Reflowing to a different width changes the row (need_to_be_under),
    -- the number of wrapped virt_lines, and/or the chunk segmentation.
    local function capture_layout()
      local marks = vim.api.nvim_buf_get_extmarks(buf, diag_ns, 0, -1, { details = true })
      local sig = {}
      for _, mark in ipairs(marks) do
        local d = mark[4] or {}
        table.insert(
          sig,
          string.format(
            "r%d/vl%d/c%d",
            mark[2],
            d.virt_lines and #d.virt_lines or 0,
            d.virt_text and #d.virt_text or 0
          )
        )
      end
      table.sort(sig)
      return sig
    end

    renderer.render(opts, buf)
    local reference = capture_layout()
    MiniTest.expect.equality(#reference > 0, true)

    -- Focus a narrow floating window onto a different buffer, leaving buf's
    -- window geometry untouched (models opening another window without
    -- resizing the diagnostic window). The pre-fix code reads the float's
    -- width; the fix reads buf's own window width.
    local other_buf = H.make_buf({ "unrelated" })
    local float_win = vim.api.nvim_open_win(other_buf, true, {
      relative = "editor",
      width = 20,
      height = 3,
      row = 1,
      col = 1,
    })

    MiniTest.expect.equality(vim.api.nvim_get_current_buf() ~= buf, true)
    MiniTest.expect.equality(
      vim.api.nvim_win_get_width(float_win) < vim.api.nvim_win_get_width(win),
      true
    )

    renderer.render(opts, buf)
    local from_other_window = capture_layout()

    MiniTest.expect.equality(from_other_window, reference)

    vim.api.nvim_win_close(float_win, true)
    vim.api.nvim_buf_delete(other_buf, { force = true })
  end)

  vim.o.columns = saved_columns
end

T["window_resolution"]["clears extmarks when buffer is in no window"] = function()
  local buf = H.make_buf({ "test line" })
  local opts = create_test_opts()
  state.init(opts)

  local ns = vim.api.nvim_create_namespace("test_hidden_buf")
  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
  })
  local cache = require("tiny-inline-diagnostic.cache")
  cache.update(buf, vim.diagnostic.get(buf))

  renderer.render(opts, buf)

  local diag_ns = vim.api.nvim_create_namespace("TinyInlineDiagnostic")
  local marks = vim.api.nvim_buf_get_extmarks(buf, diag_ns, 0, -1, {})
  MiniTest.expect.equality(#marks, 0)

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["single_diagnostic_clearing"] = MiniTest.new_set()

T["single_diagnostic_clearing"]["clears when single diagnostic is removed"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)
    local cache = require("tiny-inline-diagnostic.cache")
    local ns = vim.api.nvim_create_namespace("test_single_clear")

    vim.diagnostic.set(ns, buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 4,
        message = "error",
        severity = vim.diagnostic.severity.ERROR,
      },
    })
    cache.update(buf, vim.diagnostic.get(buf))

    renderer.render(opts, buf)

    vim.diagnostic.set(ns, buf, {})
    cache.update(buf, vim.diagnostic.get(buf))

    renderer.render(opts, buf)

    MiniTest.expect.equality(cache.get(buf), {})
  end)
end

T["single_diagnostic_clearing"]["clears when last diagnostic is removed from multiple"] = function()
  H.with_win_buf({ "line 1", "line 2" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)
    local cache = require("tiny-inline-diagnostic.cache")
    local ns = vim.api.nvim_create_namespace("test_multi_clear")

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "error1", severity = vim.diagnostic.severity.ERROR },
      { lnum = 1, col = 0, message = "error2", severity = vim.diagnostic.severity.ERROR },
    })
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)

    vim.diagnostic.set(ns, buf, {
      { lnum = 1, col = 0, message = "error2", severity = vim.diagnostic.severity.ERROR },
    })
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 1)
    MiniTest.expect.equality(cached[1].message, "error2")

    vim.diagnostic.set(ns, buf, {})
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)

    MiniTest.expect.equality(cache.get(buf), {})
  end)
end

T["single_diagnostic_clearing"]["handles rapid diagnostic changes"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)
    local cache = require("tiny-inline-diagnostic.cache")
    local ns = vim.api.nvim_create_namespace("test_rapid_changes")

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "error1", severity = vim.diagnostic.severity.ERROR },
    })
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)

    vim.diagnostic.set(ns, buf, {})
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)
    MiniTest.expect.equality(cache.get(buf), {})

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "error2", severity = vim.diagnostic.severity.WARN },
    })
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 1)
    MiniTest.expect.equality(cached[1].message, "error2")

    vim.diagnostic.set(ns, buf, {})
    cache.update(buf, vim.diagnostic.get(buf))
    renderer.render(opts, buf)
    MiniTest.expect.equality(cache.get(buf), {})
  end)
end

T["single_diagnostic_clearing"]["does not persist stale diagnostics after namespace update"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    state.init(opts)
    local cache = require("tiny-inline-diagnostic.cache")
    local ns = vim.api.nvim_create_namespace("test_namespace_update")

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "initial", severity = vim.diagnostic.severity.ERROR },
    })
    cache.update(buf, vim.diagnostic.get(buf, { namespace = ns }))
    renderer.render(opts, buf)

    local cached_initial = cache.get(buf)
    MiniTest.expect.equality(#cached_initial, 1)

    vim.diagnostic.set(ns, buf, {})
    cache.update(buf, vim.diagnostic.get(buf, { namespace = ns }))
    renderer.render(opts, buf)

    local cached_final = cache.get(buf)
    MiniTest.expect.equality(cached_final, {})
  end)
end

local function plugin_marks_on_row(buf, row)
  local ns = vim.api.nvim_get_namespaces()["TinyInlineDiagnostic"]
  return #vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, {})
end

T["render"]["multilines.severity restricts non-cursor lines"] = function()
  H.with_win_buf({ "line 1", "line 2", "line 3" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    opts.options.multilines.enabled = true
    opts.options.multilines.always_show = true
    opts.options.multilines.severity = { vim.diagnostic.severity.ERROR }
    state.init(opts)

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, {
      { lnum = 1, col = 0, end_col = 5, message = "err", severity = vim.diagnostic.severity.ERROR },
      { lnum = 2, col = 0, end_col = 5, message = "warn", severity = vim.diagnostic.severity.WARN },
    })
    renderer.render(opts, buf)

    MiniTest.expect.equality(plugin_marks_on_row(buf, 1) > 0, true)
    MiniTest.expect.equality(plugin_marks_on_row(buf, 2), 0)
  end)
end

T["render"]["show_diags_only_under_cursor takes precedence over multilines"] = function()
  H.with_win_buf({ "line 1", "line 2", "line 3" }, { 2, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    opts.options.multilines.enabled = true
    opts.options.multilines.always_show = true
    opts.options.show_diags_only_under_cursor = true
    state.init(opts)

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, {
      { lnum = 0, col = 0, end_col = 5, message = "a", severity = vim.diagnostic.severity.ERROR },
      { lnum = 1, col = 0, end_col = 5, message = "b", severity = vim.diagnostic.severity.ERROR },
      { lnum = 2, col = 0, end_col = 5, message = "c", severity = vim.diagnostic.severity.ERROR },
    })
    renderer.render(opts, buf)

    MiniTest.expect.equality(plugin_marks_on_row(buf, 1) > 0, true)
    MiniTest.expect.equality(plugin_marks_on_row(buf, 0), 0)
    MiniTest.expect.equality(plugin_marks_on_row(buf, 2), 0)
  end)
end

T["render"]["does not render diagnostics outside the visible range"] = function()
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, "line " .. i)
  end
  H.with_win_buf(lines, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    opts.options.multilines.enabled = true
    opts.options.multilines.always_show = true
    state.init(opts)

    local cache = require("tiny-inline-diagnostic.cache")
    cache.update(buf, {
      {
        lnum = 0,
        col = 0,
        end_col = 5,
        message = "near",
        severity = vim.diagnostic.severity.ERROR,
      },
      {
        lnum = 90,
        col = 0,
        end_col = 5,
        message = "far",
        severity = vim.diagnostic.severity.ERROR,
      },
    })
    renderer.render(opts, buf)

    MiniTest.expect.equality(plugin_marks_on_row(buf, 0) > 0, true)
    MiniTest.expect.equality(plugin_marks_on_row(buf, 90), 0)
  end)
end

return T
