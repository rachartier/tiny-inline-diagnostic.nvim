local H = require("tests.helpers")
local MiniTest = require("mini.test")
local filter = require("tiny-inline-diagnostic.filter")

local T = MiniTest.new_set()

T["at_position"] = MiniTest.new_set()

T["at_position"]["returns empty for no diagnostics"] = function()
  local result = filter.at_position({ options = {} }, {}, 0, 0)
  MiniTest.expect.equality(result, {})
end

T["at_position"]["returns diagnostics on line"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
    H.make_diagnostic({ lnum = 5, col = 30, end_col = 40 }),
    H.make_diagnostic({ lnum = 10, col = 0, end_col = 5 }),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 15)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].col, 10)
end

T["at_position"]["returns all diagnostics on line when show_all_diags_on_cursorline enabled"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
    H.make_diagnostic({ lnum = 5, col = 30, end_col = 40 }),
    H.make_diagnostic({ lnum = 10, col = 0, end_col = 5 }),
  }

  local result =
    filter.at_position({ options = { show_all_diags_on_cursorline = true } }, diagnostics, 5, 0)
  MiniTest.expect.equality(#result, 2)
end

T["at_position"]["returns diagnostics under cursor position"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
    H.make_diagnostic({ lnum = 5, col = 30, end_col = 40 }),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 35)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].col, 30)
end

T["at_position"]["returns line diagnostics when cursor not in range"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
    H.make_diagnostic({ lnum = 5, col = 30, end_col = 40 }),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 0)
  MiniTest.expect.equality(#result, 2)
end

T["at_position"]["returns empty when show_diags_only_under_cursor enabled and cursor not in range"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
    H.make_diagnostic({ lnum = 5, col = 30, end_col = 40 }),
  }

  local result =
    filter.at_position({ options = { show_diags_only_under_cursor = true } }, diagnostics, 5, 0)
  MiniTest.expect.equality(#result, 0)
end

T["at_position"]["matches whole line when diagnostic has no column info and show_diags_only_under_cursor enabled"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 0, end_col = 0 }),
  }

  local result =
    filter.at_position({ options = { show_diags_only_under_cursor = true } }, diagnostics, 5, 12)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].lnum, 5)
end

T["at_position"]["matches whole line when diagnostic has no column info under default options"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 0, end_col = 0 }),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 12)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].lnum, 5)
end

T["at_position"]["default mode keeps line fallback when mixed whole-line and column-specific diagnostics"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 0, end_col = 0 }),
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 5)
  MiniTest.expect.equality(#result, 2)
end

T["at_position"]["default mode returns only column-specific diagnostic when cursor is on it"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 0, end_col = 0 }),
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 15)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].col, 10)
end

T["at_position"]["show_diags_only_under_cursor merges whole-line and under-cursor diagnostics"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 0, end_col = 0 }),
    H.make_diagnostic({ lnum = 5, col = 10, end_col = 20 }),
  }

  local result =
    filter.at_position({ options = { show_diags_only_under_cursor = true } }, diagnostics, 5, 15)
  MiniTest.expect.equality(#result, 2)
end

T["at_position"]["zero-width diagnostic matches cursor at col and col-1"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 5, col = 33, end_col = 33 }),
  }
  local opts = { options = { show_diags_only_under_cursor = true } }

  MiniTest.expect.equality(#filter.at_position(opts, diagnostics, 5, 32), 1)
  MiniTest.expect.equality(#filter.at_position(opts, diagnostics, 5, 33), 1)
  MiniTest.expect.equality(#filter.at_position(opts, diagnostics, 5, 31), 0)
  MiniTest.expect.equality(#filter.at_position(opts, diagnostics, 5, 34), 0)
end

T["under_cursor"] = MiniTest.new_set()

T["under_cursor"]["returns empty for invalid buffer"] = function()
  local result = filter.under_cursor({ options = {} }, -1, {})
  MiniTest.expect.equality(result, {})
end

T["under_cursor"]["returns empty for nil diagnostics"] = function()
  H.with_buf({}, function(buf)
    vim.api.nvim_set_current_buf(buf)
    local result = filter.under_cursor({ options = {} }, buf, nil)
    MiniTest.expect.equality(result, {})
  end)
end

T["under_cursor"]["returns diagnostics at cursor position"] = function()
  H.with_win_buf({ "line1", "line2", "line3" }, { 2, 5 }, nil, function(buf)
    local diagnostics = {
      H.make_diagnostic({ lnum = 1, col = 0, end_col = 10 }),
      H.make_diagnostic({ lnum = 2, col = 0, end_col = 5 }),
    }

    local result = filter.under_cursor({ options = {} }, buf, diagnostics)
    MiniTest.expect.equality(#result, 1)
  end)
end

T["by_multiline_severity"] = MiniTest.new_set()

T["by_multiline_severity"]["filters by the multilines severity list"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 0, col = 0, end_col = 5, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 1, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.INFO }),
    H.make_diagnostic({ lnum = 3, col = 0, end_col = 5, severity = vim.diagnostic.severity.HINT }),
  }

  local result = filter.by_multiline_severity({
    options = {
      multilines = {
        severity = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN },
      },
    },
  }, diagnostics)

  MiniTest.expect.equality(#result, 2)
  MiniTest.expect.equality(result[1].severity, vim.diagnostic.severity.ERROR)
  MiniTest.expect.equality(result[2].severity, vim.diagnostic.severity.WARN)
end

T["by_multiline_severity"]["passes everything through when severity is nil"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 0, col = 0, end_col = 5, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 1, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
    H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.INFO }),
  }

  local result =
    filter.by_multiline_severity({ options = { multilines = { severity = nil } } }, diagnostics)

  MiniTest.expect.equality(#result, 3)
end

T["by_multiline_severity"]["keeps only listed severities"] = function()
  local diagnostics = {
    H.make_diagnostic({ lnum = 0, col = 0, end_col = 5, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 1, col = 0, end_col = 5, severity = vim.diagnostic.severity.ERROR }),
    H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
  }

  local result = filter.by_multiline_severity({
    options = { multilines = { severity = { vim.diagnostic.severity.ERROR } } },
  }, diagnostics)

  MiniTest.expect.equality(#result, 2)
  for _, diag in ipairs(result) do
    MiniTest.expect.equality(diag.severity, vim.diagnostic.severity.ERROR)
  end
end

return T
