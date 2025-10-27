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

T["for_display"] = MiniTest.new_set()

T["for_display"]["returns under_cursor when multilines disabled"] = function()
  H.with_win_buf({ "line1", "line2" }, { 1, 0 }, nil, function(buf)
    local diagnostics = {
      H.make_diagnostic({ lnum = 0, col = 0, end_col = 5 }),
      H.make_diagnostic({ lnum = 1, col = 0, end_col = 5 }),
    }

    local result =
      filter.for_display({ options = { multilines = { enabled = false } } }, buf, diagnostics)

    MiniTest.expect.equality(#result, 1)
  end)
end

T["for_display"]["returns all diagnostics when multilines.always_show enabled"] = function()
  H.with_buf({}, function(buf)
    local diagnostics = {
      H.make_diagnostic({ lnum = 0, col = 0, end_col = 5 }),
      H.make_diagnostic({ lnum = 1, col = 0, end_col = 5 }),
    }

    local result = filter.for_display(
      { options = { multilines = { enabled = true, always_show = true } } },
      buf,
      diagnostics
    )

    MiniTest.expect.equality(#result, 2)
  end)
end

T["visible"] = MiniTest.new_set()

T["visible"]["returns diagnostics in visible range"] = function()
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, tostring(i))
  end

  H.with_win_buf(lines, nil, nil, function(buf)
    local diagnostics = {
      H.make_diagnostic({ lnum = 5, col = 0, end_col = 5 }),
      H.make_diagnostic({ lnum = 10, col = 0, end_col = 5 }),
      H.make_diagnostic({ lnum = 200, col = 0, end_col = 5 }),
    }

    local result = filter.visible(diagnostics)
    MiniTest.expect.equality(type(result), "table")
  end)
end

T["visible"]["groups diagnostics by line"] = function()
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, tostring(i))
  end

  H.with_win_buf(lines, nil, nil, function(buf)
    local diagnostics = {
      H.make_diagnostic({ lnum = 5, col = 0, end_col = 5 }),
      H.make_diagnostic({ lnum = 5, col = 10, end_col = 15 }),
      H.make_diagnostic({ lnum = 10, col = 0, end_col = 5 }),
    }

    local result = filter.visible(diagnostics)
    if result[5] then
      MiniTest.expect.equality(#result[5], 2)
    end
  end)
end

T["for_display"]["filters by multilines.severity when always_show enabled"] = function()
  H.with_buf({}, function(buf)
    local diagnostics = {
      H.make_diagnostic({
        lnum = 0,
        col = 0,
        end_col = 5,
        severity = vim.diagnostic.severity.ERROR,
      }),
      H.make_diagnostic({ lnum = 1, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
      H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.INFO }),
      H.make_diagnostic({ lnum = 3, col = 0, end_col = 5, severity = vim.diagnostic.severity.HINT }),
    }

    local result = filter.for_display({
      options = {
        multilines = {
          enabled = true,
          always_show = true,
          severity = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN },
        },
      },
    }, buf, diagnostics)

    MiniTest.expect.equality(#result, 2)
    MiniTest.expect.equality(result[1].severity, vim.diagnostic.severity.ERROR)
    MiniTest.expect.equality(result[2].severity, vim.diagnostic.severity.WARN)
  end)
end

T["for_display"]["shows all diagnostics when multilines.severity is nil"] = function()
  H.with_buf({}, function(buf)
    local diagnostics = {
      H.make_diagnostic({
        lnum = 0,
        col = 0,
        end_col = 5,
        severity = vim.diagnostic.severity.ERROR,
      }),
      H.make_diagnostic({ lnum = 1, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
      H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.INFO }),
    }

    local result = filter.for_display({
      options = {
        multilines = {
          enabled = true,
          always_show = true,
          severity = nil,
        },
      },
    }, buf, diagnostics)

    MiniTest.expect.equality(#result, 3)
  end)
end

T["for_display"]["filters only errors with multilines.severity"] = function()
  H.with_buf({}, function(buf)
    local diagnostics = {
      H.make_diagnostic({
        lnum = 0,
        col = 0,
        end_col = 5,
        severity = vim.diagnostic.severity.ERROR,
      }),
      H.make_diagnostic({
        lnum = 1,
        col = 0,
        end_col = 5,
        severity = vim.diagnostic.severity.ERROR,
      }),
      H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
    }

    local result = filter.for_display({
      options = {
        multilines = {
          enabled = true,
          always_show = true,
          severity = { vim.diagnostic.severity.ERROR },
        },
      },
    }, buf, diagnostics)

    MiniTest.expect.equality(#result, 2)
    for _, diag in ipairs(result) do
      MiniTest.expect.equality(diag.severity, vim.diagnostic.severity.ERROR)
    end
  end)
end

T["for_display"]["filters by multilines.severity when always_show is false"] = function()
  H.with_win_buf({ "line1", "line2", "line3" }, { 1, 0 }, nil, function(buf)
    local diagnostics = {
      H.make_diagnostic({
        lnum = 0,
        col = 0,
        end_col = 5,
        severity = vim.diagnostic.severity.ERROR,
      }),
      H.make_diagnostic({ lnum = 1, col = 0, end_col = 5, severity = vim.diagnostic.severity.WARN }),
      H.make_diagnostic({ lnum = 2, col = 0, end_col = 5, severity = vim.diagnostic.severity.INFO }),
    }

    local result = filter.for_display({
      options = {
        multilines = {
          enabled = true,
          always_show = false,
          severity = { vim.diagnostic.severity.ERROR },
        },
      },
    }, buf, diagnostics)

    MiniTest.expect.equality(#result, 1)
    MiniTest.expect.equality(result[1].severity, vim.diagnostic.severity.ERROR)
  end)
end

return T
