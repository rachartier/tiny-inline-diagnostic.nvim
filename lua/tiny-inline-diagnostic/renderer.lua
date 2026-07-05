local M = {}

local cache = require("tiny-inline-diagnostic.cache")
local chunk_utils = require("tiny-inline-diagnostic.chunk")
local extmarks = require("tiny-inline-diagnostic.extmarks")
local filter = require("tiny-inline-diagnostic.filter")
local state = require("tiny-inline-diagnostic.state")
local virtual_text_forge = require("tiny-inline-diagnostic.virtual_text")

---@param bufnr number
---@return table|nil
local function validate_and_prepare_state(bufnr)
  local current_win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(current_win) then
    return nil
  end

  if
    not state.user_toggle_state
    or not (state.enabled and vim.diagnostic.is_enabled({ bufnr = bufnr }) and vim.api.nvim_buf_is_valid(bufnr))
  then
    extmarks.clear(bufnr)
    return nil
  end

  local diagnostics = cache.get(bufnr)
  if vim.tbl_isempty(diagnostics) then
    local live_diagnostics = vim.diagnostic.get(bufnr)
    if live_diagnostics and #live_diagnostics > 0 then
      diagnostics = live_diagnostics
    else
      extmarks.clear(bufnr)
      return nil
    end
  end

  return diagnostics
end

---@param opts table
---@param bufnr number
---@param diagnostics table
---@param cursor_line number
---@return table, table
local function build_render_plan(opts, bufnr, diagnostics, cursor_line)
  local filtered_diags = filter.for_display(opts, bufnr, diagnostics)
  local visible_diags = filter.visible(filtered_diags)

  local diags_dims = {}
  local plan = {}

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
          virtual_text_forge.from_diagnostic(opts, chunks, 1, max_width, 1)
      end

      table.insert(diags_dims, { lnum, #virt_lines })
      table.insert(plan, {
        virt_lines = virt_lines,
        offset = offset,
        need_to_be_under = need_to_be_under,
        diagnostic_pos = diagnostic_pos,
      })
    end
  end

  return plan, diags_dims
end

---@param opts table
---@param bufnr number
---@param plan table
---@param diags_dims table
---@param virt_priority number
local function apply_render_plan(opts, bufnr, plan, diags_dims, virt_priority)
  local left_width = vim.fn.strdisplaywidth(opts.signs.left)
  local arrow_width = vim.fn.strdisplaywidth(opts.signs.arrow)

  for _, item in ipairs(plan) do
    local signs_offset = item.need_to_be_under and left_width or left_width + arrow_width
    extmarks.create_extmarks(
      opts,
      bufnr,
      item.diagnostic_pos[1],
      diags_dims,
      item.virt_lines,
      item.offset,
      signs_offset,
      item.need_to_be_under,
      virt_priority
    )
  end
end

---@param opts table
---@param bufnr number
function M.safe_render(opts, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  M.render(opts, bufnr)
end

---@param bufnr number
---@return number|nil
local function resolve_render_win(bufnr)
  local current_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_is_valid(current_win) and vim.api.nvim_win_get_buf(current_win) == bufnr then
    return current_win
  end
  local wins = vim.fn.win_findbuf(bufnr)
  return wins and wins[1] or nil
end

---@param opts table
---@param bufnr number
function M.render(opts, bufnr)
  local diagnostics = validate_and_prepare_state(bufnr)
  if not diagnostics then
    return
  end

  local winid = resolve_render_win(bufnr)
  if not winid then
    extmarks.clear(bufnr)
    return
  end

  vim.api.nvim_win_call(winid, function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    extmarks.clear(bufnr)

    local plan, diags_dims = build_render_plan(opts, bufnr, diagnostics, cursor_line)
    apply_render_plan(opts, bufnr, plan, diags_dims, opts.options.virt_texts.priority)
  end)
end

return M
