local MiniTest = require("mini.test")
local filter = require("tiny-inline-diagnostic.filter")

local T = MiniTest.new_set()

local function create_diagnostic(lnum, col, end_col, severity, message)
  return {
    lnum = lnum,
    col = col,
    end_col = end_col,
    severity = severity or vim.diagnostic.severity.ERROR,
    message = message or "test diagnostic",
  }
end

T["at_position"] = MiniTest.new_set()

T["at_position"]["returns empty for no diagnostics"] = function()
  local result = filter.at_position({ options = {} }, {}, 0, 0)
  MiniTest.expect.equality(result, {})
end

T["at_position"]["returns diagnostics on line"] = function()
  local diagnostics = {
    create_diagnostic(5, 10, 20),
    create_diagnostic(5, 30, 40),
    create_diagnostic(10, 0, 5),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 15)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].col, 10)
end

T["at_position"]["returns all diagnostics on line when show_all_diags_on_cursorline enabled"] = function()
  local diagnostics = {
    create_diagnostic(5, 10, 20),
    create_diagnostic(5, 30, 40),
    create_diagnostic(10, 0, 5),
  }

  local result =
    filter.at_position({ options = { show_all_diags_on_cursorline = true } }, diagnostics, 5, 0)
  MiniTest.expect.equality(#result, 2)
end

T["at_position"]["returns diagnostics under cursor position"] = function()
  local diagnostics = {
    create_diagnostic(5, 10, 20),
    create_diagnostic(5, 30, 40),
  }

  local result = filter.at_position({ options = {} }, diagnostics, 5, 35)
  MiniTest.expect.equality(#result, 1)
  MiniTest.expect.equality(result[1].col, 30)
end

T["at_position"]["returns line diagnostics when cursor not in range"] = function()
  local diagnostics = {
    create_diagnostic(5, 10, 20),
    create_diagnostic(5, 30, 40),
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
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)

  local result = filter.under_cursor({ options = {} }, buf, nil)
  MiniTest.expect.equality(result, {})

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["under_cursor"]["returns diagnostics at cursor position"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2", "line3" })
  vim.api.nvim_win_set_cursor(0, { 2, 5 })

  local diagnostics = {
    create_diagnostic(1, 0, 10),
    create_diagnostic(2, 0, 5),
  }

  local result = filter.under_cursor({ options = {} }, buf, diagnostics)
  MiniTest.expect.equality(#result, 1)

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["for_display"] = MiniTest.new_set()

T["for_display"]["returns under_cursor when multilines disabled"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local diagnostics = {
    create_diagnostic(0, 0, 5),
    create_diagnostic(1, 0, 5),
  }

  local result =
    filter.for_display({ options = { multilines = { enabled = false } } }, buf, diagnostics)

  MiniTest.expect.equality(#result, 1)

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["for_display"]["returns all diagnostics when multilines.always_show enabled"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  local diagnostics = {
    create_diagnostic(0, 0, 5),
    create_diagnostic(1, 0, 5),
  }

  local result = filter.for_display(
    { options = { multilines = { enabled = true, always_show = true } } },
    buf,
    diagnostics
  )

  MiniTest.expect.equality(#result, 2)

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["visible"] = MiniTest.new_set()

T["visible"]["returns diagnostics in visible range"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, tostring(i))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local diagnostics = {
    create_diagnostic(5, 0, 5),
    create_diagnostic(10, 0, 5),
    create_diagnostic(200, 0, 5),
  }

  local result = filter.visible(diagnostics)
  MiniTest.expect.equality(type(result), "table")

  vim.api.nvim_buf_delete(buf, { force = true })
end

T["visible"]["groups diagnostics by line"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, tostring(i))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local diagnostics = {
    create_diagnostic(5, 0, 5),
    create_diagnostic(5, 10, 15),
    create_diagnostic(10, 0, 5),
  }

  local result = filter.visible(diagnostics)
  if result[5] then
    MiniTest.expect.equality(#result[5], 2)
  end

  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
