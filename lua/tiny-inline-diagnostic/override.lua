local M = {}

local state = require("tiny-inline-diagnostic.state")
local tiny_diag = require("tiny-inline-diagnostic.diagnostic")

local diagnostic_float_active = false
local original_tiny_state = true
local original_open_float = vim.diagnostic.open_float

M.open_float = function(...)
  if not diagnostic_float_active then
    diagnostic_float_active = true
    -- Only restore the plugin after the float closes if it was enabled before;
    -- a user-disabled plugin must stay disabled
    original_tiny_state = state.user_toggle_state
    tiny_diag.disable()
  end

  local bufnr = original_open_float(...)

  if bufnr == nil then
    diagnostic_float_active = false
    if original_tiny_state then
      tiny_diag.enable()
    end
    return
  end

  diagnostic_float_active = true

  local group = vim.api.nvim_create_augroup("RestoreTinyDiag", { clear = true })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWinLeave" }, {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      diagnostic_float_active = false
      vim.api.nvim_del_augroup_by_id(group)
      vim.schedule(function()
        if not diagnostic_float_active and original_tiny_state then
          tiny_diag.enable()
        end
      end)
    end,
  })

  return bufnr
end

return M
