local M = {}

local timers = require("tiny-inline-diagnostic.timer")

local AUGROUP_NAME = "TinyInlineDiagnosticAutocmds"

local attached_buffers = {}

---@param bufnr number
---@return boolean
function M.is_attached(bufnr)
  return attached_buffers[bufnr] or false
end

---@param bufnr number
---@param cleanup_callback function|nil
function M.detach(bufnr, cleanup_callback)
  local cache = require("tiny-inline-diagnostic.cache")
  local state = require("tiny-inline-diagnostic.state")
  timers.close(bufnr)
  attached_buffers[bufnr] = nil
  cache.clear(bufnr)
  state.invalidate_render(bufnr)
  if cleanup_callback then
    cleanup_callback(bufnr)
  end
end

---@param autocmd_ns number
---@param opts table
---@param bufnr number
---@param throttle_apply function
function M.setup_cursor_autocmds(autocmd_ns, opts, bufnr, throttle_apply)
  local events = opts.options.enable_on_insert and { "CursorMoved", "CursorMovedI" }
    or { "CursorMoved" }

  vim.api.nvim_create_autocmd(events, {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      if vim.api.nvim_buf_is_valid(event.buf) then
        throttle_apply(event.buf)
      else
        M.detach(event.buf)
      end
    end,
    desc = "Update diagnostics on cursor move (throttled)",
  })
end

---@param autocmd_ns number
---@param bufnr number
---@param on_mode_change function
function M.setup_mode_change_autocmds(autocmd_ns, bufnr, on_mode_change)
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      if not vim.api.nvim_buf_is_valid(event.buf) then
        M.detach(event.buf)
        return
      end

      local mode = vim.v.event.new_mode
      on_mode_change(mode, event.buf)
    end,
  })
end

---@param autocmd_ns number
---@param opts table
---@param bufnr number
---@param throttled_apply function
---@param direct_apply function
---@param on_diagnostic_change function
function M.setup_buffer_autocmds(
  autocmd_ns,
  opts,
  bufnr,
  throttled_apply,
  direct_apply,
  on_diagnostic_change
)
  if not vim.api.nvim_buf_is_valid(bufnr) or attached_buffers[bufnr] then
    return
  end

  attached_buffers[bufnr] = true

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(args)
      if vim.api.nvim_buf_is_valid(args.buf) then
        on_diagnostic_change(args.buf, args.data.diagnostics)
        direct_apply(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "LspDetach", "BufDelete", "BufUnload", "BufWipeout" }, {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      M.detach(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = autocmd_ns,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        local state = require("tiny-inline-diagnostic.state")
        state.invalidate_render(bufnr)
        direct_apply(bufnr)
      else
        M.detach(bufnr)
      end
    end,
    desc = "Update diagnostics on window resize",
  })

  vim.api.nvim_create_autocmd({ "WinScrolled" }, {
    group = autocmd_ns,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        local state = require("tiny-inline-diagnostic.state")
        state.invalidate_render(bufnr)
        throttled_apply(bufnr)
      end
    end,
    desc = "Update diagnostics on window scroll",
  })
end

---@return number
function M.create_augroup()
  return vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
end

return M
