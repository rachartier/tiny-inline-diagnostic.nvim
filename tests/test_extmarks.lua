local MiniTest = require("mini.test")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local H = require("tests.helpers")

local T = MiniTest.new_set()

T["clear"] = MiniTest.new_set()

T["clear"]["clears extmarks from valid buffer"] = function()
  H.with_buf({}, function(buf)
    extmarks.clear(buf)
  end)
end

T["clear"]["handles invalid buffer"] = function()
  extmarks.clear(999999)
end

T["get_extmarks_on_line"] = MiniTest.new_set()

T["get_extmarks_on_line"]["returns empty table for invalid buffer"] = function()
  local result = extmarks.get_extmarks_on_line(999999, 0, 0)
  MiniTest.expect.equality(result, {})
end

T["get_extmarks_on_line"]["returns table for valid buffer"] = function()
  H.with_buf({ "test line" }, function(buf)
    local result = extmarks.get_extmarks_on_line(buf, 0, 0)
    MiniTest.expect.equality(type(result), "table")
  end)
end

T["handle_other_extmarks"] = MiniTest.new_set()

T["handle_other_extmarks"]["returns 0 for line with no extmarks"] = function()
  H.with_buf({ "test line" }, function(buf)
    local offset = extmarks.handle_other_extmarks(buf, 0, 0)
    MiniTest.expect.equality(offset, 0)
  end)
end

T["handle_other_extmarks"]["calculates offset from eol extmarks"] = function()
  H.with_buf({ "test line" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_ns")
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text = { { "virtual", "Comment" } },
      virt_text_pos = "eol",
    })

    local offset = extmarks.handle_other_extmarks(buf, 0, 0)
    MiniTest.expect.equality(offset >= 0, true)
  end)
end

T["count_inlay_hints_characters"] = MiniTest.new_set()

T["count_inlay_hints_characters"]["returns 0 for line without hints"] = function()
  H.with_buf({ "test line" }, function(buf)
    local count = extmarks.count_inlay_hints_characters(buf, 0)
    MiniTest.expect.equality(count, 0)
  end)
end

T["count_inlay_hints_characters"]["handles nil line"] = function()
  H.with_buf({}, function(buf)
    local count = extmarks.count_inlay_hints_characters(buf, 10)
    MiniTest.expect.equality(count, 0)
  end)
end

T["create_extmarks"] = MiniTest.new_set()

T["create_extmarks"]["handles invalid buffer"] = function()
  local opts = {
    options = { multilines = false },
  }
  extmarks.create_extmarks(opts, 999999, 0, {}, {}, 0, 0, false, 100)
end

T["create_extmarks"]["handles empty virt_lines"] = function()
  H.with_buf({ "test" }, function(buf)
    local opts = {
      options = { multilines = false },
    }
    extmarks.create_extmarks(opts, buf, 0, {}, {}, 0, 0, false, 100)
  end)
end

T["create_extmarks"]["creates extmarks for valid input"] = function()
  H.with_win_buf({ "test line", "line 2", "line 3" }, { 1, 0 }, nil, function(buf)
    local opts = {
      options = { multilines = false },
    }
    local virt_lines = {
      { { "diag", "DiagnosticError" } },
    }

    extmarks.create_extmarks(opts, buf, 0, {}, virt_lines, 0, 2, false, 100)
  end)
end

T["create_extmarks"]["handles multiline mode"] = function()
  H.with_win_buf({ "line 1", "line 2", "line 3" }, { 1, 0 }, nil, function(buf)
    local opts = {
      options = { multilines = true },
    }
    local virt_lines = {
      { { "diag", "DiagnosticError" } },
    }

    extmarks.create_extmarks(opts, buf, 1, { { 0, 1 } }, virt_lines, 0, 2, false, 100)
  end)
end

T["create_extmarks"]["handles need_to_be_under flag"] = function()
  H.with_win_buf({ "test line", "line 2" }, { 1, 0 }, nil, function(buf)
    local opts = {
      options = { multilines = false },
    }
    local virt_lines = {
      { { " ", "None" } },
      { { "up", "DiagnosticError" } },
      { { "msg", "DiagnosticError" } },
    }

    extmarks.create_extmarks(opts, buf, 0, {}, virt_lines, 0, 2, true, 100)
  end)
end

T["create_extmarks"]["handles buffer at end of file"] = function()
  H.with_win_buf({ "line 1" }, { 1, 0 }, nil, function(buf)
    local opts = {
      options = { multilines = false },
    }
    local virt_lines = {
      { { "diag", "DiagnosticError" } },
      { { "more", "DiagnosticError" } },
    }

    extmarks.create_extmarks(opts, buf, 0, {}, virt_lines, 0, 2, false, 100)
  end)
end

return T
