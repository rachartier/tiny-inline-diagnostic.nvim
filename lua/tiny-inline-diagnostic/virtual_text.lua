---@class DiagnosticConfig
---@field blend { factor: number }
---@field options table
---@field disabled_ft table

---@class ChunkInfo
---@field chunks string[]
---@field need_to_be_under boolean
---@field offset_win_col number
---@field severities table
---@field line number

local M = {}

-- Dependencies
local chunk_utils = require("tiny-inline-diagnostic.chunk")
local highlights = require("tiny-inline-diagnostic.highlights")
local utils = require("tiny-inline-diagnostic.utils")

---Format message with appropriate padding
---@param message string
---@param padding number
---@return string
local function format_chunk_message(message, padding)
  local trimmed = message
  local padding_needed = padding - vim.fn.strdisplaywidth(trimmed)
  return trimmed .. string.rep(" ", math.max(0, padding_needed))
end

---Build first chunk with header and optional arrow
---@param opts DiagnosticConfig
---@param chunk_info ChunkInfo
---@param message string
---@param hl table
---@param index_diag number
---@param total_chunks number
---@param diag_count number
---@param is_related boolean
---@return table
local function build_first_chunk(
  opts,
  chunk_info,
  message,
  hl,
  index_diag,
  total_chunks,
  diag_count,
  is_related
)
  local chunk_header = chunk_utils.get_header_from_chunk(
    message,
    index_diag,
    chunk_info,
    opts,
    hl.diag_hi,
    hl.diag_inv_hi,
    total_chunks,
    chunk_info.severities,
    diag_count,
    is_related
  )

  if index_diag == 1 and not is_related then
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    local chunk_arrow =
      chunk_utils.get_arrow_from_chunk(opts, cursor_line, chunk_info, hl.diag_inv_hi)

    if type(chunk_arrow[1]) == "table" then
      return { chunk_arrow, chunk_header }
    else
      table.insert(chunk_header, 1, chunk_arrow)
      return { chunk_header }
    end
  end

  return { chunk_header }
end

--- Generate virtual text from a diagnostic.
--- @param opts DiagnosticConfig
--- @param ret ChunkInfo
--- @param index_diag number Index of the current diagnostic.
--- @param padding number Padding to align the text.
--- @param total_chunks number Total number of chunks.
--- @param diag_count number Number of diagnostics on the line.
--- @return table, number, boolean Virtual texts, offset window column, and whether it needs to be under.
function M.from_diagnostic(opts, ret, index_diag, padding, total_chunks, diag_count)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  local diag_hi, diag_inv_hi, body_hi =
    highlights.get_diagnostic_highlights(opts.blend.factor, ret, cursor_line, index_diag)

  local all_virtual_texts = {}

  for index_chunk, chunk in ipairs(ret.chunks) do
    local message = format_chunk_message(chunk, padding)

    if index_chunk == 1 then
      local first_chunks = build_first_chunk(
        opts,
        ret,
        message,
        { diag_hi = diag_hi, diag_inv_hi = diag_inv_hi },
        index_diag,
        total_chunks,
        diag_count,
        ret.is_related or false
      )
      vim.list_extend(all_virtual_texts, first_chunks)
    else
      local chunk_body = chunk_utils.get_body_from_chunk(
        message,
        index_diag,
        index_chunk,
        #ret.chunks,
        ret.need_to_be_under,
        opts,
        diag_hi,
        body_hi,
        total_chunks
      )
      table.insert(all_virtual_texts, chunk_body)
    end
  end

  if ret.need_to_be_under then
    table.insert(all_virtual_texts, 1, { { " ", "None" } })
  end

  return all_virtual_texts, ret.offset_win_col, ret.need_to_be_under
end

--- Generate virtual text from multiple diagnostics.
--- @param opts DiagnosticConfig
--- @param diags_on_line table[]
--- @param cursor_pos number[]
--- @param buf number
--- @return table, number, boolean Virtual texts, offset window column, and whether it needs to be under.
function M.from_diagnostics(opts, diags_on_line, cursor_pos, buf)
  local all_virtual_texts = {}
  local offset_win_col = 0
  local need_to_be_under = false

  local chunks = {}
  local max_chunk_line_length = 0
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  for index = 1, #diags_on_line do
    local ret = chunk_utils.get_chunks(opts, diags_on_line, index, cursor_pos[1], current_line, buf)
    local chunk_line_length = chunk_utils.get_max_width_from_chunks(ret.chunks)
    max_chunk_line_length = math.max(max_chunk_line_length, chunk_line_length)
    chunks[index] = ret
  end

  for index_diag, ret in ipairs(chunks) do
    local virt_texts, _, diag_need_to_be_under =
      M.from_diagnostic(opts, ret, index_diag, max_chunk_line_length, #chunks, #diags_on_line)

    need_to_be_under = need_to_be_under or diag_need_to_be_under

    if need_to_be_under and index_diag > 1 then
      table.remove(virt_texts, 1)
    end

    vim.list_extend(all_virtual_texts, virt_texts)
  end

  return all_virtual_texts, offset_win_col, need_to_be_under
end

return M
