---@class Timer
---@field close function

---@class TimerManager
---@field private timers_by_buffer table<number, Timer>
local M = {}

M.timers_by_buffer = {}

---@class TimerError
---@field message string
---@field buffer number|nil
local TimerError = {}

local ERROR_MESSAGES = {
	INVALID_BUFFER = "Invalid buffer provided: %d",
	TIMER_NOT_FOUND = "No timer found for buffer: %d",
	NIL_TIMER = "Attempting to add nil timer for buffer: %d",
}

---@param buf number
---@return boolean
local function is_valid_buffer(buf)
	return buf and type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

---@param timer Timer
---@return boolean
local function is_valid_timer(timer)
	return timer ~= nil and type(timer.close) == "function"
end

---@param message string
---@param buffer? number
---@return TimerError
local function create_error(message, buffer)
	return {
		message = message,
		buffer = buffer,
	}
end

---Closes all active timers and cleans up the timer storage
---@return boolean success
---@return TimerError|nil error
function M.close_timers()
	local success = true
	local last_error = nil

	for buf, timer in pairs(M.timers_by_buffer) do
		if is_valid_timer(timer) then
			local timer_success, err = pcall(function()
				timer:close()
			end)

			if not timer_success then
				success = false
				last_error = create_error(string.format("Failed to close timer for buffer %d: %s", buf, err), buf)
			end
		end
	end

	return success, last_error
end

---Closes and removes a specific timer for a buffer
---@param buf number The buffer number
---@return boolean success
---@return TimerError|nil error
function M.close(buf)
	if not is_valid_buffer(buf) then
		return false, create_error(string.format(ERROR_MESSAGES.INVALID_BUFFER, buf), buf)
	end

	local timer = M.timers_by_buffer[buf]
	if not timer then
		return false, create_error(string.format(ERROR_MESSAGES.TIMER_NOT_FOUND, buf), buf)
	end

	local success, err = pcall(function()
		timer:close()
	end)

	if success then
		M.timers_by_buffer[buf] = nil
		return true, nil
	else
		return false, create_error(string.format("Failed to close timer for buffer %d: %s", buf, err), buf)
	end
end

---Resets all timers and cleans up the timer storage
---@return boolean success
---@return TimerError|nil error
function M.set_timers()
	if not vim.tbl_isempty(M.timers_by_buffer) then
		local success, err = M.close_timers()
		if not success then
			return false, err
		end
	end

	M.timers_by_buffer = {}
	return true, nil
end

---Adds a new timer for a specific buffer
---@param buf number The buffer number
---@param timer Timer The timer object to add
---@return boolean success
---@return TimerError|nil error
function M.add(buf, timer)
	if not is_valid_buffer(buf) then
		return false, create_error(string.format(ERROR_MESSAGES.INVALID_BUFFER, buf), buf)
	end

	if not is_valid_timer(timer) then
		return false, create_error(string.format(ERROR_MESSAGES.NIL_TIMER, buf), buf)
	end

	if M.timers_by_buffer[buf] then
		-- If a timer already exists, close it first
		local success, err = M.close(buf)
		if not success then
			return false, err
		end
	end

	M.timers_by_buffer[buf] = timer
	return true, nil
end

---Gets the timer for a specific buffer
---@param buf number The buffer number
---@return Timer|nil timer The timer object if it exists
---@return TimerError|nil error
function M.get_timer(buf)
	if not is_valid_buffer(buf) then
		return nil, create_error(string.format(ERROR_MESSAGES.INVALID_BUFFER, buf), buf)
	end

	local timer = M.timers_by_buffer[buf]
	if not timer then
		return nil, create_error(string.format(ERROR_MESSAGES.TIMER_NOT_FOUND, buf), buf)
	end

	return timer, nil
end

---Checks if a buffer has an active timer
---@param buf number The buffer number
---@return boolean has_timer
function M.has_timer(buf)
	return is_valid_buffer(buf) and M.timers_by_buffer[buf] ~= nil
end

---Gets the count of active timers
---@return number count
function M.get_timer_count()
	return vim.tbl_count(M.timers_by_buffer)
end

return M
