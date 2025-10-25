local MiniTest = require("mini.test")
local state = require("tiny-inline-diagnostic.state")

local T = MiniTest.new_set()

T["init"] = MiniTest.new_set()

T["init"]["disables insert mode when enable_on_insert is false"] = function()
  state.init({ options = { enable_on_insert = false, enable_on_select = true } })
  local result = state.is_mode_disabled("i")
  MiniTest.expect.equality(result, true)
end

T["init"]["disables select modes when enable_on_select is false"] = function()
  state.init({ options = { enable_on_insert = true, enable_on_select = false } })
  MiniTest.expect.equality(state.is_mode_disabled("s"), true)
  MiniTest.expect.equality(state.is_mode_disabled("v"), true)
  MiniTest.expect.equality(state.is_mode_disabled("V"), true)
end

T["init"]["enables all modes when both flags are true"] = function()
  state.init({ options = { enable_on_insert = true, enable_on_select = true } })
  MiniTest.expect.equality(state.is_mode_disabled("i"), false)
  MiniTest.expect.equality(state.is_mode_disabled("s"), false)
  MiniTest.expect.equality(state.is_mode_disabled("v"), false)
end

T["is_mode_disabled"] = MiniTest.new_set()

T["is_mode_disabled"]["returns false for enabled mode"] = function()
  state.init({ options = { enable_on_insert = true, enable_on_select = true } })
  local result = state.is_mode_disabled("n")
  MiniTest.expect.equality(result, false)
end

T["is_mode_disabled"]["returns true for disabled mode"] = function()
  state.init({ options = { enable_on_insert = false, enable_on_select = false } })
  local result = state.is_mode_disabled("i")
  MiniTest.expect.equality(result, true)
end

T["enable"] = MiniTest.new_set()

T["enable"]["sets enabled to true"] = function()
  state.enabled = false
  state.enable()
  MiniTest.expect.equality(state.enabled, true)
end

T["enable"]["does not change if already enabled"] = function()
  state.enabled = true
  state.enable()
  MiniTest.expect.equality(state.enabled, true)
end

T["disable"] = MiniTest.new_set()

T["disable"]["sets enabled to false"] = function()
  state.enabled = true
  state.disable()
  MiniTest.expect.equality(state.enabled, false)
end

T["disable"]["does not change if already disabled"] = function()
  state.enabled = false
  state.disable()
  MiniTest.expect.equality(state.enabled, false)
end

T["user_enable"] = MiniTest.new_set()

T["user_enable"]["sets user_toggle_state to true"] = function()
  state.user_toggle_state = false
  state.user_enable()
  MiniTest.expect.equality(state.user_toggle_state, true)
end

T["user_disable"] = MiniTest.new_set()

T["user_disable"]["sets user_toggle_state to false"] = function()
  state.user_toggle_state = true
  state.user_disable()
  MiniTest.expect.equality(state.user_toggle_state, false)
end

T["user_toggle"] = MiniTest.new_set()

T["user_toggle"]["toggles user_toggle_state from true to false"] = function()
  state.user_toggle_state = true
  state.user_toggle()
  MiniTest.expect.equality(state.user_toggle_state, false)
end

T["user_toggle"]["toggles user_toggle_state from false to true"] = function()
  state.user_toggle_state = false
  state.user_toggle()
  MiniTest.expect.equality(state.user_toggle_state, true)
end

return T
