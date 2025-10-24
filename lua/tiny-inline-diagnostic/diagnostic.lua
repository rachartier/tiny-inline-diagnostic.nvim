local M = {}

local chunk_utils = require("tiny-inline-diagnostic.chunk")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local timers = require("tiny-inline-diagnostic.timer")
local utils = require("tiny-inline-diagnostic.utils")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")

local AUGROUP_NAME = "TinyInlineDiagnosticAutocmds"
local USER_EVENT = "TinyDiagnosticEvent"
local USER_EVENT_THROTTLED = "TinyDiagnosticEventThrottled"
local DISABLED_MODES = {}

M.enabled = true
M.user_toggle_state = true
local attached_buffers = {}

---Buffer number => diagnostics
---@type table<number, any>
local diagnostics_cache = {}

---@class DiagnosticPosition
---@field line number
---@field col number

local function enable()
  -- Prevents calling `enable` even if it's not needed
  if not M.enabled then
    M.enabled = true
    vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
  end
end

local function disable()
  if M.enabled then
    M.enabled = false
    vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
  end
end

-- Diagnostic filtering functions
---@param opts DiagnosticConfig
---@param diagnostics table
---@param line number
---@param col number
---@return table
local function filter_diags_at_position(opts, diagnostics, line, col)
  if not diagnostics or #diagnostics == 0 then
    return {}
  end

  local diags_on_line = vim.tbl_filter(function(diag)
    return diag.lnum == line
  end, diagnostics)

  if opts.options.show_all_diags_on_cursorline then
    return #diags_on_line > 0 and diags_on_line or {}
  end

  local current_pos_diags = vim.tbl_filter(function(diag)
    return diag.lnum == line and col >= diag.col and col <= diag.end_col
  end, diagnostics)

  return #current_pos_diags > 0 and current_pos_diags or diags_on_line
end

---@param opts DiagnosticConfig
---@param buf number
---@param diagnostics table
---@return table
function M.filter_diags_under_cursor(opts, buf, diagnostics)
  if
    not vim.api.nvim_buf_is_valid(buf)
    or vim.api.nvim_get_current_buf() ~= buf
    or not diagnostics
    or #diagnostics == 0
  then
    return {}
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  return filter_diags_at_position(opts, diagnostics, cursor_pos[1] - 1, cursor_pos[2])
end

---@param opts DiagnosticConfig
---@param diagnostics table
---@return table
local function filter_by_severity(opts, diagnostics)
  return vim.tbl_filter(function(diag)
    return vim.tbl_contains(opts.options.severity, diag.severity)
  end, diagnostics)
end

---@param opts DiagnosticConfig
---@param bufnr number
---@param diagnostics table
---@return table
local function filter_diagnostics(opts, bufnr, diagnostics)
  if not opts.options.multilines.enabled then
    return M.filter_diags_under_cursor(opts, bufnr, diagnostics)
  end

  if opts.options.multilines.always_show then
    return diagnostics
  end

  local under_cursor = M.filter_diags_under_cursor(opts, bufnr, diagnostics)
  return not vim.tbl_isempty(under_cursor) and under_cursor or diagnostics
end

---@param diagnostics table
---@return table<number, table>
local function get_visible_diagnostics(diagnostics)
  local first_line = vim.fn.line("w0") - 1
  local last_line = vim.fn.line("w$")
  local visible_diags = {}

  for _, diag in ipairs(diagnostics) do
    if diag.lnum >= first_line and diag.lnum <= last_line then
      visible_diags[diag.lnum] = visible_diags[diag.lnum] or {}
      table.insert(visible_diags[diag.lnum], diag)
    end
  end

  return visible_diags
end

