local M = {}

local cache = require("tiny-inline-diagnostic.cache")

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
---@param diags_on_line table|nil Precomputed diagnostics of that line (cache-owned, not mutated)
---@return table
function M.at_position(opts, diagnostics, line, col, diags_on_line)
  if not diags_on_line then
    if not diagnostics or #diagnostics == 0 then
      return {}
    end
    diags_on_line = {}
    for _, diag in ipairs(diagnostics) do
      if diag.lnum == line then
        diags_on_line[#diags_on_line + 1] = diag
      end
    end
  end

  -- Wholesale returns copy the list: diags_on_line may be a cache-owned
  -- bucket and callers mutate the result
  if opts.options.show_all_diags_on_cursorline then
    return { unpack(diags_on_line) }
  end

  local current_pos_diags = {}
  for _, diag in ipairs(diags_on_line) do
    -- Zero-width LSP range (Range.end exclusive, start == end): anchor to the
    -- character on either side of the point so end-of-token diagnostics match
    local under_cursor
    if diag.col == diag.end_col and diag.col > 0 then
      under_cursor = col == diag.col or col == diag.col - 1
    else
      under_cursor = col >= diag.col and col <= diag.end_col
    end
    if under_cursor then
      current_pos_diags[#current_pos_diags + 1] = diag
    end
  end

  if opts.options.show_diags_only_under_cursor then
    local seen = {}
    for _, d in ipairs(current_pos_diags) do
      seen[d] = true
    end
    local result = vim.list_extend({}, current_pos_diags)
    for _, d in ipairs(diags_on_line) do
      if not seen[d] and d.col == 0 and d.end_col == 0 then
        result[#result + 1] = d
      end
    end
    return result
  end

  if #current_pos_diags > 0 then
    return current_pos_diags
  end
  return { unpack(diags_on_line) }
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
---@param diagnostics table
---@return table
local function add_related_diagnostics(opts, diagnostics)
  if not opts.options.show_related or not opts.options.show_related.enabled then
    return diagnostics
  end

  local result = {}
  local max_count = opts.options.show_related.max_count

  for _, diag in ipairs(diagnostics) do
    table.insert(result, diag)
    if has_related_info(diag) then
      local related = extract_related_diagnostics(diag, max_count)
      vim.list_extend(result, related)
    end
  end

  return result
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
  local cursor_lnum = cursor_pos[1] - 1

  -- When operating on the cached list, use its per-line index instead of
  -- scanning all diagnostics
  local diags_on_line
  if diagnostics == cache.get(buf) then
    diags_on_line = cache.get_by_line(buf)[cursor_lnum] or {}
  end

  local filtered_diags = M.at_position(opts, diagnostics, cursor_lnum, cursor_pos[2], diags_on_line)

  filtered_diags = M.by_severity(opts, filtered_diags)

  return add_related_diagnostics(opts, filtered_diags)
end

---Apply the multilines-specific severity filter, if configured. Passthrough
---when unconfigured: the result may alias the input, treat it as read-only.
---@param opts table
---@param diagnostics table
---@return table
function M.by_multiline_severity(opts, diagnostics)
  if not opts.options.multilines.severity then
    return diagnostics
  end
  return M.by_severity({ options = { severity = opts.options.multilines.severity } }, diagnostics)
end

local by_multiline_severity = M.by_multiline_severity

---@param opts table
---@param bufnr number
---@param diagnostics table
---@return table
function M.for_display(opts, bufnr, diagnostics)
  if opts.options.show_diags_only_under_cursor then
    return M.under_cursor(opts, bufnr, diagnostics)
  end

  if not opts.options.multilines.enabled then
    return M.under_cursor(opts, bufnr, diagnostics)
  end

  if opts.options.multilines.always_show then
    local under_cursor = M.under_cursor(opts, bufnr, diagnostics)
    local multiline_diags = by_multiline_severity(opts, diagnostics)

    local seen = {}
    for _, diag in ipairs(under_cursor) do
      seen[diag] = true
    end

    for _, diag in ipairs(multiline_diags) do
      if not seen[diag] then
        table.insert(under_cursor, diag)
      end
    end

    return under_cursor
  end

  local under_cursor = M.under_cursor(opts, bufnr, diagnostics)
  if not vim.tbl_isempty(under_cursor) then
    return under_cursor
  end

  return by_multiline_severity(opts, diagnostics)
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
