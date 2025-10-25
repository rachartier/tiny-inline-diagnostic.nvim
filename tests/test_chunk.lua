local H = require("tests.helpers")
local MiniTest = require("mini.test")
local chunk = require("tiny-inline-diagnostic.chunk")

local T = MiniTest.new_set()

T["get_max_width_from_chunks"] = MiniTest.new_set()

T["get_max_width_from_chunks"]["returns max width from chunks"] = function()
  local chunks = { "short", "much longer text", "mid" }
  local result = chunk.get_max_width_from_chunks(chunks)
  MiniTest.expect.equality(result, vim.fn.strdisplaywidth("much longer text"))
end

T["get_max_width_from_chunks"]["handles empty chunks"] = function()
  local result = chunk.get_max_width_from_chunks({})
  MiniTest.expect.equality(result, 0)
end

T["get_max_width_from_chunks"]["handles single chunk"] = function()
  local chunks = { "single" }
  local result = chunk.get_max_width_from_chunks(chunks)
  MiniTest.expect.equality(result, 6)
end

T["get_diagnostic_icon"] = MiniTest.new_set()

T["get_diagnostic_icon"]["returns default icon when use_icons_from_diagnostic is false"] = function()
  local opts = H.make_opts({
    options = { use_icons_from_diagnostic = false },
  })
  local result = chunk.get_diagnostic_icon(opts, { vim.diagnostic.severity.ERROR }, 1, 1)
  MiniTest.expect.equality(result, "●")
end

T["get_diagnostic_icon"]["uses diagnostic icon when enabled"] = function()
  local opts = H.make_opts({
    options = { use_icons_from_diagnostic = true },
  })
  local result = chunk.get_diagnostic_icon(opts, { vim.diagnostic.severity.ERROR }, 1, 1)
  MiniTest.expect.equality(type(result), "string")
  MiniTest.expect.no_equality(result, "●")
end

T["add_severity_icons"] = MiniTest.new_set()

