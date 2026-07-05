local MiniTest = require("mini.test")
local override = require("tiny-inline-diagnostic.override")
local state = require("tiny-inline-diagnostic.state")

local T = MiniTest.new_set()

T["open_float"] = MiniTest.new_set()

T["open_float"]["restores plugin when it was enabled before the float"] = function()
  state.user_enable()

  -- No diagnostics under cursor: open_float returns nil, exercising the restore path
  override.open_float()

  MiniTest.expect.equality(state.user_toggle_state, true)
end

T["open_float"]["keeps plugin disabled when user disabled it before the float"] = function()
  state.user_disable()

  override.open_float()

  MiniTest.expect.equality(state.user_toggle_state, false)
  state.user_enable()
end

return T
