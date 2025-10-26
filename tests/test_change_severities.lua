local H = require("tests.helpers")

local T = MiniTest.new_set()

local cache = require("tiny-inline-diagnostic.cache")

T["refilter_all"] = MiniTest.new_set()

T["refilter_all"]["filters cached diagnostics by new severity"] = function()
  local opts = H.make_opts()

  local buf1 = H.make_buf({ "line1", "line2" })
  local buf2 = H.make_buf({ "line1", "line2" })

  local diags1 = {
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.HINT }),
  }
  local diags2 = {
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 0, severity = vim.diagnostic.severity.INFO }),
  }

  cache.update(opts, buf1, diags1)
  cache.update(opts, buf2, diags2)

  local cached1 = cache.get(buf1)
  local cached2 = cache.get(buf2)
  MiniTest.expect.equality(#cached1, 3)
  MiniTest.expect.equality(#cached2, 2)

  opts.options.severity = { vim.diagnostic.severity.ERROR }
  cache.refilter_all(opts)

  cached1 = cache.get(buf1)
  cached2 = cache.get(buf2)

  MiniTest.expect.equality(#cached1, 1)
  MiniTest.expect.equality(cached1[1].severity, vim.diagnostic.severity.ERROR)
  MiniTest.expect.equality(#cached2, 1)
  MiniTest.expect.equality(cached2[1].severity, vim.diagnostic.severity.ERROR)

  vim.api.nvim_buf_delete(buf1, { force = true })
  vim.api.nvim_buf_delete(buf2, { force = true })
end

T["refilter_all"]["expands severity filter"] = function()
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
  MiniTest.expect.equality(#cached, 1)

  opts.options.severity = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN }
  cache.refilter_all(opts)

  cached = cache.get(buf)

  MiniTest.expect.equality(#cached, 1)

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["refilter_all"]["handles empty cache"] = function()
  local opts = H.make_opts()

  cache.refilter_all(opts)

  MiniTest.expect.no_error(function()
    cache.refilter_all(opts)
  end)
end

return T
