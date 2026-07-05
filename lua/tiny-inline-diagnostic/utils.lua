local M = {}

-- Constants
local DEFAULT_RGB = { 0, 0, 0 }
local MAX_COLOR_VALUE = 255
local HEX_BASE = 16

-- Color utilities
---Converts a hex color string to RGB values
---@param hex string|nil The hex color string (e.g., "#FFFFFF" or "FFFFFF")
---@return number[] rgb Array of RGB values [r, g, b]
function M.hex_to_rgb(hex)
  if not hex or hex == "None" then
    return DEFAULT_RGB
  end

  hex = hex:gsub("#", ""):lower()
  if #hex ~= 6 then
    return DEFAULT_RGB
  end

  local rgb = {}
  for i = 1, 5, 2 do
    local value = tonumber(hex:sub(i, i + 1), HEX_BASE)
    if not value then
      return DEFAULT_RGB
    end
    table.insert(rgb, value)
  end

  return rgb
end

---Blends two colors with a given alpha value
---@param foreground string Foreground color in hex format
---@param background string Background color in hex format
---@param alpha number|string Alpha value (0-1 or hex string)
---@return string hex The resulting blended color in hex format
function M.blend(foreground, background, alpha)
  -- Convert hex alpha to decimal if needed
  if type(alpha) == "string" then
    alpha = tonumber(alpha, HEX_BASE) / 0xff
  end

  -- Validate alpha range
  alpha = math.max(0, math.min(1, alpha or 0))

  local fg = M.hex_to_rgb(foreground)
  local bg = M.hex_to_rgb(background)

  ---@param channel number
  ---@return number
  local function blend_channel(channel)
    local value = (alpha * fg[channel] + ((1 - alpha) * bg[channel]))
    return math.floor(math.min(math.max(0, value), MAX_COLOR_VALUE) + 0.5)
  end

  return string.format("#%02X%02X%02X", blend_channel(1), blend_channel(2), blend_channel(3))
end

---Converts an integer to a hex color string
---@param int number|nil The integer to convert
---@return string hex The resulting hex color or "None"
function M.int_to_hex(int)
  if not int then
    return "None"
  end
  return string.format("#%06X", int)
end

-- String utilities
---Trims whitespace from both ends of a string
---@param s string The string to trim
---@return string trimmed The trimmed string
function M.trim(s)
  if type(s) ~= "string" then
    return ""
  end
  -- Remove BOM and whitespace from beginning and end
  return (s:gsub("^[%s\194\160]*(.-)%s*$", "%1"))
end

---Splits a string into lines
---@param s string The string to split
---@return string[] lines Array of lines
function M.split_lines(s)
  if type(s) ~= "string" then
    return {}
  end

  local lines = {}
  for line in s:gmatch("([^\n\r]*)\r?\n?") do
    if line ~= "" then
      table.insert(lines, line)
    end
  end
  return lines
end

---Replaces newlines with spaces
---@param s string The string to process
---@return table processed The processed string as table
function M.remove_newline(s)
  if type(s) ~= "string" then
    return ""
  end
  local processed, _ = s:gsub("\n", " ")
  return { processed }
end

---Wraps text to a specified length
---@param text string|nil The text to wrap
---@param max_length number The maximum line length
---@param trim_whitespaces boolean Whether to trim leading whitespace
---@return string[] lines Array of wrapped lines
function M.wrap_text(text, max_length, trim_whitespaces, tabstop)
  if not text then
    return {}
  end
  if max_length <= 0 then
    return M.split_lines(text)
  end

  text = text:gsub("\t", string.rep(" ", tabstop))

  local lines = {}

  for _, split_line in ipairs(M.split_lines(text)) do
    -- Handle empty lines
    if split_line:match("^%s*$") then
      table.insert(lines, split_line)
    elseif trim_whitespaces then
      local parts = {}
      local len = 0
      local pos = 1
      while true do
        local s, e = split_line:find("%S+", pos)
        if not s then
          break
        end
        local word_len = e - s + 1
        if #parts == 0 then
          parts[1] = split_line:sub(s, e)
          len = word_len
        elseif len + 1 + word_len <= max_length then
          parts[#parts + 1] = split_line:sub(s, e)
          len = len + 1 + word_len
        else
          table.insert(lines, table.concat(parts, " "))
          parts = { split_line:sub(s, e) }
          len = word_len
        end
        pos = e + 1
      end
      if #parts > 0 then
        table.insert(lines, table.concat(parts, " "))
      end
    else
      -- Inter-word whitespace is kept verbatim, so every output line is a
      -- slice of the input; continuation lines are re-prefixed with the
      -- line's leading whitespace
      local prefix = split_line:match("^%s*")
      local start_idx = 1
      local _, last_e = split_line:find("%S+")
      local pos = last_e + 1

      local function emit()
        if start_idx == 1 then
          table.insert(lines, split_line:sub(1, last_e))
        else
          table.insert(lines, prefix .. split_line:sub(start_idx, last_e))
        end
      end

      while true do
        local s, e = split_line:find("%S+", pos)
        if not s then
          break
        end
        local potential_len = start_idx == 1 and e or (#prefix + e - start_idx + 1)
        if potential_len <= max_length then
          last_e = e
        else
          emit()
          start_idx = s
          last_e = e
        end
        pos = e + 1
      end
      emit()
    end
  end

  return lines
end

-- Async utilities
---Creates a throttled version of a function
---@param fn function The function to throttle
---@param ms number Throttle delay in milliseconds
---@return function throttled The throttled function
---@return userdata timer The timer object
function M.throttle(fn, ms)
  local timer = vim.uv.new_timer()
  local running = false
  local pending_arg = nil
  local has_pending = false

  ---@param ... any
  local function throttled(...)
    local arg = select(1, ...)

    if not running and timer then
      local success = pcall(function()
        timer:start(ms, 0, function()
          if timer then
            timer:stop()
          end
          running = false

          if has_pending and pending_arg then
            pcall(vim.schedule_wrap(fn), pending_arg)
            has_pending = false
            pending_arg = nil
          end
        end)
      end)

      if success then
        running = true
        has_pending = false
        pending_arg = nil
        pcall(vim.schedule_wrap(fn), arg)
      end
    else
      pending_arg = arg
      has_pending = true
    end
  end

  return throttled, timer
end

return M
