local M = {}

local extmarks = require("tiny-inline-diagnostic.extmarks")
local highlights = require("tiny-inline-diagnostic.highlights")
local overflow_strategies = require("tiny-inline-diagnostic.overflow_strategies")

--- Calculate the maximum width from a list of chunks.
---@param chunks table: A table representing the chunks of a diagnostic message.
---@return number: The maximum width among all chunks.
function M.get_max_width_from_chunks(chunks)
  local max_chunk_line_length = 0

  for _, chunk in ipairs(chunks) do
    local line_length = vim.fn.strdisplaywidth(chunk)
    if line_length > max_chunk_line_length then
      max_chunk_line_length = line_length
    end
  end

  return max_chunk_line_length
end

--- Generate a header for a diagnostic message chunk.
---@param message string: The diagnostic message.
---@param index_diag number: The index of the diagnostic message.
---@param chunk_info ChunkInfo
---@param opts table: The options table, which includes signs for the diagnostic message.
---@param diag_hi string: The highlight group for the diagnostic message.
---@param diag_inv_hi string: The highlight group for the diagnostic signs.
---@param total_chunks number: The total number of chunks.
---@param severities table: The severities of the diagnostic messages.
---@param diag_count number: The number of diagnostics on the line.
---@param is_related boolean: Whether this is a related diagnostic.
---@return table: A table representing the virtual text array for the diagnostic message header.
function M.get_header_from_chunk(
  message,
  index_diag,
  chunk_info,
  opts,
  diag_hi,
  diag_inv_hi,
  total_chunks,
  severities,
  diag_count,
  is_related
)
  local virt_texts = {}
  local num_chunks = #chunk_info.chunks

  if index_diag == 1 then
    virt_texts = { { opts.signs.left, diag_inv_hi } }
  end

  if is_related then
    vim.list_extend(virt_texts, { { "  ", diag_hi } })
  else
    vim.list_extend(virt_texts, { { " ", diag_hi } })
  end

  if index_diag == 1 and total_chunks == 1 and not is_related then
    M.add_severity_icons(virt_texts, opts, severities, diag_hi)
  end

  local icon = M.get_diagnostic_icon(opts, severities, index_diag, total_chunks)
  if is_related then
    icon = "↳ "
  end
  vim.list_extend(virt_texts, { { icon, diag_hi } })

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local add_messages_opts = type(opts.options.add_messages) == "table" and opts.options.add_messages
    or {
      messages = opts.options.add_messages,
      display_count = false,
      use_max_severity = false,
      show_multiple_glyphs = true,
    }

  local add_messages = add_messages_opts.messages
  local display_count = add_messages_opts.display_count
  local show_multiple_glyphs = add_messages_opts.show_multiple_glyphs
  local use_max_severity = add_messages_opts.use_max_severity

  if display_count and cursor_line ~= chunk_info.line and not is_related then
    if use_max_severity then
      local max_severity = severities[1]
      for _, sev in ipairs(severities) do
        if sev < max_severity then
          max_severity = sev
        end
      end
      local count = 0
      for _, sev in ipairs(severities) do
        if sev == max_severity then
          count = count + 1
        end
      end
      message = count
    else
      message = #severities
    end
  elseif not add_messages and cursor_line ~= chunk_info.line and not is_related then
    message = ""
  end

  M.add_message_text(
    virt_texts,
    message,
    num_chunks,
    total_chunks,
    index_diag,
    opts,
    diag_hi,
    diag_inv_hi,
    is_related or false
  )

  return virt_texts
end

