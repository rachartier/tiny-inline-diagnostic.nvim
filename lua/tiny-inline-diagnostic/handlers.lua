local M = {}

local utils = require("tiny-inline-diagnostic.utils")

---Compute events list for diagnostic autocmds
---@param opts table Plugin options
---@return string[] List of event names
function M.compute_events(opts)
  return opts.options.overwrite_events or { "LspAttach" }
end

---Build throttled renderer function with timer
---@param opts table Plugin options
---@param renderer table Renderer module
---@return table { fn: function, timer: table }
function M.build_throttled_renderer(opts, renderer)
  local throttled_fn, timer = utils.throttle(function(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      renderer.render(opts, bufnr)
    end
  end, opts.options.throttle)

  return {
    fn = throttled_fn,
    timer = timer,
  }
end

---Build direct (non-throttled) renderer function
---@param opts table Plugin options
---@param renderer table Renderer module
---@return function Renderer function(bufnr: number)
function M.build_direct_renderer(opts, renderer)
  return function(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      renderer.render(opts, bufnr)
    end
  end
end

---Build diagnostic change handler closure
---@param cache table Cache module
---@param opts table Plugin options
---@return function Handler function(buf: number, diagnostics: table)
function M.build_diagnostic_change_handler(cache, opts)
  return function(buf, diagnostics)
    cache.update(opts, buf, diagnostics)
  end
end

---Build mode change handler closure
---@param state table State module
---@param renderer table Renderer module
---@param opts table Plugin options
---@return function Handler function(mode: string, bufnr: number)
function M.build_mode_change_handler(state, renderer, opts)
  return function(mode, bufnr)
    if state.is_mode_disabled(mode) then
      state.disable()
      renderer.render(opts, bufnr)
    else
      state.enable()
      renderer.render(opts, bufnr)
    end
  end
end

return M
