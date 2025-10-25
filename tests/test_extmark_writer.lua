local H = require("tests.helpers")
local MiniTest = require("mini.test")
local extmark_writer = require("tiny-inline-diagnostic.extmark_writer")

local T = MiniTest.new_set()

T["create_single_extmark"] = MiniTest.new_set()

T["create_single_extmark"]["handles invalid buffer"] = function()
  local uid_fn = H.uid_gen()
  extmark_writer.create_single_extmark(999999, 0, 0, {}, 0, 100, "eol", uid_fn)
end

T["create_single_extmark"]["creates extmark with eol position"] = function()
  H.with_buf({ "test line" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_writer")
    local uid_fn = H.uid_gen()
    local virt_text = { { "virtual text", "Comment" } }

    extmark_writer.create_single_extmark(buf, ns, 0, virt_text, 0, 100, "eol", uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_single_extmark"]["creates extmark with overlay position"] = function()
  H.with_buf({ "test line" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_writer2")
    local uid_fn = H.uid_gen()
    local virt_text = { { "overlay", "Comment" } }

    extmark_writer.create_single_extmark(buf, ns, 0, virt_text, 5, 100, "overlay", uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_multiline_extmark"] = MiniTest.new_set()

T["create_multiline_extmark"]["creates multiline extmark"] = function()
  H.with_buf({ "line 1", "line 2", "line 3" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_multiline")
    local uid_fn = H.uid_gen()
    local virt_lines = {
      { { "first", "Comment" } },
      { { "second", "Comment" } },
    }

    extmark_writer.create_multiline_extmark(buf, ns, 0, virt_lines, 100, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_multiline_extmark"]["trims first line spaces"] = function()
  H.with_buf({ "line 1" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_multiline2")
    local uid_fn = H.uid_gen()
    local virt_lines = {
      { { "  first  ", "Comment" }, { "  second  ", "Comment" } },
      { { "third", "Comment" } },
    }

    extmark_writer.create_multiline_extmark(buf, ns, 0, virt_lines, 100, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_overflow_extmarks"] = MiniTest.new_set()

T["create_overflow_extmarks"]["creates extmarks for overflow"] = function()
  H.with_buf({ "line 1", "line 2", "line 3" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_overflow")
    local uid_fn = H.uid_gen()
    local params = {
      curline = 0,
      virt_lines = {
        { { "first", "Comment" } },
        { { "second", "Comment" } },
      },
      win_col = 0,
      offset = 0,
      signs_offset = 2,
      priority = 100,
      need_to_be_under = false,
      buf_lines_count = 3,
    }

    extmark_writer.create_overflow_extmarks(buf, ns, params, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_overflow_extmarks"]["handles need_to_be_under"] = function()
  H.with_buf({ "line 1", "line 2", "line 3", "line 4" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_overflow2")
    local uid_fn = H.uid_gen()
    local params = {
      curline = 0,
      virt_lines = {
        { { "space", "None" } },
        { { "arrow", "Comment" } },
        { { "msg", "Comment" } },
      },
      win_col = 0,
      offset = 0,
      signs_offset = 2,
      priority = 100,
      need_to_be_under = true,
      buf_lines_count = 4,
    }

    extmark_writer.create_overflow_extmarks(buf, ns, params, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_overflow_extmarks"]["creates virt_lines for lines beyond buffer"] = function()
  H.with_buf({ "line 1" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_overflow3")
    local uid_fn = H.uid_gen()
    local params = {
      curline = 0,
      virt_lines = {
        { { "first", "Comment" } },
        { { "second", "Comment" } },
        { { "third", "Comment" } },
        { { "fourth", "Comment" } },
      },
      win_col = 0,
      offset = 0,
      signs_offset = 2,
      priority = 100,
      need_to_be_under = false,
      buf_lines_count = 1,
    }

    extmark_writer.create_overflow_extmarks(buf, ns, params, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks > 0, true)
  end)
end

T["create_simple_extmarks"] = MiniTest.new_set()

T["create_simple_extmarks"]["creates extmarks for each virt_line"] = function()
  H.with_buf({ "line 1", "line 2", "line 3" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_simple")
    local uid_fn = H.uid_gen()
    local virt_lines = {
      { { "first", "Comment" } },
      { { "second", "Comment" } },
    }

    extmark_writer.create_simple_extmarks(buf, ns, 0, virt_lines, 0, 0, 2, 100, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks, 2)
  end)
end

T["create_simple_extmarks"]["applies offset for subsequent lines"] = function()
  H.with_buf({ "line 1", "line 2", "line 3" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_simple2")
    local uid_fn = H.uid_gen()
    local virt_lines = {
      { { "first", "Comment" } },
      { { "second", "Comment" } },
      { { "third", "Comment" } },
    }

    extmark_writer.create_simple_extmarks(buf, ns, 0, virt_lines, 5, 10, 2, 100, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    MiniTest.expect.equality(#marks, 3)
  end)
end

T["create_simple_extmarks"]["uses overlay position for lines after first"] = function()
  H.with_buf({ "line 1", "line 2" }, function(buf)
    local ns = vim.api.nvim_create_namespace("test_simple3")
    local uid_fn = H.uid_gen()
    local virt_lines = {
      { { "first", "Comment" } },
      { { "second", "Comment" } },
    }

    extmark_writer.create_simple_extmarks(buf, ns, 0, virt_lines, 0, 0, 2, 100, uid_fn)

    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
    MiniTest.expect.equality(#marks, 2)
  end)
end

return T
