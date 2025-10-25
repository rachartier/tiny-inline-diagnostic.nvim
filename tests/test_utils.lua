local MiniTest = require("mini.test")
local utils = require("tiny-inline-diagnostic.utils")

local T = MiniTest.new_set()

T["hex_to_rgb"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      MiniTest.finally(function() end)
    end,
  },
})

T["hex_to_rgb"]["converts valid hex color"] = function()
  local result = utils.hex_to_rgb("#FF5500")
  MiniTest.expect.equality(result, { 255, 85, 0 })
end

T["hex_to_rgb"]["handles hex without hash"] = function()
  local result = utils.hex_to_rgb("00FF00")
  MiniTest.expect.equality(result, { 0, 255, 0 })
end

T["hex_to_rgb"]["returns default for nil"] = function()
  local result = utils.hex_to_rgb(nil)
  MiniTest.expect.equality(result, { 0, 0, 0 })
end

T["hex_to_rgb"]["returns default for None"] = function()
  local result = utils.hex_to_rgb("None")
  MiniTest.expect.equality(result, { 0, 0, 0 })
end

T["hex_to_rgb"]["returns default for invalid length"] = function()
  local result = utils.hex_to_rgb("#FFF")
  MiniTest.expect.equality(result, { 0, 0, 0 })
end

T["blend"] = MiniTest.new_set()

T["blend"]["blends two colors with alpha"] = function()
  local result = utils.blend("#FF0000", "#0000FF", 0.5)
  MiniTest.expect.equality(result, "#800080")
end

T["blend"]["clamps alpha to 0-1 range"] = function()
  local result = utils.blend("#FFFFFF", "#000000", 2.0)
  MiniTest.expect.equality(result, "#FFFFFF")

  result = utils.blend("#FFFFFF", "#000000", -1.0)
  MiniTest.expect.equality(result, "#000000")
end

T["blend"]["handles hex alpha values"] = function()
  local result = utils.blend("#FF0000", "#00FF00", "80")
  local rgb = utils.hex_to_rgb(result)
  MiniTest.expect.equality(rgb[1] > 0, true)
  MiniTest.expect.equality(rgb[2] > 0, true)
end

T["int_to_hex"] = MiniTest.new_set()

T["int_to_hex"]["converts integer to hex"] = function()
  local result = utils.int_to_hex(16711680)
  MiniTest.expect.equality(result, "#FF0000")
end

T["int_to_hex"]["returns None for nil"] = function()
  local result = utils.int_to_hex(nil)
  MiniTest.expect.equality(result, "None")
end

T["trim"] = MiniTest.new_set()

T["trim"]["removes leading and trailing whitespace"] = function()
  local result = utils.trim("  hello world  ")
  MiniTest.expect.equality(result, "hello world")
end

T["trim"]["handles strings with no whitespace"] = function()
  local result = utils.trim("hello")
  MiniTest.expect.equality(result, "hello")
end

T["trim"]["returns empty for non-string"] = function()
  local result = utils.trim(123)
  MiniTest.expect.equality(result, "")
end

T["trim"]["handles BOM characters"] = function()
  local result = utils.trim("\194\160  test  ")
  MiniTest.expect.equality(result, "test")
end

T["split_lines"] = MiniTest.new_set()

T["split_lines"]["splits on newlines"] = function()
  local result = utils.split_lines("line1\nline2\nline3")
  MiniTest.expect.equality(#result, 3)
  MiniTest.expect.equality(result[1], "line1")
  MiniTest.expect.equality(result[2], "line2")
  MiniTest.expect.equality(result[3], "line3")
end

T["split_lines"]["handles CRLF"] = function()
  local result = utils.split_lines("line1\r\nline2\r\n")
  MiniTest.expect.equality(#result, 2)
end

T["split_lines"]["returns empty for non-string"] = function()
  local result = utils.split_lines(nil)
  MiniTest.expect.equality(result, {})
end

T["remove_newline"] = MiniTest.new_set()

T["remove_newline"]["replaces newlines with spaces"] = function()
  local result = utils.remove_newline("hello\nworld")
  MiniTest.expect.equality(result, { "hello world" })
end

T["remove_newline"]["handles non-string"] = function()
  local result = utils.remove_newline(nil)
  MiniTest.expect.equality(result, "")
end

T["wrap_text"] = MiniTest.new_set()

T["wrap_text"]["wraps text at max length"] = function()
  local result = utils.wrap_text("hello world test", 10, false, 4)
  MiniTest.expect.equality(#result > 1, true)
end

T["wrap_text"]["returns empty for nil text"] = function()
  local result = utils.wrap_text(nil, 10, false, 4)
  MiniTest.expect.equality(result, {})
end

T["wrap_text"]["returns lines as-is when max_length is 0"] = function()
  local result = utils.wrap_text("line1\nline2", 0, false, 4)
  MiniTest.expect.equality(#result, 2)
end

T["wrap_text"]["expands tabs"] = function()
  local result = utils.wrap_text("\thello", 100, false, 4)
  MiniTest.expect.equality(result[1]:match("^%s+"), "    ")
end

T["wrap_text"]["trims whitespace when requested"] = function()
  local result = utils.wrap_text("  hello  world  ", 5, true, 4)
  MiniTest.expect.equality(result[1]:match("^%s*"), "")
end

T["throttle"] = MiniTest.new_set()

T["throttle"]["creates throttled function"] = function()
  local call_count = 0
  local fn = function()
    call_count = call_count + 1
  end

  local throttled, timer = utils.throttle(fn, 10)
  MiniTest.expect.equality(type(throttled), "function")
  MiniTest.expect.no_equality(timer, nil)

  if timer then
    timer:close()
  end
end

T["fast_uuid"] = MiniTest.new_set()

T["fast_uuid"]["returns a number"] = function()
  local result = utils.fast_uuid()
  MiniTest.expect.equality(type(result), "number")
end

T["fast_uuid"]["returns different values"] = function()
  local result1 = utils.fast_uuid()
  local result2 = utils.fast_uuid()
  MiniTest.expect.no_equality(result1, result2)
end

T["fast_uuid"]["returns value in range"] = function()
  local result = utils.fast_uuid()
  MiniTest.expect.equality(result >= 1, true)
  MiniTest.expect.equality(result <= 2 ^ 31 - 1, true)
end

return T
