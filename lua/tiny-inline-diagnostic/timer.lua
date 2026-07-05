local M = {}

M.timers_by_buffer = {}

---Close and remove the timer for a buffer
---@param buf number
function M.close(buf)
  local timer = M.timers_by_buffer[buf]
  if timer then
    pcall(function()
      timer:close()
    end)
    M.timers_by_buffer[buf] = nil
  end
end

---Close all timers and reset storage
function M.set_timers()
  for buf in pairs(M.timers_by_buffer) do
    M.close(buf)
  end
  M.timers_by_buffer = {}
end

---Add a timer for a buffer, closing any existing one
---@param buf number
---@param timer table
function M.add(buf, timer)
  M.close(buf)
  M.timers_by_buffer[buf] = timer
end

return M
