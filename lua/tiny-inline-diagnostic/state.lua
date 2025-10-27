local M = {}

local disabled_modes = {}

M.enabled = true
M.user_toggle_state = true

---@param opts table
function M.init(opts)
  disabled_modes = {}

  if not opts.options.enable_on_select then
    table.insert(disabled_modes, "s")
    table.insert(disabled_modes, "v")
    table.insert(disabled_modes, "V")
  end

  if not opts.options.enable_on_insert then
    table.insert(disabled_modes, "i")
    table.insert(disabled_modes, "ic")
    table.insert(disabled_modes, "ix")
  end
end

---@param mode string
---@return boolean
function M.is_mode_disabled(mode)
  return vim.tbl_contains(disabled_modes, mode)
end

function M.enable()
  M.enabled = true
end

function M.disable()
  M.enabled = false
end

function M.user_enable()
  M.user_toggle_state = true
end

function M.user_disable()
  M.user_toggle_state = false
end

function M.user_toggle()
  M.user_toggle_state = not M.user_toggle_state
end

return M