--- Add severity icons to the virtual text array.
---@param virt_texts table: The virtual text array.
---@param opts table: The options table.
---@param severities table: The severities of the diagnostic messages.
---@param diag_hi string: The highlight group for the diagnostic message.
function M.add_severity_icons(virt_texts, opts, severities, diag_hi)
  if not severities or #severities == 0 then
    return
  end

  local add_messages_opts = type(opts.options.add_messages) == "table" and opts.options.add_messages
    or {
      messages = opts.options.add_messages,
      display_count = false,
      use_max_severity = false,
      show_multiple_glyphs = true,
    }

  local show_multiple_glyphs = add_messages_opts.show_multiple_glyphs
  local use_max_severity = add_messages_opts.use_max_severity

  local sorted_severities = vim.deepcopy(severities)
  table.sort(sorted_severities)

  local main_severity = sorted_severities[1]

  if use_max_severity then
    if show_multiple_glyphs then
      local count = 0
      for _, sev in ipairs(severities) do
        if sev == main_severity then
          count = count + 1
        end
      end

      for i = 1, count - 1 do
        local hl =
          highlights.get_diagnostic_mixed_highlights_from_severity(main_severity, main_severity)
        local icon = opts.signs.diag

        if opts.options.use_icons_from_diagnostic then
          icon = highlights.get_diagnostic_icon(main_severity)
        end

        vim.list_extend(virt_texts, { { icon, hl } })
      end
    end
    return
  end

  if show_multiple_glyphs then
    for i = #sorted_severities, 2, -1 do
      local severity = sorted_severities[i]
      local hl = highlights.get_diagnostic_mixed_highlights_from_severity(main_severity, severity)
      local icon = opts.signs.diag

      if opts.options.use_icons_from_diagnostic then
        icon = highlights.get_diagnostic_icon(severity)
      end

      vim.list_extend(virt_texts, { { icon, hl } })
    end
  else
    local unique_severities = {}
    local seen = {}
    for _, sev in ipairs(sorted_severities) do
      if not seen[sev] then
        seen[sev] = true
        table.insert(unique_severities, sev)
      end
    end

    for i = #unique_severities, 2, -1 do
      local severity = unique_severities[i]
      local hl = highlights.get_diagnostic_mixed_highlights_from_severity(main_severity, severity)
      local icon = opts.signs.diag

      if opts.options.use_icons_from_diagnostic then
        icon = highlights.get_diagnostic_icon(severity)
      end

      vim.list_extend(virt_texts, { { icon, hl } })
    end
  end
end

