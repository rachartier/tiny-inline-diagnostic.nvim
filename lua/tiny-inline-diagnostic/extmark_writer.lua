local M = {}

---@param buf number
---@param namespace number
---@param line number
---@param virt_text table
---@param win_col number
---@param priority number
---@param pos string|nil
---@param uid_fn function
function M.create_single_extmark(buf, namespace, line, virt_text, win_col, priority, pos, uid_fn)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local extmark_opts = {
    id = uid_fn(),
    virt_text = virt_text,
    virt_text_pos = pos or "eol",
    virt_text_win_col = win_col,
    priority = priority,
    strict = false,
  }

  vim.api.nvim_buf_set_extmark(buf, namespace, line, 0, extmark_opts)
end

---@param buf number
---@param namespace number
---@param curline number
---@param virt_lines table
---@param priority number
---@param uid_fn function
function M.create_multiline_extmark(buf, namespace, curline, virt_lines, priority, uid_fn)
  local remaining_lines = { unpack(virt_lines, 2) }

  local virt_lines_trimmed = {}
  for i, t in ipairs(virt_lines[1]) do
    local ktrimmed = i == 1 and t[1] or t[1]:gsub("%s+", " ")
    virt_lines_trimmed[i] = { ktrimmed, t[2] }
  end

  vim.api.nvim_buf_set_extmark(buf, namespace, curline, 0, {
    id = uid_fn(),
    virt_text_pos = "eol",
    virt_text = virt_lines_trimmed,
    virt_lines = remaining_lines,
    priority = priority,
    strict = false,
  })
end

---@param buf number
---@param namespace number
---@param params table
---@param uid_fn function
function M.create_overflow_extmarks(buf, namespace, params, uid_fn)
  local existing_lines = params.buf_lines_count - params.curline
  local start_index = params.need_to_be_under and 3 or 1
  local signs_offset = params.need_to_be_under and (params.signs_offset == 0 and 0 or 1)
    or params.signs_offset

  if params.need_to_be_under then
    M.create_single_extmark(
      buf,
      namespace,
      params.curline + 1,
      params.virt_lines[2],
      params.win_col,
      params.priority,
      nil,
      uid_fn
    )
  end

  for i = start_index, existing_lines do
    local col_offset = params.win_col + params.offset + (i > start_index and signs_offset or 0)
    M.create_single_extmark(
      buf,
      namespace,
      params.curline + i - 1,
      params.virt_lines[i],
      col_offset,
      params.priority,
      "overlay",
      uid_fn
    )
  end

  local overflow_lines = {}
  for i = existing_lines + 1, #params.virt_lines do
    local line = vim.deepcopy(params.virt_lines[i])
    local col_offset = params.win_col + params.offset + (i > start_index and signs_offset or 0)
    table.insert(line, 1, { string.rep(" ", col_offset), "None" })
    table.insert(overflow_lines, line)
  end

  if #overflow_lines > 0 then
    vim.api.nvim_buf_set_extmark(buf, namespace, params.buf_lines_count - 1, 0, {
      id = uid_fn(),
      virt_lines_above = false,
      virt_lines = overflow_lines,
      priority = params.priority,
      strict = false,
    })
  end
end

---@param buf number
---@param namespace number
---@param curline number
---@param virt_lines table
---@param win_col number
---@param offset number
---@param signs_offset number
---@param priority number
---@param uid_fn function
function M.create_simple_extmarks(
  buf,
  namespace,
  curline,
  virt_lines,
  win_col,
  offset,
  signs_offset,
  priority,
  uid_fn
)
  for i = 1, #virt_lines do
    local col_offset = i == 1 and win_col or (win_col + offset + signs_offset)
    M.create_single_extmark(
      buf,
      namespace,
      curline + i - 1,
      virt_lines[i],
      col_offset,
      priority,
      i > 1 and "overlay" or nil,
      uid_fn
    )
  end
end

return M
