local M = {}

-- Constants
local DEFAULT_RGB = { 0, 0, 0 }
local MAX_COLOR_VALUE = 255
local HEX_BASE = 16
local UUID_MAX = 2 ^ 31 - 1

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
	return { s:gsub("[\n\r]+", " ") }
end

---Wraps text to a specified length
---@param text string|nil The text to wrap
---@param max_length number The maximum line length
---@return string[] lines Array of wrapped lines
function M.wrap_text(text, max_length)
	if not text then
		return {}
	end
	if max_length <= 0 then
		return M.split_lines(text)
	end

	local lines = {}
	local split_lines = M.split_lines(text)

	for i, split_line in ipairs(split_lines) do
		local current_line = ""
		for word in split_line:gmatch("%S+") do
			local potential_line = current_line ~= "" and (current_line .. " " .. word) or word

			if #potential_line <= max_length then
				current_line = potential_line
			else
				if current_line ~= "" then
					table.insert(lines, current_line)
				end
				current_line = word
			end
		end
		if current_line ~= "" then
			table.insert(lines, current_line)
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
	local timer = vim.loop.new_timer()
	local running = false

	---@param ... any
	local function throttled(...)
		if not running then
			timer:start(ms, 0, function()
				timer:stop()
				running = false
			end)
			running = true
			pcall(vim.schedule_wrap(fn), select(1, ...))
		end
	end

	return throttled, timer
end

math.randomseed(os.time())

---@return number uuid A random number between 1 and 2^31-1
function M.fast_uuid()
	return math.random(1, UUID_MAX)
end

return M
