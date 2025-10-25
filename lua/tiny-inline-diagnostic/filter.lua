local M = {}

---@param opts table
---@param diagnostics table
---@param line number
---@param col number
---@return table
function M.at_position(opts, diagnostics, line, col)
  if not diagnostics or #diagnostics == 0 then
    return {}
  end

  local diags_on_line = vim.tbl_filter(function(diag)
    return diag.lnum == line
  end, diagnostics)

  if opts.options.show_all_diags_on_cursorline then
    return #diags_on_line > 0 and diags_on_line or {}
  end

  local current_pos_diags = vim.tbl_filter(function(diag)
    return diag.lnum == line and col >= diag.col and col <= diag.end_col
  end, diagnostics)

  return #current_pos_diags > 0 and current_pos_diags or diags_on_line
end

---@param opts table
---@param buf number
---@param diagnostics table
---@return table
function M.under_cursor(opts, buf, diagnostics)
  if
    not vim.api.nvim_buf_is_valid(buf)
    or vim.api.nvim_get_current_buf() ~= buf
    or not diagnostics
    or #diagnostics == 0
  then
    return {}
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  return M.at_position(opts, diagnostics, cursor_pos[1] - 1, cursor_pos[2])
end

---@param opts table
---@param bufnr number
---@param diagnostics table
---@return table
function M.for_display(opts, bufnr, diagnostics)
  if not opts.options.multilines.enabled then
    return M.under_cursor(opts, bufnr, diagnostics)
  end

  if opts.options.multilines.always_show then
    return diagnostics
  end

  local under_cursor = M.under_cursor(opts, bufnr, diagnostics)
  return not vim.tbl_isempty(under_cursor) and under_cursor or diagnostics
end

---@param diagnostics table
---@return table
function M.visible(diagnostics)
  local first_line = vim.fn.line("w0") - 1
  local last_line = vim.fn.line("w$")
  local visible_diags = {}

  for _, diag in ipairs(diagnostics) do
    if diag.lnum >= first_line and diag.lnum <= last_line then
      visible_diags[diag.lnum] = visible_diags[diag.lnum] or {}
      table.insert(visible_diags[diag.lnum], diag)
    end
  end

  return visible_diags
end

return M