---@param opts DiagnosticConfig
---@param bufnr number
---@param diagnostics table
local function update_diagnostics_cache(opts, bufnr, diagnostics)
  if not diagnostics or vim.tbl_isempty(diagnostics) then
    -- The event doesn't contain the associated namespace of the diagnostics,
    -- meaning we can't know which namespace was cleared. We thus have to get
    -- the diagnostics through normal means.
    local diags = vim.diagnostic.get(bufnr)
    table.sort(diags, function(a, b)
      return a.severity < b.severity
    end)
    diagnostics_cache[bufnr] = diags
    return
  end

  local diag_buf = diagnostics_cache[bufnr] or {}

  -- Do the upfront work of filtering and sorting
  diagnostics = filter_by_severity(opts, diagnostics)

  -- Find the namespaces of the incoming diagnostics.
  -- Use the namespace and not the source because the event is triggered per namespace,
  -- while the source field can be unreliable (e.g. Deno LSP seems to switch between
  -- deno and deno-ts).
  local namespaces = {}
  for _, diag in ipairs(diagnostics) do
    if not vim.tbl_contains(namespaces, diag.namespace) then
      table.insert(namespaces, diag.namespace)
    end
  end

  -- Clear the diagnostics that are from the incoming source
  diag_buf = vim.tbl_filter(function(diag)
    return not vim.tbl_contains(namespaces, diag.namespace)
  end, diag_buf)

  -- Insert and sort the results
  for _, diag in pairs(diagnostics) do
    table.insert(diag_buf, diag)
  end

  table.sort(diag_buf, function(a, b)
    return a.severity < b.severity
  end)

  diagnostics_cache[bufnr] = diag_buf
end

---@param opts DiagnosticConfig
---@param bufnr number
local function apply_virtual_texts(opts, bufnr)
  -- Validate window and state
  local current_win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(current_win) then
    return
  end

  if
    not M.user_toggle_state
    or not (M.enabled and vim.diagnostic.is_enabled() and vim.api.nvim_buf_is_valid(bufnr))
  then
    extmarks.clear(bufnr)
    return
  end

  local mode = vim.api.nvim_get_mode().mode
  if M.enabled and vim.tbl_contains(DISABLED_MODES, mode) then
    disable()
    extmarks.clear(bufnr)
    return
  end

  -- Get diagnostics and clear them if needed
  local diagnostics = diagnostics_cache[bufnr] or {}
  if vim.tbl_isempty(diagnostics) then
    extmarks.clear(bufnr)
    return
  end

  -- Process diagnostics
  local filtered_diags = filter_diagnostics(opts, bufnr, diagnostics)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local visible_diags = get_visible_diagnostics(filtered_diags)

  -- Clear existing extmarks
  extmarks.clear(bufnr)

  local diags_dims = {}
  local to_render = {}
  local virt_priority = opts.options.virt_texts.priority

  -- Create new extmarks
  for lnum, diags in pairs(visible_diags) do
    if diags then
      local diagnostic_pos = { lnum, 0 }
      local virt_lines, offset, need_to_be_under

      if lnum == cursor_line then
        virt_lines, offset, need_to_be_under =
          virtual_text_forge.from_diagnostics(opts, diags, diagnostic_pos, bufnr)
      else
        local chunks = chunk_utils.get_chunks(opts, diags, 1, diagnostic_pos[1], cursor_line, bufnr)
        local max_width = chunk_utils.get_max_width_from_chunks(chunks.chunks)
        virt_lines, offset, need_to_be_under =
          virtual_text_forge.from_diagnostic(opts, chunks, 1, max_width, 1, #diags)
      end

      table.insert(diags_dims, { lnum, #virt_lines })
      table.insert(to_render, {
        virt_lines = virt_lines,
        offset = offset,
        need_to_be_under = need_to_be_under,
        diagnostic_pos = diagnostic_pos,
      })
    end
  end

  for _, data in ipairs(to_render) do
    local virt_lines = data.virt_lines
    local offset = data.offset
    local need_to_be_under = data.need_to_be_under
    local diagnostic_pos = data.diagnostic_pos
    local signs_offset = 0

    if need_to_be_under then
      signs_offset = vim.fn.strdisplaywidth(opts.signs.left)
    else
      signs_offset = vim.fn.strdisplaywidth(opts.signs.left)
        + vim.fn.strdisplaywidth(opts.signs.arrow)
    end

    extmarks.create_extmarks(
      opts,
      bufnr,
      diagnostic_pos[1],
      diags_dims,
      virt_lines,
      offset,
      signs_offset,
      need_to_be_under,
      virt_priority
    )
  end
end

---@param buf number
local function detach_buffer(buf)
  timers.close(buf)
  attached_buffers[buf] = nil
  diagnostics_cache[buf] = nil
end

---@param autocmd_ns number
---@param opts DiagnosticConfig
---@param bufnr number
---@param throttle_apply fun(bufnr: number): nil
local function setup_cursor_autocmds(autocmd_ns, opts, bufnr, throttle_apply)
  local events = opts.options.enable_on_insert and { "CursorMoved", "CursorMovedI" }
    or { "CursorMoved" }

  vim.api.nvim_create_autocmd(events, {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      if vim.api.nvim_buf_is_valid(event.buf) then
        throttle_apply(event.buf)
      else
        detach_buffer(event.buf)
      end
    end,
    desc = "Update diagnostics on cursor move (throttled)",
  })
end

---@param autocmd_ns number
---@param bufnr number
local function setup_mode_change_autocmds(autocmd_ns, bufnr)
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      local mode = vim.fn.mode()

      if not vim.api.nvim_buf_is_valid(event.buf) then
        detach_buffer(event.buf)
        return
      end

      if vim.tbl_contains(DISABLED_MODES, mode) then
        disable()
        extmarks.clear(bufnr)
      else
        enable()
      end
    end,
  })
end

---@param autocmd_ns number
---@param opts DiagnosticConfig
---@param bufnr number
---@param throttled_apply fun(bufnr: number): nil
local function setup_buffer_autocmds(autocmd_ns, opts, bufnr, throttled_apply)
  if not vim.api.nvim_buf_is_valid(bufnr) or attached_buffers[bufnr] then
    return
  end

  attached_buffers[bufnr] = true

  -- Setup diagnostic change events
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(args)
      if vim.api.nvim_buf_is_valid(args.buf) then
        update_diagnostics_cache(opts, args.buf, args.data.diagnostics)
        vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
      end
    end,
  })

  -- Setup core diagnostic events
  vim.api.nvim_create_autocmd("User", {
    group = autocmd_ns,
    pattern = USER_EVENT,
    callback = function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        detach_buffer(bufnr)
        return
      end
      apply_virtual_texts(opts, bufnr)
    end,
  })

  -- Setup buffer cleanup events
  vim.api.nvim_create_autocmd({ "LspDetach", "BufDelete", "BufUnload", "BufWipeout" }, {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      detach_buffer(event.buf)
    end,
  })

  -- Setup throttled events
  vim.api.nvim_create_autocmd("User", {
    group = autocmd_ns,
    pattern = USER_EVENT_THROTTLED,
    callback = function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        detach_buffer(bufnr)
        return
      end
      throttled_apply(bufnr)
    end,
  })

  -- Setup window resize handling
  vim.api.nvim_create_autocmd("VimResized", {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
      else
        detach_buffer(event.buf)
      end
    end,
    desc = "Update diagnostics on window resize",
  })
