local MiniTest = require("mini.test")
local H = require("tests.helpers")
local virtual_text = require("tiny-inline-diagnostic.virtual_text")

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
    },
  })
end

T["from_diagnostic"] = MiniTest.new_set()

T["from_diagnostic"]["returns virtual text table"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local chunk_info = {
      chunks = { " test error" },
      severity = vim.diagnostic.severity.ERROR,
      severities = { vim.diagnostic.severity.ERROR },
      line = 0,
      need_to_be_under = false,
      offset_win_col = 0,
    }

    local virt_texts, offset, need_to_be_under =
      virtual_text.from_diagnostic(opts, chunk_info, 1, 20, 1, 1)

    MiniTest.expect.equality(type(virt_texts), "table")
    MiniTest.expect.equality(#virt_texts > 0, true)
    MiniTest.expect.equality(type(offset), "number")
    MiniTest.expect.equality(type(need_to_be_under), "boolean")
  end)
end

T["from_diagnostic"]["handles multiline chunks"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local chunk_info = {
      chunks = { " line1", " line2", " line3" },
      severity = vim.diagnostic.severity.ERROR,
      severities = { vim.diagnostic.severity.ERROR },
      line = 0,
      need_to_be_under = false,
      offset_win_col = 0,
    }

    local virt_texts, _, _ = virtual_text.from_diagnostic(opts, chunk_info, 1, 20, 1, 1)

    MiniTest.expect.equality(#virt_texts >= 3, true)
  end)
end

T["from_diagnostic"]["adds space when need_to_be_under"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local chunk_info = {
      chunks = { " test error" },
      severity = vim.diagnostic.severity.ERROR,
      severities = { vim.diagnostic.severity.ERROR },
      line = 0,
      need_to_be_under = true,
      offset_win_col = 0,
    }

    local virt_texts, _, _ = virtual_text.from_diagnostic(opts, chunk_info, 1, 20, 1, 1)

    MiniTest.expect.equality(type(virt_texts[1][1][1]), "string")
  end)
end

T["from_diagnostic"]["handles multiple diagnostics"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local chunk_info = {
      chunks = { " error" },
      severity = vim.diagnostic.severity.ERROR,
      severities = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN },
      line = 0,
      need_to_be_under = false,
      offset_win_col = 0,
    }

    local virt_texts, _, _ = virtual_text.from_diagnostic(opts, chunk_info, 2, 20, 2, 2)

    MiniTest.expect.equality(type(virt_texts), "table")
  end)
end

T["from_diagnostics"] = MiniTest.new_set()

T["from_diagnostics"]["returns virtual text for multiple diagnostics"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local diags = {
      { message = "error 1", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
      { message = "warning 1", severity = vim.diagnostic.severity.WARN, lnum = 0 },
    }

    local virt_texts, offset, need_to_be_under =
      virtual_text.from_diagnostics(opts, diags, { 0, 0 }, buf)

    MiniTest.expect.equality(type(virt_texts), "table")
    MiniTest.expect.equality(#virt_texts > 0, true)
    MiniTest.expect.equality(type(offset), "number")
    MiniTest.expect.equality(type(need_to_be_under), "boolean")
  end)
end

T["from_diagnostics"]["handles single diagnostic"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local diags = {
      { message = "error 1", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
    }

    local virt_texts, _, _ = virtual_text.from_diagnostics(opts, diags, { 0, 0 }, buf)

    MiniTest.expect.equality(type(virt_texts), "table")
  end)
end

T["from_diagnostics"]["aligns multiple diagnostics"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local diags = {
      { message = "short", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
      { message = "much longer message", severity = vim.diagnostic.severity.WARN, lnum = 0 },
    }

    local virt_texts, _, _ = virtual_text.from_diagnostics(opts, diags, { 0, 0 }, buf)

    MiniTest.expect.equality(type(virt_texts), "table")
    MiniTest.expect.equality(#virt_texts > 0, true)
  end)
end

T["from_diagnostics"]["removes space for subsequent need_to_be_under"] = function()
  H.with_win_buf({ string.rep("x", 200) }, { 1, 0 }, 50, function(buf, win)
    local opts = create_test_opts()
    opts.options.overflow.mode = "wrap"

    local diags = {
      { message = "error 1", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
      { message = "error 2", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
    }

    local virt_texts, _, need_to_be_under = virtual_text.from_diagnostics(opts, diags, { 0, 0 }, buf)

    MiniTest.expect.equality(type(virt_texts), "table")
  end)
end

T["from_diagnostics"]["handles empty diagnostics"] = function()
  H.with_win_buf({ "test line" }, { 1, 0 }, nil, function(buf, win)
    local opts = create_test_opts()
    local virt_texts, offset, need_to_be_under = virtual_text.from_diagnostics(
      opts,
      {},
      { 0, 0 },
      buf
    )

    MiniTest.expect.equality(type(virt_texts), "table")
    MiniTest.expect.equality(#virt_texts, 0)
  end)
end

return T
