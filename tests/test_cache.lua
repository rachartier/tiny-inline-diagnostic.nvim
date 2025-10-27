local H = require("tests.helpers")
local MiniTest = require("mini.test")
local cache = require("tiny-inline-diagnostic.cache")

local T = MiniTest.new_set()

local function create_test_opts()
  return H.make_opts({
    options = {
      severity = {
        vim.diagnostic.severity.ERROR,
        vim.diagnostic.severity.WARN,
        vim.diagnostic.severity.INFO,
        vim.diagnostic.severity.HINT,
      },
    },
  })
end

T["get"] = MiniTest.new_set()

T["get"]["returns empty table for buffer without diagnostics"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  local result = cache.get(buf)
  MiniTest.expect.equality(result, {})
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["get"]["returns cached diagnostics for buffer"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local diags = H.make_diags({
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    cache.update(opts, buf, diags)
    local result = cache.get(buf)

    MiniTest.expect.equality(#result, 1)
    MiniTest.expect.equality(result[1].message, "error")
  end)
end

T["update"] = MiniTest.new_set()

T["update"]["stores diagnostics in cache"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local diags = H.make_diags({
      { lnum = 0, col = 0, message = "test error", severity = vim.diagnostic.severity.ERROR },
    })

    cache.update(opts, buf, diags)
    local cached = cache.get(buf)

    MiniTest.expect.equality(#cached, 1)
    MiniTest.expect.equality(cached[1].message, "test error")
  end)
end

T["update"]["sorts diagnostics by severity"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local diags = H.make_diags({
      { lnum = 0, col = 0, message = "warn", severity = vim.diagnostic.severity.WARN },
      { lnum = 0, col = 5, message = "error", severity = vim.diagnostic.severity.ERROR },
      { lnum = 0, col = 10, message = "info", severity = vim.diagnostic.severity.INFO },
    })

    cache.update(opts, buf, diags)
    local cached = cache.get(buf)

    MiniTest.expect.equality(#cached, 3)
    MiniTest.expect.equality(cached[1].severity, vim.diagnostic.severity.ERROR)
    MiniTest.expect.equality(cached[2].severity, vim.diagnostic.severity.WARN)
    MiniTest.expect.equality(cached[3].severity, vim.diagnostic.severity.INFO)
  end)
end

T["update"]["clears cache when diagnostics are empty"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()

    local diags = H.make_diags({
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })
    cache.update(opts, buf, diags)

    local cached_before = cache.get(buf)
    MiniTest.expect.equality(#cached_before, 1)

    cache.update(opts, buf, {})

    local cached_after = cache.get(buf)
    MiniTest.expect.equality(cached_after, {})
  end)
end

T["update"]["clears cache when nil diagnostics and buffer has none"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()

    local diags = H.make_diags({
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })
    cache.update(opts, buf, diags)

    local cached_before = cache.get(buf)
    MiniTest.expect.equality(#cached_before, 1)

    cache.update(opts, buf, nil)

    local cached_after = cache.get(buf)
    MiniTest.expect.equality(cached_after, {})
  end)
end

T["update"]["handles namespace filtering"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local ns1 = vim.api.nvim_create_namespace("test_ns1")
    local ns2 = vim.api.nvim_create_namespace("test_ns2")

    vim.diagnostic.set(ns1, buf, {
      { lnum = 0, col = 0, message = "error1", severity = vim.diagnostic.severity.ERROR },
    })

    local diags_ns1 = vim.diagnostic.get(buf, { namespace = ns1 })
    cache.update(opts, buf, diags_ns1)

    vim.diagnostic.set(ns2, buf, {
      { lnum = 0, col = 0, message = "error2", severity = vim.diagnostic.severity.WARN },
    })

    local diags_ns2 = vim.diagnostic.get(buf, { namespace = ns2 })
    cache.update(opts, buf, diags_ns2)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 2)
  end)
end

T["update"]["replaces diagnostics from same namespace"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local ns = vim.api.nvim_create_namespace("test_replace_ns")

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "old error", severity = vim.diagnostic.severity.ERROR },
    })

    local diags_old = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags_old)

    local cached_old = cache.get(buf)
    MiniTest.expect.equality(#cached_old, 1)
    MiniTest.expect.equality(cached_old[1].message, "old error")

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "new error", severity = vim.diagnostic.severity.WARN },
    })

    local diags_new = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags_new)

    local cached_new = cache.get(buf)
    MiniTest.expect.equality(#cached_new, 1)
    MiniTest.expect.equality(cached_new[1].message, "new error")
  end)
end

T["clear"] = MiniTest.new_set()

T["clear"]["removes diagnostics from cache"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local diags = H.make_diags({
      { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
    })

    cache.update(opts, buf, diags)
    local cached_before = cache.get(buf)
    MiniTest.expect.equality(#cached_before, 1)

    cache.clear(buf)
    local cached_after = cache.get(buf)
    MiniTest.expect.equality(cached_after, {})
  end)
end

T["clear"]["handles clearing non-existent buffer"] = function()
  cache.clear(999999)
end

T["single_diagnostic_persistence_bug"] = MiniTest.new_set()

T["single_diagnostic_persistence_bug"]["does not persist single diagnostic after fix"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = create_test_opts()
    local ns = vim.api.nvim_create_namespace("test_persist_bug")

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
    cache.update(opts, buf, diags)

    local cached_with_diag = cache.get(buf)
    MiniTest.expect.equality(#cached_with_diag, 1)

    vim.diagnostic.set(ns, buf, {})

    local diags_after_fix = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags_after_fix)

    local cached_after_fix = cache.get(buf)
    MiniTest.expect.equality(cached_after_fix, {})
  end)
end

T["single_diagnostic_persistence_bug"]["handles partial diagnostic removal"] = function()
  H.with_buf({ "line 1", "line 2", "line 3" }, function(buf)
    local opts = create_test_opts()
    local ns = vim.api.nvim_create_namespace("test_partial_removal")

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "error1", severity = vim.diagnostic.severity.ERROR },
      { lnum = 1, col = 0, message = "error2", severity = vim.diagnostic.severity.ERROR },
      { lnum = 2, col = 0, message = "error3", severity = vim.diagnostic.severity.ERROR },
    })

    local diags = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags)
    MiniTest.expect.equality(#cache.get(buf), 3)

    vim.diagnostic.set(ns, buf, {
      { lnum = 1, col = 0, message = "error2", severity = vim.diagnostic.severity.ERROR },
    })

    local diags_after = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags_after)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 1)
    MiniTest.expect.equality(cached[1].message, "error2")
    MiniTest.expect.equality(cached[1].lnum, 1)
  end)
end

T["single_diagnostic_persistence_bug"]["handles empty to non-empty transition"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = create_test_opts()
    local ns = vim.api.nvim_create_namespace("test_transition")

    cache.update(opts, buf, {})
    MiniTest.expect.equality(cache.get(buf), {})

    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, message = "new error", severity = vim.diagnostic.severity.ERROR },
    })

    local diags = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags)

    local cached = cache.get(buf)
    MiniTest.expect.equality(#cached, 1)
    MiniTest.expect.equality(cached[1].message, "new error")

    vim.diagnostic.set(ns, buf, {})
    local diags_cleared = vim.diagnostic.get(buf, { namespace = ns })
    cache.update(opts, buf, diags_cleared)

    MiniTest.expect.equality(cache.get(buf), {})
  end)
end

return T
