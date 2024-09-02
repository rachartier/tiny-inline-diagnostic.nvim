local M = {}

---@param foreground string foreground color
---@param background string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(foreground, background, alpha)
	alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha

	local fg = M.hex_to_rgb(foreground)
	local bg = M.hex_to_rgb(background)

	local blend_channel = function(i)
		local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
		return math.floor(math.min(math.max(0, ret), 255) + 0.5)
	end

	return string.format("#%02x%02x%02x", blend_channel(1), blend_channel(2), blend_channel(3)):upper()
end

function M.hex_to_rgb(hex)
	if hex == nil or hex == "None" then
		return { 0, 0, 0 }
	end

	hex = hex:gsub("#", "")
	hex = string.lower(hex)

	return {
		tonumber(hex:sub(1, 2), 16),
		tonumber(hex:sub(3, 4), 16),
		tonumber(hex:sub(5, 6), 16),
	}
end

function M.int_to_hex(int)
	if int == nil then
		return "None"
	end

	return string.format("#%06X", int)
end

function M.trim(s)
	s = s:gsub("^[%s\194\160]*", ""):gsub("[%s\194\160]*$", "")

	return s:match("^%s*(.-)%s*$")
end

function M.split_lines(s)
	local lines = {}
	for line in s:gmatch("([^\n\t]*)\n?") do
		table.insert(lines, line)
	end
	table.remove(lines, #lines)
	return lines
end

function M.remove_newline(s)
	local removed_nl, _ = s:gsub("\n", " ")
	return removed_nl
end

function M.wrap_text(text, max_length)
	local lines = {}

	local split_lines = M.split_lines(text)

	for i, split_line in ipairs(split_lines) do
		local line = ""

		for word in split_line:gmatch("%S+") do
			if #line + #word <= max_length or max_length <= 0 then
				if #line == 0 and i > 1 then
					line = word
				else
					line = line .. " " .. word
				end
			else
				table.insert(lines, line)
				line = word
			end
		end
		table.insert(lines, line)
	end

	return lines
end

--- @param fn function Function to throttle
--- @param ms number Timeout in ms
--- @returns function, timer throttled function and timer. Remember to call
function M.throttle(fn, ms)
	local timer = vim.loop.new_timer()
	local running = false

	local function wrapped_fn(...)
		if not running then
			timer:start(ms, 0, function()
				timer:stop()
				running = false
			end)
			running = true
			pcall(vim.schedule_wrap(fn), select(1, ...))
		end
	end
	return wrapped_fn, timer
end

math.randomseed(os.time())

function M.fast_uuid()
	return math.random(1, 2 ^ 31 - 1)
end

return M