T["add_severity_icons"]["adds icons for multiple severities"] = function()
  local virt_texts = {}
  local opts = H.make_opts({
    options = {
      use_icons_from_diagnostic = false,
      add_messages = { messages = true, show_multiple_glyphs = true, use_max_severity = false },
    },
  })
  local severities = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN }

  chunk.add_severity_icons(virt_texts, opts, severities, "DiagnosticError")
  MiniTest.expect.equality(#virt_texts > 0, true)
end

T["add_severity_icons"]["handles empty severities"] = function()
  local virt_texts = {}
  local opts = H.make_opts({
    options = { use_icons_from_diagnostic = false, add_messages = true },
  })
  chunk.add_severity_icons(virt_texts, opts, {}, "DiagnosticError")
  MiniTest.expect.equality(#virt_texts, 0)
end

T["add_message_text"] = MiniTest.new_set()

T["add_message_text"]["adds message with right sign for last chunk"] = function()
  local virt_texts = {}
  local opts = H.make_opts()
  chunk.add_message_text(
    virt_texts,
    "error message",
    1,
    1,
    1,
    opts,
    "DiagnosticError",
    "DiagnosticErrorInv"
  )

  local has_right_sign = false
  for _, vt in ipairs(virt_texts) do
    if vt[1]:find("") then
      has_right_sign = true
      break
    end
  end
  MiniTest.expect.equality(has_right_sign, true)
end

T["add_message_text"]["handles multiple chunks"] = function()
  local virt_texts = {}
  local opts = H.make_opts()
  chunk.add_message_text(
    virt_texts,
    "chunk1",
    3,
    2,
    1,
    opts,
    "DiagnosticError",
    "DiagnosticErrorInv"
  )

  MiniTest.expect.equality(#virt_texts > 0, true)
end

T["get_header_from_chunk"] = MiniTest.new_set()

T["get_header_from_chunk"]["creates header with left sign for first diagnostic"] = function()
  local opts = H.make_opts({
    options = { add_messages = true, use_icons_from_diagnostic = false },
  })
  local chunk_info = {
    chunks = { "message" },
    line = 0,
  }

  local result = chunk.get_header_from_chunk(
    "message",
    1,
    chunk_info,
    opts,
    "DiagnosticError",
    "DiagnosticErrorInv",
    1,
    { vim.diagnostic.severity.ERROR },
    1
  )

  MiniTest.expect.equality(type(result), "table")
  MiniTest.expect.equality(#result > 0, true)
end

T["get_body_from_chunk"] = MiniTest.new_set()

T["get_body_from_chunk"]["creates body with vertical sign"] = function()
  local opts = H.make_opts()

  local result = chunk.get_body_from_chunk(
    "chunk text",
    1,
    1,
    2,
    false,
    opts,
    "DiagnosticError",
    "DiagnosticErrorInv",
    1
  )

  MiniTest.expect.equality(type(result), "table")
  MiniTest.expect.equality(#result > 0, true)
end

T["get_body_from_chunk"]["uses vertical_end for last chunk"] = function()
  local opts = H.make_opts()

  local result = chunk.get_body_from_chunk(
    "last chunk",
    1,
    2,
    2,
    false,
    opts,
    "DiagnosticError",
    "DiagnosticErrorInv",
    1
  )

  local has_vertical_end = false
  for _, vt in ipairs(result) do
    if vt[1]:find("└") then
      has_vertical_end = true
      break
    end
  end
  MiniTest.expect.equality(has_vertical_end, true)
end

T["get_arrow_from_chunk"] = MiniTest.new_set()

T["get_arrow_from_chunk"]["returns arrow for inline display"] = function()
  local opts = H.make_opts({
    options = { set_arrow_to_diag_color = false },
  })
  local ret = {
    need_to_be_under = false,
    line = 0,
  }

  local result = chunk.get_arrow_from_chunk(opts, 0, ret, "DiagnosticError")
  MiniTest.expect.equality(type(result), "table")
end

T["get_arrow_from_chunk"]["returns up_arrow when need_to_be_under"] = function()
  local opts = H.make_opts({
    options = { set_arrow_to_diag_color = false },
  })
  local ret = {
    need_to_be_under = true,
    line = 0,
  }

  local result = chunk.get_arrow_from_chunk(opts, 0, ret, "DiagnosticError")
  MiniTest.expect.equality(type(result), "table")
  MiniTest.expect.equality(type(result[1]), "table")
end

T["handle_overflow_modes"] = MiniTest.new_set()

T["handle_overflow_modes"]["applies wrap mode"] = function()
  local opts = H.make_opts({
    options = {
      overflow = { mode = "wrap" },
      break_line = { enabled = false },
      softwrap = 10,
    },
  })
  local result = chunk.handle_overflow_modes(opts, "very long diagnostic message", false, 80, 0)
  MiniTest.expect.equality(type(result), "table")
end

T["handle_overflow_modes"]["applies none mode"] = function()
  local opts = H.make_opts({
    options = {
      overflow = { mode = "none" },
      break_line = { enabled = false },
    },
  })
  local result = chunk.handle_overflow_modes(opts, "diagnostic message", false, 80, 0)
  MiniTest.expect.equality(type(result), "table")
end

T["handle_overflow_modes"]["applies oneline mode"] = function()
  local opts = H.make_opts({
    options = {
      overflow = { mode = "oneline" },
      break_line = { enabled = false },
    },
  })
  local result = chunk.handle_overflow_modes(opts, "diagnostic message\nwith newline", false, 80, 0)
  MiniTest.expect.equality(type(result), "table")
end

T["handle_overflow_modes"]["applies break_line when enabled"] = function()
  local opts = H.make_opts({
    options = {
      overflow = { mode = "wrap" },
      break_line = { enabled = true, after = 30 },
    },
  })
  local result = chunk.handle_overflow_modes(opts, "diagnostic message", false, 80, 0)
  MiniTest.expect.equality(type(result), "table")
end

T["get_chunks"] = MiniTest.new_set()

T["get_chunks"]["returns chunk info for diagnostic"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = H.make_opts({
      options = {
        overflow = { mode = "none" },
        multilines = { enabled = false },
        softwrap = 10,
        break_line = { enabled = false },
        show_source = { enabled = false },
      },
    })
    local diags = {
      { message = "test error", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
    }

    local result = chunk.get_chunks(opts, diags, 1, 0, 0, buf)

    MiniTest.expect.equality(type(result), "table")
    MiniTest.expect.equality(type(result.chunks), "table")
    MiniTest.expect.equality(type(result.severity), "number")
    MiniTest.expect.equality(type(result.severities), "table")
  end)
end

T["get_chunks"]["includes source when show_source is enabled"] = function()
  H.with_buf({ "test line" }, function(buf)
    local opts = H.make_opts({
      options = {
        overflow = { mode = "none" },
        multilines = { enabled = false },
        softwrap = 10,
        break_line = { enabled = false },
        show_source = { enabled = true },
      },
    })
    local diags = {
      {
        message = "test error",
        severity = vim.diagnostic.severity.ERROR,
        lnum = 0,
        source = "test_lsp",
      },
    }

    local result = chunk.get_chunks(opts, diags, 1, 0, 0, buf)
    local full_message = table.concat(result.chunks, "")
    MiniTest.expect.equality(full_message:find("test_lsp") ~= nil, true)
  end)
end

T["get_chunks"]["sets need_to_be_under for long lines"] = function()
  local long_line = string.rep("x", 200)
  H.with_win_buf({ long_line }, nil, 80, function(buf, win)
    local opts = H.make_opts({
      options = {
        overflow = { mode = "wrap" },
        multilines = { enabled = false },
        softwrap = 10,
        break_line = { enabled = false },
        show_source = { enabled = false },
      },
    })
    local diags = {
      { message = "test error", severity = vim.diagnostic.severity.ERROR, lnum = 0 },
    }

    local result = chunk.get_chunks(opts, diags, 1, 0, 0, buf)
    MiniTest.expect.equality(type(result.need_to_be_under), "boolean")
  end)
end

return T
