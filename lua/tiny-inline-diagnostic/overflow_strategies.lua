local M = {}

local utils = require("tiny-inline-diagnostic.utils")

---@param message string
---@param offset number
---@param win_width number
---@param opts table
---@param is_related boolean
---@return table
local function get_message_chunks_for_overflow(message, offset, win_width, opts, is_related)
  local signs_total_text_len = #opts.signs.arrow
    + #opts.signs.right
    + #opts.signs.left
    + #opts.signs.diag
    + 4
  if is_related then
    signs_total_text_len = signs_total_text_len + 3
  end
  local distance = win_width - offset - signs_total_text_len
  return utils.wrap_text(
    message,
    distance,
    opts.options.multilines.trim_whitespaces,
    opts.options.multilines.tabstop
  )
end

---@param message string
---@param opts table
---@return table
function M.apply_break_line(message, opts)
  return utils.wrap_text(
    message,
    opts.options.break_line.after,
    opts.options.multilines.trim_whitespaces,
    opts.options.multilines.tabstop
  )
end

---@param message string
---@param need_to_be_under boolean
---@param win_width number
---@param opts table
---@param is_related boolean
---@return table
function M.apply_wrap(message, need_to_be_under, win_width, opts, is_related)
  local offset = 0
  if need_to_be_under then
    offset = 0
  else
    local ok, win_col = pcall(vim.fn.virtcol, "$")
    offset = ok and win_col or 0
  end
  offset = (opts.options.overflow.padding or 0) + offset
  return get_message_chunks_for_overflow(message, offset, win_width, opts, is_related or false)
end

---@param message string
---@param opts table
---@return table
function M.apply_none(message, opts)
  return utils.wrap_text(
    message,
    0,
    opts.options.multilines.trim_whitespaces,
    opts.options.multilines.tabstop
  )
end

---@param message string
---@return string
function M.apply_oneline(message)
  return utils.remove_newline(message)
end

return M
