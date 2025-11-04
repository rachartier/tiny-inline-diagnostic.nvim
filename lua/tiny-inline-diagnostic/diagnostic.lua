local M = {}

local autocmds = require("tiny-inline-diagnostic.autocmds")
local cache = require("tiny-inline-diagnostic.cache")
local filter = require("tiny-inline-diagnostic.filter")
local handlers = require("tiny-inline-diagnostic.handlers")
local renderer = require("tiny-inline-diagnostic.renderer")
local state = require("tiny-inline-diagnostic.state")
local timers = require("tiny-inline-diagnostic.timer")

M.enabled = state.enabled
M.user_toggle_state = state.user_toggle_state

---@param opts table
---@param buf number
---@param diagnostics table
---@return table
function M.filter_diags_under_cursor(opts, buf, diagnostics)
  return filter.under_cursor(opts, buf, diagnostics)
end

---@param opts table
---@return boolean
function M.set_diagnostic_autocmds(opts)
  local autocmd_ns = autocmds.create_augroup()
  timers.set_timers()

  state.init(opts)

  local events = handlers.compute_events(opts)

  vim.api.nvim_create_autocmd(events, {
    group = autocmd_ns,
    callback = function(event)
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return
      end

      if vim.tbl_contains(opts.disabled_ft, vim.bo[event.buf].filetype) then
        return
      end

      if autocmds.is_attached(event.buf) then
        return
      end

      local throttler = handlers.build_throttled_renderer(opts, renderer)
      local direct_renderer = handlers.build_direct_renderer(opts, renderer)
      timers.add(event.buf, throttler.timer)

      local on_diagnostic_change = handlers.build_diagnostic_change_handler(cache, opts)
      local on_mode_change = handlers.build_mode_change_handler(state, renderer, opts)

      autocmds.setup_buffer_autocmds(
        autocmd_ns,
        opts,
        event.buf,
        throttler.fn,
        direct_renderer,
        on_diagnostic_change
      )
      autocmds.setup_cursor_autocmds(autocmd_ns, opts, event.buf, throttler.fn)
      autocmds.setup_mode_change_autocmds(autocmd_ns, event.buf, on_mode_change)

      local existing_diagnostics = vim.diagnostic.get(event.buf)
      if existing_diagnostics and #existing_diagnostics > 0 then
        cache.update(opts, event.buf, existing_diagnostics)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(event.buf) then
            direct_renderer(event.buf)
          end
        end)
      end
    end,
    desc = "Setup diagnostic display system",
  })

  return true
end

function M.enable()
  state.user_enable()
  local config = require("tiny-inline-diagnostic").config

  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
        if config then
          renderer.safe_render(config, bufnr)
        end
      end
    end
  end)
end

function M.disable()
  state.user_disable()
  local extmarks = require("tiny-inline-diagnostic.extmarks")

  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        extmarks.clear(bufnr)
      end
    end
  end)
end

function M.toggle()
  state.user_toggle()

  if state.user_toggle_state then
    M.enable()
  else
    M.disable()
  end
end

function M.get_diagnostic_under_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(buf)
  return M.filter_diags_under_cursor({ options = {} }, buf, diagnostics)
end

return M
