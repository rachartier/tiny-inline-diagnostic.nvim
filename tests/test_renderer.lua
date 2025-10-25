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
    cache.update(opts, buf, vim.diagnostic.get(buf))

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
    cache.update(opts, buf, vim.diagnostic.get(buf))

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
    cache.update(opts, buf, vim.diagnostic.get(buf))

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
    cache.update(opts, buf, vim.diagnostic.get(buf))

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

return T
