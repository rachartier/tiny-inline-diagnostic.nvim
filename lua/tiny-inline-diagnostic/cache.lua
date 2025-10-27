local M = {}

local diagnostics_cache = {}

local function sort_by_severity(diagnostics)
  local sorted = vim.deepcopy(diagnostics)
  table.sort(sorted, function(a, b)
    return a.severity < b.severity
  end)
  return sorted
end

local function build_by_line(list)
  local by_line = {}
  for _, d in ipairs(list) do
    local l = d.lnum
    local t = by_line[l]
    if t then
      t[#t + 1] = d
    else
      by_line[l] = { d }
    end
  end
  return by_line
end

function M.get(bufnr)
  local entry = diagnostics_cache[bufnr]
  if not entry or vim.tbl_isempty(entry) then
    return {}
  end
  if entry.list then
    return entry.list
  end
  return entry
end

function M.get_version(bufnr)
  local entry = diagnostics_cache[bufnr]
  if not entry or not entry.version then
    return 0
  end
  return entry.version
end

function M.get_visible(bufnr, first_line, last_line)
  local entry = diagnostics_cache[bufnr]
  if not entry or vim.tbl_isempty(entry) then
    return {}
  end
  local by_line = entry.by_line or {}
  local visible = {}
  for l = first_line, last_line do
    local diags = by_line[l]
    if diags then
      visible[l] = diags
    end
  end
  return visible
end

function M.get_by_line(bufnr, lnum)
  local entry = diagnostics_cache[bufnr]
  if not entry or vim.tbl_isempty(entry) then
    return {}
  end
  local by_line = entry.by_line or {}
  return by_line[lnum] or {}
end

function M.update(opts, bufnr, diagnostics)
  if diagnostics == nil or vim.tbl_isempty(diagnostics) then
    diagnostics_cache[bufnr] = {}
    return
  end
  local sorted = sort_by_severity(diagnostics)
  local entry = diagnostics_cache[bufnr]
  local version = entry and entry.version or 0
  diagnostics_cache[bufnr] = {
    list = sorted,
    by_line = build_by_line(sorted),
    version = version + 1,
    count = #sorted,
  }
end

function M.clear(bufnr)
  diagnostics_cache[bufnr] = nil
end

return M
