local M = {}

local timers = require("tiny-inline-diagnostic.timer")

local AUGROUP_NAME = "TinyInlineDiagnosticAutocmds"

local attached_buffers = {}
local last_cursor_positions = {}

---@param bufnr number
---@return boolean
function M.is_attached(bufnr)
  return attached_buffers[bufnr] or false
end

---@param bufnr number
---@param cleanup_callback function|nil
function M.detach(bufnr, cleanup_callback)
  local cache = require("tiny-inline-diagnostic.cache")
  timers.close(bufnr)
  attached_buffers[bufnr] = nil
  last_cursor_positions[bufnr] = nil
  cache.clear(bufnr)
  if cleanup_callback then
    cleanup_callback(bufnr)
  end
end

---@param autocmd_ns number
---@param opts table
---@param bufnr number
---@param throttle_apply function
---@param direct_apply function
function M.setup_cursor_autocmds(autocmd_ns, opts, bufnr, throttle_apply, direct_apply)
  local events = opts.options.enable_on_insert and { "CursorMoved", "CursorMovedI" }
    or { "CursorMoved" }

  vim.api.nvim_create_autocmd(events, {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      if not vim.api.nvim_buf_is_valid(event.buf) then
        M.detach(event.buf)
        return
      end

      local current_pos = vim.api.nvim_win_get_cursor(0)
      local current_line = current_pos[1]
      local last_pos = last_cursor_positions[event.buf]

      if last_pos then
        local line_diff = math.abs(current_line - last_pos[1])
        last_cursor_positions[event.buf] = current_pos

        if line_diff > 1 then
          direct_apply(event.buf)
        else
          throttle_apply(event.buf)
        end
      else
        last_cursor_positions[event.buf] = current_pos
        throttle_apply(event.buf)
      end
    end,
    desc = "Update diagnostics on cursor move (throttled for small moves, direct for jumps)",
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
---@param on_window_change function
function M.setup_buffer_autocmds(
  autocmd_ns,
  opts,
  bufnr,
  throttled_apply,
  direct_apply,
  on_diagnostic_change,
  on_window_change
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
        local all_diagnostics = vim.diagnostic.get(args.buf)
        on_diagnostic_change(args.buf, all_diagnostics)
        direct_apply(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = autocmd_ns,
    buffer = bufnr,
    callback = function(event)
      local remaining_clients = vim.lsp.get_clients({ bufnr = event.buf })
      local has_other_clients = false

      for _, client in ipairs(remaining_clients) do
        if client.id ~= event.data.client_id then
          has_other_clients = true
          break
        end
      end

      if not has_other_clients then
        M.detach(event.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload", "BufWipeout" }, {
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
        direct_apply(bufnr)
      else
        M.detach(bufnr)
      end
    end,
    desc = "Update diagnostics on window resize",
  })

  if opts.options.experimental.use_window_local_extmarks then
    vim.api.nvim_create_autocmd("WinEnter", {
      group = autocmd_ns,
      callback = on_window_change,
      desc = "Sync namespace window on window change",
    })
  end
end

---@return number
function M.create_augroup()
  return vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
end

return M
