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

-- function M.split_lines(s)
--     if string.find(s, "\n") then
--         local lines = {}
--         for line in string.gmatch(s, "(.-)\n") do
--             line = line:gsub("\n", "")
--             table.insert(lines, line)
--         end
--         print(vim.inspect(lines))
--         return lines
--     else
--         return { s }
--     end
-- end
--

function M.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function M.split_lines(s)
    local lines = {}
    for line in s:gmatch("([^\n]*)\n?") do
        table.insert(lines, M.trim(line))
    end
    table.remove(lines, #lines)
    return lines
end

-- function M.wrap_text(text, max_length)
--     local lines = {}
--
--     local splited_lines = M.split_lines(text)
--
--     for i, splited_line in ipairs(splited_lines) do
--         local line = ''
--
--         for word in splited_line:gmatch("%S+") do
--             if #line + #word < max_length then
--                 if #line == 0 and i > 1 then
--                     line = word
--                 else
--                     line = line .. ' ' .. word
--                 end
--             else
--                 table.insert(lines, line)
--                 line = word
--             end
--         end
--
--         table.insert(lines, line)
--     end
--
--     return lines
-- end
--
function M.wrap_text(input_string, max_length)
    local words = {}
    for word in input_string:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local current_line = words[1]
    for i = 2, #words do
        if #current_line + 1 + #words[i] > max_length then
            table.insert(lines, current_line)
            current_line = words[i]
        else
            current_line = current_line .. " " .. words[i]
        end
    end
    table.insert(lines, current_line)

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
                running = false
            end)
            running = true
            pcall(vim.schedule_wrap(fn), select(1, ...))
        end
    end
    return wrapped_fn, timer
end

return M
