---@class PluginConfig
---@field preset string
---@field hi table
---@field options table
---@field blend table

local M = {}

local diag = require("tiny-inline-diagnostic.diagnostic")
local hi = require("tiny-inline-diagnostic.highlights")
local presets = require("tiny-inline-diagnostic.presets")

local default_config = {
  preset = "modern",
  transparent_bg = false,
  transparent_cursorline = true,
  hi = {
    error = "DiagnosticError",
    warn = "DiagnosticWarn",
    info = "DiagnosticInfo",
    hint = "DiagnosticHint",
    arrow = "NonText",
    background = "CursorLine",
    mixing_color = "Normal",
  },
  options = {
    show_source = {
      enabled = false,
      if_many = false,
    },
    show_related = {
      enabled = true,
      max_count = 3,
    },
    add_messages = {
      messages = true,
      display_count = false,
      use_max_severity = false,
      show_multiple_glyphs = true,
    },
    set_arrow_to_diag_color = false,
    use_icons_from_diagnostic = false,
    throttle = 20,
    softwrap = 30,
    multilines = {
      enabled = false,
      always_show = false,
      trim_whitespaces = false,
      tabstop = 4,
    },
    show_all_diags_on_cursorline = false,
    enable_on_insert = false,
    enable_on_select = false,
    format = nil,
    overflow = {
      mode = "wrap",
    },
    break_line = {
      enabled = false,
      after = 30,
    },
    virt_texts = {
      priority = 2048,
    },
    severity = {
      vim.diagnostic.severity.ERROR,
      vim.diagnostic.severity.WARN,
      vim.diagnostic.severity.INFO,
      vim.diagnostic.severity.HINT,
    },
    override_open_float = false,
    overwrite_events = nil,
  },
  disabled_ft = {},
}

M.config = nil

---Create color scheme autocommand
local function setup_colorscheme_handler(config)
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      hi.setup_highlights(
        config.blend,
        config.hi,
        config.transparent_bg,
        config.transparent_cursorline
      )
    end,
  })
end

---Normalize configuration values
local function normalize_config(config)
  if config.options.overflow and config.options.overflow.mode then
    config.options.overflow.mode = config.options.overflow.mode:lower()
  end

  if config.signs then
    local preset = presets.build(config.preset or "modern", config.transparent_bg)
    config = vim.tbl_deep_extend("keep", config, preset)
  elseif config.preset then
    local preset = presets.build(config.preset:lower(), config.transparent_bg)
    config = vim.tbl_deep_extend("force", config, preset)
  end

  if type(config.options.multilines) == "boolean" then
    config.options.multilines = vim.tbl_deep_extend("force", default_config.options.multilines, {
      enabled = config.options.multilines,
      always_show = default_config.options.multilines.always_show,
    })
  end

  if type(config.options.add_messages) == "boolean" then
    config.options.add_messages =
      vim.tbl_deep_extend("force", default_config.options.add_messages, {
        messages = config.options.add_messages,
        display_count = default_config.options.add_messages.display_count,
        use_max_severity = default_config.options.add_messages.use_max_severity,
        show_multiple_glyphs = default_config.options.add_messages.show_multiple_glyphs,
      })
  end

  return config
end

--- Setup the tiny-inline-diagnostic plugin with user options.
---@param opts table|nil User configuration options to override the default settings.
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})

  config = normalize_config(config)

  M.config = config

  hi.setup_highlights(config.blend, config.hi, config.transparent_bg, config.transparent_cursorline)

  setup_colorscheme_handler(config)
  diag.set_diagnostic_autocmds(config)
end

--- Change the blend and highlight settings dynamically.
---@param blend table|nil New blend settings
---@param highlights table|nil New highlight settings
function M.change(blend, highlights)
  if not M.config then
    error("Plugin not initialized. Call setup() first.")
    return
  end

  local config = vim.tbl_deep_extend("force", M.config, {
    blend = blend or M.config.blend,
    hi = highlights or M.config.hi,
  })

  hi.setup_highlights(config.blend, config.hi, config.transparent_bg, config.transparent_cursorline)
end

--- Enable the diagnostic display.
function M.enable()
  diag.enable()
end

--- Disable the diagnostic display.
function M.disable()
  diag.disable()
end

--- Toggle the diagnostic display on or off.
function M.toggle()
  diag.toggle()
end

---Change diagnostic severities
---@param severities table New severity settings
function M.change_severities(severities)
  if not M.config then
    vim.notify(
      "Error in tiny-inline-diagnostic.nvim:\n\nPlugin not initialized. Call setup() first.",
      vim.log.levels.ERROR
    )
    return
  end

  if severities == nil then
    vim.notify(
      "Error in tiny-inline-diagnostic.nvim:\n\nSeverities in change_severities function cannot be nil.\n\nYou should provide a table of severities.\nE.g: {\n\tvim.diagnostic.severity.ERROR,\n\tvim.diagnostic.severity.WARN\n}\nTo only show errors and warnings.",
      vim.log.levels.ERROR
    )
    return
  end

  M.config.options.severity = severities

  vim.schedule(function()
    local renderer = require("tiny-inline-diagnostic.renderer")
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
        renderer.safe_render(M.config, bufnr)
      end
    end
  end)
end

function M.get_diagnostic_under_cursor()
  return diag.get_diagnostic_under_cursor()
end

return M
