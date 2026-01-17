local H = {}

function H.make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "" })
  return buf
end

function H.with_buf(lines, fn)
  local buf = H.make_buf(lines)
  local ok, result = pcall(fn, buf)
  vim.api.nvim_buf_delete(buf, { force = true })
  if not ok then
    error(result)
  end
  return result
end

function H.setup_win(buf, cursor, width)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  if cursor then
    vim.api.nvim_win_set_cursor(win, cursor)
  end
  if width then
    vim.api.nvim_win_set_width(win, width)
  end
  return win
end

function H.with_win_buf(lines, cursor, width, fn)
  local buf = H.make_buf(lines)
  local win = H.setup_win(buf, cursor, width)
  local ok, result = pcall(fn, buf, win)
  vim.api.nvim_buf_delete(buf, { force = true })
  if not ok then
    error(result)
  end
  return result
end

function H.make_diagnostic(tbl)
  return vim.tbl_extend("force", {
    lnum = 0,
    col = 0,
    end_col = 1,
    message = "msg",
    severity = vim.diagnostic.severity.ERROR,
  }, tbl or {})
end

function H.make_diags(list)
  local out = {}
  for _, d in ipairs(list) do
    table.insert(out, H.make_diagnostic(d))
  end
  return out
end

function H.make_opts(overrides)
  local base = {
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
    signs = {
      left = "",
      right = "",
      diag = "●",
      arrow = "    ",
      up_arrow = "    ",
      vertical = " │ ",
      vertical_end = " └ ",
    },
    blend = {
      factor = 0.27,
    },
    options = {
      show_source = {
        enabled = false,
        if_many = false,
      },
      show_code = true,
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
        severity = nil,
      },
      show_all_diags_on_cursorline = false,
      show_diags_only_under_cursor = false,
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
      multiple_diag_under_cursor = false,
      experimental = {
        use_window_local_extmarks = false,
      },
    },
    disabled_ft = {},
  }

  local defaults = vim.deepcopy(base.options)

  if overrides then
    base = vim.tbl_deep_extend("force", base, overrides)
  end

  local function normalize_option(value, default_value, boolean_key)
    if type(value) == "boolean" then
      return vim.tbl_deep_extend("force", default_value, { [boolean_key] = value })
    elseif type(value) == "table" then
      return vim.tbl_deep_extend("force", default_value, value)
    else
      return vim.deepcopy(default_value)
    end
  end

  base.options.multilines = normalize_option(base.options.multilines, defaults.multilines, "enabled")
  base.options.add_messages = normalize_option(base.options.add_messages, defaults.add_messages, "messages")
  base.options.show_source = normalize_option(base.options.show_source, defaults.show_source, "enabled")
  base.options.show_related = normalize_option(base.options.show_related, defaults.show_related, "enabled")

  return base
end

function H.uid_gen()
  local counter = 0
  return function()
    counter = counter + 1
    return counter
  end
end

function H.all_severities()
  return {
    vim.diagnostic.severity.ERROR,
    vim.diagnostic.severity.WARN,
    vim.diagnostic.severity.INFO,
    vim.diagnostic.severity.HINT,
  }
end

function H.set_diagnostics(buf, namespace_name, diagnostics)
  local ns = vim.api.nvim_create_namespace(namespace_name)
  vim.diagnostic.set(ns, buf, diagnostics)
  return ns
end

return H
