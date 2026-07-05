local H = require("tests.helpers")
local MiniTest = require("mini.test")
local autocmds = require("tiny-inline-diagnostic.autocmds")

local T = MiniTest.new_set()

local function noop() end

local function make_buf_opts()
  return H.make_opts({
    options = {
      enable_on_insert = false,
      experimental = { use_window_local_extmarks = false },
    },
  })
end

local function count_buffer_autocmds(augroup, bufnr)
  return #vim.api.nvim_get_autocmds({ group = augroup, buffer = bufnr })
end

local function count_event_autocmds(augroup, event)
  return #vim.api.nvim_get_autocmds({ group = augroup, event = event })
end

T["detach"] = MiniTest.new_set()

T["detach"]["clears buffer-scoped autocmds"] = function()
  H.with_buf({ "line" }, function(buf)
    local augroup = autocmds.create_augroup()
    autocmds.setup_buffer_autocmds(augroup, make_buf_opts(), buf, noop, noop, noop)
    autocmds.setup_cursor_autocmds(augroup, make_buf_opts(), buf, noop, noop)
    autocmds.setup_mode_change_autocmds(augroup, buf, noop)

    MiniTest.expect.equality(count_buffer_autocmds(augroup, buf) > 0, true)
    MiniTest.expect.equality(autocmds.is_attached(buf), true)

    autocmds.detach(buf)

    MiniTest.expect.equality(count_buffer_autocmds(augroup, buf), 0)
    MiniTest.expect.equality(autocmds.is_attached(buf), false)
  end)
end

T["detach"]["invokes cleanup_callback with bufnr"] = function()
  H.with_buf({ "line" }, function(buf)
    autocmds.create_augroup()

    local received
    autocmds.detach(buf, function(b)
      received = b
    end)

    MiniTest.expect.equality(received, buf)
  end)
end

T["setup_buffer_autocmds"] = MiniTest.new_set()

T["setup_buffer_autocmds"]["re-attach after detach does not duplicate autocmds"] = function()
  H.with_buf({ "line" }, function(buf)
    local augroup = autocmds.create_augroup()
    local opts = make_buf_opts()

    autocmds.setup_buffer_autocmds(augroup, opts, buf, noop, noop, noop)
    autocmds.setup_cursor_autocmds(augroup, opts, buf, noop, noop)
    autocmds.setup_mode_change_autocmds(augroup, buf, noop)
    local first_count = count_buffer_autocmds(augroup, buf)

    autocmds.detach(buf)
    MiniTest.expect.equality(count_buffer_autocmds(augroup, buf), 0)

    autocmds.setup_buffer_autocmds(augroup, opts, buf, noop, noop, noop)
    autocmds.setup_cursor_autocmds(augroup, opts, buf, noop, noop)
    autocmds.setup_mode_change_autocmds(augroup, buf, noop)
    local second_count = count_buffer_autocmds(augroup, buf)

    MiniTest.expect.equality(second_count, first_count)
  end)
end

T["setup_buffer_autocmds"]["guards against double setup without detach"] = function()
  H.with_buf({ "line" }, function(buf)
    local augroup = autocmds.create_augroup()
    local opts = make_buf_opts()

    autocmds.setup_buffer_autocmds(augroup, opts, buf, noop, noop, noop)
    local first_count = count_buffer_autocmds(augroup, buf)

    autocmds.setup_buffer_autocmds(augroup, opts, buf, noop, noop, noop)
    local second_count = count_buffer_autocmds(augroup, buf)

    MiniTest.expect.equality(second_count, first_count)
  end)
end

T["setup_buffer_autocmds"]["multiple attach/detach cycles do not leak autocmds"] = function()
  H.with_buf({ "line" }, function(buf)
    local augroup = autocmds.create_augroup()
    local opts = make_buf_opts()

    autocmds.setup_buffer_autocmds(augroup, opts, buf, noop, noop, noop)
    autocmds.setup_cursor_autocmds(augroup, opts, buf, noop, noop)
    autocmds.setup_mode_change_autocmds(augroup, buf, noop)
    local baseline = count_buffer_autocmds(augroup, buf)

    for _ = 1, 5 do
      autocmds.detach(buf)
      autocmds.setup_buffer_autocmds(augroup, opts, buf, noop, noop, noop)
      autocmds.setup_cursor_autocmds(augroup, opts, buf, noop, noop)
      autocmds.setup_mode_change_autocmds(augroup, buf, noop)
    end

    MiniTest.expect.equality(count_buffer_autocmds(augroup, buf), baseline)
  end)
end

T["setup_global_autocmds"] = MiniTest.new_set()

T["setup_global_autocmds"]["creates one resize autocmd regardless of attached buffers"] = function()
  local augroup = autocmds.create_augroup()
  local opts = make_buf_opts()

  autocmds.setup_global_autocmds(augroup, opts, noop, noop)

  local resize_count = count_event_autocmds(augroup, "VimResized")
    + count_event_autocmds(augroup, "WinResized")

  H.with_buf({ "a" }, function(buf_a)
    autocmds.setup_buffer_autocmds(augroup, opts, buf_a, noop, noop, noop)
    H.with_buf({ "b" }, function(buf_b)
      autocmds.setup_buffer_autocmds(augroup, opts, buf_b, noop, noop, noop)

      local after = count_event_autocmds(augroup, "VimResized")
        + count_event_autocmds(augroup, "WinResized")
      MiniTest.expect.equality(after, resize_count)
    end)
  end)
end

T["setup_global_autocmds"]["creates WinEnter only when experimental flag is set"] = function()
  local augroup_off = autocmds.create_augroup()
  autocmds.setup_global_autocmds(augroup_off, make_buf_opts(), noop, noop)
  MiniTest.expect.equality(count_event_autocmds(augroup_off, "WinEnter"), 0)

  local augroup_on = autocmds.create_augroup()
  local opts_on = H.make_opts({
    options = { experimental = { use_window_local_extmarks = true } },
  })
  autocmds.setup_global_autocmds(augroup_on, opts_on, noop, noop)
  MiniTest.expect.equality(count_event_autocmds(augroup_on, "WinEnter") >= 1, true)
end

T["create_augroup"] = MiniTest.new_set()

T["create_augroup"]["resets attached buffer tracking"] = function()
  H.with_buf({ "line" }, function(buf)
    local augroup = autocmds.create_augroup()
    autocmds.setup_buffer_autocmds(augroup, make_buf_opts(), buf, noop, noop, noop)
    MiniTest.expect.equality(autocmds.is_attached(buf), true)

    autocmds.create_augroup()

    MiniTest.expect.equality(autocmds.is_attached(buf), false)
  end)
end

return T