--- Get the diagnostic icon based on the options and severities.
---@param opts table: The options table.
---@param severities table: The severities of the diagnostic messages.
---@param index_diag number: The index of the diagnostic message.
---@param total_chunks number: The total number of chunks.
---@return string: The diagnostic icon.
function M.get_diagnostic_icon(opts, severities, index_diag, total_chunks)
  local icon = opts.signs.diag

  if opts.options.use_icons_from_diagnostic then
    if total_chunks == 1 then
      icon = highlights.get_diagnostic_icon(severities[#severities])
    else
      icon = highlights.get_diagnostic_icon(severities[index_diag])
    end
  end

  return icon
end

--- Add the message text to the virtual text array.
---@param virt_texts table: The virtual text array.
---@param message string: The diagnostic message.
---@param num_chunks number: The total number of chunks the message is split into.
---@param total_chunks number: The total number of chunks.
---@param index_diag number: The index of the diagnostic message.
---@param opts table: The options table.
---@param diag_hi string: The highlight group for the diagnostic message.
---@param diag_inv_hi string: The highlight group for the diagnostic signs.
---@param is_related boolean: Whether this is a related diagnostic.
function M.add_message_text(
  virt_texts,
  message,
  num_chunks,
  total_chunks,
  index_diag,
  opts,
  diag_hi,
  diag_inv_hi,
  is_related
)
  local text_after_message = " "
  local text_before_message = " "

  if is_related then
    text_before_message = ""
  end

  if num_chunks == 1 then
    if total_chunks == 1 or index_diag == total_chunks then
      if message ~= "" then
        message = message .. " "
      end
      vim.list_extend(
        virt_texts,
        { { text_before_message .. message, diag_hi }, { opts.signs.right, diag_inv_hi } }
      )
    else
      vim.list_extend(virt_texts, {
        { text_before_message .. message .. text_after_message, diag_hi },
      })
    end
  else
    vim.list_extend(virt_texts, {
      { text_before_message .. message .. text_after_message, diag_hi },
    })
  end
end

--- Generate the body for a diagnostic message chunk.
---@param chunk string: The chunk of the diagnostic message.
---@param index_diag number: The index of the diagnostic message.
---@param index_chunk number: The index of the chunk.
---@param num_chunks number: The total number of chunks the message is split into.
---@param need_to_be_under boolean: A flag indicating whether the arrow needs to point upwards.
---@param opts table: The options table, which includes signs for the diagnostic message.
---@param diag_hi string: The highlight group for the diagnostic message.
---@param diag_inv_hi string: The highlight group for the diagnostic signs.
---@param total_chunks number: The total number of chunks.
---@param is_related boolean: Whether this is a related diagnostic.
---@return table: A table representing the virtual text array for the diagnostic message body.
function M.get_body_from_chunk(
  chunk,
  index_diag,
  index_chunk,
  num_chunks,
  need_to_be_under,
  opts,
  diag_hi,
  diag_inv_hi,
  total_chunks,
  is_related
)
  local vertical_sign = opts.signs.vertical
  local is_last = index_diag == total_chunks and index_chunk == num_chunks

  if index_chunk == num_chunks then
    vertical_sign = opts.signs.vertical_end
  end

  local chunk_virtual_texts
  if is_related then
    chunk_virtual_texts = {
      { "    " .. chunk, diag_hi },
      { " ", diag_hi },
    }
  else
    chunk_virtual_texts = {
      { vertical_sign, diag_hi },
      { " " .. chunk, diag_hi },
      { " ", diag_hi },
    }
  end

  if is_last then
    vim.list_extend(chunk_virtual_texts, { { opts.signs.right, diag_inv_hi } })
  end

  return chunk_virtual_texts
end

--- Get the arrow for a diagnostic message chunk.
---@param opts table: The options table.
---@param diagnostic_line number: The line number of the diagnostic message.
---@param ret table: The return table containing diagnostic information.
---@param hl_diag_hi string: The highlight group for the diagnostic message.
---@return table: A table representing the virtual text array for the arrow.
function M.get_arrow_from_chunk(opts, diagnostic_line, ret, hl_diag_hi)
  local arrow = opts.signs.arrow
  local need_to_be_under = ret.need_to_be_under

  local chunk = {}

  local hi = "TinyInlineDiagnosticVirtualTextArrow"
  if opts.options.set_arrow_to_diag_color then
    hi = hl_diag_hi
  end

  if diagnostic_line ~= ret.line or ret.need_to_be_under then
    hi = "TinyInlineDiagnosticVirtualTextArrowNoBg"

    if opts.options.set_arrow_to_diag_color then
      hi = hl_diag_hi
    end
  end

  if need_to_be_under then
    arrow = opts.signs.up_arrow
    chunk = {
      { "", "None" },
      { arrow, hi },
    }
  else
    chunk = { arrow, hi }
  end

  return chunk
end

--- Split a diagnostic message into chunks for overflow handling.
---@param message string: The diagnostic message.
---@param offset number: The offset from the start of the line to the diagnostic position.
---@param win_width number: The width of the window where the diagnostic message is displayed.
---@param opts table: The options table, which includes signs for the diagnostic message and the softwrap option.
---@return table: A table representing the chunks of the diagnostic message.
function M.get_message_chunks_for_overflow(message, offset, win_width, opts)
  return overflow_strategies.apply_wrap(message, false, win_width, opts)
end

--- Get the chunks for a diagnostic message.
---@param opts table: The options table.
---@param diags_on_line table: The diagnostics on the line.
---@param diag_index number: The index of the diagnostic message.
---@param diag_line number: The line number of the diagnostic message.
---@param cursor_line number: The line number of the cursor.
---@param buf number: The buffer number.
---@return table: A table containing the chunks and other diagnostic information.
function M.get_chunks(opts, diags_on_line, diag_index, diag_line, cursor_line, buf)
  local win_width = vim.api.nvim_win_get_width(0)
  local lines = vim.api.nvim_buf_get_lines(buf, diag_line, diag_line + 1, false)
  local line_length = lines[1] and #lines[1] or 0
  local offset = 0
  local need_to_be_under = false

  local diag = diags_on_line[diag_index]

  local show_source = false
  if type(opts.options.show_source) == "table" then
    if opts.options.show_source.enabled then
      if opts.options.show_source.if_many then
        local sources = {}
        for _, d in ipairs(diags_on_line) do
          if d.source then
            sources[d.source] = true
          end
        end
        show_source = vim.tbl_count(sources) > 1
      else
        show_source = true
      end
    end
  elseif opts.options.show_source then
    show_source = true
  end

  local diag_message = diag.message
  if diag.is_related then
    local location_info = ""
    if diag.related_location and diag.related_location.uri then
      local uri = diag.related_location.uri
      local filename = vim.uri_to_fname(uri)
      local short_name = vim.fn.fnamemodify(filename, ":t")
      if diag.related_location.range and diag.related_location.range.start then
        local line_num = diag.related_location.range.start.line + 1
        location_info = string.format(" [%s:%d]", short_name, line_num)
      else
        location_info = string.format(" [%s]", short_name)
      end
    end
    diag_message = diag_message .. location_info
  elseif show_source and diag.source then
    diag_message = diag_message .. " (" .. diag.source .. ")"
  end

  local chunks = { diag_message }
  local severities = vim.tbl_map(function(d)
    return d.severity
  end, diags_on_line)

  local other_extmarks_offset = extmarks.handle_other_extmarks(buf, diag_line, line_length)

  if
    (opts.options.overflow.mode ~= "none" and not opts.options.multilines)
    or cursor_line == diag_line
  then
    if (line_length + other_extmarks_offset) > win_width - opts.options.softwrap then
      need_to_be_under = true
    end
  end

  if opts.options.format and diag_message and not diag.is_related then
    diag_message = opts.options.format(diag)
  end

  if not opts.options.multilines or cursor_line == diag_line then
    chunks = M.handle_overflow_modes(
      opts,
      diag_message,
      need_to_be_under,
      win_width,
      offset,
      diag.is_related or false
    )
  else
    chunks = { " " .. diag_message }
  end

  return {
    chunks = chunks,
    severity = diag.severity,
    severities = severities,
    source = diag.source,
    offset = offset,
    offset_win_col = other_extmarks_offset,
    need_to_be_under = need_to_be_under,
    line = diag.lnum,
    is_related = diag.is_related or false,
  }
end

--- Handle different overflow modes for diagnostic messages.
---@param opts table: The options table.
---@param diag_message string: The diagnostic message.
---@param need_to_be_under boolean: A flag indicating whether the arrow needs to point upwards.
---@param win_width number: The width of the window where the diagnostic message is displayed.
---@param offset number: The offset from the start of the line to the diagnostic position.
---@param is_related boolean: Whether this is a related diagnostic.
---@return table: A table representing the chunks of the diagnostic message.
function M.handle_overflow_modes(
  opts,
  diag_message,
  need_to_be_under,
  win_width,
  offset,
  is_related
)
  local chunks = {}

  if opts.options.break_line.enabled then
    chunks = overflow_strategies.apply_break_line(diag_message, opts)
  elseif opts.options.overflow.mode == "wrap" then
    chunks =
      overflow_strategies.apply_wrap(diag_message, need_to_be_under, win_width, opts, is_related)
  elseif opts.options.overflow.mode == "none" then
    chunks = overflow_strategies.apply_none(diag_message, opts)
  elseif opts.options.overflow.mode == "oneline" then
    chunks = overflow_strategies.apply_oneline(diag_message)
  end

  return chunks
end

return M
