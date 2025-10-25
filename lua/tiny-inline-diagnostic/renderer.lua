local M = {}

local cache = require("tiny-inline-diagnostic.cache")
local chunk_utils = require("tiny-inline-diagnostic.chunk")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local filter = require("tiny-inline-diagnostic.filter")
local state = require("tiny-inline-diagnostic.state")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")

---@param opts table
---@param bufnr number
function M.safe_render(opts, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  M.render(opts, bufnr)
end

---@param opts table
---@param bufnr number
function M.render(opts, bufnr)
  local current_win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(current_win) then
    return
  end

  if
    not state.user_toggle_state
    or not (state.enabled and vim.diagnostic.is_enabled() and vim.api.nvim_buf_is_valid(bufnr))
  then
    extmarks.clear(bufnr)
    return
  end

  local diagnostics = cache.get(bufnr)
  if vim.tbl_isempty(diagnostics) then
    extmarks.clear(bufnr)
    return
  end

  local filtered_diags = filter.for_display(opts, bufnr, diagnostics)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local visible_diags = filter.visible(filtered_diags)

  extmarks.clear(bufnr)

  local diags_dims = {}
  local to_render = {}
  local virt_priority = opts.options.virt_texts.priority

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

return M
