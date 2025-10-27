local M = {}

local diagnostics_cache = {}

---@param diagnostics table
---@return table
local function sort_by_severity(diagnostics)
  local sorted = vim.deepcopy(diagnostics)
  table.sort(sorted, function(a, b)
    return a.severity < b.severity
  end)
  return sorted
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
    diagnostics = vim.diagnostic.get(bufnr)
  end

  local diag_buf = diagnostics_cache[bufnr] or {}

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

  diagnostics_cache[bufnr] = sort_by_severity(diag_buf)
end

---@param bufnr number
function M.clear(bufnr)
  diagnostics_cache[bufnr] = nil
end

return M
