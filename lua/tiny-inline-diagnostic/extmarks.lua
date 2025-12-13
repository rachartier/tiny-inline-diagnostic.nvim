local M = {}

local extmark_writer = require("tiny-inline-diagnostic.extmark_writer")

local INITIAL_UID = 1
local MAX_UID = 2 ^ 32 - 1
local DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace("TinyInlineDiagnostic")

local state = {
  uid_counter = INITIAL_UID,
}

function M.update_namespace_window()
  local current_window = vim.api.nvim_get_current_win()
  vim.api.nvim__ns_set(DIAGNOSTIC_NAMESPACE, { wins = { current_window } })
end

local function is_valid_buffer(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function generate_uid()
  state.uid_counter = (state.uid_counter % MAX_UID) + 1
  return state.uid_counter
end

local function get_window_position()
  local ok_winline, result_winline = pcall(vim.fn.winline)
  local ok_virtcol, result_virtcol = pcall(vim.fn.virtcol, "$")
  local ok_winsaveview, result_winsaveview = pcall(vim.fn.winsaveview)

  if not (ok_winline and ok_virtcol and ok_winsaveview) then
    return { row = 0, col = 0 }
  end

  return {
    row = result_winline - 1,
    col = result_virtcol - result_winsaveview.leftcol,
  }
end

local function should_skip_line(cursor_line, diag_line, diags_dims, virt_lines_count)
  for _, dims in ipairs(diags_dims) do
    if diag_line ~= dims[1] then
      if cursor_line == dims[1] then
        if diag_line > dims[1] and diag_line < dims[1] + dims[2] then
          return true
        end
      end
    end
  end

  return false
end

---Count inlay hint characters
---@param buf number
---@param linenr number
---@return number
function M.count_inlay_hints_characters(buf, linenr)
  local line = vim.api.nvim_buf_get_lines(buf, linenr, linenr + 1, false)[1]
  if not line then
    return 0
  end

  local line_char_count = vim.fn.strchars(line)
  local inlay_hints = vim.lsp.inlay_hint.get({
    bufnr = buf,
    range = {
      start = { line = linenr, character = 0 },
      ["end"] = { line = linenr, character = line_char_count },
    },
  })

  local count = 0
  for _, hint in ipairs(inlay_hints) do
    if type(hint.inlay_hint.label) == "string" then
      count = count + #hint.inlay_hint.label
    else
      for _, label in ipairs(hint.inlay_hint.label) do
        count = count + #label.value
      end
    end
  end
  return count
end

-- Public API

---Clear extmarks from buffer
---@param buf number
function M.clear(buf)
  if not is_valid_buffer(buf) then
    return
  end
  pcall(vim.api.nvim_buf_clear_namespace, buf, DIAGNOSTIC_NAMESPACE, 0, -1)
end

---Get extmarks on a specific line
---@param bufnr number
---@param linenr number
---@param col number
---@return table
function M.get_extmarks_on_line(bufnr, linenr, col)
  if not is_valid_buffer(bufnr) then
    return {}
  end

  return vim.api.nvim_buf_get_extmarks(bufnr, -1, { linenr, col }, { linenr, -1 }, {
    details = true,
    overlap = vim.fn.has("nvim-0.10.0") == 1,
  })
end

---Handle other extmarks
---@param bufnr number
---@param curline number
---@param col number
---@return number
function M.handle_other_extmarks(bufnr, curline, col)
  local extmarks = M.get_extmarks_on_line(bufnr, curline, col)
  local offset = 0

  for _, extmark in ipairs(extmarks) do
    local detail = extmark[4]
    if
      (detail.virt_text_pos == "eol" or detail.virt_text_pos == "win_col")
      and detail.virt_text
      and detail.virt_text[1]
      and detail.virt_text[1][1]
    then
      offset = offset + #detail.virt_text[1][1]
    end
  end

  if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
    offset = offset + M.count_inlay_hints_characters(bufnr, curline)
  end

  return offset
end

---Create extmarks
---@param opts table
---@param bufnr number
---@param diag_line number
---@param virt_lines table
---@param offset number
---@param signs_offset number
---@param need_to_be_under boolean
---@param virt_priority number
function M.create_extmarks(
  opts,
  bufnr,
  diag_line,
  diags_dims,
  virt_lines,
  offset,
  signs_offset,
  need_to_be_under,
  virt_priority
)
  if not is_valid_buffer(bufnr) or not virt_lines or vim.tbl_isempty(virt_lines) then
    return
  end

  local buf_lines_count = vim.api.nvim_buf_line_count(bufnr)
  if buf_lines_count == 0 then
    return
  end

  local win_col = need_to_be_under and 0 or get_window_position().col
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  if opts.options.multilines and diag_line ~= cursor_line then
    if should_skip_line(cursor_line, diag_line, diags_dims, #virt_lines) then
      return
    end

    extmark_writer.create_multiline_extmark(
      bufnr,
      DIAGNOSTIC_NAMESPACE,
      diag_line,
      virt_lines,
      virt_priority,
      generate_uid
    )

    return
  end

  if need_to_be_under or diag_line - 1 + #virt_lines > buf_lines_count - 1 then
    extmark_writer.create_overflow_extmarks(bufnr, DIAGNOSTIC_NAMESPACE, {
      curline = diag_line,
      virt_lines = virt_lines,
      win_col = win_col,
      offset = offset,
      signs_offset = signs_offset,
      priority = virt_priority,
      need_to_be_under = need_to_be_under,
      buf_lines_count = buf_lines_count,
    }, generate_uid)
  else
    extmark_writer.create_simple_extmarks(
      bufnr,
      DIAGNOSTIC_NAMESPACE,
      diag_line,
      virt_lines,
      win_col,
      offset,
      signs_offset,
      virt_priority,
      generate_uid
    )
  end
end

return M
