local MiniTest = require("mini.test")
local presets = require("tiny-inline-diagnostic.presets")

local T = MiniTest.new_set()

T["build"] = MiniTest.new_set()

T["build"]["creates classic preset"] = function()
  local result = presets.build("classic", false)
  MiniTest.expect.equality(type(result), "table")
  MiniTest.expect.equality(type(result.signs), "table")
  MiniTest.expect.equality(result.signs.diag, "●")
  MiniTest.expect.equality(result.signs.left, "")
  MiniTest.expect.equality(result.signs.right, "")
end

T["build"]["creates simple preset"] = function()
  local result = presets.build("simple", false)
  MiniTest.expect.equality(type(result.signs.diag), "string")
  MiniTest.expect.equality(#result.signs.diag > 0, true)
  MiniTest.expect.equality(result.signs.left, "")
  MiniTest.expect.equality(result.signs.right, "")
end

T["build"]["creates minimal preset"] = function()
  local result = presets.build("minimal", false)
  MiniTest.expect.equality(result.signs.left, "")
  MiniTest.expect.equality(result.signs.right, "")
  MiniTest.expect.equality(result.blend.factor, 0)
end

T["build"]["creates nonerdfont preset"] = function()
  local result = presets.build("nonerdfont", false)
  MiniTest.expect.equality(result.signs.left, "░")
  MiniTest.expect.equality(result.signs.right, "░")
  MiniTest.expect.equality(result.signs.diag, "●")
end

T["build"]["creates ghost preset"] = function()
  local result = presets.build("ghost", false)
  MiniTest.expect.equality(result.signs.diag, "󰊠")
end

T["build"]["creates amongus preset"] = function()
  local result = presets.build("amongus", false)
  MiniTest.expect.equality(result.signs.diag, "ඞ")
end

T["build"]["creates powerline preset"] = function()
  local result = presets.build("powerline", false)
  MiniTest.expect.equality(result.signs.left, "")
  MiniTest.expect.equality(result.signs.right, " ")
  MiniTest.expect.equality(result.options.set_arrow_to_diag_color, true)
end

T["build"]["returns default for unknown preset"] = function()
  local result = presets.build("unknown", false)
  MiniTest.expect.equality(type(result), "table")
  MiniTest.expect.equality(type(result.signs), "table")
end

T["build"]["applies transparent_bg when true"] = function()
  local result = presets.build("classic", true)
  MiniTest.expect.equality(result.signs.left, "")
  MiniTest.expect.equality(result.signs.right, "")
  MiniTest.expect.equality(result.blend.factor, 0)
end

T["build"]["does not modify left/right when transparent_bg is false"] = function()
  local result = presets.build("classic", false)
  MiniTest.expect.equality(result.signs.left, "")
  MiniTest.expect.equality(result.signs.right, "")
  MiniTest.expect.no_equality(result.blend.factor, 0)
end

T["build"]["includes default signs"] = function()
  local result = presets.build("classic", false)
  MiniTest.expect.equality(type(result.signs.arrow), "string")
  MiniTest.expect.equality(type(result.signs.up_arrow), "string")
  MiniTest.expect.equality(type(result.signs.vertical), "string")
  MiniTest.expect.equality(type(result.signs.vertical_end), "string")
end

T["build"]["has blend table with factor"] = function()
  local result = presets.build("classic", false)
  MiniTest.expect.equality(type(result.blend), "table")
  MiniTest.expect.equality(type(result.blend.factor), "number")
end

T["build"]["has options table"] = function()
  local result = presets.build("powerline", false)
  MiniTest.expect.equality(type(result.options), "table")
end

return T