end

---Setup diagnostic autocmds
---@param opts DiagnosticConfig
---@return boolean success
---@return string|nil error
function M.set_diagnostic_autocmds(opts)
  local autocmd_ns = vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
  timers.set_timers()

  local events = opts.options.overwrite_events or { "LspAttach" }

  if not opts.options.enable_on_select then
    table.insert(DISABLED_MODES, "s")
  end

  if not opts.options.enable_on_insert then
    table.insert(DISABLED_MODES, "i")
    table.insert(DISABLED_MODES, "v")
    table.insert(DISABLED_MODES, "V")
  end

  vim.api.nvim_create_autocmd(events, {
    callback = function(event)
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return
      end

      if vim.tbl_contains(opts.disabled_ft, vim.bo[event.buf].filetype) then
        return
      end

      ---@type fun(bufnr: number): nil
      local throttled_fn, timer = utils.throttle(function(bufnr)
        if vim.api.nvim_buf_is_valid(bufnr) then
          apply_virtual_texts(opts, bufnr)
        end
      end, opts.options.throttle)

      timers.add(event.buf, timer)

      setup_buffer_autocmds(autocmd_ns, opts, event.buf, throttled_fn)
      setup_cursor_autocmds(autocmd_ns, opts, event.buf, throttled_fn)
      setup_mode_change_autocmds(autocmd_ns, event.buf)
    end,
    desc = "Setup diagnostic display system",
  })

  return true
end

function M.enable()
  M.user_toggle_state = true
  vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

function M.disable()
  M.user_toggle_state = false
  vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

function M.toggle()
  M.user_toggle_state = not M.user_toggle_state
  vim.api.nvim_exec_autocmds("User", { pattern = USER_EVENT })
end

function M.get_diagnostic_under_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(buf)
  return M.filter_diags_under_cursor({ options = {} }, buf, diagnostics)
end

return M
