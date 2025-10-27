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
---@param diagnostics table|nil
function M.update(opts, bufnr, diagnostics)
  if diagnostics == nil or vim.tbl_isempty(diagnostics) then
    diagnostics = {}
  end

  local diag_buf = diagnostics_cache[bufnr] or {}

  -- extract namespaces from incoming diagnostics
  local namespaces = {}
  for _, diag in ipairs(diagnostics) do
    if not vim.tbl_contains(namespaces, diag.namespace) then
      table.insert(namespaces, diag.namespace)
    end
  end

  if diagnostics and #namespaces == 0 and #diagnostics == 0 then
    diag_buf = {}
  else
    diag_buf = vim.tbl_filter(function(diag)
      return not vim.tbl_contains(namespaces, diag.namespace)
    end, diag_buf)

    for _, diag in pairs(diagnostics) do
      table.insert(diag_buf, diag)
    end
  end

  diagnostics_cache[bufnr] = sort_by_severity(diag_buf)
end

---@param bufnr number
function M.clear(bufnr)
  diagnostics_cache[bufnr] = nil
end

return M
