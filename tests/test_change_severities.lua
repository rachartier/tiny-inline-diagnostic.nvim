local H = require("tests.helpers")

local T = MiniTest.new_set()

local cache = require("tiny-inline-diagnostic.cache")
local filter = require("tiny-inline-diagnostic.filter")

T["filter.by_severity"] = MiniTest.new_set()

T["filter.by_severity"]["filters diagnostics by severity"] = function()
  local opts = H.make_opts()
  opts.options.severity = { vim.diagnostic.severity.ERROR }

  local diags = {
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.HINT }),
  }

  local filtered = filter.by_severity(opts, diags)

  MiniTest.expect.equality(#filtered, 1)
  MiniTest.expect.equality(filtered[1].severity, vim.diagnostic.severity.ERROR)
end

T["filter.by_severity"]["allows multiple severities"] = function()
  local opts = H.make_opts()
  opts.options.severity = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN }

  local diags = {
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.HINT }),
  }

  local filtered = filter.by_severity(opts, diags)

  MiniTest.expect.equality(#filtered, 2)
end

T["filter.by_severity"]["handles empty diagnostics"] = function()
  local opts = H.make_opts()
  local filtered = filter.by_severity(opts, {})
  MiniTest.expect.equality(#filtered, 0)
end

T["cache.update"] = MiniTest.new_set()

T["cache.update"]["stores all diagnostics without severity filtering"] = function()
  local opts = H.make_opts()
  opts.options.severity = { vim.diagnostic.severity.ERROR }

  local buf = H.make_buf({ "line1" })

  local diags = {
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.HINT }),
  }

  cache.update(opts, buf, diags)

  local cached = cache.get(buf)
  MiniTest.expect.equality(#cached, 3)

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["filter.for_display"] = MiniTest.new_set()

T["filter.for_display"]["applies severity filter"] = function()
  local opts = H.make_opts()
  opts.options.severity = { vim.diagnostic.severity.WARN }
  opts.options.multilines.enabled = true
  opts.options.multilines.always_show = true
  opts.options.multilines.severity = { vim.diagnostic.severity.ERROR }

  local buf = H.make_buf({ "line1" })

  local diags = {
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.HINT }),
  }

  local filtered = filter.for_display(opts, buf, diags)

  MiniTest.expect.equality(#filtered, 1)
  MiniTest.expect.equality(filtered[1].severity, vim.diagnostic.severity.ERROR)

  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
