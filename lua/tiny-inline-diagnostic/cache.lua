local M = {}

local diagnostics_cache = {}
local by_lnum_cache = {}
-- ns_store[bufnr][namespace] = that namespace's diagnostic list. The lists
-- coming from DiagnosticChanged payloads are live references into nvim's own
-- diagnostic cache: they must never be mutated.
local ns_store = {}

---Bucket a severity-sorted list by lnum; bucketing preserves the global
---order, so each bucket stays sorted (severity asc, _extmark_id desc, #164)
---@param sorted table
---@return table<number, table>
local function index_by_lnum(sorted)
  local by_lnum = {}
  for _, diag in ipairs(sorted) do
    local bucket = by_lnum[diag.lnum]
    if bucket then
      bucket[#bucket + 1] = diag
    else
      by_lnum[diag.lnum] = { diag }
    end
  end
  return by_lnum
end

---_extmark_id is attached by nvim core in vim.diagnostic.get(); tie-break on
---it because table.sort is unstable and equal severities would render in
---random order otherwise (#164)
local function compare_severity(a, b)
  return a.severity < b.severity
    or (
      a.severity == b.severity
      and a._extmark_id ~= nil
      and b._extmark_id ~= nil
      and a._extmark_id > b._extmark_id
    )
end

---Store a freshly built flat list as the buffer's sorted cache + line index
---@param bufnr number
---@param flat table
local function set_sorted(bufnr, flat)
  table.sort(flat, compare_severity)
  diagnostics_cache[bufnr] = flat
  by_lnum_cache[bufnr] = index_by_lnum(flat)
end

---@param bufnr number
---@return table
function M.get(bufnr)
  return diagnostics_cache[bufnr] or {}
end

---Per-line buckets of the cached diagnostics. Buckets are cache-owned:
---callers must not mutate them.
---@param bufnr number
---@return table<number, table>
function M.get_by_line(bufnr)
  return by_lnum_cache[bufnr] or {}
end

---Replace the whole cache for a buffer with a full diagnostic list
---@param bufnr number
---@param diagnostics table|nil
function M.update(bufnr, diagnostics)
  local store = {}
  if diagnostics == nil or vim.tbl_isempty(diagnostics) then
    diagnostics_cache[bufnr] = {}
    by_lnum_cache[bufnr] = {}
  else
    for _, diag in ipairs(diagnostics) do
      local ns = diag.namespace or 0
      local bucket = store[ns]
      if bucket then
        bucket[#bucket + 1] = diag
      else
        store[ns] = { diag }
      end
    end
    set_sorted(bufnr, { unpack(diagnostics) })
  end
  ns_store[bufnr] = store
end

---Update from a DiagnosticChanged payload, replacing only the emitting
---namespace instead of re-fetching (and deep-copying) every diagnostic via
---vim.diagnostic.get(). An empty payload does not identify its namespace
---(reset(ns) and set(ns, {}) are indistinguishable), so it falls back to a
---full resync.
---@param bufnr number
---@param event_diags table|nil args.data.diagnostics of the event
function M.update_from_event(bufnr, event_diags)
  if not event_diags or #event_diags == 0 then
    M.update(bufnr, vim.diagnostic.get(bufnr))
    return
  end

  local store = ns_store[bufnr]
  if not store then
    store = {}
    ns_store[bufnr] = store
  end
  store[event_diags[1].namespace or 0] = event_diags

  local flat = {}
  for _, diags in pairs(store) do
    for _, diag in ipairs(diags) do
      flat[#flat + 1] = diag
    end
  end
  set_sorted(bufnr, flat)
end

---@param bufnr number
function M.clear(bufnr)
  diagnostics_cache[bufnr] = nil
  by_lnum_cache[bufnr] = nil
  ns_store[bufnr] = nil
end

return M
