local M = {}

local diagnostics_cache = {}

---@param diagnostics table
---@return table
local function sort_by_severity(diagnostics)
  local sorted = vim.deepcopy(diagnostics)
  table.sort(sorted, function(a, b)
    return a.severity < b.severity
      or (
        a.severity == b.severity
        and a._extmark_id
        and b._extmark_id
        and a._extmark_id > b._extmark_id
      )
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
    diagnostics_cache[bufnr] = {}
  else
    diagnostics_cache[bufnr] = sort_by_severity(diagnostics)
  end
end

---@param bufnr number
function M.clear(bufnr)
  diagnostics_cache[bufnr] = nil
end

return M
