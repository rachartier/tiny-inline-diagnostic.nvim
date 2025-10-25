local M = {}

local SEVERITY_NAMES = { "Error", "Warn", "Info", "Hint" }
local HIGHLIGHT_PREFIX = "TinyInlineDiagnosticVirtualText"
local INV_HIGHLIGHT_PREFIX = "TinyInlineInvDiagnosticVirtualText"

---@param colors table
---@param blends table
---@param transparent boolean
---@return table
function M.build_base_groups(colors, blends, transparent)
  local hi = {
    [HIGHLIGHT_PREFIX .. "Bg"] = { bg = colors.background },
  }

  for severity, name in pairs(SEVERITY_NAMES) do
    local name_lower = string.lower(name)
    local color = colors[name_lower]

    hi[HIGHLIGHT_PREFIX .. name .. "CursorLine"] = {
      bg = colors.cursor_line.bg,
      fg = color.fg,
      italic = color.italic,
    }

    hi[HIGHLIGHT_PREFIX .. name] = {
      bg = transparent and "None" or blends[name_lower],
      fg = color.fg,
      italic = color.italic,
    }

    hi[HIGHLIGHT_PREFIX .. name .. "Dimmed"] = {
      bg = transparent and "None" or blends[name_lower],
      fg = color.fg,
      italic = color.italic,
      blend = 50,
    }

    hi[HIGHLIGHT_PREFIX .. name .. "NoBg"] = {
      fg = color.fg,
      bg = "None",
      italic = color.italic,
    }

    hi[INV_HIGHLIGHT_PREFIX .. name] = {
      fg = blends[name_lower],
      bg = transparent and "None" or colors.background,
      italic = color.italic,
    }

    hi[INV_HIGHLIGHT_PREFIX .. name .. "NoBg"] = {
      fg = blends[name_lower],
      bg = "None",
      italic = color.italic,
    }
  end

  hi[HIGHLIGHT_PREFIX .. "Arrow"] = {
    bg = colors.background,
    fg = colors.arrow.fg,
  }
  hi[HIGHLIGHT_PREFIX .. "ArrowNoBg"] = {
    bg = "None",
    fg = colors.arrow.fg,
  }

  return hi
end

---@param base_groups table
---@return table
function M.build_mixed_groups(base_groups)
  local hi = {}
  local group_names = {
    HIGHLIGHT_PREFIX .. "Error",
    HIGHLIGHT_PREFIX .. "Warn",
    HIGHLIGHT_PREFIX .. "Info",
    HIGHLIGHT_PREFIX .. "Hint",
  }

  for _, primary in ipairs(group_names) do
    for _, secondary in ipairs(group_names) do
      local mixed_name = primary .. "Mix" .. secondary:match("Text(%w+)$")
      hi[mixed_name] = {
        fg = base_groups[primary].fg,
        bg = base_groups[secondary].bg,
        italic = base_groups[primary].italic,
      }
    end
  end

  return hi
end

---@param base table
---@param mixed table
---@return table
function M.merge_groups(base, mixed)
  local result = vim.deepcopy(base)
  for name, opts in pairs(mixed) do
    result[name] = opts
  end
  return result
end

return M
