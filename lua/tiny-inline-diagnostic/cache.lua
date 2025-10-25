local M = {}

local diagnostics_cache = {}

---@param opts table
---@param diagnostics table
---@return table
local function filter_by_severity(opts, diagnostics)
  return vim.tbl_filter(function(diag)
    return vim.tbl_contains(opts.options.severity, diag.severity)
  end, diagnostics)
end

---@param bufnr number
---@return table
function M.get(bufnr)
  return diagnostics_cache[bufnr] or {}
end

---@param opts table
---@param bufnr number
---@param diagnostics table
function M.update(opts, bufnr, diagnostics)
  if not diagnostics or vim.tbl_isempty(diagnostics) then
    local diags = vim.diagnostic.get(bufnr)
    table.sort(diags, function(a, b)
      return a.severity < b.severity
    end)
    diagnostics_cache[bufnr] = diags
    return
  end

  local diag_buf = diagnostics_cache[bufnr] or {}

  diagnostics = filter_by_severity(opts, diagnostics)

  local namespaces = {}
  for _, diag in ipairs(diagnostics) do
    if not vim.tbl_contains(namespaces, diag.namespace) then
      table.insert(namespaces, diag.namespace)
    end
  end

  diag_buf = vim.tbl_filter(function(diag)
    return not vim.tbl_contains(namespaces, diag.namespace)
  end, diag_buf)

  for _, diag in pairs(diagnostics) do
    table.insert(diag_buf, diag)
  end

  table.sort(diag_buf, function(a, b)
    return a.severity < b.severity
  end)

  diagnostics_cache[bufnr] = diag_buf
end

---@param bufnr number
function M.clear(bufnr)
  diagnostics_cache[bufnr] = nil
end

return M
