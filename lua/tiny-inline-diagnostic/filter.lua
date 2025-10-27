local M = {}

---@param opts table
---@param diagnostics table
---@return table
function M.by_severity(opts, diagnostics)
  if not diagnostics or #diagnostics == 0 then
    return {}
  end
  if not opts.options.severity then
    return diagnostics
  end
  return vim.tbl_filter(function(diag)
    return vim.tbl_contains(opts.options.severity, diag.severity)
  end, diagnostics)
end

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

---@param related_info table
---@param parent_diag table
---@return table
local function create_related_diagnostic(related_info, parent_diag)
  return {
    message = related_info.message,
    severity = parent_diag.severity,
    lnum = parent_diag.lnum,
    col = parent_diag.col,
    end_lnum = parent_diag.end_lnum,
    end_col = parent_diag.end_col,
    source = parent_diag.source,
    is_related = true,
    related_location = related_info.location,
  }
end

---@param diag table
---@return boolean
local function has_related_info(diag)
  return diag.user_data
    and diag.user_data.lsp
    and diag.user_data.lsp.relatedInformation
    and #diag.user_data.lsp.relatedInformation > 0
end

---@param diag table
---@param max_count number
---@return table
local function extract_related_diagnostics(diag, max_count)
  local related = {}
  for i, info in ipairs(diag.user_data.lsp.relatedInformation) do
    if i > max_count then
      break
    end
    if info.message and info.message ~= "" then
      table.insert(related, create_related_diagnostic(info, diag))
    end
  end
  return related
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
  local filtered_diags = M.at_position(opts, diagnostics, cursor_pos[1] - 1, cursor_pos[2])

  if not opts.options.show_related or not opts.options.show_related.enabled then
    return filtered_diags
  end

  local result = {}
  local max_count = opts.options.show_related.max_count or 3

  for _, diag in ipairs(filtered_diags) do
    table.insert(result, diag)
    if has_related_info(diag) then
      local related = extract_related_diagnostics(diag, max_count)
      vim.list_extend(result, related)
    end
  end

  return result
end

---@param opts table
---@param bufnr number
---@param diagnostics table
---@return table
function M.for_display(opts, bufnr, diagnostics)
  diagnostics = M.by_severity(opts, diagnostics)

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
