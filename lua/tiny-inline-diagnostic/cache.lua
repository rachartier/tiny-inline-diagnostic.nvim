local M = {}

local diagnostics_cache = {}

---@param diagnostics table
---@return table
local function sort_by_severity(diagnostics)
  -- Shallow copy: the sort only reorders references and no consumer mutates
  -- the diagnostic tables
  local sorted = { unpack(diagnostics) }
  table.sort(sorted, function(a, b)
    -- _extmark_id is attached by nvim core in vim.diagnostic.get(); tie-break on
    -- it because table.sort is unstable and equal severities would render in
    -- random order otherwise (#164)
    return a.severity < b.severity
      or (
        a.severity == b.severity
        and a._extmark_id ~= nil
        and b._extmark_id ~= nil
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

---@param bufnr number
---@param diagnostics table|nil
function M.update(bufnr, diagnostics)
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
